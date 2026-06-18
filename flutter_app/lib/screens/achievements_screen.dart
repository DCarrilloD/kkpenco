import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/achievement.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  List<String> _unlockedIds = [];
  String? _equippedTitle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievementsData();
  }

  Future<void> _loadAchievementsData() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (useMockData) {
        // Cargar desde SharedPreferences en modo simulación
        final prefs = await _dbService.getSharedPreferences();
        final unlocked = prefs.getStringList('unlocked_achievements_${user.uid}') ?? ['first_poop']; // first_poop desbloqueado por defecto en mock
        final title = prefs.getString('equipped_title_${user.uid}');
        
        setState(() {
          _unlockedIds = unlocked;
          _equippedTitle = title;
        });
      } else {
        // Firestore real
        final userData = await _dbService.getUserData(user.uid);
        final List<dynamic> achievements = userData['achievements'] ?? [];
        final title = userData['equippedTitle'] as String?;
        
        setState(() {
          _unlockedIds = achievements.map((e) => e.toString()).toList();
          _equippedTitle = title;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar logros: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _equipTitle(String? title) async {
    final user = _authService.currentUser;
    if (user == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _equippedTitle = title;
    });

    try {
      if (useMockData) {
        final prefs = await _dbService.getSharedPreferences();
        if (title != null) {
          await prefs.setString('equipped_title_${user.uid}', title);
        } else {
          await prefs.remove('equipped_title_${user.uid}');
        }
        
        // Actualizar en _mockRankings
        await _dbService.updateMockUserTitle(user.uid, title);
      } else {
        await _dbService.updateUserTitle(user.uid, title);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(title != null 
                ? '👑 Título equipado: "$title"' 
                : 'Título desequipado.'),
            backgroundColor: Colors.brown,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al equipar título: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Álbum de Logros', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera de progreso
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown[800]!.withAlpha(153), Colors.brown[900]!.withAlpha(204)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.brown[700]!.withAlpha(102), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_unlockedIds.length} / ${Achievement.list.length} Desbloqueados',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _unlockedIds.length / Achievement.list.length,
                            backgroundColor: Colors.grey[800],
                            color: Colors.amberAccent,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _equippedTitle != null
                              ? 'Título Equipado: "$_equippedTitle" 👑'
                              : 'Sin título equipado (toca un logro para equipar uno)',
                          style: TextStyle(
                            color: _equippedTitle != null ? Colors.amberAccent : Colors.grey[400],
                            fontSize: 14,
                            fontWeight: _equippedTitle != null ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_equippedTitle != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _equipTitle(null),
                            child: const Text('Quitar título', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          )
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Insignias del Trono',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Grid de Logros
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: Achievement.list.length,
                    itemBuilder: (context, index) {
                      final ach = Achievement.list[index];
                      final isUnlocked = _unlockedIds.contains(ach.id);
                      final isEquipped = ach.rewardTitle != null && _equippedTitle == ach.rewardTitle;

                      return GestureDetector(
                        onTap: () {
                          if (isUnlocked && ach.rewardTitle != null) {
                            _equipTitle(isEquipped ? null : ach.rewardTitle);
                          } else if (!isUnlocked) {
                            HapticFeedback.vibrate();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    Icon(Icons.lock_outline_rounded, color: ach.color),
                                    const SizedBox(width: 8),
                                    const Text('Logro Bloqueado', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                                content: Text(
                                  'Consigue este logro para desbloquear la insignia y el título: "${ach.rewardTitle ?? 'Sin título'}".\n\nCriterio: ${ach.description}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Entendido', style: TextStyle(color: Colors.grey)),
                                  )
                                ],
                              ),
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUnlocked 
                                ? (isEquipped ? Colors.amber[900]!.withAlpha(76) : const Color(0xFF1E1E1E))
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnlocked
                                  ? (isEquipped ? Colors.amberAccent : ach.color.withAlpha(127))
                                  : Colors.grey[850]!,
                              width: isEquipped ? 2.0 : 1.0,
                            ),
                            boxShadow: isUnlocked
                                ? [
                                    BoxShadow(
                                      color: ach.color.withAlpha(25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: isUnlocked 
                                        ? ach.color.withAlpha(51)
                                        : Colors.grey[900],
                                    child: Icon(
                                      ach.icon,
                                      color: isUnlocked ? ach.color : Colors.grey[700],
                                      size: 30,
                                    ),
                                  ),
                                  if (!isUnlocked)
                                    const Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.black,
                                        child: Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ach.title,
                                style: TextStyle(
                                  color: isUnlocked ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  ach.description,
                                  style: TextStyle(
                                    color: isUnlocked ? Colors.grey[400] : Colors.grey[700],
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnlocked && ach.rewardTitle != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isEquipped ? Colors.amberAccent : Colors.brown[900]?.withAlpha(127),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isEquipped ? 'EQUIPADO' : ach.rewardTitle!,
                                    style: TextStyle(
                                      color: isEquipped ? Colors.black : Colors.amberAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
