import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kkpenco/services/auth_service.dart';
import 'package:kkpenco/services/database_service.dart';
import 'package:kkpenco/models/event.dart';

/// Pruebas de regresión de PLAN_MEJORAS_2.md:
/// - 1.2: addEvent devuelve el evento persistido con su ID real, de modo que
///   borrar una KK recién registrada (ventana de 5 minutos) funciona y los
///   contadores del ranking quedan cuadrados.
/// - 2.2: los duelos terminan al llegar alguien a 5 puntos (misma regla que
///   en Firebase) y quedan marcados como 'finished' con fecha de fin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    useMockData = true;
    SharedPreferences.setMockInitialValues({});
  });

  KKEvent buildEvent(String userId, String username) {
    return KKEvent(
      id: '', // el ID real lo asigna addEvent
      userId: userId,
      displayName: username,
      timestamp: DateTime.now(),
      duration: 300,
      consistency: Consistency.normal,
      color: PoopColor.cafe,
      location: LocationTag.casa,
      difficulty: 3,
      estimatedWeight: 300.0,
      notes: null,
    );
  }

  group('1.2 ID real al guardar y borrar una KK recién creada', () {
    test('addEvent devuelve el evento con un ID existente en el historial', () async {
      final authService = AuthService();
      final dbService = DatabaseService();
      await authService.signIn(email: 'david@test.com', password: 'x');
      final user = authService.currentUser!;

      final saved = await dbService.addEvent(buildEvent(user.uid, user.displayName));

      expect(saved.id, isNotEmpty);
      final events = await dbService.getUserEvents(user.uid);
      expect(events.any((e) => e.id == saved.id), isTrue,
          reason: 'El evento devuelto debe existir en el historial con ese mismo ID');
    });

    test('guardar → borrar deja el historial y el contador como estaban', () async {
      final authService = AuthService();
      final dbService = DatabaseService();
      await authService.signIn(email: 'david@test.com', password: 'x');
      final user = authService.currentUser!;

      final countBefore = (await dbService.getUserEvents(user.uid)).length;
      final rankingBefore = await dbService.getRanking().first;
      final rankBefore = rankingBefore.firstWhere(
        (r) => r['uid'] == user.uid,
        orElse: () => {'poopCount': 0},
      )['poopCount'] as int;

      final saved = await dbService.addEvent(buildEvent(user.uid, user.displayName));

      // Borrado dentro de la ventana de 5 minutos, con el ID devuelto
      await dbService.deleteEvent(saved);

      final eventsAfter = await dbService.getUserEvents(user.uid);
      expect(eventsAfter.length, countBefore,
          reason: 'El evento debe desaparecer del historial (antes el ID fantasma dejaba el evento vivo)');
      expect(eventsAfter.any((e) => e.id == saved.id), isFalse);

      final rankingAfter = await dbService.getRanking().first;
      final rankAfter = rankingAfter.firstWhere(
        (r) => r['uid'] == user.uid,
        orElse: () => {'poopCount': 0},
      )['poopCount'] as int;
      expect(rankAfter, rankBefore,
          reason: 'El contador del ranking no debe quedar desincronizado tras guardar y borrar');
    });
  });

  group('2.2 Fin de duelo unificado (primero a 5 puntos)', () {
    test('el duelo pasa a finished al llegar el retador a 5', () async {
      final authService = AuthService();
      final dbService = DatabaseService();
      await authService.signIn(email: 'david@test.com', password: 'x');
      final user = authService.currentUser!;

      await dbService.sendDuelChallenge('rival_uid', 'Rival');
      var duels = await dbService.getActiveDuels(user.uid).first;
      final duelId = duels.last['id'];
      await dbService.acceptDuelChallenge(duelId);

      // 5 KKs del retador → primero a 5 gana
      for (int i = 0; i < 5; i++) {
        await dbService.addEvent(buildEvent(user.uid, user.displayName));
      }

      duels = await dbService.getActiveDuels(user.uid).first;
      final duel = duels.firstWhere((d) => d['id'] == duelId);
      expect(duel['status'], 'finished');
      expect(duel['challengerCount'], 5);
      expect(duel['finishedAt'], isA<DateTime>(),
          reason: 'finishedAt marca cuándo dejar de mostrar la tarjeta de resultado');
    });
  });
}
