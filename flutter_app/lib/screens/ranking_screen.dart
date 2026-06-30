import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'heatmap_screen.dart';
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}


class _RankingScreenState extends State<RankingScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Clasificación', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded, color: Colors.amberAccent),
            tooltip: 'Ver Mapa de Calor y Territorios',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HeatmapScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Duelos Activos / Pendientes
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dbService.getActiveDuels(currentUser.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final duels = snapshot.data!;
              return Container(
                height: 105,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: duels.length,
                  itemBuilder: (context, index) {
                    final duel = duels[index];
                    final isPending = duel['status'] == 'pending';
                    final isMeChallenged = duel['challengedId'] == currentUser.uid;
                    final opponentName = duel['challengerId'] == currentUser.uid 
                        ? duel['challengedName'] 
                        : duel['challengerName'];

                    return Card(
                      color: const Color(0xFF1A1510), // Marrón oscuro
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.brown[900]!, width: 1.5),
                      ),
                      margin: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 250,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.compare_arrows_rounded, color: Colors.deepOrangeAccent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      isPending ? 'DESAFÍO PENDIENTE' : 'DUELO EN CURSO ⚔️',
                                      style: const TextStyle(color: Colors.deepOrangeAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (!isPending) ...[
                                  Text(
                                    'Restante: ${_getDaysRemaining(duel['endDate'])}d',
                                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                                  )
                                ]
                              ],
                            ),
                            if (isPending) ...[
                              Text(
                                isMeChallenged 
                                    ? '¡$opponentName te ha desafiado!' 
                                    : 'Esperando a $opponentName...',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isMeChallenged) ...[
                                SizedBox(
                                  height: 28,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isActionLoading ? null : () => _acceptChallenge(duel['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[800],
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Aceptar Duelo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ] else ...[
                                const Text(
                                  'Pendiente de aceptación.',
                                  style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                                )
                              ]
                            ] else ...[
                              // Marcador
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tú: ${duel['challengerId'] == currentUser.uid ? duel['challengerCount'] : duel['challengedCount']} 💩',
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Text('vs', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  Expanded(
                                    child: Text(
                                      ' $opponentName: ${duel['challengerId'] == currentUser.uid ? duel['challengedCount'] : duel['challengerCount']} 💩',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                                child: LinearProgressIndicator(
                                  value: 0.5, // Marcador neutral para representar competencia
                                  color: Colors.deepOrangeAccent,
                                  backgroundColor: Colors.grey,
                                  minHeight: 4,
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Tabla del Leaderboard
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dbService.getRanking(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar ranking: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final rankingList = snapshot.data ?? [];
                if (rankingList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay datos en la clasificación.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final top3 = rankingList.take(3).toList();
                final remaining = rankingList.skip(3).toList();

                return CustomScrollView(
                  slivers: [
                    // Podio
                    if (top3.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (top3.length > 1)
                                _buildPodiumItem(
                                  user: top3[1],
                                  position: 2,
                                  color: Colors.grey[400]!,
                                  height: 110,
                                  currentUserId: currentUser.uid,
                                ),
                              _buildPodiumItem(
                                user: top3[0],
                                position: 1,
                                color: const Color(0xFFFFD700),
                                height: 145,
                                currentUserId: currentUser.uid,
                              ),
                              if (top3.length > 2)
                                _buildPodiumItem(
                                  user: top3[2],
                                  position: 3,
                                  color: const Color(0xFFCD7F32),
                                  height: 95,
                                  currentUserId: currentUser.uid,
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Lista de restantes
                    if (remaining.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = remaining[index];
                              final actualPosition = index + 4;
                              final lastPoop = user['lastPoop'] as DateTime?;
                              final title = user['equippedTitle'] as String?;
                              final streak = user['currentStreak'] as int? ?? 0;
                              final isMe = user['uid'] == currentUser.uid;

                              // Calcular si mostrar el botón Nudge (racha activa y más de 18 horas sin cagar)
                              bool showNudgeButton = false;
                              if (!isMe && streak > 0 && lastPoop != null) {
                                final hoursSinceLast = DateTime.now().difference(lastPoop).inHours;
                                if (hoursSinceLast >= 18) {
                                  showNudgeButton = true;
                                }
                              }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.brown[900]!.withAlpha(127) : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isMe ? Border.all(color: Colors.brown[700]!, width: 1) : null,
                                  ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 25,
                                      child: Text(
                                        '$actualPosition',
                                        style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.brown[700],
                                      child: Text(
                                        user['username'].substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  user['username'],
                                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (streak > 0) ...[
                                                const SizedBox(width: 4),
                                                Text('🔥$streak', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ]
                                            ],
                                          ),
                                          if (title != null) ...[
                                            Text(
                                              '👑 $title',
                                              style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (lastPoop != null)
                                            Text(
                                              'Última: ${DateFormat('dd/MM HH:mm').format(lastPoop)}',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Acciones rápidas (Nudge y Desafiar) si no soy yo
                                    if (!isMe) ...[
                                      if (showNudgeButton)
                                        IconButton(
                                          icon: const Icon(Icons.flash_on_rounded, color: Colors.orangeAccent, size: 18),
                                          tooltip: 'Empujar racha',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          onPressed: () => _sendNudge(user['uid'], user['username'], streak),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.compare_arrows_rounded, color: Colors.amberAccent, size: 18),
                                        tooltip: 'Desafiar a Duelo',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        onPressed: () => _sendChallenge(user['uid'], user['username']),
                                      ),
                                    ],
                                    const SizedBox(width: 4),

                                    // Puntuación
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.brown[900]?.withAlpha(102),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${user['poopCount']} 💩',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: remaining.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required Map<String, dynamic> user,
    required int position,
    required Color color,
    required double height,
    required String currentUserId,
  }) {
    final isMe = user['uid'] == currentUserId;
    final username = user['username'] as String;
    final count = user['poopCount'] as int;
    final title = user['equippedTitle'] as String?;
    final streak = user['currentStreak'] as int? ?? 0;
    final lastPoop = user['lastPoop'] as DateTime?;

    // Nudge
    bool showNudge = false;
    if (!isMe && streak > 0 && lastPoop != null) {
      if (DateTime.now().difference(lastPoop).inHours >= 18) {
        showNudge = true;
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: position == 1 ? 30 : 25,
              backgroundColor: isMe ? Colors.amberAccent : color,
              child: CircleAvatar(
                radius: position == 1 ? 27 : 22,
                backgroundColor: const Color(0xFF1E1E1E),
                child: Text(
                  username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: position == 1 ? 22 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (position == 1)
              const Positioned(
                top: -14,
                child: Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 20),
              ),
          ],
        ),
        const SizedBox(height: 6),
        
        // Nombre del podio con racha
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 60),
              child: Text(
                username,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (streak > 0) ...[
              const SizedBox(width: 2),
              const Text('🔥', style: TextStyle(fontSize: 10)),
            ]
          ],
        ),
        if (title != null) ...[
          Container(
            constraints: const BoxConstraints(maxWidth: 75),
            child: Text(
              title,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          )
        ],
        const SizedBox(height: 2),
        Text('$count 💩', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        
        // Acciones podio
        if (!isMe) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showNudge)
                GestureDetector(
                  onTap: () => _sendNudge(user['uid'], username, streak),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.orangeAccent, size: 14),
                ),
              if (showNudge) const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _sendChallenge(user['uid'], username),
                child: const Icon(Icons.compare_arrows_rounded, color: Colors.amberAccent, size: 14),
              ),
            ],
          ),
        ],

        const SizedBox(height: 8),
        Container(
          width: position == 1 ? 70 : 60,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(204), color.withAlpha(76)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Center(
            child: Text(
              '#$position',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  int _getDaysRemaining(dynamic endDate) {
    if (endDate == null) return 7;
    if (endDate is DateTime) {
      return max(1, endDate.difference(DateTime.now()).inDays);
    }
    return 7;
  }

  // Acciones
  Future<void> _sendChallenge(String uid, String username) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActionLoading = true;
    });
    try {
      await _dbService.sendDuelChallenge(uid, username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚔️ ¡Desafío enviado a $username!'),
            backgroundColor: Colors.brown,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al desafiar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _acceptChallenge(String duelId) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActionLoading = true;
    });
    try {
      await _dbService.acceptDuelChallenge(duelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚔️ ¡Duelo aceptado! Ha comenzado la batalla.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar duelo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _sendNudge(String uid, String username, int streak) async {
    HapticFeedback.mediumImpact();
    try {
      await _dbService.sendNudge(uid, username, streak);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ ¡Has empujado a $username para ir al baño!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar empujón: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
