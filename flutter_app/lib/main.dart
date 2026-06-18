import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/event.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
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

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  Consistency consistency;
  if (consistencyStr == 'normal') {
    consistency = Consistency.normal;
  } else if (consistencyStr == 'jurasica') {
    consistency = Consistency.jurasica;
  } else if (consistencyStr == 'espurruteo') {
    consistency = Consistency.espurruteo;
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
    username: user.displayName ?? 'Usuario',
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

  await dbService.addEvent(newEvent);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TrackerScreen(),
    RankingScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

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
          setState(() {
            _currentIndex = index;
          });
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
      body: _screens[_currentIndex],
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
