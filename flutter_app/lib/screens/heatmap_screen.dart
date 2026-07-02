import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/event.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  List<KKEvent> _geolocatedEvents = [];
  List<TerritoryZone> _territories = [];
  List<CountryConquest> _countries = [];
  bool _isLoading = true;
  bool _resolvingCountries = false;
  LatLng _mapCenter = const LatLng(40.4168, -3.7038); // Madrid por defecto
  
  // Detalle de selección
  TerritoryZone? _selectedTerritory;
  CountryConquest? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _dbService.getAllEvents();
      // Filtrar solo los que tienen coordenadas válidas
      final geoEvents = events.where((e) => e.latitude != null && e.longitude != null).toList();

      if (geoEvents.isNotEmpty) {
        // Centrar mapa en la deposición más reciente
        _mapCenter = LatLng(geoEvents.first.latitude!, geoEvents.first.longitude!);
      }

      // Agrupar eventos en zonas geográficas (Territorios de ~100m de radio)
      final territories = _calculateTerritories(geoEvents);

      setState(() {
        _geolocatedEvents = geoEvents;
        _territories = territories;
        _isLoading = false;
      });

      // Resolver los países asíncronamente en segundo plano
      _resolveCountries(geoEvents);

    } catch (e) {
      debugPrint('Error al cargar datos del mapa: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Geocodificación inversa inteligente con caché local en SharedPreferences
  Future<Map<String, String>?> _reverseGeocode(double lat, double lon) async {
    // Redondear a 2 decimales para la caché de zona (~1.1 km)
    final cacheKey = 'country_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final parts = cached.split('|');
        if (parts.length == 2) {
          return {'name': parts[0], 'code': parts[1]};
        }
      }
      
      // Consultar Nominatim (OpenStreetMap) con zoom=3 (nivel de país)
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=3&accept-language=es'
      );
      final response = await http.get(uri, headers: {'User-Agent': 'kkpenco_app_v1'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          final countryName = address['country'] as String?;
          final countryCode = (address['country_code'] as String?)?.toUpperCase();
          if (countryName != null && countryCode != null) {
            // Guardar en caché
            await prefs.setString(cacheKey, '$countryName|$countryCode');
            return {'name': countryName, 'code': countryCode};
          }
        }
      }
    } catch (e) {
      debugPrint('Error en reverse geocoding: $e');
    }
    return null;
  }

  // Resolver y agrupar cacas por países de forma asíncrona
  Future<void> _resolveCountries(List<KKEvent> geoEvents) async {
    if (geoEvents.isEmpty) return;
    setState(() {
      _resolvingCountries = true;
    });

    final Map<String, List<KKEvent>> countryGroups = {};
    final Map<String, String> countryNames = {};

    // Agrupar previamente por lat/lon aproximada (2 decimales ~1.1km)
    // para evitar hacer múltiples llamadas HTTP duplicadas a Nominatim por ubicaciones cercanas
    final Map<String, LatLng> uniqueZones = {};
    for (var event in geoEvents) {
      if (event.latitude != null && event.longitude != null) {
        final zoneKey = '${event.latitude!.toStringAsFixed(2)}_${event.longitude!.toStringAsFixed(2)}';
        uniqueZones[zoneKey] = LatLng(event.latitude!, event.longitude!);
      }
    }

    // Geocodificar solo las zonas geográficas únicas
    final Map<String, Map<String, String>?> geocodedZones = {};
    for (var entry in uniqueZones.entries) {
      final res = await _reverseGeocode(entry.value.latitude, entry.value.longitude);
      geocodedZones[entry.key] = res;
    }

    // Distribuir la respuesta de país a todos los eventos según su zona
    for (var event in geoEvents) {
      if (event.latitude != null && event.longitude != null) {
        final zoneKey = '${event.latitude!.toStringAsFixed(2)}_${event.longitude!.toStringAsFixed(2)}';
        final res = geocodedZones[zoneKey];
        if (res != null) {
          final code = res['code']!;
          final name = res['name']!;
          countryNames[code] = name;
          countryGroups.putIfAbsent(code, () => []).add(event);
        }
      }
    }

    final List<CountryConquest> conquests = [];

    countryGroups.forEach((code, list) {
      // Calcular estadísticas de este país
      final total = list.length;

      // Encontrar líder del país
      final Map<String, int> userCounts = {};
      final Map<String, String> userNames = {};
      for (var e in list) {
        userCounts[e.userId] = (userCounts[e.userId] ?? 0) + 1;
        userNames[e.userId] = e.displayName ?? 'Anónimo';
      }

      String leaderId = '';
      String leaderName = '';
      int maxPoops = 0;
      userCounts.forEach((uid, count) {
        if (count > maxPoops) {
          maxPoops = count;
          leaderId = uid;
          leaderName = userNames[uid] ?? 'Usuario';
        }
      });

      // Calcular centro medio del país a partir de sus deposiciones
      double avgLat = list.map((e) => e.latitude!).reduce((a, b) => a + b) / list.length;
      double avgLon = list.map((e) => e.longitude!).reduce((a, b) => a + b) / list.length;

      conquests.add(CountryConquest(
        countryCode: code,
        countryName: countryNames[code]!,
        totalPoops: total,
        leaderId: leaderId,
        leaderName: leaderName,
        leaderCount: maxPoops,
        avgCenter: LatLng(avgLat, avgLon),
      ));
    });

    // Ordenar países de mayor a menor número de deposiciones
    conquests.sort((a, b) => b.totalPoops.compareTo(a.totalPoops));

    // Desbloquear logros de conquista de países asíncronamente
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId != null) {
      int myCountriesCount = 0;
      bool isLeaderOfAnyCountry = false;

      countryGroups.forEach((code, list) {
        final hasMyPoop = list.any((e) => e.userId == currentUserId);
        if (hasMyPoop) {
          myCountriesCount++;
        }

        // Buscar el líder de este país
        final Map<String, int> userCounts = {};
        for (var e in list) {
          userCounts[e.userId] = (userCounts[e.userId] ?? 0) + 1;
        }
        String leaderId = '';
        int maxPoops = 0;
        userCounts.forEach((uid, count) {
          if (count > maxPoops) {
            maxPoops = count;
            leaderId = uid;
          }
        });
        if (leaderId == currentUserId) {
          isLeaderOfAnyCountry = true;
        }
      });

      if (myCountriesCount >= 2) {
        await _dbService.unlockAchievement(currentUserId, 'conquistador_internacional', null);
      }
      if (myCountriesCount >= 3) {
        await _dbService.unlockAchievement(currentUserId, 'poop_colonizer', null);
      }
      if (isLeaderOfAnyCountry) {
        await _dbService.unlockAchievement(currentUserId, 'world_leader', null);
      }
    }

    if (mounted) {
      setState(() {
        _countries = conquests;
        _resolvingCountries = false;
      });
    }
  }

  List<TerritoryZone> _calculateTerritories(List<KKEvent> events) {
    final Map<String, List<KKEvent>> grid = {};

    // Redondear a 3 decimales agrupa coordenadas en celdas de aprox 110m x 110m
    for (var event in events) {
      final latKey = event.latitude!.toStringAsFixed(3);
      final lonKey = event.longitude!.toStringAsFixed(3);
      final key = '${latKey}_$lonKey';

      if (!grid.containsKey(key)) {
        grid[key] = [];
      }
      grid[key]!.add(event);
    }

    final List<TerritoryZone> result = [];

    grid.forEach((key, list) {
      // Contar deposiciones por usuario en esta cuadrícula
      final Map<String, int> userCounts = {};
      final Map<String, String> userNames = {};

      for (var e in list) {
        userCounts[e.userId] = (userCounts[e.userId] ?? 0) + 1;
        userNames[e.userId] = e.displayName ?? 'Anónimo';
      }

      // Encontrar al líder (Señor del Trono)
      String leaderId = '';
      String leaderName = '';
      int maxPoops = 0;

      userCounts.forEach((uid, count) {
        if (count > maxPoops) {
          maxPoops = count;
          leaderId = uid;
          leaderName = userNames[uid] ?? 'Usuario';
        }
      });

      // Calcular centro medio de la zona
      double avgLat = list.map((e) => e.latitude!).reduce((a, b) => a + b) / list.length;
      double avgLon = list.map((e) => e.longitude!).reduce((a, b) => a + b) / list.length;

      // Etiqueta predominante
      final Map<LocationTag, int> locCounts = {};
      for (var e in list) {
        locCounts[e.location] = (locCounts[e.location] ?? 0) + 1;
      }
      LocationTag primaryLoc = LocationTag.casa;
      int maxLoc = 0;
      locCounts.forEach((loc, count) {
        if (count > maxLoc) {
          maxLoc = count;
          primaryLoc = loc;
        }
      });

      result.add(TerritoryZone(
        id: key,
        center: LatLng(avgLat, avgLon),
        primaryLocation: primaryLoc,
        totalPoops: list.length,
        leaderId: leaderId,
        leaderName: leaderName,
        leaderCount: maxPoops,
        events: list,
      ));
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          title: const Text('KKpencos por el mundo 🌍', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMapData,
            )
          ],
          bottom: const TabBar(
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(
                icon: Icon(Icons.local_fire_department_rounded),
                text: 'Calor & Territorios',
              ),
              Tab(
                icon: Icon(Icons.public_rounded),
                text: 'Cacas por el Mundo',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.brown))
            : TabBarView(
                children: [
                  _buildLocalHeatmapTab(currentUser.uid),
                  _buildWorldConquestTab(currentUser.uid),
                ],
              ),
      ),
    );
  }

  // PESTAÑA 1: Calor local y zonas de dominio
  Widget _buildLocalHeatmapTab(String currentUserId) {
    return Stack(
      children: [
        // Mapa interactivo
        FlutterMap(
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 14.0,
            maxZoom: 18.0,
            minZoom: 3.0,
          ),
          children: [
            // Capa de tiles del mapa (CartoDB Dark Matter)
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.kkpenco.app',
            ),

            // Capa de Calor
            CircleLayer(
              circles: _geolocatedEvents.map((event) {
                return CircleMarker(
                  point: LatLng(event.latitude!, event.longitude!),
                  color: Colors.orangeAccent.withAlpha(25),
                  useRadiusInMeter: true,
                  radius: 40.0,
                );
              }).toList(),
            ),

            // Marcadores de Zonas de Dominio
            MarkerLayer(
              markers: _territories.map((territory) {
                final isMeLeader = territory.leaderId == currentUserId;

                return Marker(
                  point: territory.center,
                  width: 45,
                  height: 45,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTerritory = territory;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isMeLeader 
                              ? Colors.amberAccent.withAlpha(51)
                              : Colors.brown.withAlpha(76),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isMeLeader ? Colors.amberAccent : Colors.grey,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: isMeLeader ? Colors.amberAccent : Colors.grey[400],
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Tarjeta de información inferior del territorio
        if (_selectedTerritory != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildTerritoryCard(currentUserId),
          ),
      ],
    );
  }

  // PESTAÑA 2: Conquista mundial por países
  Widget _buildWorldConquestTab(String currentUserId) {
    return Column(
      children: [
        if (_resolvingCountries)
          const LinearProgressIndicator(
            backgroundColor: Color(0xFF1E1E1E),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            minHeight: 3,
          ),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(20.0, 0.0),
                  initialZoom: 1.5,
                  maxZoom: 8.0,
                  minZoom: 1.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.kkpenco.app',
                  ),
                  MarkerLayer(
                    markers: _countries.map((country) {
                      final isMeLeader = country.leaderId == currentUserId;
                      return Marker(
                        point: country.avgCenter,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCountry = country;
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isMeLeader
                                    ? Colors.greenAccent.withAlpha(51)
                                    : Colors.cyanAccent.withAlpha(51),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isMeLeader ? Colors.greenAccent : Colors.cyanAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    country.flagEmoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey, width: 0.5),
                                  ),
                                  child: Text(
                                    '${country.totalPoops}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (_selectedCountry != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildCountryCard(currentUserId),
                ),
            ],
          ),
        ),
        // Panel inferior: Lista horizontal Bento de países conquistados
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFF161616),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
                  child: Text(
                    'Países Conquistados por el Grupo 🏆',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: _countries.isEmpty
                      ? Center(
                          child: Text(
                            _resolvingCountries 
                                ? 'Cargando países conquistados...'
                                : 'Aún no hay registros de países. ¡Activa el GPS!',
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _countries.length,
                          itemBuilder: (context, index) {
                            final country = _countries[index];
                            final isMeLeader = country.leaderId == currentUserId;
                            return Container(
                              width: 170,
                              margin: const EdgeInsets.only(right: 12.0, bottom: 12.0),
                              child: Card(
                                color: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isMeLeader
                                        ? Colors.greenAccent.withAlpha(76)
                                        : Colors.cyanAccent.withAlpha(38),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _selectedCountry = country;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              country.flagEmoji,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF000000),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${country.totalPoops}💩',
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          country.countryName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        const Text(
                                          'Líder Nacional:',
                                          style: TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 12),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                isMeLeader ? 'Tú' : country.leaderName,
                                                style: TextStyle(
                                                  color: isMeLeader ? Colors.greenAccent : Colors.white70,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerritoryCard(String currentUserId) {
    final territory = _selectedTerritory!;
    final isMeLeader = territory.leaderId == currentUserId;

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isMeLeader ? Colors.amberAccent : Colors.brown[800]!,
          width: 1.5,
        ),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      territory.primaryLocation == LocationTag.casa
                          ? Icons.home_rounded
                          : (territory.primaryLocation == LocationTag.trabajo
                              ? Icons.business_center_rounded
                              : Icons.forest_rounded),
                      color: Colors.brown[300],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trono: ${territory.primaryLocation.displayName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedTerritory = null;
                    });
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Señor del Trono 👑', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      isMeLeader ? 'Tú (Líder)' : territory.leaderName,
                      style: TextStyle(
                        color: isMeLeader ? Colors.amberAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Deposiciones', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${territory.leaderCount} de ${territory.totalPoops} totales',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMeLeader)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '¡Dominas este territorio! Defiéndelo.',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  // Desbloquear logro "Señor del Trono" de forma simulada
                  _dbService.unlockAchievement(currentUserId, 'conqueror', 'Tú');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('💩 ¡Registra tu caca aquí para arrebatarle el trono!'),
                      backgroundColor: Colors.brown,
                    ),
                  );
                },
                icon: const Icon(Icons.shield_rounded, size: 16),
                label: const Text('Arrebatar el Trono de Hierro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCard(String currentUserId) {
    final country = _selectedCountry!;
    final isMeLeader = country.leaderId == currentUserId;

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isMeLeader ? Colors.greenAccent : Colors.cyan[800]!,
          width: 1.5,
        ),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      country.flagEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      country.countryName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedCountry = null;
                    });
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Líder del País 👑', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      isMeLeader ? 'Tú (Presidente)' : country.leaderName,
                      style: TextStyle(
                        color: isMeLeader ? Colors.greenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Cacas del Grupo', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${country.leaderCount} de ${country.totalPoops} totales',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMeLeader)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '¡Eres el Conquistador Nacional de este país! 🏆',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Dominado por ${country.leaderName}. ¡Viaja y conquista!',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- CLASES AUXILIARES ---
class TerritoryZone {
  final String id;
  final LatLng center;
  final LocationTag primaryLocation;
  final int totalPoops;
  final String leaderId;
  final String leaderName;
  final int leaderCount;
  final List<KKEvent> events;

  TerritoryZone({
    required this.id,
    required this.center,
    required this.primaryLocation,
    required this.totalPoops,
    required this.leaderId,
    required this.leaderName,
    required this.leaderCount,
    required this.events,
  });
}

class CountryConquest {
  final String countryCode;
  final String countryName;
  final int totalPoops;
  final String leaderId;
  final String leaderName;
  final int leaderCount;
  final LatLng avgCenter;

  CountryConquest({
    required this.countryCode,
    required this.countryName,
    required this.totalPoops,
    required this.leaderId,
    required this.leaderName,
    required this.leaderCount,
    required this.avgCenter,
  });

  String get flagEmoji {
    if (countryCode.length != 2) return '🏳️';
    try {
      final int firstChar = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
      final int secondChar = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
      return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
    } catch (_) {
      return '🏳️';
    }
  }
}
