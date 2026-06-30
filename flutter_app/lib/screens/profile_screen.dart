import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/event.dart';
import 'stats_panel_screen.dart';
import 'biometric_simulation_dialog.dart';
import 'achievements_screen.dart';
import 'admin_panel_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _dbService = DatabaseService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _emailPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();


  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  bool _biometricsEnabled = false;
  bool _autoGeolocate = false;
  int _userStreak = 0;
  String? _equippedTitle;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadAutoGeolocatePreference();
  }

  Future<void> _loadAutoGeolocatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoGeolocate = prefs.getBool('auto_geolocate') ?? false;
      });
    } catch (e) {
      debugPrint('Error al cargar auto_geolocate en perfil: $e');
    }
  }

  Future<void> _toggleAutoGeolocate(bool value) async {
    HapticFeedback.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_geolocate', value);
      setState(() {
        _autoGeolocate = value;
      });
    } catch (e) {
      debugPrint('Error al guardar auto_geolocate en perfil: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final enabled = await _authService.isBiometricEnabled();
    final user = _authService.currentUser;
    int streak = 0;
    String? title;
    bool adminRole = false;
    if (user != null) {
      try {
        final streaks = await _dbService.getUserStreaks(user.uid);
        streak = streaks['currentStreak'] ?? 0;
        
        final userData = await _dbService.getUserData(user.uid);
        title = userData['equippedTitle'] as String?;

        final profile = await _authService.getUserProfile(user.uid);
        adminRole = profile != null && profile['role'] == 'admin';
      } catch (e) {
        debugPrint('Error al cargar racha de perfil: $e');
      }
    }
    if (mounted) {
      setState(() {
        _biometricsEnabled = enabled;
        _userStreak = streak;
        _equippedTitle = title;
        _isAdmin = adminRole;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        bool authenticated = false;

        if (useMockData || (!canCheck && !isSupported)) {
          // Fallback en Windows/Simulador
          if (mounted) {
            authenticated = await showDialog<bool>(
              context: context,
              builder: (context) => const BiometricSimulationDialog(
                reason: 'Activar acceso rápido por huella o rostro',
              ),
            ) ?? false;
          }
        } else {
          authenticated = await _localAuth.authenticate(
            localizedReason: 'Confirma tu identidad para activar la biometría',
            biometricOnly: false,
          );
        }

        if (authenticated) {
          await _authService.setBiometricEnabled(true);
          setState(() {
            _biometricsEnabled = true;
          });
        }
      } catch (e) {
        debugPrint('Error general al activar biometría: $e');
        if (mounted) {
          String errMsg = 'Ocurrió un error al activar la biometría: $e';
          final errStr = e.toString();
          
          if (errStr.contains('noCredentialSet') || errStr.contains('NotEnrolled')) {
            errMsg = 'No tienes ninguna huella, rostro o PIN/patrón configurado en tu dispositivo. Por favor, configúralo en los ajustes del sistema operativo para poder usar esta función.';
          } else if (errStr.contains('NotAvailable') || errStr.contains('passcodeNotSet')) {
            errMsg = 'La biometría no está disponible en este dispositivo o requiere que configures un bloqueo de pantalla primero.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      await _authService.setBiometricEnabled(false);
      setState(() {
        _biometricsEnabled = false;
      });
    }
  }


  Future<void> _editProfile(BuildContext context, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    File? selectedImage;
    bool isEditing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Editar Perfil', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (pickedFile != null) {
                          setModalState(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      } catch (e) {
                         debugPrint('Error picking image: $e');
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.brown[700],
                      backgroundImage: selectedImage != null 
                          ? FileImage(selectedImage!) 
                          : (_authService.currentUser?.photoURL != null ? CachedNetworkImageProvider(_authService.currentUser!.photoURL!) : null) as ImageProvider?,
                      child: selectedImage == null && _authService.currentUser?.photoURL == null
                          ? const Icon(Icons.camera_alt, color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Toca para cambiar foto', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      labelStyle: TextStyle(color: Colors.brown[300]),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown[700]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: isEditing ? null : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;
                        setModalState(() => isEditing = true);
                        try {
                          await _authService.updateProfile(
                            displayName: newName != currentName ? newName : null,
                            avatarImage: selectedImage,
                          );
                          if (mounted) {
                            setState(() {
                               _loadProfileData();
                            }); // Refrescar pantalla principal
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          setModalState(() => isEditing = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: isEditing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _changeEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      await _authService.changeEmail(
        currentPassword: _emailPasswordController.text,
        newEmail: _newEmailController.text.trim(),
      );
      setState(() {
        _successMessage = 'Se ha enviado un correo de confirmación (o cambiado directo).';
        _emailPasswordController.clear();
        _newEmailController.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();

      setState(() {
        _successMessage = 'Contraseña actualizada correctamente.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportToCSV() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _dbService.getAllEvents();
      
      // Estructura del CSV
      List<List<dynamic>> rows = [];
      rows.add(["ID", "Usuario", "Fecha/Hora", "Consistencia", "Duración (segundos)", "Notas"]);

      for (var event in events) {
        rows.add([
          event.id,
          event.displayName ?? event.userId,
          event.timestamp.toIso8601String(),
          event.consistency.displayName,
          event.duration ?? "",
          event.notes ?? ""
        ]);
      }

      // Convertir a cadena CSV
      String csvData = const ListToCsvConverter().convert(rows);

      // Guardar localmente de forma temporal
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/kk_logs.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // Compartir archivo
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Exportación de Logs de KKpenco 💩',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportToJSON() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _dbService.getAllEvents();
      
      // Convertir eventos a mapas compatibles con JSON
      List<Map<String, dynamic>> list = events.map((e) => {
        'id': e.id,
        'userId': e.userId,
        'username': e.displayName,
        'timestamp': e.timestamp.toIso8601String(),
        'duration': e.duration,
        'consistency': e.consistency.name,
        'color': e.color.name,
        'location': e.location.name,
        'difficulty': e.difficulty,
        'estimatedWeight': e.estimatedWeight,
        'notes': e.notes,
        'latitude': e.latitude,
        'longitude': e.longitude,
      }).toList();

      String jsonString = jsonEncode(list);

      // Guardar localmente de forma temporal
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/kk_backup.json";
      final file = File(path);
      await file.writeAsString(jsonString);

      // Compartir archivo
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Copia de Seguridad de KKpenco 💩',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar JSON: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importFromJSON() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);

      final user = _authService.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      // 2. Parsear y validar
      List<KKEvent> importedEvents = [];
      for (var m in decoded) {
        if (m is! Map<String, dynamic>) continue;
        
        // Mapear campos de forma segura
        importedEvents.add(KKEvent(
          id: m['id'] ?? '',
          userId: user.uid, // Sobreescritura segura de userId
          displayName: user.displayName, // Sobreescritura segura de username
          timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
          duration: m['duration'],
          consistency: Consistency.values.firstWhere(
            (c) => c.name == m['consistency'] || c.displayName == m['consistency'],
            orElse: () => Consistency.normal,
          ),
          color: PoopColor.values.firstWhere(
            (c) => c.name == m['color'] || c.displayName == m['color'],
            orElse: () => PoopColor.cafe,
          ),
          location: LocationTag.values.firstWhere(
            (c) => c.name == m['location'] || c.displayName == m['location'],
            orElse: () => LocationTag.casa,
          ),
          difficulty: m['difficulty'] ?? 3,
          estimatedWeight: (m['estimatedWeight'] ?? 150.0).toDouble(),
          notes: m['notes'],
          latitude: m['latitude'] != null ? (m['latitude'] as num).toDouble() : null,
          longitude: m['longitude'] != null ? (m['longitude'] as num).toDouble() : null,
        ));
      }

      // 3. Confirmación del usuario
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmar Restauración', style: TextStyle(color: Colors.white)),
          content: Text(
            'Se importarán ${importedEvents.length} registros. ADVERTENCIA: Esto reemplazará tu historial actual de cacas. ¿Deseas continuar?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              child: const Text('Restaurar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _dbService.importBackupEvents(user.uid, user.displayName, importedEvents);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Historial restaurado con éxito! 💩🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar copia de seguridad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteAccountDialog(
        authService: _authService,
        dbService: _dbService,
      ),
    );

    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta eliminada con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _promptStatsPassword() async {
    if (_biometricsEnabled) {
      try {
        bool authenticated = false;
        if (useMockData) {
          authenticated = await showDialog<bool>(
            context: context,
            builder: (context) => const BiometricSimulationDialog(
              reason: 'Acceder al Panel de Estadísticas Avanzadas',
            ),
          ) ?? false;
        } else {
          authenticated = await _localAuth.authenticate(
            localizedReason: 'Acceder al Panel de Estadísticas Avanzadas',
            biometricOnly: false,
          );
        }

        if (authenticated) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatsPanelScreen()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error en verificación biométrica: $e');
        if (mounted) {
          String errMsg = 'Error biométrico: $e';
          final errStr = e.toString();
          
          if (errStr.contains('noCredentialSet') || errStr.contains('NotEnrolled')) {
            errMsg = 'No tienes configurada ninguna opción de seguridad (huella, rostro o PIN). Por favor, ve a los ajustes de tu teléfono para configurarlo.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }

    if (!mounted) return;

    final passwordCorrect = await showDialog<bool>(
      context: context,
      builder: (context) => const _StatsPasswordDialog(),
    );

    if (passwordCorrect == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatsPanelScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isAdmin = _isAdmin || user.email == 'd.carrillo.d@gmail.com' || user.displayName.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UserProfileCard(
              user: user,
              equippedTitle: _equippedTitle,
              userStreak: _userStreak,
              onEditProfile: () => _editProfile(context, user.displayName),
            ),
            const SizedBox(height: 20),
            _SettingsTile(
              icon: Icons.fingerprint_rounded,
              title: 'Seguridad Biométrica',
              subtitle: 'Activar FaceID / Huella Dactilar',
              value: _biometricsEnabled,
              onChanged: _toggleBiometrics,
            ),
            const SizedBox(height: 20),
            _SettingsTile(
              icon: Icons.autorenew_rounded,
              title: 'Autolocalizar al Iniciar',
              subtitle: 'Obtener GPS automáticamente al abrir la app',
              value: _autoGeolocate,
              onChanged: _toggleAutoGeolocate,
            ),
            const SizedBox(height: 20),
            _ProfileButtons(
              isAdmin: isAdmin,
              isLoading: _isLoading,
              onViewAchievements: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                ).then((_) => _loadProfileData());
              },
              onViewAdminPanel: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                ).then((_) => _loadProfileData());
              },
              onViewStats: _promptStatsPassword,
              onExportCSV: _exportToCSV,
            ),
            const SizedBox(height: 20),
            _BackupRestoreSection(
              isLoading: _isLoading,
              onExport: _exportToJSON,
              onImport: _importFromJSON,
            ),
            const SizedBox(height: 20),
            _ChangePasswordForm(
              formKey: _formKey,
              currentPasswordController: _currentPasswordController,
              newPasswordController: _newPasswordController,
              isLoading: _isLoading,
              successMessage: _successMessage,
              errorMessage: _errorMessage,
              onChangePassword: _changePassword,
            ),
            const SizedBox(height: 20),
            _ChangeEmailForm(
              formKey: _emailFormKey,
              emailController: _newEmailController,
              passwordController: _emailPasswordController,
              isLoading: _isLoading,
              onChangeEmail: _changeEmail,
            ),
            const SizedBox(height: 24),
            _DangerZone(
              isLoading: _isLoading,
              onSignOut: () async {
                await _authService.signOut();
              },
              onDeleteAccount: _confirmDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final dynamic user;
  final String? equippedTitle;
  final int userStreak;
  final VoidCallback onEditProfile;

  const _UserProfileCard({
    required this.user,
    this.equippedTitle,
    required this.userStreak,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.brown[700],
                  shape: BoxShape.circle,
                ),
                child: (user.photoURL != null && user.photoURL!.trim().isNotEmpty)
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.photoURL!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(color: Colors.brown),
                          errorWidget: (context, url, error) {
                            return Center(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onEditProfile,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.amberAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayName ?? 'Sin Nombre',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditProfile,
                child: const Icon(Icons.edit_rounded, color: Colors.grey, size: 18),
              ),
            ],
          ),
          if (equippedTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              '👑 $equippedTitle',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            user.email ?? '',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          if (userStreak > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[900]?.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber[700]!, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '¡Racha de $userStreak días! 🔥',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.brown, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.brown[400],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileButtons extends StatelessWidget {
  final bool isAdmin;
  final bool isLoading;
  final VoidCallback onViewAchievements;
  final VoidCallback onViewAdminPanel;
  final VoidCallback onViewStats;
  final VoidCallback onExportCSV;

  const _ProfileButtons({
    required this.isAdmin,
    required this.isLoading,
    required this.onViewAchievements,
    required this.onViewAdminPanel,
    required this.onViewStats,
    required this.onExportCSV,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: onViewAchievements,
          icon: const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent),
          label: const Text('Ver Álbum de Logros', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        if (isAdmin) ...[
          ElevatedButton.icon(
            onPressed: onViewAdminPanel,
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.pinkAccent),
            label: const Text('Panel de Administración 👑', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1525),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.pinkAccent, width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        ElevatedButton.icon(
          onPressed: isLoading ? null : onViewStats,
          icon: const Icon(Icons.bar_chart_rounded, color: Colors.amberAccent),
          label: const Text('Ver Panel de Estadísticas', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3F2B96),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onExportCSV,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Descargar Todos los Logs (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}

class _BackupRestoreSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _BackupRestoreSection({
    required this.isLoading,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Copia de Seguridad y Restauración',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Descarga o restaura tu historial en formato JSON',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onExport,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Exportar JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onImport,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Restaurar JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final VoidCallback onChangePassword;

  const _ChangePasswordForm({
    required this.formKey,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cambiar Contraseña',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (successMessage != null) ...[
              Text(successMessage!, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
            ],
            if (errorMessage != null) ...[
              Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Contraseña Actual',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Ingresa tu contraseña actual' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) => val == null || val.length < 6
                  ? 'La nueva contraseña debe tener al menos 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[500],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Actualizar Contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeEmailForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onChangeEmail;

  const _ChangeEmailForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onChangeEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cambiar Email',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Contraseña Actual',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Ingresa tu contraseña actual' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nuevo Correo Electrónico',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) => val == null || !val.contains('@') ? 'Ingresa un email válido' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onChangeEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[500],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Actualizar Email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const _DangerZone({
    required this.isLoading,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: isLoading ? null : onDeleteAccount,
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
          label: const Text(
            'Autodestrucción de Cuenta e Historial (GDPR)',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final dynamic authService;
  final dynamic dbService;

  const _DeleteAccountDialog({
    required this.authService,
    required this.dbService,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  String? _localError;
  bool _dialogLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _localError = 'La contraseña no puede estar vacía');
      return;
    }

    setState(() {
      _dialogLoading = true;
      _localError = null;
    });

    try {
      final user = widget.authService.currentUser;
      if (user == null) throw Exception("Usuario no identificado");

      await widget.authService.reauthenticate(password);
      await widget.dbService.deleteAllUserData(user.uid);
      await widget.authService.deleteAccount(password);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _dialogLoading = false;
        _localError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Autodestrucción de Cuenta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esta acción es IRREVERSIBLE. Se eliminará tu cuenta y todo tu historial de cacas para siempre.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'Por favor, introduce tu contraseña actual para confirmar:',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF000000),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_localError != null) ...[
            const SizedBox(height: 8),
            Text(
              _localError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          if (_dialogLoading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _dialogLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _dialogLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
          child: const Text('ELIMINAR TODO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _StatsPasswordDialog extends StatefulWidget {
  const _StatsPasswordDialog();

  @override
  State<_StatsPasswordDialog> createState() => _StatsPasswordDialogState();
}

class _StatsPasswordDialogState extends State<_StatsPasswordDialog> {
  final _passwordController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.amberAccent),
          SizedBox(width: 8),
          Text('Acceso Protegido', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Introduce la contraseña para acceder al panel de estadísticas avanzadas.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF000000),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_localError != null) ...[
            const SizedBox(height: 8),
            Text(
              _localError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_passwordController.text == 'kkpenco2026') {
              Navigator.pop(context, true);
            } else {
              setState(() {
                _localError = 'Contraseña incorrecta';
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[600]),
          child: const Text('Acceder', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
