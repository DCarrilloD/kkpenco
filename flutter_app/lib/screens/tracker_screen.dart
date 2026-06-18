import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'trono_zen_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Consistency _selectedConsistency = Consistency.normal;
  LocationTag _selectedLocation = LocationTag.casa;
  double _durationMinutes = 5.0; // Valor por defecto
  bool _isLoading = false;

  // Geolocation state
  double? _latitude;
  double? _longitude;
  bool _isGettingGPS = false;
  bool _autoGeolocate = false;
  bool _isHistoryExpanded = false;

  // History Pagination variables
  final List<KKEvent> _eventsList = [];
  Object? _lastCursor;
  bool _hasMore = true;
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadFirstPage();
    _loadAutoGeolocatePreference();
  }

  Future<void> _loadAutoGeolocatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoGeolocate = prefs.getBool('auto_geolocate') ?? false;
      });
      if (_autoGeolocate) {
        // Ejecutar obtención de GPS tras el primer frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _getCurrentLocation();
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar preferencia auto_geolocate: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_loadingHistory) {
        _loadNextPage();
      }
    }
  }

  Future<void> _loadFirstPage() async {
    final user = _authService.currentUser;
    if (user == null) return;
    setState(() {
      _loadingHistory = true;
    });
    try {
      final res = await _dbService.getEventsPaged(user.uid, limit: 15);
      setState(() {
        _eventsList.clear();
        _eventsList.addAll(res.events);
        _lastCursor = res.cursor;
        _hasMore = res.hasMore;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    final user = _authService.currentUser;
    if (user == null) return;
    setState(() {
      _loadingHistory = true;
    });
    try {
      final res = await _dbService.getEventsPaged(user.uid, limit: 15, cursor: _lastCursor);
      setState(() {
        _eventsList.addAll(res.events);
        _lastCursor = res.cursor;
        _hasMore = res.hasMore;
      });
    } catch (e) {
      debugPrint('Error loading next events page: $e');
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<Map<String, double>?> _getLocationByIP() async {
    try {
      final response = await http
          .get(Uri.parse('https://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final double lat = (data['lat'] as num).toDouble();
          final double lon = (data['lon'] as num).toDouble();
          return {'latitude': lat, 'longitude': lon};
        }
      }
    } catch (e) {
      debugPrint('Error en fallback de IP: $e');
    }
    return null;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingGPS = true;
    });

    try {
      HapticFeedback.lightImpact();

      if (useMockData) {
        // Simular obtención de coordenadas (ej: Madrid Río)
        await Future.delayed(const Duration(milliseconds: 1000));
        setState(() {
          _latitude = 40.4115 + (DateTime.now().millisecond % 100) * 0.0001;
          _longitude = -3.7122 - (DateTime.now().second % 60) * 0.0001;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Ubicación simulada con éxito (Madrid Río)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      try {
        // Verificar si el servicio está activo
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Los servicios de ubicación GPS están desactivados.');
        }

        // Verificar y solicitar permisos
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Permisos de ubicación denegados.');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception('Permisos de ubicación denegados permanentemente en ajustes.');
        }

        // Obtener posición actual con timeout de 6 segundos
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );

        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Ubicación fijada por GPS con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (gpsError) {
        debugPrint('Fallo de GPS nativo: $gpsError. Activando fallback por IP...');
        
        // Intentar fallback por IP
        final ipLocation = await _getLocationByIP();
        if (ipLocation != null) {
          setState(() {
            _latitude = ipLocation['latitude'];
            _longitude = ipLocation['longitude'];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🌐 GPS falló. Ubicación estimada por IP fijada con éxito.'),
                backgroundColor: Colors.brown,
              ),
            );
          }
        } else {
          throw Exception('${gpsError.toString().replaceFirst('Exception: ', '')} (Y el fallback de IP también falló).');
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de geolocalización: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingGPS = false;
        });
      }
    }
  }

  Future<void> _launchMap(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la URL del mapa.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir mapa: $e')),
        );
      }
    }
  }

  Future<void> _saveEvent() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final durationSecs = (_durationMinutes * 60).toInt();

      final newEvent = KKEvent(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}', // ID temporal para simulación/local
        userId: user.uid,
        username: user.displayName ?? 'Usuario',
        timestamp: DateTime.now(),
        duration: durationSecs,
        consistency: _selectedConsistency,
        color: PoopColor.cafe,
        location: _selectedLocation,
        difficulty: 3,
        estimatedWeight: KKEvent.calculateWeight(
          consistency: _selectedConsistency,
          durationSeconds: durationSecs,
          difficulty: 3,
        ),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );

      await _dbService.addEvent(newEvent);
      
      // Haptic feedback impact when saving poop
      HapticFeedback.mediumImpact();

      _notesController.clear();
      setState(() {
        _selectedConsistency = Consistency.normal;
        _selectedLocation = LocationTag.casa;
        _durationMinutes = 5.0;
        _latitude = null;
        _longitude = null;
        // Prepend new element to local paginated list
        _eventsList.insert(0, newEvent);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💩 Registro guardado con éxito'),
            backgroundColor: Colors.brown,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
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
  Future<void> _sharePoopToChat(KKEvent event) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final metadata = {
      'weight': event.estimatedWeight,
      'consistency': event.consistency.displayName,
      'location': event.location.displayName,
      'difficulty': event.difficulty,
      'color': event.color.displayName,
      if (event.latitude != null) 'latitude': event.latitude,
      if (event.longitude != null) 'longitude': event.longitude,
    };

    final chatMsg = ChatMessage(
      id: '',
      userId: user.uid,
      username: user.displayName ?? 'Usuario',
      content: '¡Ha compartido un registro de caca! 💩',
      timestamp: DateTime.now(),
      type: 'share_poop',
      metadata: metadata,
    );

    try {
      await _dbService.sendChatMessage(chatMsg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💩 Registro compartido en el chat COS'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir en chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePoopEvent(KKEvent event) async {
    final user = _authService.currentUser;
    if (user == null || event.userId != user.uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes permisos para eliminar este registro.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final diff = DateTime.now().difference(event.timestamp).inMinutes;
    if (diff >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo puedes eliminar registros durante los primeros 5 minutos.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('¿Eliminar registro?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Esta acción borrará este registro de caca permanentemente y no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _dbService.deleteEvent(event);
      
      setState(() {
        _eventsList.removeWhere((e) => e.id == event.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Registro eliminado con éxito'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString().replaceFirst('Exception: ', '')}'),
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

  Widget _buildConsistencyCard(Consistency consistency, IconData icon, Color activeColor) {
    final isSelected = _selectedConsistency == consistency;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedConsistency = consistency;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withAlpha(51) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey[400],
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                consistency.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  IconData _getLocationIcon(LocationTag location) {
    switch (location) {
      case LocationTag.casa:
        return Icons.home_rounded;
      case LocationTag.trabajo:
        return Icons.business_center_rounded;
      case LocationTag.publico:
        return Icons.wc_rounded;
      case LocationTag.naturaleza:
        return Icons.forest_rounded;
      case LocationTag.visita:
        return Icons.people_alt_rounded;
    }
  }



  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [


                  // Consistencia
                  const Text(
                    'Consistencia',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildConsistencyCard(Consistency.normal, Icons.check_circle_outline_rounded, Colors.green),
                      const SizedBox(width: 10),
                      _buildConsistencyCard(Consistency.jurasica, Icons.terrain_rounded, Colors.orange),
                      const SizedBox(width: 10),
                      _buildConsistencyCard(Consistency.espurruteo, Icons.water_drop_rounded, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Selector de Ubicación
                  const Text(
                    'Lugar',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: LocationTag.values.where((l) => l != LocationTag.publico).map((locVal) {
                      final isSelected = _selectedLocation == locVal;
                      final locIcon = _getLocationIcon(locVal);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedLocation = locVal;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.brown[900]?.withAlpha(102) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.brown[400]! : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  locIcon,
                                  size: 20,
                                  color: isSelected ? Colors.brown[300] : Colors.grey[400],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  locVal.displayName.split(' ')[0], // Ejemplo: "Baño" de "Baño Público"
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Control de Duración
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Duración',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_durationMinutes.toInt()} min',
                        style: TextStyle(
                          color: Colors.brown[400],
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _durationMinutes,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    activeColor: Colors.brown[400],
                    inactiveColor: Colors.grey[800],
                    onChanged: (val) {
                      if (val.toInt() != _durationMinutes.toInt()) {
                        HapticFeedback.lightImpact();
                      }
                      setState(() {
                        _durationMinutes = val;
                      });
                    },
                  ),
                  const SizedBox(height: 28),

                  // Geolocalización GPS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Geolocalización',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (_latitude != null && _longitude != null)
                        Text(
                          '📍 Fijo: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        )
                      else if (_isGettingGPS)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.brown),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Buscando satélites...',
                              style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Sin fijar',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                  if (!_autoGeolocate) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isGettingGPS ? null : _getCurrentLocation,
                      icon: _isGettingGPS
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.brown),
                            )
                          : Icon(
                              _latitude != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                              color: _latitude != null ? Colors.greenAccent : Colors.brown[300],
                            ),
                      label: Text(
                        _isGettingGPS
                            ? 'Buscando satélites...'
                            : (_latitude != null ? 'Ubicación Fijada (Pulsar para refrescar)' : 'Geolocaliza la KK'),
                        style: TextStyle(
                          color: _latitude != null ? Colors.greenAccent : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _latitude != null ? Colors.greenAccent : (Colors.brown[500]!),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Notas
                  TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Notas o reflexiones (opcional)...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botones Registrar KK & Modo Trono Zen
                  Row(
                    children: [
                      // Botón Registrar KK (Premium)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[600],
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: Colors.brown.withAlpha(80),
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Registrar KK 💩',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón Modo Trono Zen (Premium con presencia)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final double? duration = await Navigator.push<double>(
                              context,
                              MaterialPageRoute(builder: (context) => const TronoZenScreen()),
                            );
                            if (duration != null) {
                              setState(() {
                                _durationMinutes = duration.clamp(1.0, 60.0);
                              });
                            }
                          },
                          icon: const Icon(Icons.self_improvement_rounded, color: Colors.amberAccent, size: 30),
                          label: const Text(
                            'Modo Trono Zen',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF231712), // Marrón café muy oscuro
                            foregroundColor: Colors.amberAccent,
                            elevation: 4,
                            shadowColor: Colors.amber.withAlpha(40),
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            side: BorderSide(color: Colors.amber[700]!.withAlpha(120), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Encabezado del Historial Desplegable
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isHistoryExpanded = !_isHistoryExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isHistoryExpanded ? Colors.brown[900]! : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, color: Colors.brown, size: 22),
                              const SizedBox(width: 10),
                              const Text(
                                'Tu Historial Reciente',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (_eventsList.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.brown[900],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_eventsList.length}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          AnimatedRotation(
                            turns: _isHistoryExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isHistoryExpanded) ...[
                    const SizedBox(height: 18),
                    // Historial paginado con scroll
                    if (_eventsList.isEmpty && !_loadingHistory)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Aún no has registrado ninguna sesión.',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _eventsList.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _eventsList.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(color: Colors.brown)),
                          );
                        }

                        final event = _eventsList[index];
                        Color indicatorColor;
                        IconData indicatorIcon;

                        switch (event.consistency) {
                          case Consistency.normal:
                            indicatorColor = Colors.green;
                            indicatorIcon = Icons.check_circle_outline_rounded;
                            break;
                          case Consistency.jurasica:
                            indicatorColor = Colors.orange;
                            indicatorIcon = Icons.terrain_rounded;
                            break;
                          case Consistency.espurruteo:
                            indicatorColor = Colors.blue;
                            indicatorIcon = Icons.water_drop_rounded;
                            break;
                        }

                        final locIcon = _getLocationIcon(event.location);

                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Fila superior (Consistencia + Fecha + Compartir + GPS)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(indicatorIcon, color: indicatorColor, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          event.consistency.displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('dd MMM yyyy, HH:mm').format(event.timestamp),
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        if (event.latitude != null && event.longitude != null) ...[
                                          IconButton(
                                            icon: const Icon(Icons.map_rounded, size: 16, color: Colors.greenAccent),
                                            tooltip: 'Ver en Mapa',
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _launchMap(event.latitude!, event.longitude!),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        IconButton(
                                          icon: const Icon(Icons.share_rounded, size: 16, color: Colors.grey),
                                          tooltip: 'Compartir en Chat',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _sharePoopToChat(event),
                                        ),
                                        if (event.userId == user.uid &&
                                            DateTime.now().difference(event.timestamp).inMinutes < 5) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                            tooltip: 'Eliminar Registro',
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _deletePoopEvent(event),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Grid de detalles (Color, Lugar, Esfuerzo, Peso)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    // Peso
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.scale_rounded, color: Colors.grey, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${event.estimatedWeight} g (est)',
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    // Lugar
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(locIcon, color: Colors.grey, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.location.displayName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                if (event.duration != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Duración en el trono: ${(event.duration! / 60).round()} min',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ],
                                if (event.notes != null && event.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Observaciones: ${event.notes}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
