"use strict";

// Cloud Functions de KKpenco: envían avisos push (FCM) ante nuevos eventos,
// duelos y mensajes de chat. La API legacy de envío desde el cliente la cerró
// Google en 2024, así que el envío server-side se hace aquí, en un entorno de
// confianza. Requiere plan Blaze (activo). Desplegar desde `flutter_app/`:
//   cd functions && npm install
//   cd .. && firebase deploy --only functions

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Defaults de preferencias IDÉNTICOS al cliente
// (DatabaseService.defaultNotifPrefs): eventos y duelos activos, chat opt-in.
const DEFAULT_PREFS = { events: true, duels: true, chat: false };

function prefEnabled(userData, key) {
  const prefs = (userData && userData.notifPrefs) || {};
  const val = prefs[key];
  return typeof val === "boolean" ? val : DEFAULT_PREFS[key];
}

/**
 * Envía una notificación a un conjunto de usuarios (por uid), respetando su
 * preferencia `prefKey` y su token FCM. Excluye a los uids indicados y limpia
 * los tokens que ya no estén registrados.
 */
async function notifyUsers({
  prefKey,
  recipientUids,
  excludeUids = [],
  title,
  body,
  data = {},
}) {
  const exclude = new Set(excludeUids);
  const uids = [...new Set(recipientUids)].filter(
    (uid) => uid && !exclude.has(uid)
  );
  if (uids.length === 0) return;

  const refs = uids.map((uid) => db.collection("users").doc(uid));
  const snaps = await db.getAll(...refs);

  const targets = []; // { uid, token }
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const u = snap.data();
    if (!u.fcmToken) continue;
    if (!prefEnabled(u, prefKey)) continue;
    targets.push({ uid: snap.id, token: u.fcmToken });
  }
  if (targets.length === 0) return;

  const stringData = {};
  for (const [k, v] of Object.entries(data)) stringData[k] = String(v);

  const res = await messaging.sendEachForMulticast({
    tokens: targets.map((t) => t.token),
    notification: { title, body },
    data: stringData,
    android: { priority: "high" },
  });

  // Limpieza de tokens caducados/invalidos
  const cleanups = [];
  res.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      cleanups.push(
        db
          .collection("users")
          .doc(targets[i].uid)
          .update({ fcmToken: admin.firestore.FieldValue.delete() })
      );
    } else {
      logger.warn("Fallo al enviar push", { uid: targets[i].uid, code });
    }
  });
  await Promise.all(cleanups);
}

async function allOtherUserUids(excludeUid) {
  // El grupo es pequeño: leer la colección `users` (unos pocos docs) es barato.
  const snap = await db.collection("users").get();
  return snap.docs.map((d) => d.id).filter((id) => id !== excludeUid);
}

// 1) Nueva KK -> avisar al resto del grupo
exports.onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data) return;
  const authorUid = data.userId;
  const username = data.username || "Alguien";
  const recipients = await allOtherUserUids(authorUid);
  await notifyUsers({
    prefKey: "events",
    recipientUids: recipients,
    excludeUids: [authorUid],
    title: "💩 ¡Nueva KK!",
    body: `${username} acaba de registrar una KK`,
    data: { type: "event" },
  });
});

// 2) Duelo creado -> avisar al desafiado
exports.onDuelCreated = onDocumentCreated("duels/{duelId}", async (event) => {
  const d = event.data && event.data.data();
  if (!d) return;
  await notifyUsers({
    prefKey: "duels",
    recipientUids: [d.challengedId],
    excludeUids: [d.challengerId],
    title: "⚔️ ¡Te han retado!",
    body: `${d.challengerName || "Alguien"} te ha desafiado a un duelo de cacas`,
    data: { type: "duel", duelId: event.params.duelId },
  });
});

// 3) Duelo aceptado/finalizado -> avisar a ambos participantes
exports.onDuelUpdated = onDocumentUpdated("duels/{duelId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (before.status === after.status) return;

  const both = [after.challengerId, after.challengedId];

  if (after.status === "active") {
    await notifyUsers({
      prefKey: "duels",
      recipientUids: both,
      title: "⚔️ ¡Duelo aceptado!",
      body: `El duelo entre ${after.challengerName} y ${after.challengedName} ha comenzado`,
      data: { type: "duel", duelId: event.params.duelId },
    });
  } else if (after.status === "finished") {
    const chCount = after.challengerCount || 0;
    const cdCount = after.challengedCount || 0;
    let result;
    if (chCount === cdCount) {
      result = `Empate a ${chCount} 💩`;
    } else {
      const winner =
        chCount > cdCount ? after.challengerName : after.challengedName;
      result = `Ganó ${winner} (${Math.max(chCount, cdCount)}-${Math.min(
        chCount,
        cdCount
      )}) 💩`;
    }
    await notifyUsers({
      prefKey: "duels",
      recipientUids: both,
      title: "🏁 Duelo finalizado",
      body: result,
      data: { type: "duel", duelId: event.params.duelId },
    });
  }
});

// 5) Autodestrucción de cuenta. Debe ser server-side: las reglas de Firestore
// no permiten al dueño borrar su propio doc de `users` ni sus eventos de más
// de 5 minutos, así que el borrado desde el cliente fallaba SIEMPRE. Con el
// Admin SDK las reglas no aplican. El cliente reautentica antes de llamar.
// Orden: datos primero, usuario de Auth al final — si algo falla a medias, la
// cuenta sigue existiendo y se puede reintentar sin dejar huérfanos sin dueño.
exports.deleteMyAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para eliminar tu cuenta."
    );
  }

  try {
    // 1. Referencias a borrar: eventos del usuario + monthly_stats + su doc
    const eventsSnap = await db
      .collection("events")
      .where("userId", "==", uid)
      .get();
    const statsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("monthly_stats")
      .get();

    const refs = [
      ...eventsSnap.docs.map((d) => d.ref),
      ...statsSnap.docs.map((d) => d.ref),
      db.collection("users").doc(uid),
    ];

    // 2. Borrado en lotes de 500 (límite de un batch de Firestore)
    for (let i = 0; i < refs.length; i += 500) {
      const batch = db.batch();
      refs.slice(i, i + 500).forEach((ref) => batch.delete(ref));
      await batch.commit();
    }

    // 3. Storage: avatar y fotos subidas al chat. No bloquea el borrado si
    // falla (p. ej. sin archivos): los datos personales clave ya no existen.
    const bucket = admin.storage().bucket();
    await Promise.all([
      bucket
        .deleteFiles({ prefix: `avatars/${uid}` })
        .catch((e) => logger.warn("Storage avatars", { uid, e: e.message })),
      bucket
        .deleteFiles({ prefix: `chat_images/${uid}/` })
        .catch((e) => logger.warn("Storage chat", { uid, e: e.message })),
    ]);

    // 4. Usuario de Auth, al final de todo
    await admin.auth().deleteUser(uid);

    logger.info("Cuenta eliminada", { uid, events: eventsSnap.size });
    return { deletedEvents: eventsSnap.size };
  } catch (e) {
    logger.error("Fallo al eliminar la cuenta", { uid, error: e.message });
    throw new HttpsError(
      "internal",
      "No se pudo completar el borrado. Inténtalo de nuevo."
    );
  }
});

// 4) Mensaje de chat -> avisar al resto (opt-in, desactivado por defecto)
exports.onChatCreated = onDocumentCreated("chat/{msgId}", async (event) => {
  const m = event.data && event.data.data();
  if (!m) return;
  // No avisar de los mensajes del sistema (logros, duelos, nudges)
  if (m.userId === "system" || m.type === "system") return;
  const authorUid = m.userId;
  const username = m.username || "Alguien";
  const content = (m.content || "").toString();
  const body =
    content.length > 80
      ? `${content.substring(0, 77)}...`
      : content || "📷 Foto";
  const recipients = await allOtherUserUids(authorUid);
  await notifyUsers({
    prefKey: "chat",
    recipientUids: recipients,
    excludeUids: [authorUid],
    title: username,
    body,
    data: { type: "chat" },
  });
});
