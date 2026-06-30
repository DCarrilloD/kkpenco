import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Timer? _typingTimer;
  bool _isTyping = false;

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final admin = await _dbService.isAdminUser(currentUser.uid);
      if (mounted) {
        setState(() {
          _isAdmin = admin;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    if (!_isTyping && _messageController.text.isNotEmpty) {
      _isTyping = true;
      _dbService.setTypingStatus(currentUser.uid, currentUser.displayName, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (_isTyping) {
        _isTyping = false;
        _dbService.setTypingStatus(currentUser.uid, currentUser.displayName, false);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = _authService.currentUser;
    if (user == null) return;

    // Reset typing status immediately
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _dbService.setTypingStatus(user.uid, user.displayName, false);
    }

    final newMessage = ChatMessage(
      id: '',
      userId: user.uid,
      displayName: user.displayName,
      content: text,
      timestamp: DateTime.now(),
      type: 'text',
      reactions: {},
    );

    _messageController.clear();

    try {
      await _dbService.sendChatMessage(newMessage);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final user = _authService.currentUser;
      if (user == null) return;

      final newMessage = ChatMessage(
        id: '',
        userId: user.uid,
        displayName: user.displayName,
        content: '📷 Foto compartida',
        timestamp: DateTime.now(),
        type: 'image',
        metadata: {'imagePath': image.path},
      );

      await _dbService.sendChatMessage(newMessage);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showReactionsMenu(ChatMessage msg) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final isMe = msg.userId == currentUser.uid;
    final canDelete = isMe || _isAdmin;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Opciones de Mensaje', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Reaccionar:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '💩', '😂', '🔥', '👏', '👑'].map((emoji) {
                  final hasReacted = msg.reactions[emoji]?.contains(currentUser.uid) ?? false;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _dbService.reactToMessage(msg.id, emoji, currentUser.uid);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasReacted ? Colors.brown[900] : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasReacted ? Colors.amber[700]! : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              if (canDelete) ...[
                const Divider(color: Colors.white12, height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await _dbService.deleteChatMessage(msg.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mensaje eliminado correctamente.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al eliminar mensaje: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Eliminar Mensaje', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getPoopColorHex(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'marrón':
      case 'cafe':
        return const Color(0xFF5D4037);
      case 'amarillo':
        return const Color(0xFFFFB300);
      case 'verde':
        return const Color(0xFF2E7D32);
      case 'negro':
        return const Color(0xFF212121);
      case 'rojo':
        return const Color(0xFFC62828);
      case 'arcilla':
      case 'arcilla/blanco':
        return const Color(0xFFE0E0E0);
      default:
        return const Color(0xFF5D4037);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('COS Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stream de mensajes
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _dbService.getChatMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error en chat: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final messages = snapshot.data ?? [];

                // Desplazar al final tras renderizar
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Aún no hay mensajes. ¡Di hola!',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.userId == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showReactionsMenu(msg),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.brown[600] : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Nombre de usuario en mensajes de otros
                              if (!isMe)
                                Text(
                                  msg.displayName,
                                  style: TextStyle(
                                    color: Colors.brown[300],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              if (!isMe) const SizedBox(height: 4),

                              // Renderizado según tipo de mensaje
                              if (msg.type == 'share_poop' && msg.metadata != null) ...[
                                _buildSharedPoopCard(msg.metadata!),
                              ] else if (msg.type == 'image' && msg.metadata != null && msg.metadata!['imagePath'] != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(msg.metadata!['imagePath']!),
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 180,
                                        height: 180,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                      );
                                    },
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  msg.content,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                              const SizedBox(height: 6),

                              // Reacciones
                              if (msg.reactions.isNotEmpty) ...[
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: msg.reactions.entries.map((entry) {
                                    final emoji = entry.key;
                                    final list = entry.value;
                                    final userReacted = list.contains(currentUser.uid);

                                    return GestureDetector(
                                      onTap: () async {
                                        await _dbService.reactToMessage(msg.id, emoji, currentUser.uid);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: userReacted ? Colors.brown[800] : const Color(0xFF000000),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: userReacted ? Colors.amber[700]! : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(emoji, style: const TextStyle(fontSize: 11)),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${list.length}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 4),
                              ],

                              // Hora de envío
                              Text(
                                DateFormat('HH:mm').format(msg.timestamp),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Indicador de Escritura
          StreamBuilder<Map<String, String>>(
            stream: _dbService.getTypingUsers(),
            builder: (context, snapshot) {
              final typingMap = snapshot.data ?? {};
              typingMap.remove(currentUser.uid); // Excluir al propio usuario
              if (typingMap.isEmpty) return const SizedBox.shrink();

              final names = typingMap.values.join(', ');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$names está escribiendo...',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              );
            },
          ),

          // Caja de texto inferior
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E1E1E),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_photo_alternate_rounded, color: Colors.brown[400]),
                    onPressed: _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.brown[400]),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPoopCard(Map<String, dynamic> data) {
    final weight = data['weight'] ?? 0.0;
    final consistency = data['consistency'] ?? 'Normal';
    final location = data['location'] ?? 'Casa';
    final difficulty = data['difficulty'] ?? 3;
    final colorStr = data['color'] ?? 'Marrón';
    final poopColorHex = _getPoopColorHex(colorStr);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💩', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Caca: $consistency',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.grey, height: 12, thickness: 0.5),
          Text(
            '⚖️ Peso: $weight g',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '📍 Lugar: $location',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '⚡ Esfuerzo: $difficulty/5',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('🎨 Color: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: poopColorHex,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                colorStr,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
