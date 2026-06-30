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
      backgroundColor: const Color(0xFF000000),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.greenAccent.withAlpha(50)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    Achievement.getBuffDescription(Achievement.getCategoryByTitle(_equippedTitle)),
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontStyle: FontStyle.italic),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    'Insignias del Trono por Categoría',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  ...AchievementCategory.values.map((category) {
                    final categoryAchievements = Achievement.list.where((a) => a.category == category).toList();
                    if (categoryAchievements.isEmpty) return const SizedBox.shrink();

                    String catTitle = '';
                    IconData catIcon = Icons.star;
                    switch (category) {
                      case AchievementCategory.firstSteps: catTitle = 'Primeros Pasos'; catIcon = Icons.rocket_launch_rounded; break;
                      case AchievementCategory.streaks: catTitle = 'Rachas y Constancia'; catIcon = Icons.local_fire_department_rounded; break;
                      case AchievementCategory.calendar: catTitle = 'Calendario y Horarios'; catIcon = Icons.calendar_month_rounded; break;
                      case AchievementCategory.stats: catTitle = 'Estadísticas y Medidas'; catIcon = Icons.bar_chart_rounded; break;
                      case AchievementCategory.locations: catTitle = 'Ubicaciones y GPS'; catIcon = Icons.explore_rounded; break;
                      case AchievementCategory.social: catTitle = 'Social y Comunidad'; catIcon = Icons.people_rounded; break;
                      case AchievementCategory.games: catTitle = 'Minijuegos (Modo Juanito)'; catIcon = Icons.videogame_asset_rounded; break;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Row(
                            children: [
                              Icon(catIcon, color: Colors.amberAccent, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                catTitle,
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: categoryAchievements.length,
                          itemBuilder: (context, index) {
                            final ach = categoryAchievements[index];
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
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: CustomPaint(
                                            painter: AchievementBadgePainter(
                                              achievementId: ach.id,
                                              icon: ach.icon,
                                              color: ach.color,
                                              isUnlocked: isUnlocked,
                                            ),
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
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
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
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}

class AchievementBadgePainter extends CustomPainter {
  final String achievementId;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  AchievementBadgePainter({
    required this.achievementId,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Aura de brillo si está desbloqueado
    if (isUnlocked) {
      final glowPaint = Paint()
        ..color = color.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, radius - 4, glowPaint);
    }

    // 2. Borde metálico con gradiente de barrido
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    if (isUnlocked) {
      rimPaint.shader = SweepGradient(
        colors: [
          color,
          color.withAlpha(120),
          Colors.white,
          color,
          color.withAlpha(120),
          color,
        ],
        stops: const [0.0, 0.2, 0.45, 0.6, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      rimPaint.color = Colors.grey[800]!;
    }
    canvas.drawCircle(center, radius - 3, rimPaint);

    // 3. Fondo interior oscuro
    final bgPaint = Paint()
      ..color = isUnlocked ? const Color(0xFF1E1610) : const Color(0xFF161616)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 5, bgPaint);

    if (!isUnlocked) {
      // Si está bloqueado, dibujar candado o icono plano gris oscuro
      final lockPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 24,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.grey[800],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      lockPainter.layout();
      lockPainter.paint(
        canvas,
        Offset(center.dx - lockPainter.width / 2, center.dy - lockPainter.height / 2),
      );
      return;
    }

    // 4. Dibujar motivo vectorial premium de alta definición según la ID del logro
    bool drawn = false;

    // --- RAYO (Velocidad / Speedrunner / Speed Demon) ---
    if (achievementId.contains('speed') || achievementId.contains('fast')) {
      final rayPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final rayPath = Path();
      rayPath.moveTo(center.dx + radius * 0.12, center.dy - radius * 0.55);
      rayPath.lineTo(center.dx - radius * 0.35, center.dy + radius * 0.05);
      rayPath.lineTo(center.dx - radius * 0.05, center.dy + radius * 0.05);
      rayPath.lineTo(center.dx - radius * 0.20, center.dy + radius * 0.60);
      rayPath.lineTo(center.dx + radius * 0.35, center.dy - radius * 0.05);
      rayPath.lineTo(center.dx + radius * 0.05, center.dy - radius * 0.05);
      rayPath.close();

      canvas.drawPath(rayPath, Paint()..color = color.withAlpha(80)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
      canvas.drawPath(rayPath, rayPaint);
      drawn = true;
    }
    // --- FUEGO / RACHAS (Streak 3, 7, 15, 30, 50) ---
    else if (achievementId.contains('streak')) {
      final firePaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.yellow, color, Colors.red[900]!],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5));
      final firePath = Path();
      firePath.moveTo(center.dx, center.dy + radius * 0.5);
      firePath.cubicTo(center.dx - radius * 0.45, center.dy + radius * 0.3, center.dx - radius * 0.35, center.dy - radius * 0.15, center.dx - radius * 0.12, center.dy - radius * 0.42);
      firePath.cubicTo(center.dx - radius * 0.22, center.dy - radius * 0.08, center.dx - radius * 0.08, center.dy + radius * 0.1, center.dx, center.dy - radius * 0.12);
      firePath.cubicTo(center.dx + radius * 0.08, center.dy + radius * 0.1, center.dx + radius * 0.22, center.dy - radius * 0.08, center.dx + radius * 0.12, center.dy - radius * 0.42);
      firePath.cubicTo(center.dx + radius * 0.35, center.dy - radius * 0.15, center.dx + radius * 0.45, center.dy + radius * 0.3, center.dx, center.dy + radius * 0.5);
      firePath.close();

      canvas.drawPath(firePath, Paint()..color = color.withAlpha(90)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
      canvas.drawPath(firePath, firePaint);
      drawn = true;
    }
    // --- PESOS / MONTAÑA / COLOSO (Colossus, weight, titan) ---
    else if (achievementId.contains('weight') || achievementId.contains('colossus') || achievementId.contains('heavy')) {
      final ironPaint = Paint()..color = color..style = PaintingStyle.fill;
      final ironPath = Path();
      ironPath.moveTo(center.dx - radius * 0.45, center.dy + radius * 0.4);
      ironPath.lineTo(center.dx + radius * 0.45, center.dy + radius * 0.4);
      ironPath.lineTo(center.dx + radius * 0.28, center.dy - radius * 0.15);
      ironPath.quadraticBezierTo(center.dx, center.dy - radius * 0.3, center.dx - radius * 0.28, center.dy - radius * 0.15);
      ironPath.close();
      canvas.drawPath(ironPath, ironPaint);

      final handlePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawArc(Rect.fromCenter(center: Offset(center.dx, center.dy - radius * 0.18), width: radius * 0.32, height: radius * 0.32), 3.14, 3.14, false, handlePaint);

      String label = achievementId.contains('100kg') ? '100KG' : (achievementId.contains('20kg') ? '20KG' : '5KG');
      if (achievementId.contains('colossus')) label = 'MAX';
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(center.dx - labelPainter.width / 2, center.dy + radius * 0.05));
      drawn = true;
    }
    // --- PLUMA (Feather) ---
    else if (achievementId.contains('feather') || achievementId.contains('light')) {
      final featherPaint = Paint()..color = color..style = PaintingStyle.fill;
      final featherPath = Path();
      featherPath.moveTo(center.dx - radius * 0.35, center.dy + radius * 0.35);
      featherPath.quadraticBezierTo(center.dx - radius * 0.1, center.dy + radius * 0.1, center.dx + radius * 0.35, center.dy - radius * 0.45);
      featherPath.quadraticBezierTo(center.dx + radius * 0.1, center.dy - radius * 0.1, center.dx - radius * 0.35, center.dy + radius * 0.35);
      featherPath.close();
      canvas.drawPath(featherPath, featherPaint);
      
      final stemPaint = Paint()..color = Colors.white70..strokeWidth = 2..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(center.dx - radius * 0.4, center.dy + radius * 0.4), Offset(center.dx + radius * 0.4, center.dy - radius * 0.5), stemPaint);
      drawn = true;
    }
    // --- COPA / CONQUISTADOR / WORLD (conqueror, world, high_scorer, master) ---
    else if (achievementId.contains('conqueror') || achievementId.contains('leader') || achievementId.contains('high_scorer') || achievementId.contains('master') || achievementId.contains('champion')) {
      final cupPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Colors.amber, Colors.yellow, Colors.orange],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5));
      
      final cupPath = Path();
      cupPath.moveTo(center.dx - radius * 0.35, center.dy - radius * 0.38);
      cupPath.lineTo(center.dx + radius * 0.35, center.dy - radius * 0.38);
      cupPath.quadraticBezierTo(center.dx + radius * 0.3, center.dy + radius * 0.08, center.dx, center.dy + radius * 0.15);
      cupPath.quadraticBezierTo(center.dx - radius * 0.3, center.dy + radius * 0.08, center.dx - radius * 0.35, center.dy - radius * 0.38);
      cupPath.close();
      canvas.drawPath(cupPath, cupPaint);

      final stemPath = Path();
      stemPath.moveTo(center.dx - radius * 0.06, center.dy + radius * 0.15);
      stemPath.lineTo(center.dx + radius * 0.06, center.dy + radius * 0.15);
      stemPath.lineTo(center.dx + radius * 0.06, center.dy + radius * 0.38);
      stemPath.lineTo(center.dx - radius * 0.06, center.dy + radius * 0.38);
      stemPath.close();
      canvas.drawPath(stemPath, cupPaint);

      final baseRect = Rect.fromCenter(center: Offset(center.dx, center.dy + radius * 0.42), width: radius * 0.46, height: radius * 0.1);
      canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(3)), cupPaint);

      final handlePaint = Paint()..color = Colors.amber..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.drawArc(Rect.fromCenter(center: Offset(center.dx - radius * 0.32, center.dy - radius * 0.15), width: radius * 0.28, height: radius * 0.38), 1.57, 3.14, false, handlePaint);
      canvas.drawArc(Rect.fromCenter(center: Offset(center.dx + radius * 0.32, center.dy - radius * 0.15), width: radius * 0.28, height: radius * 0.38), -1.57, 3.14, false, handlePaint);
      drawn = true;
    }
    // --- LUNA / ESTRELLAS (night, early_bird) ---
    else if (achievementId.contains('night') || achievementId.contains('early_bird') || achievementId.contains('owl')) {
      final moonPaint = Paint()..color = color..style = PaintingStyle.fill;
      final moonPath = Path();
      moonPath.addArc(Rect.fromCircle(center: center, radius: radius * 0.45), -1.57, 3.14);
      moonPath.quadraticBezierTo(center.dx + radius * 0.1, center.dy, center.dx, center.dy - radius * 0.45);
      canvas.drawPath(moonPath, moonPaint);
      
      canvas.drawCircle(Offset(center.dx - radius * 0.2, center.dy - radius * 0.2), 2.0, Paint()..color = Colors.white70);
      canvas.drawCircle(Offset(center.dx - radius * 0.08, center.dy + radius * 0.18), 1.5, Paint()..color = Colors.white70);
      drawn = true;
    }
    // --- MONEDA / CAPITALISTA (capitalist) ---
    else if (achievementId.contains('capitalist') || achievementId.contains('money')) {
      final coinPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.45, coinPaint);
      
      final innerPaint = Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1.5;
      canvas.drawCircle(center, radius * 0.38, innerPaint);
      
      final textPainter = TextPainter(
        text: const TextSpan(text: '\$', style: TextStyle(color: Colors.black45, fontSize: 22, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
      drawn = true;
    }
    // --- ESPADAS / COMBATE (duelist, duel_master) ---
    else if (achievementId.contains('duel')) {
      final swordPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      // Espada 1
      canvas.save();
      canvas.rotate(0.785);
      canvas.drawLine(const Offset(0, -22), const Offset(0, 18), swordPaint);
      canvas.drawLine(const Offset(-6, 12), const Offset(6, 12), swordPaint);
      canvas.drawLine(const Offset(0, 12), const Offset(0, 22), swordPaint..strokeWidth = 4);
      canvas.restore();
      // Espada 2
      canvas.save();
      canvas.rotate(-0.785);
      canvas.drawLine(const Offset(0, -22), const Offset(0, 18), swordPaint);
      canvas.drawLine(const Offset(-6, 12), const Offset(6, 12), swordPaint);
      canvas.drawLine(const Offset(0, 12), const Offset(0, 22), swordPaint..strokeWidth = 4);
      canvas.restore();
      canvas.restore();
      drawn = true;
    }

    // Si no coincide con ninguno, pintamos el icono de Material predeterminado, pero muy premium
    if (!drawn) {
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 26,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
            shadows: [
              Shadow(
                color: color.withAlpha(140),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AchievementBadgePainter oldDelegate) {
    return oldDelegate.achievementId != achievementId || oldDelegate.icon != icon || oldDelegate.color != color || oldDelegate.isUnlocked != isUnlocked;
  }
}
