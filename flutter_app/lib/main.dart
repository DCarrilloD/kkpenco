import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/event.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/push_notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/widget_data_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';

@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización segura de Firebase en segundo plano
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Si ya está inicializado
  }

  // Rutas de los widgets: kkpenco://express?consistency=X (botonera) y
  // kkpenco://mojona (botón 1x1 con armado en dos toques)
  if (uri.host == 'mojona') {
    await _handleMojonaTap();
  } else if (uri.host == 'express') {
    final consistencyStr = uri.queryParameters['consistency'];
    if (consistencyStr == null) return;
    await _quickAddFromWidget(consistencyStr);
  }
}

/// «La Mojona»: el primer toque arma el botón (borde ámbar, 5 s) y el segundo
/// dentro de la ventana registra una KK Normal. Evita registros por roce.
Future<void> _handleMojonaTap() async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final armedRaw = await HomeWidget.getWidgetData<String>('mojonaArmedMillis');

  if (mojonaTapConfirms(armedMillisRaw: armedRaw, nowMillis: now)) {
    await HomeWidget.saveWidgetData<String>('mojonaArmedMillis', '');
    await HomeWidget.updateWidget(androidName: 'MojonaWidgetProvider');
    await _quickAddFromWidget('normal');
    return;
  }

  // Armar y re-renderizar; si nadie confirma, desarmar al expirar la ventana
  // (este isolate sigue vivo unos segundos sin problema).
  final armedValue = '$now';
  await HomeWidget.saveWidgetData<String>('mojonaArmedMillis', armedValue);
  await HomeWidget.updateWidget(androidName: 'MojonaWidgetProvider');
  await Future.delayed(const Duration(milliseconds: 5500));
  final current = await HomeWidget.getWidgetData<String>('mojonaArmedMillis');
  if (current == armedValue) {
    await HomeWidget.saveWidgetData<String>('mojonaArmedMillis', '');
    await HomeWidget.updateWidget(androidName: 'MojonaWidgetProvider');
  }
}

/// Registro rápido desde cualquier widget, con guardia anti-doble-toque y
/// feedback real de resultado (éxito / sin conexión / sin sesión).
Future<void> _quickAddFromWidget(String consistencyStr) async {
  Consistency consistency;
  if (consistencyStr == 'normal') {
    consistency = Consistency.normal;
  } else if (consistencyStr == 'jurasica') {
    consistency = Consistency.jurasica;
  } else if (consistencyStr == 'espurruteo') {
    consistency = Consistency.espurruteo;
  } else if (consistencyStr == 'cabra') {
    consistency = Consistency.cabra;
  } else {
    return;
  }

  // Anti-doble-toque: dos toques nerviosos creaban dos KKs (y dos puntos en
  // el ranking). La guardia se arma ANTES de escribir nada.
  final now = DateTime.now().millisecondsSinceEpoch;
  final lastRaw = await HomeWidget.getWidgetData<String>('lastQuickAddMillis');
  if (shouldIgnoreQuickTap(lastAcceptedMillisRaw: lastRaw, nowMillis: now)) {
    return;
  }
  await HomeWidget.saveWidgetData<String>('lastQuickAddMillis', '$now');

  User? user = FirebaseAuth.instance.currentUser;
  // Timeout: sin él, un authStateChanges que nunca emite colgaría el isolate de
  // background del widget indefinidamente. La lógica pesada de logros ya se
  // eliminó de addEvent en 2.1 (contadores agregados en el batch).
  user ??= await FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(const Duration(seconds: 10), onTimeout: () => null);
  if (user == null) {
    await WidgetDataService.saveLastStatus('nosession');
    await WidgetDataService.updateAllWidgets();
    await _showWidgetNotification(
      'Sesión necesaria 🔑',
      'Abre KKpenco e inicia sesión para registrar desde el widget.',
    );
    return;
  }

  final dbService = DatabaseService();
  const int durationSecs = 300; // 5 minutos por defecto
  const location = LocationTag.casa;
  const color = PoopColor.cafe;
  const int difficulty = 3;
  final double estimatedWeight = KKEvent.calculateWeight(
    consistency: consistency,
    durationSeconds: durationSecs,
    difficulty: difficulty,
  );

  final newEvent = KKEvent(
    id: '', // el ID real lo genera addEvent
    userId: user.uid,
    displayName: user.displayName,
    timestamp: DateTime.now(),
    duration: durationSecs,
    consistency: consistency,
    color: color,
    location: location,
    difficulty: difficulty,
    estimatedWeight: estimatedWeight,
    notes: 'Registro rápido desde Escritorio ⚡📱',
    latitude: null,
    longitude: null,
  );

  // Esperar el ack del servidor: este isolate de background muere al acabar
  // y una escritura solo encolada en local no se sincronizaría hasta abrir la
  // app. Con timeout: sin conexión, antes se colgaba y moría SIN avisar.
  try {
    await dbService
        .addEvent(newEvent, waitForServerAck: true)
        .timeout(const Duration(seconds: 12));
  } on TimeoutException {
    // La escritura queda en la persistencia local de Firestore y se
    // sincroniza al abrir la app; el usuario merece saberlo.
    await WidgetDataService.saveLastStatus('offline', lastPoop: DateTime.now());
    await WidgetDataService.updateAllWidgets();
    await _showWidgetNotification(
      'Sin conexión 📡',
      'Tu registro ($consistencyStr) se guardará al abrir la app.',
    );
    return;
  } catch (e) {
    debugPrint('Error en registro rápido desde widget: $e');
    await _showWidgetNotification(
      'No se pudo guardar 😢',
      'Inténtalo de nuevo o abre la app.',
    );
    return;
  }

  await _showWidgetNotification(
    '¡Registro añadido! 💩',
    'Tu registro rápido ($consistencyStr) se ha guardado con éxito.',
  );
  // Refrescar racha/contadores/ranking que pintan los widgets
  await WidgetDataService.refresh();
}

Future<void> _showWidgetNotification(String title, String body) async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'kkpenco_quick',
      'Registros Rápidos',
      channelDescription: 'Notificaciones de registros desde el widget',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  } catch (e) {
    debugPrint('Error showing notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setLowRefreshRate(); // Forzar 60Hz por defecto para ahorrar batería
    } catch (e) {
      debugPrint('No se pudo establecer display mode: $e');
    }
  }

  // Registro del callback interactivo del Widget de Escritorio (solo Android e iOS)
  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    await HomeWidget.registerInteractivityCallback(interactiveCallback);
  }

  // Inicialización segura de Firebase
  try {
    // Si no está configurado para Windows y estamos en Windows, forzamos Mock Mode de inmediato
    if (defaultTargetPlatform == TargetPlatform.windows && !kIsWeb) {
      useMockData = true;
      debugPrint("Plataforma Windows detectada. Activando Modo Simulación.");
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase inicializado correctamente.");
    }
  } catch (e) {
    // Si falla por falta de configuración (ej. en desktop o local sin config)
    useMockData = true;
    debugPrint("Error al inicializar Firebase. Activando Modo Simulación: $e");
  }

  // Registrar el handler de mensajes push en segundo plano. Debe hacerse aquí,
  // antes de runApp, y solo con Firebase disponible (Android, no simulación).
  if (defaultTargetPlatform == TargetPlatform.android && !useMockData) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const KKpencoApp());
}

class KKpencoApp extends StatelessWidget {
  const KKpencoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KKpenco 2026',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.userChanges,
      builder: (context, snapshot) {
        // En modo simulación o si la sesión ya está activa de forma síncrona
        final user = useMockData ? authService.currentUser : snapshot.data;

        if (useMockData || snapshot.connectionState == ConnectionState.active) {
          if (user == null) {
            return const LoginScreen();
          } else {
            return const MainNavigationScreen();
          }
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late final AnimationController _tabTransitionController;

  // Solo las pestañas visitadas se montan; una vez montadas, el IndexedStack
  // las mantiene vivas (estado y streams persisten entre cambios de pestaña).
  final Set<int> _builtTabs = {0};

  final List<Widget> _screens = const [
    TrackerScreen(),
    RankingScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
    // Con sesión activa: pedir permiso de notificaciones y registrar el token
    // FCM del dispositivo para que las Cloud Functions puedan enviar avisos.
    _setupPushNotifications();
    // Reconciliar el email de Firestore con el de Auth (un cambio de email se
    // confirma por enlace, quizá con la app cerrada; changeEmail ya no escribe
    // en Firestore por adelantado).
    AuthService().syncEmailWithFirestore();
    // Publicar racha/contadores/ranking para los widgets de escritorio
    WidgetDataService.refresh();
    // Deep links de los widgets: kkpenco://open?tab=N[&trono=1] (tanto si la
    // app arranca desde el widget como si ya estaba abierta)
    if (!useMockData && defaultTargetPlatform == TargetPlatform.android) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
      _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
    }
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null || !mounted || uri.host != 'open') return;

    final tab = int.tryParse(uri.queryParameters['tab'] ?? '');
    if (tab != null && tab >= 0 && tab < _screens.length && tab != _currentIndex) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = tab;
        _builtTabs.add(tab);
      });
      _tabTransitionController.forward(from: 0.0);
    }

    // Widget «El Trono»: abrir con el cronómetro ya en marcha. El instante de
    // inicio es la llegada del intent (los PendingIntent de RemoteViews son
    // estáticos y no pueden llevar la hora del toque).
    if (uri.queryParameters['trono'] == '1') {
      TrackerScreen.tronoStartRequest.value = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _setupPushNotifications() async {
    if (useMockData) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    final push = PushNotificationService();
    await push.init();
    await push.registerDeviceForUser(uid);
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _tabTransitionController.dispose();
    super.dispose();
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    Widget? iconWidget,
    IconData? fallbackIcon,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentIndex == index) return;
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
            _builtTabs.add(index);
          });
          _tabTransitionController.forward(from: 0.0);
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.4,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isSelected ? 1.15 : 1.0,
                  child: iconWidget ?? Icon(
                    fallbackIcon,
                    size: 44,
                    color: isSelected ? Colors.brown[400] : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.brown[300] : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabTransitionController,
              builder: (context, child) {
                // Escala premium sutil tridimensional (Zoom 3D refinado del 3%) sobre la
                // pestaña entrante. El IndexedStack mantiene las pantallas montadas, así
                // que cambiar de pestaña no re-suscribe streams ni relee Firestore.
                final t = Curves.easeOutCubic.transform(_tabTransitionController.value);
                final direction = _currentIndex >= _previousIndex ? 1.0 : -1.0;
                final double beginScale = direction > 0 ? 1.03 : 0.97;
                final double scale = beginScale + (1.0 - beginScale) * t;
                final double opacity = (0.35 + 0.65 * t).clamp(0.0, 1.0);

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  for (int i = 0; i < _screens.length; i++)
                    _builtTabs.contains(i) ? _screens[i] : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF181818),
          border: Border(
            top: BorderSide(
              color: Color(0xFF262626),
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              label: 'Tracker',
              iconWidget: Image.asset(
                'assets/2.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
            _buildNavItem(
              index: 1,
              label: 'Ranking',
              iconWidget: Image.asset(
                'assets/opt-2.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
            _buildNavItem(
              index: 2,
              label: 'COS',
              iconWidget: Builder(
                builder: (context) {
                  final isSelected = _currentIndex == 2;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_rounded,
                        size: 44,
                        color: isSelected ? Colors.brown[400] : Colors.grey[500],
                      ),
                      const Positioned(
                        top: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'COS',
                              style: TextStyle(
                                color: Color(0xFF181818),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              'CHAT',
                              style: TextStyle(
                                color: Color(0xFF181818),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildNavItem(
              index: 3,
              label: 'Perfil',
              iconWidget: Image.asset(
                'assets/3.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Banner que aparece cuando no hay conexión. La persistencia offline de
// Firestore encola las escrituras, así que los registros se sincronizan solos
// al volver la red; esto es solo un aviso visual.
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner();

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  late final Stream<bool> _statusStream;

  @override
  void initState() {
    super.initState();
    _statusStream = ConnectivityService().onStatusChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _statusStream,
      builder: (context, snapshot) {
        // Sin dato aún (o en mock) asumimos conexión: no mostrar nada.
        final online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();
        return const Material(
          color: Color(0xFF7A3B00),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sin conexión — tus registros se sincronizarán al volver',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
