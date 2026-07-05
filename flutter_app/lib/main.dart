import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/event.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';

@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;
  final consistencyStr = uri.queryParameters['consistency'];
  if (consistencyStr == null) return;

  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización segura de Firebase en segundo plano
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Si ya está inicializado
  }

  User? user = FirebaseAuth.instance.currentUser;
  user ??= await FirebaseAuth.instance.authStateChanges().first;
  if (user == null) return;

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
    id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
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
  // y una escritura solo encolada en local no se sincronizaría hasta abrir la app
  await dbService.addEvent(newEvent, waitForServerAck: true);

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
      title: '¡Registro añadido! 💩',
      body: 'Tu registro rápido ($consistencyStr) se ha guardado con éxito.',
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

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
  }

  @override
  void dispose() {
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
      body: AnimatedBuilder(
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
