import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';

/// Menú de preferencias de notificaciones push. Los avisos de eventos son la
/// base (activados por defecto); los de duelos y chat se activan aquí. Las
/// preferencias se guardan en el doc del usuario para que las Cloud Functions
/// las respeten al enviar.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();

  Map<String, bool> _prefs = Map.from(DatabaseService.defaultNotifPrefs);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final prefs = await _db.getNotificationPrefs(uid);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final uid = _auth.currentUser?.uid;
    setState(() => _prefs[key] = value);
    if (uid == null) return;
    await _db.updateNotificationPrefs(uid, _prefs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    'Elige qué avisos quieres recibir en este dispositivo.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                _NotifSwitch(
                  icon: Icons.emoji_nature_rounded,
                  emoji: '💩',
                  title: 'Nuevas KK',
                  subtitle: 'Cuando alguien del grupo registra una KK',
                  value: _prefs['events'] ?? true,
                  onChanged: (v) => _setPref('events', v),
                ),
                _NotifSwitch(
                  icon: Icons.sports_kabaddi_rounded,
                  emoji: '⚔️',
                  title: 'Duelos',
                  subtitle: 'Retos recibidos y resultados de tus duelos',
                  value: _prefs['duels'] ?? true,
                  onChanged: (v) => _setPref('duels', v),
                ),
                _NotifSwitch(
                  icon: Icons.chat_bubble_rounded,
                  emoji: '💬',
                  title: 'Chat',
                  subtitle: 'Mensajes nuevos en el chat del grupo',
                  value: _prefs['chat'] ?? false,
                  onChanged: (v) => _setPref('chat', v),
                ),
              ],
            ),
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitch({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
