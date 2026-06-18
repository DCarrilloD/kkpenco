import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

enum ActiveGame { none, selectMenu, cacaCatch, flappyPoop, toiletJump, poopInvaders, storeMenu }

class TronoZenScreen extends StatefulWidget {
  const TronoZenScreen({super.key});

  @override
  State<TronoZenScreen> createState() => _TronoZenScreenState();
}

class _TronoZenScreenState extends State<TronoZenScreen> with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  // Timer Zen
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _timeString = '00:00';
  int _elapsedSeconds = 0;

  // Zen Music Control
  bool _isMusicEnabled = true;
  bool _alternateGameTrack = false;
  String? _currentlyPlayingSource;
  late AnimationController _soundAnimController;

  // Audio Player Zen
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Active Game State
  ActiveGame _activeGame = ActiveGame.none;
  int _score = 0;
  int _lives = 3;
  double _gameWidth = 300;
  double _gameHeight = 400;

  // High Scores
  int _highScoreCacaCatch = 0;
  int _highScoreFlappyPoop = 0;
  int _highScoreToiletJump = 0;
  int _highScorePoopInvaders = 0;

  // Poop Invaders Variables
  bool _isInvadersGameOver = false;
  Timer? _poopInvadersTimer;
  double _invadersShipX = 0.5;
  double _invadersShipY = 0.85;
  final List<InvaderLaser> _invaderLasers = [];
  final List<InvaderEnemy> _invaderEnemies = [];
  double _invaderSpawnProb = 0.03;
  double _invaderSpeed = 1.3;
  int _invaderShootCooldown = 0;
  bool _hasTripleShot = false;
  int _tripleShotTicksRemaining = 0;
  bool _hasBurstShot = false;
  int _burstShotTicksRemaining = 0;
  bool _isBossActive = false;
  double _bossX = 0.5;
  double _bossVx = 1.2;
  int _bossHp = 0;
  int _bossMaxHp = 10;
  int _bossShootCooldown = 0;
  final List<InvaderItem> _invaderItems = [];

  // --- MOTOR DE JUICINESS (JUGOSIDAD) ---
  final List<GameParticle> _particles = [];
  double _shakeX = 0;
  double _shakeY = 0;
  double _shakeIntensity = 0;
  int _shakeTicks = 0;
  Color? _flashColor;
  int _flashTicks = 0;

  // --- VARIABLES DE LA TIENDA Y RECOMPENSAS ---
  int _kcoins = 0;
  String _equippedSkin = '💩';
  List<String> _unlockedSkins = ['💩'];
  bool _hasInitialSoapShield = false;
  bool _hasInitialSpring = false;
  bool _hasFeverMagnet = false;
  bool _hasExtraLife = false;
  bool _isMagnetActive = false;
  bool _hasImprovedMagnet = false;
  bool _hasLifeInsurance = false;
  String _selectedGameFilter = 'todos';

  // --- VARIABLES DE JUEGO PROFESIONAL ---
  DateTime? _lastTickTime;
  final List<FloatingText> _floatingTexts = [];
  int _comboMultiplier = 1;
  int _poopsCaughtConsecutively = 0;
  bool _isPaused = false;
  bool _isCacaCatchGameOver = false;

  // Game 1: Caca Catch Variables
  double _toiletX = 0.5;
  final List<CatchItem> _catchItems = [];
  Timer? _cacaCatchTimer;
  double _catchSpawnProb = 0.05;
  double _catchSpeed = 0.015;
  
  bool _isFeverMode = false;
  int _feverTicksRemaining = 0;
  bool _hasSoapShield = false;
  int _soapShieldTicksRemaining = 0;
  bool _isSodaFrenzy = false;
  int _sodaFrenzyTicksRemaining = 0;

  // Game 2: Flappy Poop Variables
  final double _flappyX = 115.0;
  double _flappyY = 200;
  double _flappyVelocity = 0;
  final List<FlappyPipe> _flappyPipes = [];
  Timer? _flappyTimer;
  bool _isFlappyGameOver = false;
  double _flappyBgX = 0;
  bool _hasFlappyShield = false;

  // Game 3: Toilet Jump Variables
  double _jumpX = 150;
  double _jumpY = 300;
  double _jumpVx = 0;
  double _jumpVy = 0;
  double _cameraY = 0;
  final List<JumpPlatform> _jumpPlatforms = [];
  final List<BacteriaEnemy> _jumpBacterias = [];
  Timer? _toiletJumpTimer;
  bool _isJumpGameOver = false;
  double _maxHeightReached = 0;
  double _cacaScaleX = 1.0;
  double _cacaScaleY = 1.0;
  bool _hasJetpack = false;
  int _jetpackTicksRemaining = 0;
  bool _hasBalloon = false;
  int _balloonTicksRemaining = 0;


  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    
    _soundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadHighScores();
    _loadZenProfile();
    _loadMusicPreference();
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopCacaCatch();
    _stopFlappyPoop();
    _stopToiletJump();
    _stopPoopInvaders();
    _soundAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _highScoreCacaCatch = prefs.getInt('high_score_caca_catch') ?? 0;
        _highScoreFlappyPoop = prefs.getInt('high_score_flappy_poop') ?? 0;
        _highScoreToiletJump = prefs.getInt('high_score_toilet_jump') ?? 0;
        _highScorePoopInvaders = prefs.getInt('high_score_poop_invaders') ?? 0;
      });
    }
  }

  Future<void> _saveHighScore(String key, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt('high_score_$key') ?? 0;
    if (score > currentHigh) {
      await prefs.setInt('high_score_$key', score);
      await _loadHighScores();
    }
  }

  // --- MÉTODOS DE LA TIENDA Y RECOMPENSAS ---
  Future<void> _loadZenProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profile = await _dbService.getUserZenProfile(user.uid);
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _kcoins = profile['kcoins'] ?? 0;
          _equippedSkin = profile['equippedSkin'] ?? '💩';
          _unlockedSkins = List<String>.from(profile['unlockedSkins'] ?? ['💩']);
          _hasImprovedMagnet = prefs.getBool('zen_passive_magnet_${user.uid}') ?? false;
          _hasLifeInsurance = prefs.getBool('zen_passive_insurance_${user.uid}') ?? false;
        });
      }
    }
  }

  Future<void> _loadMusicPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMusicEnabled = prefs.getBool('zen_music_enabled') ?? true;
      });
      _updateMusicPlayback();
    }
  }

  Future<void> _toggleMusic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('zen_music_enabled', value);
    setState(() {
      _isMusicEnabled = value;
    });
    _updateMusicPlayback();
  }

  Future<void> _updateMusicPlayback() async {
    try {
      if (!_isMusicEnabled) {
        if (_currentlyPlayingSource != null) {
          await _audioPlayer.stop();
          _currentlyPlayingSource = null;
        }
        return;
      }

      final isMinigame = _activeGame == ActiveGame.cacaCatch ||
          _activeGame == ActiveGame.flappyPoop ||
          _activeGame == ActiveGame.toiletJump ||
          _activeGame == ActiveGame.poopInvaders;

      final String targetSource;
      final bool isLocal;

      if (isMinigame) {
        targetSource = _alternateGameTrack
            ? r"D:\CHROME\.old\Audio\First_Light_on_the_Ridge.mp3"
            : r"D:\CHROME\.old\Audio\Village_of_Seven_Springs.mp3";
        isLocal = true;
      } else {
        targetSource = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3';
        isLocal = false;
      }

      if (_currentlyPlayingSource == targetSource) {
        await _audioPlayer.setVolume(0.12);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.12);

      if (isLocal) {
        await _audioPlayer.play(DeviceFileSource(targetSource));
      } else {
        await _audioPlayer.play(UrlSource(targetSource));
      }
      _currentlyPlayingSource = targetSource;
    } catch (e) {
      debugPrint('Error updating music playback: $e');
    }
  }

  void _onGameStarted() {
    _alternateGameTrack = !_alternateGameTrack;
    _updateMusicPlayback();
  }

  Future<void> _buyAndEquipSkin(String skin, int cost) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_unlockedSkins.contains(skin)) {
      HapticFeedback.selectionClick();
      await _dbService.equipSkin(user.uid, skin);
      await _loadZenProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Aspecto "$skin" equipado con éxito! 🎭'),
          backgroundColor: Colors.brown[700],
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_kcoins < cost) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡No tienes suficientes Kakadólares! 💰 Registra KKs para ganar más.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final success = await _dbService.buySkin(user.uid, skin, cost);
    if (success) {
      await _dbService.equipSkin(user.uid, skin);
      await _loadZenProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Aspecto "$skin" comprado y equipado! 🎉 -$cost Kakadólares.'),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  Future<void> _buyPowerup(String id, int cost) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_kcoins < cost) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡No tienes suficientes Kakadólares! 💰'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool alreadyHas = false;
    if (id == 'shield' && _hasInitialSoapShield) alreadyHas = true;
    if (id == 'spring' && _hasInitialSpring) alreadyHas = true;
    if (id == 'magnet' && _hasFeverMagnet) alreadyHas = true;
    if (id == 'life' && _hasExtraLife) alreadyHas = true;
    if (id == 'passive_magnet' && _hasImprovedMagnet) alreadyHas = true;
    if (id == 'passive_insurance' && _hasLifeInsurance) alreadyHas = true;

    if (alreadyHas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Ya tienes esta mejora activa o adquirida! 🎮'),
          backgroundColor: Colors.amber[800],
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    await _dbService.addKcoins(user.uid, -cost);
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (id == 'shield') _hasInitialSoapShield = true;
      if (id == 'spring') _hasInitialSpring = true;
      if (id == 'magnet') _hasFeverMagnet = true;
      if (id == 'life') _hasExtraLife = true;
      if (id == 'passive_magnet') {
        _hasImprovedMagnet = true;
        prefs.setBool('zen_passive_magnet_${user.uid}', true);
      }
      if (id == 'passive_insurance') {
        _hasLifeInsurance = true;
        prefs.setBool('zen_passive_insurance_${user.uid}', true);
      }
    });

    await _loadZenProfile();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Power-up activado para la siguiente partida! 🚀 -$cost Kakadólares.'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  // --- HELPERS DE JUEGO PROFESIONAL ---
  double _calculateDeltaTime() {
    final now = DateTime.now();
    if (_lastTickTime == null) {
      _lastTickTime = now;
      return 0.03;
    }
    final diff = now.difference(_lastTickTime!).inMicroseconds / 1000000.0;
    _lastTickTime = now;
    return diff.clamp(0.01, 0.1);
  }

  void _spawnFloatingText(double x, double y, String text, Color color, {double fontSize = 16.0}) {
    final rand = Random();
    _floatingTexts.add(FloatingText(
      x: x,
      y: y,
      vx: (rand.nextDouble() * 2 - 1.0) * 1.5,
      vy: -2.0 - rand.nextDouble() * 2.0,
      text: text,
      color: color,
      fontSize: fontSize,
      lifeTime: 25,
    ));
  }

  Widget _buildInGameOverlay(ActiveGame game, VoidCallback onRestart) {
    bool showPause = _isPaused;
    bool showGameOver = false;
    int record = 0;
    String title = '';
    Color accentColor = Colors.amberAccent;

    if (game == ActiveGame.cacaCatch) {
      showGameOver = _isCacaCatchGameOver;
      record = _highScoreCacaCatch;
      title = 'CACA CATCH 🚽';
      accentColor = Colors.brown;
    } else if (game == ActiveGame.flappyPoop) {
      showGameOver = _isFlappyGameOver;
      record = _highScoreFlappyPoop;
      title = 'FLAPPY POOP 💩🕊️';
      accentColor = Colors.deepPurpleAccent;
    } else if (game == ActiveGame.toiletJump) {
      showGameOver = _isJumpGameOver;
      record = _highScoreToiletJump;
      title = 'TOILET JUMP 💩jump';
      accentColor = Colors.orangeAccent;
    } else if (game == ActiveGame.poopInvaders) {
      showGameOver = _isInvadersGameOver;
      record = _highScorePoopInvaders;
      title = 'POOP INVADERS 👾';
      accentColor = Colors.greenAccent;
    }

    if (!showPause && !showGameOver) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withAlpha(showPause ? 140 : 180),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showPause ? Icons.pause_circle_filled_rounded : Icons.sentiment_very_dissatisfied_rounded,
                      color: showPause ? Colors.amberAccent : Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showPause ? 'JUEGO EN PAUSA' : '¡FIN DE PARTIDA!',
                      style: TextStyle(
                        color: showPause ? Colors.white : Colors.redAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(color: accentColor.withAlpha(200), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          const Text('PUNTUACIÓN', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(
                            '$_score',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Récord: $record pts', style: TextStyle(color: Colors.yellow[700], fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showPause) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[850],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isPaused = false;
                                _lastTickTime = DateTime.now();
                              });
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Reanudar', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showPause ? Colors.grey[900] : Colors.amber[850],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onRestart();
                          },
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(showPause ? 'Reiniciar' : 'Jugar de Nuevo', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _exitToMenu();
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                      label: const Text('Volver al Menú', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- MÉTODOS DEL MOTOR DE JUGOSIDAD ---
  void _triggerShake(double intensity, int ticks) {
    _shakeIntensity = intensity;
    _shakeTicks = ticks;
  }

  void _triggerFlash(Color color, int ticks) {
    _flashColor = color;
    _flashTicks = ticks;
  }

  void _updateJuicyEffects(double dt) {
    final rand = Random();
    // Actualizar temblor
    if (_shakeTicks > 0) {
      _shakeX = (rand.nextDouble() * 2 - 1) * _shakeIntensity;
      _shakeY = (rand.nextDouble() * 2 - 1) * _shakeIntensity;
      _shakeTicks--;
    } else {
      _shakeX = 0;
      _shakeY = 0;
      _shakeIntensity = 0;
    }

    // Actualizar flash
    if (_flashTicks > 0) {
      _flashTicks--;
    } else {
      _flashColor = null;
    }

    // Actualizar partículas
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].lifeTime <= 0) {
        _particles.removeAt(i);
      }
    }
  }

  void _spawnParticles(double x, double y, String emoji, int count, {double speed = 4.0}) {
    final rand = Random();
    for (int i = 0; i < count; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final dist = rand.nextDouble() * speed + 1.0;
      _particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * dist,
        vy: sin(angle) * dist - (emoji == '💦' || emoji == '🫧' ? 2.0 : 0.0),
        emoji: emoji,
        scale: 0.8 + rand.nextDouble() * 0.5,
        lifeTime: 12 + rand.nextInt(8),
      ));
    }
  }


  void _updateTimer(Timer timer) {
    if (_stopwatch.isRunning) {
      final elapsed = _stopwatch.elapsed;
      setState(() {
        _elapsedSeconds = elapsed.inSeconds;
        _timeString = '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    }
  }

  void _selectGame(ActiveGame game) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeGame = game;
      _isFlappyGameOver = false;
      _isJumpGameOver = false;
      _isCacaCatchGameOver = false;
      _isInvadersGameOver = false;
    });
    _updateMusicPlayback();
  }

  void _exitToMenu() {
    _stopCacaCatch();
    _stopFlappyPoop();
    _stopToiletJump();
    _stopPoopInvaders();
    setState(() {
      _activeGame = ActiveGame.selectMenu;
    });
    _updateMusicPlayback();
  }

  void _exitToZen() {
    _stopCacaCatch();
    _stopFlappyPoop();
    _stopToiletJump();
    _stopPoopInvaders();
    setState(() {
      _activeGame = ActiveGame.none;
    });
    _updateMusicPlayback();
  }

  // ==========================================
  // --- MINIJUEGO 1: CACA CATCH (ATRACA) ---
  // ==========================================
  void _startCacaCatch() {
    _onGameStarted();
    _stopCacaCatch();
    setState(() {
      _score = 0;
      _lives = _hasExtraLife ? 4 : 3;
      _hasExtraLife = false; // consumido
      
      _catchItems.clear();
      _toiletX = 0.5;
      _catchSpawnProb = 0.05;
      _catchSpeed = 0.015;
      
      _isFeverMode = false;
      _feverTicksRemaining = 0;
      _isSodaFrenzy = false;
      _sodaFrenzyTicksRemaining = 0;
      _hasSoapShield = _hasInitialSoapShield;
      _soapShieldTicksRemaining = _hasInitialSoapShield ? 150 : 0;
      _hasInitialSoapShield = false; // consumido
      
      _isMagnetActive = _hasFeverMagnet;
      _hasFeverMagnet = false; // consumido
      
      _particles.clear();
      _shakeTicks = 0;
      _flashColor = null;

      // Variables de juego profesional
      _lastTickTime = DateTime.now();
      _floatingTexts.clear();
      _comboMultiplier = 1;
      _poopsCaughtConsecutively = 0;
      _isPaused = false;
      _isCacaCatchGameOver = false;
    });

    final user = _authService.currentUser;
    if (user != null) {
      _dbService.unlockAchievement(user.uid, 'zen_player', user.displayName);
    }

    _cacaCatchTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateCacaCatchStep();
    });
  }

  void _stopCacaCatch() {
    _cacaCatchTimer?.cancel();
    _cacaCatchTimer = null;
  }

  void _updateCacaCatchStep() {
    final dt = _calculateDeltaTime();
    if (_isPaused || _isCacaCatchGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    _updateJuicyEffects(dt);
    final rand = Random();

    // Lógica del imán de caca
    if (_isMagnetActive || _isSodaFrenzy) {
      for (var item in _catchItems) {
        if (item.type == CatchItemType.poop || item.type == CatchItemType.goldenPoop || item.type == CatchItemType.paper || item.type == CatchItemType.soda) {
          double attractionSpeed = _isSodaFrenzy ? 0.075 : (_hasImprovedMagnet ? 0.065 : 0.045);
          item.x += (_toiletX - item.x) * attractionSpeed * dt * 33.3; // atracción magnética
        }
      }
    }

    // Lógica de la Soda Frenesí
    if (_isSodaFrenzy) {
      _sodaFrenzyTicksRemaining--;
      if (_sodaFrenzyTicksRemaining <= 0) {
        _isSodaFrenzy = false;
      }
      if (_sodaFrenzyTicksRemaining % 6 == 0) {
        _triggerFlash(Colors.cyanAccent.withAlpha(20), 4);
      }
    }

    // Lógica del modo fiebre
    if (_isFeverMode) {
      _feverTicksRemaining--;
      if (_feverTicksRemaining <= 0) {
        _isFeverMode = false;
      }
      if (_feverTicksRemaining % 8 == 0) {
        _triggerFlash(Colors.amber.withAlpha(25), 5);
      }
    }

    // Lógica del escudo de jabón
    if (_hasSoapShield) {
      _soapShieldTicksRemaining--;
      if (_soapShieldTicksRemaining <= 0) {
        _hasSoapShield = false;
      }
    }

    // Spawn items
    double spawnChance = _isFeverMode ? 0.12 : _catchSpawnProb;
    if (rand.nextDouble() < spawnChance) {
      CatchItemType type;
      String icon;
      Color color;

      if (_isFeverMode) {
        // En modo fiebre caen cacas normales y papel a gran velocidad (sin estrellas para evitar fiebre infinita)
        if (rand.nextDouble() < 0.6) {
          type = CatchItemType.poop;
          icon = _equippedSkin;
          color = Colors.brown;
        } else {
          type = CatchItemType.paper;
          icon = '🧻';
          color = Colors.white;
        }
      } else {
        final rVal = rand.nextDouble();
        if (rVal < 0.50) {
          type = CatchItemType.poop;
          icon = _equippedSkin;
          color = Colors.brown;
        } else if (rVal < 0.65) {
          type = CatchItemType.paper;
          icon = '🧻';
          color = Colors.white;
        } else if (rVal < 0.82) {
          type = CatchItemType.bacteria;
          icon = '👾';
          color = Colors.purpleAccent;
        } else if (rVal < 0.88) {
          type = CatchItemType.soap;
          icon = '🧼';
          color = Colors.blueAccent;
        } else if (rVal < 0.92) {
          type = CatchItemType.soda;
          icon = '⚡';
          color = Colors.cyanAccent;
        } else if (rVal < 0.95) {
          type = CatchItemType.chlorineBomb;
          icon = '💣';
          color = Colors.redAccent;
        } else {
          type = CatchItemType.goldenPoop;
          icon = '⭐';
          color = Colors.amber;
        }
      }

      _catchItems.add(CatchItem(
        x: rand.nextDouble() * 0.9 + 0.05,
        y: 0.0,
        type: type,
        icon: icon,
        color: color,
      ));
    }

    // Mover y comprobar colisiones
    double currentSpeed = _isFeverMode ? _catchSpeed * 1.3 : _catchSpeed;
    for (int i = _catchItems.length - 1; i >= 0; i--) {
      final item = _catchItems[i];
      item.y += currentSpeed * dt * 33.3;

      // Colisión (píxeles reales basados en la altura del inodoro)
      final itemYPx = item.y * _gameHeight;
      final toiletYPx = _gameHeight - 50.0;

      // Ajustamos la colisión a la boca de la taza (alrededor de toiletYPx - 8.0)
      if ((itemYPx - (toiletYPx - 8.0)).abs() < 14.0) {
        final diff = (item.x * _gameWidth - _toiletX * _gameWidth).abs();
        if (diff < 32.0) {
          _handleCacaCatchHit(item);
          _catchItems.removeAt(i);
          continue;
        }
      }

      // Caída al vacío (suelo)
      if (item.y >= 1.0) {
        if (!_isFeverMode) {
          if (item.type == CatchItemType.poop || item.type == CatchItemType.goldenPoop) {
            _triggerFlash(Colors.red.withAlpha(40), 5);
            HapticFeedback.vibrate();
            _lives--;
            
            // Feedback de vidas y combos rotos
            _spawnFloatingText(item.x * _gameWidth, _gameHeight - 20, '💔 -1 Vida', Colors.redAccent, fontSize: 14);
            if (_comboMultiplier > 1) {
              _spawnFloatingText(item.x * _gameWidth, _gameHeight - 40, '¡COMBO ROTO! ❌', Colors.redAccent, fontSize: 13);
            }
            _comboMultiplier = 1;
            _poopsCaughtConsecutively = 0;
            
            if (_lives <= 0) {
              _isCacaCatchGameOver = true;
              _stopCacaCatch();
            }
          }
        }
        _catchItems.removeAt(i);
      }
    }

    // Dificultad progresiva (solo fuera de modo fiebre)
    if (!_isFeverMode && _score > 0 && _score % 10 == 0) {
      _catchSpeed = 0.015 + (_score ~/ 10) * 0.0015;
      _catchSpawnProb = 0.05 + (_score ~/ 10) * 0.003;
    }

    setState(() {});
  }

  void _handleCacaCatchHit(CatchItem item) {
    final px = item.x * _gameWidth;
    final py = item.y * _gameHeight;

    if (item.type == CatchItemType.poop) {
      HapticFeedback.lightImpact();
      _poopsCaughtConsecutively++;
      if (_poopsCaughtConsecutively >= 5) {
        if (_comboMultiplier < 5) {
          _comboMultiplier++;
          _spawnFloatingText(px, py, '¡COMBO x$_comboMultiplier! 🔥', Colors.amberAccent, fontSize: 18);
        }
        _poopsCaughtConsecutively = 0;
      }
      
      final pointsGained = 1 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained', _isSodaFrenzy ? Colors.cyanAccent : Colors.brown[300]!);
      _saveHighScore('caca_catch', _score);
      _spawnParticles(px, py, _isSodaFrenzy ? '⚡' : '💦', 5);

      final user = _authService.currentUser;
      if (user != null && _score >= 50) {
        _dbService.unlockAchievement(user.uid, 'high_scorer', user.displayName);
      }
    } else if (item.type == CatchItemType.paper) {
      HapticFeedback.mediumImpact();
      final pointsGained = 3 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained', Colors.white);
      _saveHighScore('caca_catch', _score);
      _spawnParticles(px, py, '✨', 6);
    } else if (item.type == CatchItemType.soap) {
      HapticFeedback.mediumImpact();
      if (_lives < 3) {
        _lives++;
        _spawnFloatingText(px, py, '+1 Vida ❤️', Colors.redAccent);
      } else {
        final pointsGained = 5 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
        _score += pointsGained;
        _spawnFloatingText(px, py, '+$pointsGained', Colors.blueAccent);
        _saveHighScore('caca_catch', _score);
      }
      _hasSoapShield = true;
      _soapShieldTicksRemaining = 130; // ~4 segundos
      _triggerFlash(Colors.blueAccent.withAlpha(60), 8);
      _spawnParticles(px, py, '🫧', 8);
    } else if (item.type == CatchItemType.goldenPoop) {
      HapticFeedback.heavyImpact();
      final pointsGained = 15 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained ✨', Colors.amberAccent, fontSize: 20);
      _saveHighScore('caca_catch', _score);
      _isFeverMode = true;
      _feverTicksRemaining = 130; // ~4 segundos
      _triggerFlash(Colors.amber.withAlpha(120), 12);
      _triggerShake(6.0, 12);
      _spawnParticles(px, py, '⭐', 15);
    } else if (item.type == CatchItemType.soda) {
      HapticFeedback.heavyImpact();
      _isSodaFrenzy = true;
      _sodaFrenzyTicksRemaining = 200; // ~6 segundos
      _triggerFlash(Colors.cyanAccent.withAlpha(100), 10);
      _triggerShake(4.0, 10);
      _spawnParticles(px, py, '⚡', 12);
      _spawnFloatingText(px, py, '¡SODA FRENESÍ! ⚡', Colors.cyanAccent, fontSize: 18);
    } else if (item.type == CatchItemType.chlorineBomb) {
      HapticFeedback.heavyImpact();
      _triggerFlash(Colors.white.withAlpha(120), 12);
      _triggerShake(8.0, 15);
      _spawnParticles(px, py, '💥', 15);
      
      // Eliminar bacterias
      int bacteriaCount = 0;
      for (var catchItem in _catchItems) {
        if (catchItem.type == CatchItemType.bacteria) {
          bacteriaCount++;
          _spawnParticles(catchItem.x * _gameWidth, catchItem.y * _gameHeight, '🫧', 5);
        }
      }
      _catchItems.removeWhere((i) => i.type == CatchItemType.bacteria);
      
      _comboMultiplier = 1;
      _poopsCaughtConsecutively = 0;
      _spawnFloatingText(px, py, 'BOMBA DE CLORO 💣', Colors.redAccent, fontSize: 16);
      if (bacteriaCount > 0) {
        _spawnFloatingText(_gameWidth / 2, _gameHeight * 0.4, '¡$bacteriaCount bacterias desinfectadas! 🫧', Colors.greenAccent, fontSize: 14);
      }
    } else if (item.type == CatchItemType.bacteria) {
      if (_hasSoapShield) {
        _hasSoapShield = false;
        _soapShieldTicksRemaining = 0;
        _triggerShake(3.0, 8);
        HapticFeedback.mediumImpact();
        _spawnParticles(px, py, '🫧', 10);
        _spawnFloatingText(px, py, '¡ESCUDO ROTO!', Colors.blueAccent);
      } else {
        HapticFeedback.vibrate();
        _lives--;
        _spawnFloatingText(px, py, '-1 Vida 💔', Colors.redAccent);
        _triggerShake(8.0, 12);
        _triggerFlash(Colors.redAccent.withAlpha(120), 8);
        _spawnParticles(px, py, '💥', 10);
        
        if (_comboMultiplier > 1) {
          _spawnFloatingText(px, py, '¡COMBO ROTO! ❌', Colors.redAccent, fontSize: 14);
        }
        _comboMultiplier = 1;
        _poopsCaughtConsecutively = 0;

        if (_lives <= 0) {
          _isCacaCatchGameOver = true;
          _stopCacaCatch();
        }
      }
    }
  }


  // ==========================================
  // --- MINIJUEGO 2: FLAPPY POOP 💩🕊️ ---
  // ==========================================
  void _startFlappyPoop() {
    _onGameStarted();
    _stopFlappyPoop();
    setState(() {
      _score = 0;
      _flappyY = 200;
      _flappyVelocity = 0;
      _flappyPipes.clear();
      _isFlappyGameOver = false;
      _flappyBgX = 0;
      _particles.clear();
      _shakeTicks = 0;
      _flashColor = null;
      
      _hasFlappyShield = _hasInitialSoapShield || _hasLifeInsurance;
      _hasInitialSoapShield = false; // consumido

      // Variables de juego profesional
      _lastTickTime = DateTime.now();
      _floatingTexts.clear();
      _isPaused = false;
    });

    final user = _authService.currentUser;
    if (user != null) {
      _dbService.unlockAchievement(user.uid, 'zen_player', user.displayName);
    }

    // Pipes iniciales (ajustados hacia adelante porque la caca va más adelantada)
    _spawnFlappyPipe(450);
    _spawnFlappyPipe(670);

    _flappyTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateFlappyStep();
    });
  }

  void _spawnFlappyPipe(double startX) {
    final rand = Random();
    final gapY = 80.0 + rand.nextDouble() * 120.0; // Espacio de paso vertical
    _flappyPipes.add(FlappyPipe(
      x: startX,
      gapY: gapY,
      gapHeight: 125.0,
      hasStar: rand.nextDouble() < 0.40,
    ));
  }

  void _stopFlappyPoop() {
    _flappyTimer?.cancel();
    _flappyTimer = null;
  }

  void _updateFlappyStep() {
    final dt = _calculateDeltaTime();
    if (_isPaused || _isFlappyGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    _updateJuicyEffects(dt);

    setState(() {
      // Física del salto (gravedad incrementada de 0.45 a 0.58)
      _flappyVelocity += 0.58 * dt * 33.3; 
      _flappyY += _flappyVelocity * dt * 33.3;

      // Desplazamiento del fondo
      _flappyBgX = (_flappyBgX - 0.7 * dt * 33.3) % _gameWidth;

      // Partículas estela de olor (cola de la caca en _flappyX)
      if (randPercent(25)) {
        String particleEmoji = _equippedSkin == '🌈' 
            ? ['🔴', '🟠', '🟡', '🟢', '🔵', '🟣'][Random().nextInt(6)]
            : (_equippedSkin == '🦄' ? '✨' : '💨');
        _particles.add(GameParticle(
          x: _flappyX - 10,
          y: _flappyY + (Random().nextDouble() * 10 - 5),
          vx: -1.8 - Random().nextDouble() * 1.5,
          vy: Random().nextDouble() * 0.8 - 0.4,
          emoji: particleEmoji,
          scale: 0.4 + Random().nextDouble() * 0.4,
          lifeTime: 8 + Random().nextInt(6),
        ));
      }

      // Colisión suelo/techo
      if (_flappyY < 15) _flappyY = 15;
      if (_flappyY > _gameHeight - 15) {
        _handleFlappyGameOver();
        return;
      }

      // Mover tuberías
      for (int i = _flappyPipes.length - 1; i >= 0; i--) {
        final pipe = _flappyPipes[i];
        pipe.x -= 4.8 * dt * 33.3; // velocidad de tubería incrementada de 3.5 a 4.8

        // Colisión con la caca (usando _flappyX)
        const cacaRadius = 14.0;
        final cacaX = _flappyX;

        bool hitTop = pipe.x < cacaX + cacaRadius &&
            pipe.x + 55.0 > cacaX - cacaRadius &&
            _flappyY - cacaRadius < pipe.gapY;
        bool hitBottom = pipe.x < cacaX + cacaRadius &&
            pipe.x + 55.0 > cacaX - cacaRadius &&
            _flappyY + cacaRadius > pipe.gapY + pipe.gapHeight;

        if (hitTop || hitBottom) {
          if (_hasFlappyShield) {
            _hasFlappyShield = false;
            HapticFeedback.heavyImpact();
            _triggerFlash(Colors.blueAccent.withAlpha(80), 8);
            _triggerShake(4.0, 10);
            _spawnParticles(cacaX, _flappyY, '🫧', 15);
            _spawnFloatingText(cacaX, _flappyY - 20, '¡ESCUDO ROTO! 🫧', Colors.blue);
            pipe.passed = true;
            pipe.x = -100; // Destruir la tubería
          } else {
            _handleFlappyGameOver();
            break;
          }
        }

        // Colisión con estrella
        if (pipe.hasStar && !pipe.starCollected) {
          final starX = pipe.x + 27.5;
          final starY = pipe.gapY + pipe.gapHeight / 2;
          final dist = sqrt(pow(cacaX - starX, 2) + pow(_flappyY - starY, 2));
          if (dist < 26.0) {
            pipe.starCollected = true;
            HapticFeedback.mediumImpact();
            _spawnParticles(starX, starY, '⭐', 8, speed: 4.0);
            _spawnFloatingText(starX, starY - 15, '+5 K\$', Colors.amber, fontSize: 16.0);
            
            final user = _authService.currentUser;
            if (user != null) {
              _dbService.addKcoins(user.uid, 5);
            }
          }
        }

        // Puntos
        if (!pipe.passed && pipe.x + 27.5 < cacaX) {
          pipe.passed = true;
          _score += 1;
          HapticFeedback.lightImpact();
          
          // Flash verde suave al anotar
          _triggerFlash(Colors.greenAccent.withAlpha(20), 4);
          
          // Partícula de éxito al pasar
          _spawnParticles(cacaX + 20, pipe.gapY + pipe.gapHeight / 2, '⭐', 8, speed: 5.0);
          _spawnFloatingText(cacaX + 20, pipe.gapY + pipe.gapHeight / 2 - 20, '+1', Colors.deepPurpleAccent, fontSize: 18);
          
          _saveHighScore('flappy_poop', _score);

          final user = _authService.currentUser;
          if (user != null && _score >= 25) {
            _dbService.unlockAchievement(user.uid, 'flappy_expert', user.displayName);
          }
        }

        // Eliminar y reaparecer tuberías (ajustado a +50)
        if (pipe.x < -60) {
          _flappyPipes.removeAt(i);
          _spawnFlappyPipe(_gameWidth + 50);
        }
      }
    });
  }

  bool randPercent(int percent) {
    return Random().nextInt(100) < percent;
  }

  void _handleFlappyGameOver() {
    HapticFeedback.vibrate();
    _triggerFlash(Colors.redAccent.withAlpha(120), 10);
    _triggerShake(8.0, 15);
    _spawnParticles(_flappyX, _flappyY, '💥', 12);
    _stopFlappyPoop();
    setState(() {
      _isFlappyGameOver = true;
    });
  }

  void _onFlappyTap() {
    if (_isFlappyGameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      _flappyVelocity = -7.8; // impulso del salto incrementado de -6.8 a -7.8
      // Partículas hacia abajo al saltar
      _spawnParticles(_flappyX, _flappyY + 10, '✨', 3, speed: 2.0);
    });
  }


  // ==========================================
  // --- MINIJUEGO 3: TOILET JUMP 💩jump ---
  // ==========================================
  void _startToiletJump() {
    _onGameStarted();
    _stopToiletJump();
    setState(() {
      _score = 0;
      _jumpX = 150;
      _jumpY = 280;
      _jumpVx = 0;
      
      // Aplicar super impulso inicial si se ha comprado
      _jumpVy = _hasInitialSpring ? -15.5 : -8.0;
      _hasInitialSpring = false; // consumido
      
      _cameraY = 0;
      _isJumpGameOver = false;
      _maxHeightReached = 0;
      _jumpPlatforms.clear();
      _jumpBacterias.clear();
      _particles.clear();
      _shakeTicks = 0;
      _flashColor = null;
      _cacaScaleX = 1.0;
      _cacaScaleY = 1.0;
      
      // Aplicar jetpack inicial si se ha comprado
      _hasJetpack = _hasInitialSoapShield;
      _jetpackTicksRemaining = _hasInitialSoapShield ? 60 : 0;
      _hasInitialSoapShield = false; // consumido
      
      _hasBalloon = false;
      _balloonTicksRemaining = 0;

      // Variables de juego profesional
      _lastTickTime = DateTime.now();
      _floatingTexts.clear();
      _isPaused = false;
    });

    final user = _authService.currentUser;
    if (user != null) {
      _dbService.unlockAchievement(user.uid, 'zen_player', user.displayName);
    }

    // Plataforma de inicio segura justo debajo
    _jumpPlatforms.add(JumpPlatform(x: 120, y: 350, width: 70, type: PlatformType.normal));

    // Generar plataformas iniciales escalonadas
    for (int i = 0; i < 9; i++) {
      _spawnJumpPlatform(300.0 - (i * 65.0));
    }

    _toiletJumpTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateToiletJumpStep();
    });
  }

  void _spawnJumpPlatform(double targetY) {
    final rand = Random();
    const pWidth = 55.0;
    final pX = rand.nextDouble() * (_gameWidth - pWidth - 20) + 10;
    final rVal = rand.nextDouble();
    PlatformType type = PlatformType.normal;

    if (rVal < 0.12 && targetY < 150) {
      type = PlatformType.fragile;
    } else if (rVal < 0.28 && targetY < 200) {
      type = PlatformType.moving;
    } else if (rVal < 0.38 && targetY < -100) {
      type = PlatformType.superSpring;
    }

    ItemType item = ItemType.none;
    if (type == PlatformType.normal && targetY < 250) {
      final iVal = rand.nextDouble();
      if (iVal < 0.10) {
        item = ItemType.spring;
      } else if (iVal < 0.14 && targetY < -100) {
        item = ItemType.jetpack;
      } else if (iVal < 0.22 && targetY < 0) {
        item = ItemType.balloon;
      }
    }

    _jumpPlatforms.add(JumpPlatform(
      x: pX,
      y: targetY,
      width: pWidth,
      type: type,
      item: item,
    ));

    // Añadir bacteria flotante
    if (targetY < 100 && rand.nextDouble() < 0.15) {
      _jumpBacterias.add(BacteriaEnemy(
        x: rand.nextDouble() * (_gameWidth - 40) + 10,
        y: targetY - 35.0,
        vx: (rand.nextBool() ? 1.0 : -1.0) * (1.2 + rand.nextDouble() * 1.0),
      ));
    }
  }

  void _stopToiletJump() {
    _toiletJumpTimer?.cancel();
    _toiletJumpTimer = null;
  }

  void _updateToiletJumpStep() {
    final dt = _calculateDeltaTime();
    if (_isPaused || _isJumpGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    _updateJuicyEffects(dt);

    setState(() {
      // Squash & Stretch recuperación gradual
      _cacaScaleX += (1.0 - _cacaScaleX) * 0.15 * dt * 33.3;
      _cacaScaleY += (1.0 - _cacaScaleY) * 0.15 * dt * 33.3;

      // Recuperación elástica de resortes de plataformas
      for (var p in _jumpPlatforms) {
        p.scaleY += (1.0 - p.scaleY) * 0.15 * dt * 33.3;
      }

      // Lógica de Globo de Gas
      if (_hasBalloon) {
        _balloonTicksRemaining--;
        _jumpVy = -6.5; // Ascenso suave y seguro
        if (randPercent(15)) {
          _spawnParticles(_jumpX, _jumpY + 12, '🎈', 1, speed: 1.0);
        }
        if (_balloonTicksRemaining <= 0) {
          _hasBalloon = false;
        }
      } else if (_hasJetpack) {
        _jetpackTicksRemaining--;
        _jumpVy = -13.0;
        // Partículas propulsión agua
        _spawnParticles(_jumpX, _jumpY + 12, '💦', 2, speed: 5.0);
        _triggerShake(2.0, 1);
        if (_jetpackTicksRemaining <= 0) {
          _hasJetpack = false;
        }
      } else {
        // Gravedad normal
        _jumpVy += 0.32 * dt * 33.3;
      }

      // Trail visual para skins premium en Toilet Jump
      if (randPercent(20)) {
        String trailEmoji = _equippedSkin == '🌈'
            ? ['🔴', '🟠', '🟡', '🟢', '🔵', '🟣'][Random().nextInt(6)]
            : (_equippedSkin == '🦄' ? '✨' : '');
        if (trailEmoji.isNotEmpty) {
          _particles.add(GameParticle(
            x: _jumpX,
            y: _jumpY + 12,
            vx: Random().nextDouble() * 1.0 - 0.5,
            vy: 1.0 + Random().nextDouble() * 1.5,
            emoji: trailEmoji,
            scale: 0.4 + Random().nextDouble() * 0.4,
            lifeTime: 8 + Random().nextInt(6),
          ));
        }
      }

      _jumpY += _jumpVy * dt * 33.3;
      _jumpX += _jumpVx * dt * 33.3;

      // Amortiguar movimiento X
      _jumpVx *= pow(0.85, dt * 33.3);

      // Salir por los bordes e ingresar por el otro lado (wrap-around)
      if (_jumpX < 5) _jumpX = _gameWidth - 5;
      if (_jumpX > _gameWidth - 5) _jumpX = 5;

      // Movimiento de plataformas móviles
      for (var p in _jumpPlatforms) {
        if (p.type == PlatformType.moving) {
          p.x += p.vx * dt * 33.3;
          if (p.x < 10 || p.x + p.width > _gameWidth - 10) {
            p.vx = -p.vx;
          }
        }
      }

      // Movimiento y oscilación sinusoidal de bacterias flotantes
      for (var b in _jumpBacterias) {
        b.x += b.vx * dt * 33.3;
        b.time += dt * 5.0; // velocidad de la oscilación
        b.y = b.baseY + sin(b.time) * 15.0;

        if (b.x < 10 || b.x + b.width > _gameWidth - 10) {
          b.vx = -b.vx;
        }

        // Estela de humo ocasional morado
        if (randPercent(12)) {
          _particles.add(GameParticle(
            x: b.x + b.width / 2,
            y: b.y + b.height / 2,
            vx: Random().nextDouble() * 0.6 - 0.3,
            vy: Random().nextDouble() * 0.6 + 0.2,
            emoji: '💨',
            scale: 0.5,
            lifeTime: 8,
          ));
        }
      }

      // Colisión con bacterias flotantes
      for (var b in _jumpBacterias) {
        if (b.dead) continue;

        // Caja de colisión simple
        bool overlapX = (_jumpX - (b.x + b.width / 2)).abs() < 22;
        bool overlapY = (_jumpY - (b.y + b.height / 2)).abs() < 22;

        if (overlapX && overlapY) {
          // Si cae encima de ella, la mata y rebota
          if (_jumpVy > 0 && _jumpY + 10 < b.y + b.height / 2) {
            b.dead = true;
            _jumpVy = -9.0;
            _score += 100;
            _cacaScaleY = 0.55;
            _cacaScaleX = 1.45;
            _spawnParticles(b.x + b.width / 2, b.y + b.height / 2, '💥', 8);
            _spawnFloatingText(b.x + b.width / 2, b.y + b.height / 2 - 20, '+100 💥', Colors.orangeAccent);
            _saveHighScore('toilet_jump', _score);
            HapticFeedback.mediumImpact();
          } else {
            // Si choca por debajo/lados y no tiene Jetpack ni Globo, muere
            if (!_hasJetpack && !_hasBalloon) {
              _handleToiletJumpGameOver();
              return;
            }
          }
        }
      }

      // Colisión con plataformas (solo cayendo y sin jetpack ni globo)
      if (_jumpVy > 0 && !_hasJetpack && !_hasBalloon) {
        const cacaRadius = 15.0;
        final cacaBottom = _jumpY + cacaRadius;

        for (int i = 0; i < _jumpPlatforms.length; i++) {
          final p = _jumpPlatforms[i];
          if (_jumpX + cacaRadius > p.x && 
              _jumpX - cacaRadius < p.x + p.width && 
              cacaBottom > p.y && 
              cacaBottom < p.y + 15) {
            
            if (p.type == PlatformType.fragile) {
              p.broken = true; // Se rompe al tocarla
              _spawnParticles(p.x + p.width / 2, p.y, '🟫', 6, speed: 2.0);
              HapticFeedback.vibrate();
            } else if (p.type == PlatformType.superSpring) {
              _jumpVy = -16.5; // Salto súper gigante
              _cacaScaleY = 0.3;
              _cacaScaleX = 1.7;
              _triggerFlash(Colors.redAccent.withAlpha(40), 6);
              _triggerShake(3.0, 8);
              _spawnParticles(p.x + p.width / 2, p.y, '💥', 10, speed: 4.0);
              _spawnFloatingText(_jumpX, _jumpY - 20, '¡SUPER IMPULSO! 💥', Colors.redAccent);
              HapticFeedback.heavyImpact();
            } else {
              _jumpVy = -8.5; // rebote normal
              _cacaScaleY = 0.6;
              _cacaScaleX = 1.4;
              HapticFeedback.lightImpact();

              // Si tiene objetos sobre ella
              if (p.item == ItemType.spring && !p.itemUsed) {
                p.itemUsed = true;
                p.scaleY = 0.4; // COMPRIMIR RESORTE
                _jumpVy = -14.5; // súper impulso
                _cacaScaleY = 0.4;
                _cacaScaleX = 1.6;
                _triggerFlash(Colors.amberAccent.withAlpha(30), 5);
                _spawnParticles(_jumpX, _jumpY + 10, '✨', 8);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡SÚPER IMPULSO! 🚀', Colors.amberAccent);
                HapticFeedback.heavyImpact();
              } else if (p.item == ItemType.jetpack && !p.itemUsed) {
                p.itemUsed = true;
                _hasJetpack = true;
                _jetpackTicksRemaining = 70; // ~2 segundos
                _triggerFlash(Colors.blueAccent.withAlpha(60), 8);
                _spawnParticles(_jumpX, _jumpY, '💦', 12);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡JETPACK DE AGUA! 💦', Colors.blueAccent);
                HapticFeedback.heavyImpact();
              } else if (p.item == ItemType.balloon && !p.itemUsed) {
                p.itemUsed = true;
                _hasBalloon = true;
                _balloonTicksRemaining = 130; // ~4 segundos
                _triggerFlash(Colors.greenAccent.withAlpha(60), 8);
                _spawnParticles(_jumpX, _jumpY, '🎈', 12);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡GLOBO DE HELIO! 🎈', Colors.greenAccent);
                HapticFeedback.heavyImpact();
              }
            }
            break;
          }
        }
      }

      // Cámara dinámica persigue al personaje hacia arriba
      if (_jumpY < _cameraY + 180) {
        double diff = (_cameraY + 180) - _jumpY;
        _cameraY -= diff;
        _maxHeightReached += diff;

        // Sumar puntos por altura recorrida
        final currentHeightScore = (_maxHeightReached ~/ 5).toInt();
        if (currentHeightScore > _score) {
          _score = currentHeightScore;
          _saveHighScore('toilet_jump', _score);

          final user = _authService.currentUser;
          if (user != null && _score >= 1000) {
            _dbService.unlockAchievement(user.uid, 'jump_master', user.displayName);
          }
        }
      }

      // Eliminar plataformas viejas abajo e ir generando nuevas arriba
      for (int i = _jumpPlatforms.length - 1; i >= 0; i--) {
        final p = _jumpPlatforms[i];
        if (p.y > _cameraY + _gameHeight + 40) {
          _jumpPlatforms.removeAt(i);
          // Spawn arriba
          double topPlatformY = _jumpPlatforms.map((p) => p.y).reduce(min);
          _spawnJumpPlatform(topPlatformY - 65.0);
        }
      }

      // Eliminar bacterias viejas
      for (int i = _jumpBacterias.length - 1; i >= 0; i--) {
        final b = _jumpBacterias[i];
        if (b.y > _cameraY + _gameHeight + 40) {
          _jumpBacterias.removeAt(i);
        }
      }

      // Caer fuera de cámara significa Game Over
      if (_jumpY > _cameraY + _gameHeight + 10) {
        _handleToiletJumpGameOver();
      }
    });
  }

  void _handleToiletJumpGameOver() {
    HapticFeedback.vibrate();
    _triggerFlash(Colors.redAccent.withAlpha(120), 10);
    _triggerShake(8.0, 15);
    _spawnParticles(_jumpX, _jumpY, '💥', 12);
    _stopToiletJump();
    setState(() {
      _isJumpGameOver = true;
    });
  }


  void _onToiletJumpLeftTap() {
    setState(() {
      _jumpVx = -7.5;
    });
  }

  void _onToiletJumpRightTap() {
    setState(() {
      _jumpVx = 7.5;
    });
  }

  // ==========================================
  // --- FIN DE PARTIDA & FIN DE SESIÓN ---
  // ==========================================


  void _finishZenSession() {
    _stopwatch.stop();
    _stopCacaCatch();
    _stopFlappyPoop();
    _stopToiletJump();
    
    final durationMinutes = max(1.0, _elapsedSeconds / 60.0);
    Navigator.of(context).pop(durationMinutes);
  }

  // ==========================================
  // --- CONSTRUCCIÓN DE LA INTERFAZ ---
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        title: const Text('Modo Trono Zen 🧘‍♂️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: _finishZenSession,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cronómetro Superior
              Card(
                color: const Color(0xFF121212),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.brown[900]!, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      const Text(
                        'TIEMPO EN EL TRONO DE HIERRO',
                        style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _timeString,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Área central dinámica
              Expanded(
                child: _buildDynamicArea(),
              ),
              const SizedBox(height: 16),

              // Botón de finalización
              ElevatedButton(
                onPressed: _finishZenSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded),
                    SizedBox(width: 8),
                    Text(
                      'Finalizar y Registrar KK',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicArea() {
    switch (_activeGame) {
      case ActiveGame.none:
        return _buildZenSoundsArea();
      case ActiveGame.selectMenu:
        return _buildGameSelectionMenu();
      case ActiveGame.cacaCatch:
        return _buildCacaCatchArea();
      case ActiveGame.flappyPoop:
        return _buildFlappyPoopArea();
      case ActiveGame.toiletJump:
        return _buildToiletJumpArea();
      case ActiveGame.poopInvaders:
        return _buildPoopInvadersArea();
      case ActiveGame.storeMenu:
        return _buildStoreMenuArea();
    }
  }

  // --- AREA ZEN / SONIDOS ---
  Widget _buildZenSoundsArea() {
    return Column(
      children: [
        // Onda de Sonido Visual Animada
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _toggleMusic(!_isMusicEnabled);
              },
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.brown[900]!.withAlpha(38),
                  border: Border.all(
                    color: _isMusicEnabled ? Colors.amberAccent : Colors.brown[900]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _soundAnimController,
                    builder: (context, child) {
                      final val = _isMusicEnabled ? _soundAnimController.value : 0.0;
                      return Icon(
                        _isMusicEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                        color: _isMusicEnabled ? Colors.amberAccent : Colors.grey[600],
                        size: 40 + (val * 10),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toca el círculo para pausar o reproducir la música',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 12),

        // Checkbox para activar/desactivar la música
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isMusicEnabled ? Colors.amberAccent.withAlpha(76) : Colors.transparent,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              _toggleMusic(!_isMusicEnabled);
            },
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _isMusicEnabled,
                  activeColor: Colors.amberAccent,
                  checkColor: Colors.black,
                  onChanged: (bool? val) {
                    if (val != null) {
                      _toggleMusic(val);
                    }
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  'Música de fondo Zen',
                  style: TextStyle(
                    color: _isMusicEnabled ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Botón para ir al menú
        OutlinedButton.icon(
          onPressed: () {
            _loadZenProfile();
            _selectGame(ActiveGame.selectMenu);
          },
          icon: const Icon(Icons.sports_esports_rounded, color: Colors.amberAccent),
          label: const Text('¿Aburrido? ¡Suite de Minijuegos! 🎮', style: TextStyle(color: Colors.amberAccent)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.amberAccent),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  // --- MENÚ SELECTOR DE MINIJUEGOS ---
  Widget _buildGameSelectionMenu() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_kcoins Kakadólares',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _activeGame = ActiveGame.storeMenu;
                    });
                  },
                  icon: const Icon(Icons.storefront_rounded, color: Colors.pinkAccent, size: 18),
                  label: const Text('Tienda Zen', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                IconButton(
                  icon: const Icon(Icons.music_off_rounded, color: Colors.grey),
                  onPressed: _exitToZen,
                  tooltip: 'Volver a Sonidos Zen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildGameMenuCard(
                title: 'Caca Catch 🚽',
                description: 'Atrapa las cacas y rollos con el inodoro. Evita las bacterias.',
                highScore: _highScoreCacaCatch,
                icon: Icons.umbrella_rounded,
                color: Colors.brown,
                onPlay: () => _selectGame(ActiveGame.cacaCatch),
              ),
              _buildGameMenuCard(
                title: 'Flappy Poop 💩🕊️',
                description: 'Esquiva las tuberías dando toques en la pantalla.',
                highScore: _highScoreFlappyPoop,
                icon: Icons.flight_takeoff_rounded,
                color: Colors.deepPurpleAccent,
                onPlay: () => _selectGame(ActiveGame.flappyPoop),
              ),
              _buildGameMenuCard(
                title: 'Toilet Jump 💩jump',
                description: 'Rebota por plataformas y sube hasta las nubes.',
                highScore: _highScoreToiletJump,
                icon: Icons.upgrade_rounded,
                color: Colors.orangeAccent,
                onPlay: () => _selectGame(ActiveGame.toiletJump),
              ),
              _buildGameMenuCard(
                title: 'Poop Invaders 👾',
                description: 'Destruye bacterias espaciales disparando chorros de agua.',
                highScore: _highScorePoopInvaders,
                icon: Icons.space_dashboard_rounded,
                color: Colors.greenAccent,
                onPlay: () => _selectGame(ActiveGame.poopInvaders),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameMenuCard({
    required String title,
    required String description,
    required int highScore,
    required IconData icon,
    required Color color,
    required VoidCallback onPlay,
  }) {
    return Card(
      color: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown[900]!.withAlpha(100), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('Récord: $highScore pts', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.amberAccent, size: 30),
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }

  // --- AREA JUEGO 1: CACA CATCH ---
  Widget _buildCacaCatchArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                if (_comboMultiplier > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'x$_comboMultiplier',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: List.generate(3, (i) => Icon(
                i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.redAccent, size: 18,
              )),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isCacaCatchGameOver) {
                        _isPaused = !_isPaused;
                        if (!_isPaused) {
                          _lastTickTime = DateTime.now();
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _exitToMenu,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;

              if (_gameWidth > 50 && _gameHeight > 50) {
                if (_cacaCatchTimer == null && !_isCacaCatchGameOver && !_isPaused) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _cacaCatchTimer == null) {
                      _startCacaCatch();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (_isPaused || _isCacaCatchGameOver) return;
                    setState(() {
                      double multiplier = _isSodaFrenzy ? 1.8 : 1.0;
                      _toiletX = (_toiletX + (details.delta.dx * multiplier) / _gameWidth).clamp(0.08, 0.92);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isFeverMode 
                            ? Colors.amber.withAlpha(120) 
                            : Colors.amberAccent.withAlpha(30),
                        width: _isFeverMode ? 2.0 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: CacaCatchPainter(
                                items: _catchItems,
                                toiletX: _toiletX,
                                particles: _particles,
                                hasSoapShield: _hasSoapShield,
                                isSodaFrenzy: _isSodaFrenzy,
                                isFeverMode: _isFeverMode,
                                width: _gameWidth,
                                height: _gameHeight,
                                floatingTexts: _floatingTexts,
                              ),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: Container(color: _flashColor),
                            ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '🟢 Atrapa: 💩 (+1) 🧻 (+3) 🧼 (Escudo) ⭐ (Fiebre)  |  🔴 Evita: 👾 (Daño)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          _buildInGameOverlay(ActiveGame.cacaCatch, _startCacaCatch),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- AREA JUEGO 2: FLAPPY POOP ---
  Widget _buildFlappyPoopArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('FLAPPY POOP 💩🕊️', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isFlappyGameOver) {
                        _isPaused = !_isPaused;
                        if (!_isPaused) {
                          _lastTickTime = DateTime.now();
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _exitToMenu,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;

              if (_gameWidth > 50 && _gameHeight > 50) {
                if (_flappyTimer == null && !_isFlappyGameOver && !_isPaused) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _flappyTimer == null) {
                      _startFlappyPoop();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onTap: _onFlappyTap,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: FlappyGamePainter(
                                flappyX: _flappyX,
                                poopY: _flappyY,
                                pipes: _flappyPipes,
                                width: _gameWidth,
                                height: _gameHeight,
                                flappyBgX: _flappyBgX,
                                flappyAngle: (_flappyVelocity * 0.08).clamp(-0.4, 1.1),
                                particles: _particles,
                                highScore: _highScoreFlappyPoop,
                                equippedSkin: _equippedSkin,
                                floatingTexts: _floatingTexts,
                                hasShield: _hasFlappyShield,
                              ),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: Container(color: _flashColor),
                            ),
                          _buildInGameOverlay(ActiveGame.flappyPoop, _startFlappyPoop),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- AREA JUEGO 3: TOILET JUMP ---
  Widget _buildToiletJumpArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('TOILET JUMP 💩jump', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isJumpGameOver) {
                        _isPaused = !_isPaused;
                        if (!_isPaused) {
                          _lastTickTime = DateTime.now();
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _exitToMenu,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;

              if (_gameWidth > 50 && _gameHeight > 50) {
                if (_toiletJumpTimer == null && !_isJumpGameOver && !_isPaused) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _toiletJumpTimer == null) {
                      _startToiletJump();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (_isPaused || _isJumpGameOver) return;
                    setState(() {
                      _jumpX = (_jumpX + details.delta.dx).clamp(15.0, _gameWidth - 15.0);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orangeAccent.withAlpha(40)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Canvas del juego
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ToiletJumpPainter(
                                jumpX: _jumpX,
                                jumpY: _jumpY,
                                cameraY: _cameraY,
                                platforms: _jumpPlatforms,
                                bacterias: _jumpBacterias,
                                particles: _particles,
                                width: _gameWidth,
                                height: _gameHeight,
                                scaleX: _cacaScaleX,
                                scaleY: _cacaScaleY,
                                hasJetpack: _hasJetpack,
                                hasBalloon: _hasBalloon,
                                equippedSkin: _equippedSkin,
                                floatingTexts: _floatingTexts,
                              ),
                            ),
                          ),
                          // Botones de control lateral opcionales (taps de soporte)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: GestureDetector(
                              onTap: _onToiletJumpLeftTap,
                              behavior: HitTestBehavior.translucent,
                              child: Container(),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: GestureDetector(
                              onTap: _onToiletJumpRightTap,
                              behavior: HitTestBehavior.translucent,
                              child: Container(),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: Container(color: _flashColor),
                            ),
                          _buildInGameOverlay(ActiveGame.toiletJump, _startToiletJump),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- AREA DE LA TIENDA (BAZAR DEL TRONO) ---
  Widget _buildStoreMenuArea() {
    final List<Map<String, dynamic>> skinsList = [
      {
        'skin': '💩',
        'name': 'Clásica',
        'cost': 0,
        'description': 'La caca de toda la vida.',
        'color': Colors.brown,
      },
      {
        'skin': '👑',
        'name': 'Real',
        'cost': 150,
        'description': 'Brilla con porte imperial.',
        'color': Colors.amber,
      },
      {
        'skin': '😎',
        'name': 'Molona',
        'cost': 100,
        'description': 'Demasiado cool.',
        'color': Colors.blueAccent,
      },
      {
        'skin': '🔥',
        'name': 'Caliente',
        'cost': 120,
        'description': '¡Pica al salir!',
        'color': Colors.redAccent,
      },
      {
        'skin': '🌈',
        'name': 'Arcoíris',
        'cost': 300,
        'description': 'Estela de colores brillantes.',
        'color': Colors.purple,
      },
      {
        'skin': '🦄',
        'name': 'Unicornio',
        'cost': 400,
        'description': 'Destellos mágicos rosados.',
        'color': Colors.pink,
      },
      {
        'skin': '👽',
        'name': 'Alien',
        'cost': 200,
        'description': 'De otra galaxia.',
        'color': Colors.greenAccent,
      },
      {
        'skin': '🤖',
        'name': 'Robot',
        'cost': 250,
        'description': 'Programada para ganar.',
        'color': Colors.grey,
      },
    ];

    final List<Map<String, dynamic>> powerupsList = [
      {
        'id': 'shield',
        'icon': '🧼',
        'name': 'Escudo Burbuja',
        'cost': 30,
        'description': 'Caca Catch: Escudo de jabón por 4s. Toilet Jump/Flappy: Escudo protector inicial.',
        'games': ['Caca Catch', 'Flappy Poop', 'Toilet Jump'],
      },
      {
        'id': 'spring',
        'icon': '🌀',
        'name': 'Súper Impulso',
        'cost': 40,
        'description': 'Toilet Jump: Salto inicial gigante para subir a las nubes rápidamente.',
        'games': ['Toilet Jump'],
      },
      {
        'id': 'magnet',
        'icon': '🧲',
        'name': 'Imán de Caca',
        'cost': 50,
        'description': 'Caca Catch: Atrae todas las cacas, estrellas y rollos automáticamente.',
        'games': ['Caca Catch'],
      },
      {
        'id': 'life',
        'icon': '❤️',
        'name': 'Vida Extra',
        'cost': 60,
        'description': 'Caca Catch: Inicias con 4 vidas en lugar de 3.',
        'games': ['Caca Catch'],
      },
      {
        'id': 'passive_magnet',
        'icon': '🧲✨',
        'name': 'Imán Pasivo',
        'cost': 150,
        'description': 'Caca Catch: Atrae cacas permanentemente más rápido y con mayor rango.',
        'games': ['Caca Catch'],
      },
      {
        'id': 'passive_insurance',
        'icon': '🛡️',
        'name': 'Seguro de Vida',
        'cost': 250,
        'description': 'Flappy/Invaders: Inicias siempre con un escudo protector o vida extra gratis.',
        'games': ['Flappy Poop', 'Poop Invaders'],
      },
    ];

    return Column(
      children: [
        // Cabecera de la Tienda
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _activeGame = ActiveGame.selectMenu;
                    });
                  },
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bazar del Trono 🛍️',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Mejora tu juego y aspecto',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(100), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_kcoins K\$',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Sección de Aspectos (Skins)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Text(
                  'ASPECTOS DE CACA 🎭',
                  style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: skinsList.length,
                itemBuilder: (context, index) {
                  final item = skinsList[index];
                  final skinStr = item['skin'] as String;
                  final isUnlocked = _unlockedSkins.contains(skinStr);
                  final isEquipped = _equippedSkin == skinStr;
                  final cost = item['cost'] as int;
                  final skinColor = item['color'] as Color;

                  return Card(
                    color: const Color(0xFF161616),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isEquipped 
                            ? Colors.greenAccent.withAlpha(150) 
                            : Colors.brown[900]!.withAlpha(80),
                        width: isEquipped ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: skinColor.withAlpha(30),
                            child: Text(
                              skinStr,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['description'] as String,
                                style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEquipped
                                    ? Colors.greenAccent[700]!.withAlpha(50)
                                    : (isUnlocked ? Colors.brown[800] : Colors.amber[800]),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _buyAndEquipSkin(skinStr, cost),
                              child: isEquipped
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.greenAccent),
                                        SizedBox(width: 4),
                                        Text('Equipado', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : (isUnlocked
                                      ? const Text('Equipar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.monetization_on_rounded, size: 12, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text('$cost K\$', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                                          ],
                                        )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Sección de Potenciadores (Powerups)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'POTENCIADORES CONSUMIBLES (1 USO) ⚡',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
                ),
              ),
              // Selector desplegable para filtrar por juego
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withAlpha(80), width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGameFilter,
                      dropdownColor: const Color(0xFF161616),
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.cyanAccent),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedGameFilter = newValue;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Mostrar todos los potenciadores')),
                        DropdownMenuItem(value: 'caca_catch', child: Text('Filtrar por: Caca Catch 🚽')),
                        DropdownMenuItem(value: 'flappy_poop', child: Text('Filtrar por: Flappy Poop 💩🕊️')),
                        DropdownMenuItem(value: 'toilet_jump', child: Text('Filtrar por: Toilet Jump 💩jump')),
                        DropdownMenuItem(value: 'poop_invaders', child: Text('Filtrar por: Poop Invaders 👾')),
                      ],
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final filteredPowerups = powerupsList.where((item) {
                    if (_selectedGameFilter == 'todos') return true;
                    final List<String> games = List<String>.from(item['games'] ?? []);
                    if (_selectedGameFilter == 'caca_catch' && games.contains('Caca Catch')) return true;
                    if (_selectedGameFilter == 'flappy_poop' && games.contains('Flappy Poop')) return true;
                    if (_selectedGameFilter == 'toilet_jump' && games.contains('Toilet Jump')) return true;
                    if (_selectedGameFilter == 'poop_invaders' && games.contains('Poop Invaders')) return true;
                    return false;
                  }).toList();

                  if (filteredPowerups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'No hay potenciadores para este minijuego.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPowerups.length,
                    itemBuilder: (context, index) {
                      final item = filteredPowerups[index];
                      final id = item['id'] as String;
                      final cost = item['cost'] as int;
                      final iconStr = item['icon'] as String;

                      bool isAlreadyPurchased = false;
                      if (id == 'shield' && _hasInitialSoapShield) isAlreadyPurchased = true;
                      if (id == 'spring' && _hasInitialSpring) isAlreadyPurchased = true;
                      if (id == 'magnet' && _hasFeverMagnet) isAlreadyPurchased = true;
                      if (id == 'life' && _hasExtraLife) isAlreadyPurchased = true;

                      return Card(
                        color: const Color(0xFF161616),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isAlreadyPurchased 
                                ? Colors.cyanAccent.withAlpha(120) 
                                : Colors.brown[900]!.withAlpha(80),
                            width: 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isAlreadyPurchased 
                                    ? Colors.cyanAccent.withAlpha(30)
                                    : Colors.grey[900],
                                child: Text(
                                  iconStr,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['description'] as String,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 82,
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAlreadyPurchased
                                        ? Colors.cyanAccent.withAlpha(40)
                                        : Colors.cyan[800],
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: isAlreadyPurchased ? null : () => _buyPowerup(id, cost),
                                  child: isAlreadyPurchased
                                      ? const Text(
                                          'ACTIVADO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.monetization_on_rounded, size: 10, color: Colors.amber),
                                            const SizedBox(width: 3),
                                            Text(
                                              '$cost K\$',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- MINIJUEGO 4: POOP INVADERS 👾 ---
  // ==========================================
  void _startPoopInvaders() {
    _onGameStarted();
    _stopPoopInvaders();
    setState(() {
      _score = 0;
      _lives = _hasLifeInsurance ? 4 : 3;
      _invadersShipX = 0.5;
      _invadersShipY = 0.85;
      _invaderLasers.clear();
      _invaderEnemies.clear();
      _invaderSpawnProb = 0.035;
      _invaderSpeed = 1.3;
      _invaderShootCooldown = 0;
      _isInvadersGameOver = false;
      
      _hasTripleShot = false;
      _tripleShotTicksRemaining = 0;
      _hasBurstShot = false;
      _burstShotTicksRemaining = 0;
      _isBossActive = false;
      _bossX = 0.5;
      _bossVx = 1.2;
      _bossHp = 0;
      _bossMaxHp = 10;
      _bossShootCooldown = 0;
      _invaderItems.clear();

      _particles.clear();
      _shakeTicks = 0;
      _flashColor = null;

      _lastTickTime = DateTime.now();
      _floatingTexts.clear();
      _isPaused = false;
    });

    final user = _authService.currentUser;
    if (user != null) {
      _dbService.unlockAchievement(user.uid, 'zen_player', user.displayName);
    }

    _poopInvadersTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updatePoopInvadersStep();
    });
  }

  void _stopPoopInvaders() {
    _poopInvadersTimer?.cancel();
    _poopInvadersTimer = null;
  }

  void _updatePoopInvadersStep() {
    final dt = _calculateDeltaTime();
    if (_isPaused || _isInvadersGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    _updateJuicyEffects(dt);
    final rand = Random();

    setState(() {
      // Cooldown de disparo automático o ráfaga
      if (_invaderShootCooldown > 0) {
        _invaderShootCooldown--;
      } else {
        // Disparar chorro de agua automáticamente hacia arriba
        double shipYNorm = _invadersShipY;
        double speedVal = _hasBurstShot ? 8.0 : 6.0;
        int cooldownVal = _hasBurstShot ? 4 : (_hasTripleShot ? 15 : 12);

        if (_hasTripleShot) {
          _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: shipYNorm, speed: speedVal, vx: 0.0, isBurst: _hasBurstShot));
          _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: shipYNorm, speed: speedVal, vx: -0.6, isBurst: _hasBurstShot));
          _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: shipYNorm, speed: speedVal, vx: 0.6, isBurst: _hasBurstShot));
          _invaderShootCooldown = cooldownVal;
          _spawnParticles(_invadersShipX * _gameWidth, _invadersShipY * _gameHeight, _hasBurstShot ? '🔥' : '💦', 3, speed: 2.0);
        } else {
          _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: shipYNorm, speed: speedVal, isBurst: _hasBurstShot));
          _invaderShootCooldown = cooldownVal;
          _spawnParticles(_invadersShipX * _gameWidth, _invadersShipY * _gameHeight, _hasBurstShot ? '🔥' : '💦', 1, speed: 2.0);
        }
      }

      // Countdown de disparo triple
      if (_hasTripleShot) {
        _tripleShotTicksRemaining--;
        if (_tripleShotTicksRemaining <= 0) {
          _hasTripleShot = false;
        }
      }

      // Countdown de disparo ráfaga
      if (_hasBurstShot) {
        _burstShotTicksRemaining--;
        if (_burstShotTicksRemaining <= 0) {
          _hasBurstShot = false;
        }
      }

      // Spawn jefe cada 300 puntos
      if (_score > 0 && _score % 300 == 0 && !_isBossActive) {
        _isBossActive = true;
        _bossX = 0.5;
        _bossHp = 10;
        _bossMaxHp = 10;
        _bossShootCooldown = 25;
        _bossVx = 1.2;
        _spawnFloatingText(_gameWidth / 2, _gameHeight * 0.3, '¡JEFE BACTERIA! 👑🦠', Colors.redAccent, fontSize: 20);
        _triggerShake(5.0, 15);
        _triggerFlash(Colors.redAccent.withAlpha(50), 10);
      }

      // Spawn enemigos normales
      double spawnChance = _isBossActive ? 0.005 : _invaderSpawnProb;
      if (rand.nextDouble() < spawnChance) {
        final rVal = rand.nextDouble();
        String type = '👾';
        int enemyLives = 1;
        if (rVal < 0.25) {
          type = '🦠';
          enemyLives = 2;
        } else if (rVal < 0.08) {
          type = '🧟';
          enemyLives = 3;
        }

        _invaderEnemies.add(InvaderEnemy(
          x: rand.nextDouble() * 0.85 + 0.075,
          y: 0.0,
          speed: (_invaderSpeed + rand.nextDouble() * 0.4) * (1.0 / enemyLives),
          type: type,
          lives: enemyLives,
        ));
      }

      // Lógica de movimiento del Jefe
      if (_isBossActive) {
        _bossX += _bossVx * 0.005 * dt * 33.3;
        if (_bossX < 0.15 || _bossX > 0.85) {
          _bossVx = -_bossVx;
          _bossX = _bossX.clamp(0.15, 0.85);
        }

        // Ataques del Jefe
        if (_bossShootCooldown > 0) {
          _bossShootCooldown--;
        } else {
          _invaderLasers.add(InvaderLaser(x: _bossX, y: 0.18, speed: -4.0, isEnemy: true));
          _bossShootCooldown = 35 + rand.nextInt(20);
          _spawnParticles(_bossX * _gameWidth, 0.18 * _gameHeight, '🦠', 2, speed: 2.0);
        }
      }

      // Actualizar ítems
      for (int i = _invaderItems.length - 1; i >= 0; i--) {
        final item = _invaderItems[i];
        item.y += 1.8 * 0.005 * dt * 33.3;
        
        final itemX = item.x * _gameWidth;
        final itemY = item.y * _gameHeight;
        final shipX = _invadersShipX * _gameWidth;
        final shipY = _invadersShipY * _gameHeight;
        
        if ((itemX - shipX).abs() < 24 && (itemY - shipY).abs() < 24) {
          _invaderItems.removeAt(i);
          HapticFeedback.heavyImpact();
          if (item.type == 'triple') {
            _hasTripleShot = true;
            _tripleShotTicksRemaining = 200;
            _triggerFlash(Colors.cyanAccent.withAlpha(80), 8);
            _spawnParticles(itemX, itemY, '💧', 10);
            _spawnFloatingText(itemX, itemY - 20, '¡DISPARO TRIPLE! 💧', Colors.cyanAccent, fontSize: 16);
          } else if (item.type == 'burst') {
            _hasBurstShot = true;
            _burstShotTicksRemaining = 150;
            _triggerFlash(Colors.amber.withAlpha(80), 8);
            _spawnParticles(itemX, itemY, '🔥', 10);
            _spawnFloatingText(itemX, itemY - 20, '¡RÁFAGA FUEGO! 🔫🔥', Colors.amberAccent, fontSize: 16);
          } else if (item.type == 'bomb') {
            _triggerFlash(Colors.orangeAccent.withAlpha(140), 15);
            _triggerShake(12.0, 20);
            _spawnParticles(itemX, itemY, '💥', 15, speed: 5.0);
            _spawnFloatingText(itemX, itemY - 20, '¡BOMBA TÁCTICA! 💣', Colors.redAccent, fontSize: 18);
            _executeBombExplosion();
          }
          continue;
        }
        
        if (item.y >= 0.95) {
          _invaderItems.removeAt(i);
        }
      }

      // Actualizar láseres (del jugador y enemigos)
      for (int i = _invaderLasers.length - 1; i >= 0; i--) {
        final laser = _invaderLasers[i];
        if (laser.isEnemy) {
          // Mover hacia abajo
          laser.y -= (laser.speed * 0.03 * dt * 33.3);
          
          final laserX = laser.x * _gameWidth;
          final laserY = laser.y * _gameHeight;
          final shipX = _invadersShipX * _gameWidth;
          final shipY = _invadersShipY * _gameHeight;
          
          if ((laserX - shipX).abs() < 24 && (laserY - shipY).abs() < 24) {
            _invaderLasers.removeAt(i);
            _triggerFlash(Colors.red.withAlpha(80), 5);
            HapticFeedback.vibrate();
            _lives--;
            _spawnFloatingText(shipX, shipY - 20, '💔 -1 Vida', Colors.redAccent, fontSize: 14);
            
            if (_lives <= 0) {
              _handleInvadersGameOver();
            }
          } else if (laser.y >= 0.95) {
            _invaderLasers.removeAt(i);
          }
        } else {
          // Mover hacia arriba
          laser.y -= (laser.speed * 0.03 * dt * 33.3);
          laser.x += laser.vx * 0.01 * dt * 33.3;
          
          if (laser.y < 0.0 || laser.y > 1.0 || laser.x < 0.0 || laser.x > 1.0) {
            _invaderLasers.removeAt(i);
          }
        }
      }

      // Actualizar enemigos comunes
      for (int i = _invaderEnemies.length - 1; i >= 0; i--) {
        final enemy = _invaderEnemies[i];
        enemy.y += (enemy.speed * 0.005 * dt * 33.3);

        if (enemy.y >= 0.88) {
          _triggerFlash(Colors.red.withAlpha(50), 5);
          HapticFeedback.vibrate();
          _lives--;
          _spawnFloatingText(enemy.x * _gameWidth, _gameHeight - 60, '💔 -1 Vida', Colors.redAccent, fontSize: 14);
          _invaderEnemies.removeAt(i);

          if (_lives <= 0) {
            _handleInvadersGameOver();
          }
          continue;
        }

        // Colisión con láseres del jugador
        final enemyX = enemy.x * _gameWidth;
        final enemyY = enemy.y * _gameHeight;
        bool hit = false;

        for (int j = _invaderLasers.length - 1; j >= 0; j--) {
          final laser = _invaderLasers[j];
          if (laser.isEnemy) continue;
          
          final laserX = laser.x * _gameWidth;
          final laserY = laser.y * _gameHeight;

          if ((laserX - enemyX).abs() < 26 && (laserY - enemyY).abs() < 31) {
            _invaderLasers.removeAt(j);
            enemy.lives--;
            _spawnParticles(enemyX, enemyY, '💦', 4);
            HapticFeedback.lightImpact();

            if (enemy.lives <= 0) {
              hit = true;
              int points = enemy.type == '👾' ? 10 : (enemy.type == '🦠' ? 25 : 50);
              _score += points;
              _saveHighScore('poop_invaders', _score);
              final user = _authService.currentUser;
              if (user != null && _score >= 100) {
                _dbService.unlockAchievement(user.uid, 'invaders_expert', user.displayName);
              }
              _spawnParticles(enemyX, enemyY, '💥', 8);
              _spawnFloatingText(enemyX, enemyY - 10, '+$points 💥', Colors.greenAccent);
              
              if (rand.nextDouble() < 0.15) {
                final rItem = rand.nextDouble();
                final String itemType;
                if (rItem < 0.45) {
                  itemType = 'triple';
                } else if (rItem < 0.80) {
                  itemType = 'burst';
                } else {
                  itemType = 'bomb';
                }
                _invaderItems.add(InvaderItem(x: enemy.x, y: enemy.y, type: itemType));
              }

              // Dificultad progresiva
              if (_score > 0 && _score % 150 == 0) {
                _invaderSpeed += 0.15;
                _invaderSpawnProb += 0.005;
                _spawnFloatingText(_gameWidth / 2, _gameHeight * 0.4, '¡MÁS VELOCIDAD! ⚡', Colors.redAccent, fontSize: 18);
              }
            }
            break;
          }
        }

        if (hit) {
          _invaderEnemies.removeAt(i);
        }
      }

      // Colisión del Jefe con láseres del jugador
      if (_isBossActive) {
        final bossXReal = _bossX * _gameWidth;
        final bossYReal = 0.15 * _gameHeight;
        
        for (int j = _invaderLasers.length - 1; j >= 0; j--) {
          final laser = _invaderLasers[j];
          if (laser.isEnemy) continue;
          
          final laserX = laser.x * _gameWidth;
          final laserY = laser.y * _gameHeight;
          
          if ((laserX - bossXReal).abs() < 36 && (laserY - bossYReal).abs() < 36) {
            _invaderLasers.removeAt(j);
            _bossHp--;
            _spawnParticles(bossXReal, bossYReal, '💦', 5);
            HapticFeedback.lightImpact();
            _triggerShake(2.0, 4);
            
            if (_bossHp <= 0) {
              _isBossActive = false;
              _score += 100;
              _saveHighScore('poop_invaders', _score);
              final user = _authService.currentUser;
              if (user != null && _score >= 100) {
                _dbService.unlockAchievement(user.uid, 'invaders_expert', user.displayName);
              }
              _triggerFlash(Colors.greenAccent.withAlpha(120), 15);
              _triggerShake(8.0, 25);
              _spawnParticles(bossXReal, bossYReal, '💥', 25, speed: 6.0);
              _spawnFloatingText(bossXReal, bossYReal, '+100 👑', Colors.greenAccent, fontSize: 20);
              
              if (user != null) {
                _dbService.addKcoins(user.uid, 20);
                _spawnFloatingText(bossXReal, bossYReal + 20, '+20 K\$ 💰', Colors.amberAccent, fontSize: 16.0);
              }
              final bossItemType = rand.nextBool() ? 'bomb' : 'burst';
              _invaderItems.add(InvaderItem(x: _bossX, y: 0.15, type: bossItemType));
            }
            break;
          }
        }
      }

      // Actualizar textos flotantes
      for (int i = _floatingTexts.length - 1; i >= 0; i--) {
        _floatingTexts[i].update(dt);
        if (_floatingTexts[i].lifeTime <= 0) {
          _floatingTexts.removeAt(i);
        }
      }
    });
  }

  void _handleInvadersGameOver() {
    HapticFeedback.vibrate();
    _triggerFlash(Colors.redAccent.withAlpha(120), 10);
    _triggerShake(8.0, 15);
    _stopPoopInvaders();
    setState(() {
      _isInvadersGameOver = true;
    });

    // Otorgar Kakadólares según puntuación (1 K$ por cada 10 puntos)
    final user = _authService.currentUser;
    if (user != null && _score > 0) {
      final kcoinsEarned = (_score / 10).floor();
      if (kcoinsEarned > 0) {
        _dbService.addKcoins(user.uid, kcoinsEarned);
        _spawnFloatingText(_gameWidth / 2, _gameHeight / 2, '¡Ganaste $kcoinsEarned K\$! 💰', Colors.amberAccent, fontSize: 20);
      }
    }
  }

  void _executeBombExplosion() {
    HapticFeedback.vibrate();
    int totalEnemiesDestroyed = 0;
    int pointsGained = 0;

    for (var enemy in _invaderEnemies) {
      final enemyX = enemy.x * _gameWidth;
      final enemyY = enemy.y * _gameHeight;
      int points = enemy.type == '👾' ? 10 : (enemy.type == '🦠' ? 25 : 50);
      pointsGained += points;
      totalEnemiesDestroyed++;

      _spawnParticles(enemyX, enemyY, '💥', 8);
      _spawnParticles(enemyX, enemyY, '🔥', 4);
      _spawnFloatingText(enemyX, enemyY - 10, '+$points 💥', Colors.greenAccent);
    }
    _invaderEnemies.clear();

    if (_isBossActive) {
      final bossXReal = _bossX * _gameWidth;
      final bossYReal = 0.15 * _gameHeight;
      const damage = 5;
      _bossHp -= damage;
      _spawnParticles(bossXReal, bossYReal, '💥', 12, speed: 4.0);
      _spawnFloatingText(bossXReal, bossYReal, '-$damage HP 👑💥', Colors.redAccent, fontSize: 18);
      
      if (_bossHp <= 0) {
        _isBossActive = false;
        pointsGained += 100;
        _triggerFlash(Colors.greenAccent.withAlpha(120), 15);
        _triggerShake(8.0, 25);
        _spawnParticles(bossXReal, bossYReal, '💥', 25, speed: 6.0);
        _spawnFloatingText(bossXReal, bossYReal, '+100 👑', Colors.greenAccent, fontSize: 20);
        
        final user = _authService.currentUser;
        if (user != null) {
          _dbService.addKcoins(user.uid, 20);
          _spawnFloatingText(bossXReal, bossYReal + 20, '+20 K\$ 💰', Colors.amberAccent, fontSize: 16.0);
        }
      }
    }

    if (pointsGained > 0) {
      setState(() {
        _score += pointsGained;
        _saveHighScore('poop_invaders', _score);
      });
      final user = _authService.currentUser;
      if (user != null && _score >= 100) {
        _dbService.unlockAchievement(user.uid, 'invaders_expert', user.displayName);
      }
    }

    _spawnFloatingText(_gameWidth / 2, _gameHeight / 2, '¡LIMPIEZA TOTAL! 💣 ($totalEnemiesDestroyed)', Colors.orangeAccent, fontSize: 18);
  }

  Widget _buildPoopInvadersArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Row(
              children: List.generate(3, (i) => Icon(
                i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.redAccent, size: 18,
              )),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isInvadersGameOver) {
                        _isPaused = !_isPaused;
                        if (!_isPaused) {
                          _lastTickTime = DateTime.now();
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _exitToMenu,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;

              if (_gameWidth > 50 && _gameHeight > 50) {
                if (_poopInvadersTimer == null && !_isInvadersGameOver && !_isPaused) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _poopInvadersTimer == null) {
                      _startPoopInvaders();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (_isPaused || _isInvadersGameOver) return;
                    setState(() {
                      _invadersShipX = (_invadersShipX + details.delta.dx / _gameWidth).clamp(0.08, 0.92);
                      _invadersShipY = (_invadersShipY + details.delta.dy / _gameHeight).clamp(0.30, 0.90);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B11),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withAlpha(40)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PoopInvadersPainter(
                                shipX: _invadersShipX,
                                shipY: _invadersShipY,
                                lasers: _invaderLasers,
                                enemies: _invaderEnemies,
                                particles: _particles,
                                width: _gameWidth,
                                height: _gameHeight,
                                floatingTexts: _floatingTexts,
                                score: _score,
                                record: _highScorePoopInvaders,
                                isBossActive: _isBossActive,
                                bossX: _bossX,
                                bossHp: _bossHp,
                                bossMaxHp: _bossMaxHp,
                                items: _invaderItems,
                              ),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: Container(color: _flashColor),
                            ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '👈 Desliza para mover el inodoro  |  🔫 Disparo automático',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          _buildInGameOverlay(ActiveGame.poopInvaders, _startPoopInvaders),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}

// ==========================================
// --- CLASES AUXILIARES Y PINTORES ---
// ==========================================

class GameParticle {
  double x;
  double y;
  double vx;
  double vy;
  String emoji;
  double opacity;
  double scale;
  int lifeTime;
  int maxLifeTime;

  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.emoji,
    this.opacity = 1.0,
    this.scale = 1.0,
    required this.lifeTime,
  }) : maxLifeTime = lifeTime;

  void update(double dt) {
    x += vx * dt * 33.3;
    y += vy * dt * 33.3;
    lifeTime--;
    opacity = (lifeTime / maxLifeTime).clamp(0.0, 1.0);
  }
}

// --- CACA CATCH ---
enum CatchItemType { poop, paper, bacteria, soap, goldenPoop, soda, chlorineBomb }

class CatchItem {
  double x;
  double y;
  final CatchItemType type;
  final String icon;
  final Color color;

  CatchItem({
    required this.x,
    required this.y,
    required this.type,
    required this.icon,
    required this.color,
  });
}

class CacaCatchPainter extends CustomPainter {
  final List<CatchItem> items;
  final double toiletX;
  final List<GameParticle> particles;
  final bool hasSoapShield;
  final bool isSodaFrenzy;
  final bool isFeverMode;
  final double width;
  final double height;
  final List<FloatingText> floatingTexts;

  CacaCatchPainter({
    required this.items,
    required this.toiletX,
    required this.particles,
    required this.hasSoapShield,
    required this.isSodaFrenzy,
    required this.isFeverMode,
    required this.width,
    required this.height,
    required this.floatingTexts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar fondo de cuadrícula
    final gridPaint = Paint()
      ..color = isFeverMode ? Colors.amber.withAlpha(20) : Colors.white10
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    if (isFeverMode) {
      // Texto "FIEBRE" en el fondo
      final textPainter = TextPainter(
        text: TextSpan(
          text: '¡FIEBRE!',
          style: TextStyle(
            color: Colors.amber.withAlpha(40),
            fontSize: 42,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((width - textPainter.width) / 2, height * 0.35));
    }

    // Dibujar items
    for (var item in items) {
      final isSpecial = item.type == CatchItemType.goldenPoop || item.type == CatchItemType.soap || item.type == CatchItemType.soda || item.type == CatchItemType.chlorineBomb;
      
      if (isSpecial) {
        final glowPaint = Paint()
          ..color = item.color.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
        canvas.drawCircle(Offset(item.x * width, item.y * height), 16, glowPaint);
      }

      final textPainter = TextPainter(
        text: TextSpan(text: item.icon, style: const TextStyle(fontSize: 26)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(item.x * width - textPainter.width / 2, item.y * height - textPainter.height / 2));
    }

    // Dibujar inodoro 🚽 en la parte inferior
    final toiletY = height - 50.0;
    final toiletRealX = toiletX * width;
    
    // Si tiene escudo de jabón, dibujar halo celeste brillante
    if (hasSoapShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 34, shieldPaint);
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 34, borderPaint);
    }

    // Si tiene soda frenesí, dibujar aura cian brillante
    if (isSodaFrenzy) {
      final frenzyPaint = Paint()
        ..color = Colors.cyanAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final frenzyBorder = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 36, frenzyPaint);
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 36, frenzyBorder);
    }

    // Si es modo fiebre, dibujar aura dorada alrededor de la taza
    if (isFeverMode) {
      final feverPaint = Paint()
        ..color = Colors.amber.withAlpha(90)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 32, feverPaint);
    }

    final toiletPainter = TextPainter(
      text: const TextSpan(text: '🚽', style: TextStyle(fontSize: 42)),
      textDirection: TextDirection.ltr,
    );
    toiletPainter.layout();
    toiletPainter.paint(canvas, Offset(toiletRealX - toiletPainter.width / 2, toiletY - 8));

    // Dibujar partículas
    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(ft.x - textPainter.width / 2, ft.y - textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- FLAPPY POOP ---
class FlappyPipe {
  double x;
  final double gapY;
  final double gapHeight;
  bool passed = false;
  bool hasStar;
  bool starCollected;

  FlappyPipe({
    required this.x,
    required this.gapY,
    required this.gapHeight,
    this.hasStar = false,
    this.starCollected = false,
  });
}

class FlappyGamePainter extends CustomPainter {
  final double flappyX;
  final double poopY;
  final List<FlappyPipe> pipes;
  final double width;
  final double height;
  final double flappyBgX;
  final double flappyAngle;
  final List<GameParticle> particles;
  final int highScore;
  final String equippedSkin;
  final List<FloatingText> floatingTexts;
  final bool hasShield;

  FlappyGamePainter({
    required this.flappyX,
    required this.poopY,
    required this.pipes,
    required this.width,
    required this.height,
    required this.flappyBgX,
    required this.flappyAngle,
    required this.particles,
    required this.highScore,
    required this.equippedSkin,
    required this.floatingTexts,
    required this.hasShield,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar estrellas lejanas (Parallax)
    final starsRand = Random(123);
    for (int i = 0; i < 20; i++) {
      double sx = (starsRand.nextDouble() * width + flappyBgX * 0.2) % width;
      double sy = starsRand.nextDouble() * height;
      double size = 0.5 + starsRand.nextDouble() * 1.0;
      double opacity = 0.2 + 0.8 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      final starPaint = Paint()..color = Colors.white.withAlpha((opacity * 255).toInt());
      canvas.drawCircle(Offset(sx, sy), size, starPaint);
    }

    // Dibujar nubes en el fondo con scroll parallax
    final cloudPaint = Paint()..color = Colors.white.withAlpha(22);
    for (int i = 0; i < 3; i++) {
      double cloudX = (flappyBgX + (i * width / 1.5)) % (width + 120) - 60;
      double cloudY = 50.0 + (i * 40) % 100;
      canvas.drawCircle(Offset(cloudX, cloudY), 24, cloudPaint);
      canvas.drawCircle(Offset(cloudX + 14, cloudY - 4), 20, cloudPaint);
      canvas.drawCircle(Offset(cloudX - 14, cloudY - 4), 20, cloudPaint);
    }

    // Dibujar fondo de tuberías/mallas
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    // Dibujar tuberías
    final pipePaint = Paint()
      ..color = Colors.green[800]!
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.fill;

    for (var pipe in pipes) {
      // Sombra proyectada
      canvas.drawRect(Rect.fromLTWH(pipe.x + 4, 0, 50, pipe.gapY), shadowPaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x + 4, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight)), shadowPaint);

      // Tubería superior
      canvas.drawRect(Rect.fromLTWH(pipe.x, 0, 50, pipe.gapY), pipePaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x - 3, pipe.gapY - 18, 56, 18), rimPaint);

      // Tubería inferior
      canvas.drawRect(Rect.fromLTWH(pipe.x, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight)), pipePaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x - 3, pipe.gapY + pipe.gapHeight, 56, 18), rimPaint);

      // Dibujar estrella si está presente
      if (pipe.hasStar && !pipe.starCollected) {
        final starX = pipe.x + 27.5;
        final starY = pipe.gapY + pipe.gapHeight / 2;
        
        final glowStar = Paint()
          ..color = Colors.amber.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
        canvas.drawCircle(Offset(starX, starY), 12, glowStar);

        final starPainter = TextPainter(
          text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 20)),
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(canvas, Offset(starX - starPainter.width / 2, starY - starPainter.height / 2));
      }
    }

    // Dibujar línea de High Score
    if (highScore > 0) {
      final scorePaint = Paint()
        ..color = Colors.yellow[700]!.withAlpha(120)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, height - 30), Offset(width, height - 30), scorePaint);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🏆 RÉCORD: $highScore',
          style: TextStyle(color: Colors.yellow[700]!.withAlpha(150), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, height - 28));
    }

    // Dibujar partículas
    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar la caca rotada
    canvas.save();
    canvas.translate(flappyX, poopY);
    canvas.rotate(flappyAngle);

    // Dibujar escudo alrededor del personaje
    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(0, 0), 22, shieldPaint);
      canvas.drawCircle(const Offset(0, 0), 22, borderPaint);
    }

    final textPainter = TextPainter(
      text: TextSpan(text: equippedSkin, style: const TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();

    // Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      final ftPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ftPainter.layout();
      ftPainter.paint(canvas, Offset(ft.x - ftPainter.width / 2, ft.y - ftPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- TOILET JUMP ---
enum PlatformType { normal, moving, fragile, superSpring }
enum ItemType { none, spring, jetpack, balloon }

class JumpPlatform {
  double x;
  double y;
  double width;
  final PlatformType type;
  double vx = 2.0; // Velocidad de plataformas móviles
  bool broken = false;
  ItemType item;
  bool itemUsed = false;
  double scaleY = 1.0;

  JumpPlatform({
    required this.x,
    required this.y,
    required this.width,
    required this.type,
    this.item = ItemType.none,
  });
}

class BacteriaEnemy {
  double x;
  double y;
  double baseY;
  double vx;
  double width = 28;
  double height = 28;
  bool dead = false;
  double time = 0.0;

  BacteriaEnemy({
    required this.x,
    required this.y,
    required this.vx,
  }) : baseY = y;
}

class ToiletJumpPainter extends CustomPainter {
  final double jumpX;
  final double jumpY;
  final double cameraY;
  final List<JumpPlatform> platforms;
  final List<BacteriaEnemy> bacterias;
  final List<GameParticle> particles;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final bool hasJetpack;
  final bool hasBalloon;
  final String equippedSkin;
  final List<FloatingText> floatingTexts;

  ToiletJumpPainter({
    required this.jumpX,
    required this.jumpY,
    required this.cameraY,
    required this.platforms,
    required this.bacterias,
    required this.particles,
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.hasJetpack,
    required this.hasBalloon,
    required this.equippedSkin,
    required this.floatingTexts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar gradiente atmosférico basado en la altura de la cámara (-cameraY)
    final heightClimbed = -cameraY;
    
    Color skyTop;
    Color skyBottom;
    
    if (heightClimbed < 2000) {
      final t = (heightClimbed / 2000.0).clamp(0.0, 1.0);
      skyTop = Color.lerp(const Color(0xFF1E2836), const Color(0xFF0D1017), t)!;
      skyBottom = Color.lerp(const Color(0xFFE28A3B), const Color(0xFF1A1B24), t)!;
    } else if (heightClimbed < 5000) {
      final t = ((heightClimbed - 2000.0) / 3000.0).clamp(0.0, 1.0);
      skyTop = Color.lerp(const Color(0xFF0D1017), const Color(0xFF020202), t)!;
      skyBottom = Color.lerp(const Color(0xFF1A1B24), const Color(0xFF050505), t)!;
    } else {
      skyTop = const Color(0xFF010101);
      skyBottom = const Color(0xFF030303);
    }
    
    final skyRect = Rect.fromLTWH(0, 0, width, height);
    final skyGradient = LinearGradient(
      colors: [skyTop, skyBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final skyPaint = Paint()..shader = skyGradient.createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Dibujar estrellas procedurales en parallax
    final starsRand = Random(42);
    for (int i = 0; i < 35; i++) {
      double sx = starsRand.nextDouble() * width;
      double sy = (starsRand.nextDouble() * height - (cameraY * 0.4)) % height;
      double size = 0.5 + starsRand.nextDouble() * 1.5;
      double opacity = 0.3 + 0.7 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      
      final starPaint = Paint()..color = Colors.white.withAlpha((opacity * 255).toInt());
      canvas.drawCircle(Offset(sx, sy), size, starPaint);
    }

    canvas.save();
    canvas.translate(0, -cameraY);

    // Dibujar plataformas
    final normalPaint = Paint()
      ..color = Colors.greenAccent[700]!
      ..style = PaintingStyle.fill;
    final movingPaint = Paint()
      ..color = Colors.blueAccent[400]!
      ..style = PaintingStyle.fill;
    final fragilePaint = Paint()
      ..color = Colors.brown[600]!
      ..style = PaintingStyle.fill;
    final superSpringPaint = Paint()
      ..color = Colors.redAccent[400]!
      ..style = PaintingStyle.fill;

    for (var p in platforms) {
      if (p.broken) continue;

      Paint pPaint = normalPaint;
      if (p.type == PlatformType.moving) {
        pPaint = movingPaint;
      } else if (p.type == PlatformType.fragile) {
        pPaint = fragilePaint;
      } else if (p.type == PlatformType.superSpring) {
        pPaint = superSpringPaint;
      }

      final rect = Rect.fromLTWH(p.x, p.y, p.width, 10);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(rrect, pPaint);

      final borderPaint = Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);

      // Dibujar objetos sobre las plataformas
      if (p.item != ItemType.none && !p.itemUsed) {
        final itemIcon = p.item == ItemType.spring 
            ? '🌀' 
            : (p.item == ItemType.jetpack ? '🚀' : '🎈');
        
        canvas.save();
        canvas.translate(p.x + p.width / 2, p.y - 4);
        if (p.item == ItemType.spring) {
          canvas.scale(1.0, p.scaleY);
        }
        
        final itemPainter = TextPainter(
          text: TextSpan(text: itemIcon, style: const TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
        );
        itemPainter.layout();
        itemPainter.paint(canvas, Offset(-itemPainter.width / 2, -itemPainter.height));
        canvas.restore();
      }
    }

    // Dibujar bacterias enemigas
    for (var b in bacterias) {
      if (b.dead) continue;
      final enemyPainter = TextPainter(
        text: const TextSpan(text: '👾', style: TextStyle(fontSize: 24)),
        textDirection: TextDirection.ltr,
      );
      enemyPainter.layout();
      enemyPainter.paint(canvas, Offset(b.x, b.y));
    }

    // Dibujar partículas
    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar personaje
    canvas.save();
    canvas.translate(jumpX, jumpY);
    canvas.scale(scaleX, scaleY);

    if (hasJetpack) {
      final jetpackPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(60)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(0, 0), 20, jetpackPaint);
    }

    if (hasBalloon) {
      // Dibujar hilo del globo
      final linePaint = Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.0;
      canvas.drawLine(const Offset(0, -10), const Offset(12, -32), linePaint);
      
      // Dibujar globo 🎈
      final balloonPainter = TextPainter(
        text: const TextSpan(text: '🎈', style: TextStyle(fontSize: 18)),
        textDirection: TextDirection.ltr,
      );
      balloonPainter.layout();
      balloonPainter.paint(canvas, Offset(12 - balloonPainter.width / 2, -32 - balloonPainter.height));
    }

    final cacaPainter = TextPainter(
      text: TextSpan(text: equippedSkin, style: const TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    );
    cacaPainter.layout();
    cacaPainter.paint(canvas, Offset(-cacaPainter.width / 2, -cacaPainter.height / 2));
    canvas.restore();

    // Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      // Traducir las coordenadas del texto flotante a la cámara para que floten estables
      final ftPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ftPainter.layout();
      ftPainter.paint(canvas, Offset(ft.x - ftPainter.width / 2, ft.y - ftPainter.height / 2));
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class FloatingText {
  double x;
  double y;
  double vx;
  double vy;
  String text;
  Color color;
  double fontSize;
  double opacity;
  double scale;
  int lifeTime;
  int maxLifeTime;

  FloatingText({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.text,
    required this.color,
    this.fontSize = 16.0,
    this.opacity = 1.0,
    this.scale = 1.0,
    required this.lifeTime,
  }) : maxLifeTime = lifeTime;

  void update(double dt) {
    x += vx * dt * 60;
    y += vy * dt * 60;
    lifeTime--;
    opacity = (lifeTime / maxLifeTime).clamp(0.0, 1.0);
    scale = 0.8 + 0.4 * (lifeTime / maxLifeTime);
  }
}

// --- POOP INVADERS ---
class InvaderLaser {
  double x;
  double y;
  double speed;
  double vx;
  bool isEnemy;
  bool isBurst;
  InvaderLaser({
    required this.x,
    required this.y,
    this.speed = 8.0,
    this.vx = 0.0,
    this.isEnemy = false,
    this.isBurst = false,
  });
}

class InvaderItem {
  double x;
  double y;
  double speed;
  String type; // 'triple'
  InvaderItem({required this.x, required this.y, this.speed = 1.8, required this.type});
}

class InvaderEnemy {
  double x;
  double y;
  double speed;
  String type; // '👾', '🦠', '🧟'
  int lives;
  InvaderEnemy({required this.x, required this.y, this.speed = 1.5, required this.type, this.lives = 1});
}

class PoopInvadersPainter extends CustomPainter {
  final double shipX;
  final double shipY;
  final List<InvaderLaser> lasers;
  final List<InvaderEnemy> enemies;
  final List<GameParticle> particles;
  final double width;
  final double height;
  final List<FloatingText> floatingTexts;
  final int score;
  final int record;
  final bool isBossActive;
  final double bossX;
  final int bossHp;
  final int bossMaxHp;
  final List<InvaderItem> items;

  PoopInvadersPainter({
    required this.shipX,
    required this.shipY,
    required this.lasers,
    required this.enemies,
    required this.particles,
    required this.width,
    required this.height,
    required this.floatingTexts,
    required this.score,
    required this.record,
    required this.isBossActive,
    required this.bossX,
    required this.bossHp,
    required this.bossMaxHp,
    required this.items,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo de cuadrícula espacial / matriz retro
    final gridPaint = Paint()
      ..color = Colors.greenAccent.withAlpha(15)
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    // Dibujar estrellas lejanas (Parallax)
    final starsRand = Random(999);
    for (int i = 0; i < 25; i++) {
      double sx = starsRand.nextDouble() * width;
      double sy = (starsRand.nextDouble() * height + DateTime.now().millisecondsSinceEpoch * 0.05) % height;
      double starSize = 0.5 + starsRand.nextDouble() * 1.5;
      final starPaint = Paint()..color = Colors.white.withAlpha(120);
      canvas.drawCircle(Offset(sx, sy), starSize, starPaint);
    }

    // Dibujar enemigos
    for (var enemy in enemies) {
      final textPainter = TextPainter(
        text: TextSpan(text: enemy.type, style: const TextStyle(fontSize: 36)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(enemy.x * width - textPainter.width / 2, enemy.y * height - textPainter.height / 2),
      );

      // Si tienen más de 1 vida, dibujar barra de vida
      if (enemy.lives > 1) {
        final barPaint = Paint()..color = Colors.redAccent;
        canvas.drawRect(
          Rect.fromLTWH(enemy.x * width - 15, enemy.y * height - 20, 30.0 * (enemy.lives / 3.0), 3),
          barPaint,
        );
      }
    }

    // Dibujar lasers
    for (var laser in lasers) {
      final color = laser.isEnemy 
          ? Colors.purpleAccent 
          : (laser.isBurst ? Colors.amberAccent : Colors.cyanAccent);
      final laserPaint = Paint()
        ..color = color
        ..strokeWidth = laser.isEnemy ? 4.0 : 3.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(laser.x * width, laser.y * height),
        Offset(laser.x * width, laser.y * height - (laser.isEnemy ? -12 : 12)),
        laserPaint,
      );
      
      // Brillo del laser (solo del jugador)
      if (!laser.isEnemy) {
        final glowColor = laser.isBurst ? Colors.amberAccent : Colors.cyanAccent;
        final glowPaint = Paint()
          ..color = glowColor.withAlpha(80)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
        canvas.drawLine(
          Offset(laser.x * width, laser.y * height),
          Offset(laser.x * width, laser.y * height - 12),
          glowPaint,
        );
      }
    }

    // Dibujar items flotando
    for (var item in items) {
      final color = item.type == 'triple' 
          ? Colors.cyanAccent 
          : (item.type == 'burst' ? Colors.amber : Colors.orangeAccent);
      
      final glowPaint = Paint()
        ..color = color.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
      canvas.drawCircle(Offset(item.x * width, item.y * height), 12, glowPaint);
      
      final String emoji = item.type == 'triple' 
          ? '💧' 
          : (item.type == 'burst' ? '🔫' : '💣');
      
      final itemPainter = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 18)),
        textDirection: TextDirection.ltr,
      );
      itemPainter.layout();
      itemPainter.paint(canvas, Offset(item.x * width - itemPainter.width / 2, item.y * height - itemPainter.height / 2));
    }

    // Dibujar Jefe Bacteria
    if (isBossActive) {
      final bossXReal = bossX * width;
      final bossYReal = 0.15 * height;
      
      // Glow
      final glowPaint = Paint()
        ..color = Colors.redAccent.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 10);
      canvas.drawCircle(Offset(bossXReal, bossYReal), 34, glowPaint);

      final bossPainter = TextPainter(
        text: const TextSpan(text: '👑🦠', style: TextStyle(fontSize: 48)),
        textDirection: TextDirection.ltr,
      );
      bossPainter.layout();
      bossPainter.paint(canvas, Offset(bossXReal - bossPainter.width / 2, bossYReal - bossPainter.height / 2));
      
      // HP Bar
      final hpBarBg = Paint()..color = Colors.white24;
      final hpBarFg = Paint()..color = Colors.redAccent;
      
      const barWidth = 60.0;
      const barHeight = 4.0;
      final barLeft = bossXReal - barWidth / 2;
      final barTop = bossYReal - 34.0;
      
      canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barWidth, barHeight), hpBarBg);
      canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barWidth * (bossHp / bossMaxHp), barHeight), hpBarFg);
    }

    // Dibujar inodoro (nave) en su posición dinámica
    final shipYReal = shipY * height;
    final shipRealX = shipX * width;
    final shipPainter = TextPainter(
      text: const TextSpan(text: '🚽', style: TextStyle(fontSize: 38)),
      textDirection: TextDirection.ltr,
    );
    shipPainter.layout();
    shipPainter.paint(
      canvas,
      Offset(shipRealX - shipPainter.width / 2, shipYReal - shipPainter.height / 2),
    );

    // Dibujar partículas
    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(ft.x - textPainter.width / 2, ft.y - textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
