import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'user';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _authorizeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      await _dbService.authorizeEmail(email, _selectedRole);
      
      if (mounted) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$email autorizado con éxito como $_selectedRole! 💌'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _revokeEmail(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Revocar Autorización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas revocar el acceso a $email? El usuario no podrá acceder o registrarse.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbService.revokeEmail(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Autorización de $email revocada.'),
              backgroundColor: Colors.orange[800],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        title: const Text(
          'Administración 👑',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddAuthorizedUserForm(
                formKey: _formKey,
                emailController: _emailController,
                selectedRole: _selectedRole,
                isLoading: _isLoading,
                onRoleSelected: (role) => setState(() => _selectedRole = role),
                onSubmit: _authorizeEmail,
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: Text(
                  'LISTA BLANCA DE ACCESO 🔒',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              _AuthorizedEmailsList(
                emailsStream: _dbService.getAuthorizedEmails(),
                onRevoke: _revokeEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAuthorizedUserForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final String selectedRole;
  final bool isLoading;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onSubmit;

  const _AddAuthorizedUserForm({
    required this.formKey,
    required this.emailController,
    required this.selectedRole,
    required this.isLoading,
    required this.onRoleSelected,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AUTORIZAR NUEVO AMIGO 💌',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingresa el correo';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Rol asignado:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Usuario'),
                  selected: selectedRole == 'user',
                  selectedColor: Colors.blue[800],
                  disabledColor: Colors.grey[900],
                  labelStyle: TextStyle(
                    color: selectedRole == 'user' ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFF0D0D0D),
                  onSelected: (selected) {
                    if (selected) onRoleSelected('user');
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Admin'),
                  selected: selectedRole == 'admin',
                  selectedColor: Colors.pink[800],
                  disabledColor: Colors.grey[900],
                  labelStyle: TextStyle(
                    color: selectedRole == 'admin' ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFF0D0D0D),
                  onSelected: (selected) {
                    if (selected) onRoleSelected('admin');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline_rounded),
                label: const Text(
                  'Añadir a la Lista Blanca',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorizedEmailsList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> emailsStream;
  final ValueChanged<String> onRevoke;

  const _AuthorizedEmailsList({
    required this.emailsStream,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: emailsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar lista blanca: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          final emails = snapshot.data!;
          if (emails.isEmpty) {
            return Center(
              child: Text(
                'No hay correos autorizados en la lista blanca.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            );
          }

          return ListView.builder(
            itemCount: emails.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final item = emails[index];
              final email = item['email'] as String;
              final role = item['role'] as String;
              final isRegistered = item['registered'] as bool;

              final bool isAdmin = role == 'admin';

              return Card(
                color: const Color(0xFF161616),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white10, width: 0.5),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isAdmin 
                        ? Colors.pinkAccent.withAlpha(20) 
                        : Colors.blueAccent.withAlpha(20),
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                      color: isAdmin ? Colors.pinkAccent : Colors.blueAccent,
                    ),
                  ),
                  title: Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(top: 4, right: 8),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.pink[900]!.withAlpha(80) : Colors.blue[900]!.withAlpha(80),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: isAdmin ? Colors.pinkAccent : Colors.blueAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isRegistered ? Colors.green[900]!.withAlpha(80) : Colors.amber[900]!.withAlpha(80),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isRegistered ? 'REGISTRADO' : 'PENDIENTE',
                          style: TextStyle(
                            color: isRegistered ? Colors.greenAccent : Colors.amberAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => onRevoke(email),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
