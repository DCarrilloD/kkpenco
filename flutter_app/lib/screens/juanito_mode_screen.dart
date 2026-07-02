import 'dart:async';
import 'juanito_mode/caca_catch_game.dart';
import 'juanito_mode/flappy_poop_game.dart';
import 'juanito_mode/toilet_jump_game.dart';
import 'juanito_mode/poop_invaders_game.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/achievement.dart';

enum ActiveGame { none, selectMenu, cacaCatch, flappyPoop, toiletJump, poopInvaders, storeMenu }

class JuanitoModeScreen extends StatefulWidget {
  const JuanitoModeScreen({super.key});

  @override
  State<JuanitoModeScreen> createState() => _JuanitoModeScreenState();
}

class _JuanitoModeScreenState extends State<JuanitoModeScreen> with SingleTickerProviderStateMixin {
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


  // High Scores
  int _highScoreCacaCatch = 0;
  int _highScoreFlappyPoop = 0;
  int _highScoreToiletJump = 0;
  int _highScorePoopInvaders = 0;

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
  AchievementCategory? _activeBuffCategory;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = _stopwatch.elapsed.inSeconds;
          final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
          _timeString = '$minutes:$seconds';
        });
      }
    });

    _soundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadHighScores();
    _loadZenProfile();
    _loadMusicPreference();
    _precacheFlameAudios();
  }

  void _precacheFlameAudios() {
    FlameAudio.audioCache.loadAll([
      'jump.wav',
      'coin.wav',
      'hit.wav',
      'shoot.wav',
      'explosion.wav',
    ]).then((_) {
      debugPrint('Audios de Flame precargados con éxito.');
    }).catchError((e) {
      debugPrint('Error precargando audios de Flame: $e');
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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

  // --- M├ëTODOS DE LA TIENDA Y RECOMPENSAS ---
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
          
          final powerups = profile['activePowerups'] as Map<String, dynamic>? ?? {};
          _hasInitialSoapShield = powerups['shield'] == true;
          _hasInitialSpring = powerups['spring'] == true;
          _hasFeverMagnet = powerups['magnet'] == true;
          _hasExtraLife = powerups['life'] == true;
          _hasImprovedMagnet = powerups['passive_magnet'] == true;
          _hasLifeInsurance = powerups['passive_insurance'] == true;

          if (profile['equippedTitle'] != null) {
            _activeBuffCategory = Achievement.getCategoryByTitle(profile['equippedTitle']);
          } else {
            _activeBuffCategory = null;
          }
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
            ? 'audio/First_Light_on_the_Ridge.mp3'
            : 'audio/Village_of_Seven_Springs.mp3';
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

      if (isMinigame) {
        await _audioPlayer.play(AssetSource(targetSource));
      } else {
        await _audioPlayer.play(UrlSource(targetSource));
      }
      _currentlyPlayingSource = targetSource;
    } catch (e) {
      debugPrint('Error updating music playback: $e');
    }
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
          content: Text('¡No tienes suficientes Kakadólares! 💸 Registra KKs para ganar más.'),
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
          content: Text('¡No tienes suficientes Kakadólares! 💸'),
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
          content: const Text('¡Ya tienes esta mejora activa o adquirida! 🛒'),
          backgroundColor: Colors.amber[800],
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    
    bool isPassive = id.startsWith('passive_');
    String dbId = isPassive ? id.replaceAll('passive_', '') : id;
    
    bool success = await _dbService.buyPowerupTransaction(user.uid, dbId, cost, isPassive: isPassive);
    
    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al procesar la compra. Verifica tu conexión.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    setState(() {
      if (id == 'shield') _hasInitialSoapShield = true;
      if (id == 'spring') _hasInitialSpring = true;
      if (id == 'magnet') _hasFeverMagnet = true;
      if (id == 'life') _hasExtraLife = true;
      if (id == 'passive_magnet') _hasImprovedMagnet = true;
      if (id == 'passive_insurance') _hasLifeInsurance = true;
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

  void _selectGame(ActiveGame game) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeGame = game;
    });
    _updateMusicPlayback();
  }




  void _exitToZen() {
    setState(() {
      _activeGame = ActiveGame.none;
    });
    _updateMusicPlayback();
  }

  // ==========================================
  // --- MINIJUEGO 1: CACA CATCH (ATRACA) ---
  // ==========================================









  // ==========================================
  // --- MINIJUEGO 2: FLAPPY POOP ­ƒÆ®­ƒòè´©Å ---
  // ==========================================








  bool randPercent(int percent) {
    return Random().nextInt(100) < percent;
  }






  // ==========================================
  // --- MINIJUEGO 3: TOILET JUMP ­ƒÆ®jump ---
  // ==========================================















  // ==========================================
  // --- FIN DE PARTIDA & FIN DE SESIÓN ---
  // ==========================================


  void _finishZenSession() {
    _stopwatch.stop();
    
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
        title: const Text('Modo Juanito 💩', style: TextStyle(fontWeight: FontWeight.bold)),
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
          return RepaintBoundary(
            child: CacaCatchGame(
              highScore: _highScoreCacaCatch,
              equippedSkin: _equippedSkin,
              hasImprovedMagnet: _hasImprovedMagnet,
              hasInitialSoapShield: _hasInitialSoapShield,
              hasExtraLife: _hasExtraLife,
              hasFeverMagnet: _hasFeverMagnet,
              activeBuffCategory: _activeBuffCategory,
              onGameOver: (score) => _selectGame(ActiveGame.selectMenu),
              onAddKcoins: (coins) {
                if (_activeBuffCategory == AchievementCategory.streaks) coins = (coins * 1.25).ceil();
                final user = _authService.currentUser;
                if (user != null) _dbService.addKcoins(user.uid, coins);
              },
              onUnlockAchievement: () {},
              onSaveHighScore: (score) => _saveHighScore('caca_catch', score),
            ),
          );
        case ActiveGame.flappyPoop:
          return RepaintBoundary(
            child: FlappyPoopGame(
              highScore: _highScoreFlappyPoop,
              equippedSkin: _equippedSkin,
              hasInitialSoapShield: _hasInitialSoapShield,
              hasLifeInsurance: _hasLifeInsurance,
              activeBuffCategory: _activeBuffCategory,
              onGameOver: (score) => _selectGame(ActiveGame.selectMenu),
              onAddKcoins: (coins) {
                if (_activeBuffCategory == AchievementCategory.streaks) coins = (coins * 1.25).ceil();
                final user = _authService.currentUser;
                if (user != null) _dbService.addKcoins(user.uid, coins);
              },
              onUnlockAchievement: () {},
              onSaveHighScore: (score) => _saveHighScore('flappy_poop', score),
            ),
          );
        case ActiveGame.toiletJump:
          return RepaintBoundary(
            child: ToiletJumpGame(
              equippedSkin: _equippedSkin,
              activeBuffCategory: _activeBuffCategory,
              onGameOver: (score, coins) => _selectGame(ActiveGame.selectMenu),
            ),
          );
        case ActiveGame.poopInvaders:
          return RepaintBoundary(
            child: PoopInvadersGame(
              highScore: _highScorePoopInvaders,
              equippedSkin: _equippedSkin,
              hasTripleShot: false,
              hasBurstShot: false,
              activeBuffCategory: _activeBuffCategory,
              onGameOver: (score) => _selectGame(ActiveGame.selectMenu),
              onAddKcoins: (coins) {
                if (_activeBuffCategory == AchievementCategory.streaks) coins = (coins * 1.25).ceil();
                final user = _authService.currentUser;
                if (user != null) _dbService.addKcoins(user.uid, coins);
              },
              onSaveHighScore: (score) => _saveHighScore('poop_invaders', score),
            ),
          );
      case ActiveGame.storeMenu:
        return _buildStoreMenuArea();
    }
  }

  // --- AREA ZEN / SONIDOS ---
  Widget _buildZenSoundsArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón principal y grande para Minijuegos
        ElevatedButton(
          onPressed: () {
            _loadZenProfile();
            _selectGame(ActiveGame.selectMenu);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 8,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_esports_rounded, size: 72, color: Colors.black87),
              SizedBox(height: 16),
              Text(
                'SUITE DE MINIJUEGOS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              SizedBox(height: 4),
              Text(
                '¡Juega mientras esperas!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 50),

        // Control secundario y más pequeño de Música Zen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleMusic(!_isMusicEnabled);
                },
                child: AnimatedBuilder(
                  animation: _soundAnimController,
                  builder: (context, child) {
                    final val = _isMusicEnabled ? _soundAnimController.value : 0.0;
                    return Icon(
                      _isMusicEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                      color: _isMusicEnabled ? Colors.amberAccent : Colors.grey[600],
                      size: 24 + (val * 4),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text('Música Zen', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(width: 8),
              Switch(
                value: _isMusicEnabled,
                activeColor: Colors.amberAccent,
                activeTrackColor: Colors.amberAccent.withAlpha(50),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.white10,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  _toggleMusic(val);
                },
              ),
            ],
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
                title: 'Caca Catch 🪠',
                description: 'Atrapa las cacas y rollos con el inodoro. Evita las bacterias.',
                highScore: _highScoreCacaCatch,
                icon: Icons.umbrella_rounded,
                color: Colors.brown,
                onPlay: () => _selectGame(ActiveGame.cacaCatch),
              ),
              _buildGameMenuCard(
                title: 'Flappy Poop 🪶',
                description: 'Esquiva las tuberías dando toques en la pantalla.',
                highScore: _highScoreFlappyPoop,
                icon: Icons.flight_takeoff_rounded,
                color: Colors.deepPurpleAccent,
                onPlay: () => _selectGame(ActiveGame.flappyPoop),
              ),
              _buildGameMenuCard(
                title: 'Toilet Jump 🦘',
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


  // --- AREA JUEGO 2: FLAPPY POOP ---


  // --- AREA JUEGO 3: TOILET JUMP ---


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
              // Secci├│n de Aspectos (Skins)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Text(
                  'ASPECTOS DE CACA ­ƒÄ¡',
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

              // Secci├│n de Potenciadores (Powerups)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'POTENCIADORES CONSUMIBLES (1 USO) ÔÜí',
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
                        DropdownMenuItem(value: 'caca_catch', child: Text('Filtrar por: Caca Catch ­ƒÜ¢')),
                        DropdownMenuItem(value: 'flappy_poop', child: Text('Filtrar por: Flappy Poop ­ƒÆ®­ƒòè´©Å')),
                        DropdownMenuItem(value: 'toilet_jump', child: Text('Filtrar por: Toilet Jump ­ƒÆ®jump')),
                        DropdownMenuItem(value: 'poop_invaders', child: Text('Filtrar por: Poop Invaders ­ƒæ¥')),
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
  // --- MINIJUEGO 4: POOP INVADERS ­ƒæ¥ ---
  // ==========================================












}

