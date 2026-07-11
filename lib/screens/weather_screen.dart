import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffeecore/config.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _locationController = TextEditingController();
  final Logger _log = Logger(printer: PrettyPrinter());

  // Same Google Weather API endpoints used by the Farm Mapping section
  // (climate_satellite_service.dart) — currentConditions + a lightweight
  // 5-day forecast, instead of a heavy 120-hour lookup.
  static const String _weatherBase = 'https://weather.googleapis.com/v1';
  static const String _cacheKey = 'weather_cache_v2';

  bool _isLoading = false;
  bool _isLocating = false;
  bool _isOffline = false;
  String? _errorMessage;
  String? _locationLabel;
  bool _isCurrentLocation = true;
  DateTime? _dataAsOf;

  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _daily = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasCache = await _loadCachedWeather();
    await _refreshCurrentLocation(background: hasCache);
  }

  // ─────────────────────────────────────────────────────────────
  // NETWORK
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _geocode(String location) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(location)}&key=${Config.weatherApiKey}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Geocoding error (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body);
    final status = data['status'] as String?;
    if (status == 'ZERO_RESULTS') return null;
    final results = data['results'] as List?;
    if (status != 'OK' || results == null || results.isEmpty) {
      final detail = data['error_message'] as String?;
      throw Exception(
          'Geocoding failed: $status${detail != null ? ' ($detail)' : ''}');
    }
    final loc = results[0]['geometry']['location'];
    return {
      'lat': (loc['lat'] as num).toDouble(),
      'lon': (loc['lng'] as num).toDouble(),
      'label': results[0]['formatted_address'] as String? ?? location,
    };
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lon&key=${Config.weatherApiKey}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    final results = data['results'] as List?;
    if (data['status'] != 'OK' || results == null || results.isEmpty) {
      return null;
    }
    return results[0]['formatted_address'] as String?;
  }

  Future<Map<String, dynamic>> _fetchCurrentConditions(
      double lat, double lon) async {
    final uri = Uri.parse(
      '$_weatherBase/currentConditions:lookup'
      '?key=${Config.weatherApiKey}'
      '&location.latitude=$lat&location.longitude=$lon'
      '&unitsSystem=METRIC',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception(extractApiMessage(res.body) ??
          'Weather service error (HTTP ${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _fetchDaily(double lat, double lon) async {
    final uri = Uri.parse(
      '$_weatherBase/forecast/days:lookup'
      '?key=${Config.weatherApiKey}'
      '&location.latitude=$lat&location.longitude=$lon'
      '&days=5&unitsSystem=METRIC',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception(extractApiMessage(res.body) ??
          'Forecast service error (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body);
    return (data['forecastDays'] as List<dynamic>?) ?? [];
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _refreshCurrentLocation({bool background = false}) async {
    if (!background) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (_current == null) {
          setState(() => _errorMessage =
              'Location permission is needed to show weather for your farm. Or search a location above.');
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (_current == null) {
          setState(() => _errorMessage =
              'Turn on location services, or search a location above.');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      // Fetch the location's display name and its weather in parallel —
      // the name isn't needed to start the weather request.
      final results = await Future.wait([
        _reverseGeocode(pos.latitude, pos.longitude),
        _fetchCurrentConditions(pos.latitude, pos.longitude),
        _fetchDaily(pos.latitude, pos.longitude),
      ]);
      final label = results[0] as String? ?? 'Current Location';
      final current = results[1] as Map<String, dynamic>;
      final dailyRaw = results[2] as List<dynamic>;
      _applyForecast(current, dailyRaw, label, isCurrentLocation: true);
      await _persistCache(pos.latitude, pos.longitude, label);
      if (mounted) setState(() => _isOffline = false);
    } catch (e, st) {
      _log.e('WeatherScreen: Current location error – $e', stackTrace: st);
      if (mounted) {
        if (_current == null) {
          setState(() => _errorMessage = e is ServiceUnavailableException
              ? e.userMessage
              : 'Could not load weather for your current location.');
        } else {
          // We still have cached/previous data on screen — flag it as stale
          // instead of wiping it out over a transient refresh failure.
          setState(() => _isOffline = true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _search() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      _showSnackBar('Enter a location to check the weather.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final coords = await _geocode(location);
      if (coords == null) {
        setState(() => _errorMessage =
            'Couldn\'t find "$location". Try a nearby town or city name.');
        return;
      }
      final lat = coords['lat'] as double;
      final lon = coords['lon'] as double;
      final results = await Future.wait([
        _fetchCurrentConditions(lat, lon),
        _fetchDaily(lat, lon),
      ]);
      _applyForecast(
        results[0] as Map<String, dynamic>,
        results[1] as List<dynamic>,
        coords['label'] as String,
        isCurrentLocation: false,
      );
      if (mounted) setState(() => _isOffline = false);
    } catch (e, st) {
      _log.e('WeatherScreen: Search error – $e', stackTrace: st);
      setState(() => _errorMessage = e is ServiceUnavailableException
          ? e.userMessage
          : (isNetworkError(e)
              ? 'Could not reach the weather service — check your internet connection.'
              : e.toString().replaceFirst('Exception: ', '')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyForecast(
    Map<String, dynamic> current,
    List<dynamic> dailyRaw,
    String label, {
    required bool isCurrentLocation,
  }) {
    final days = <Map<String, dynamic>>[];
    for (final item in dailyRaw) {
      final entry = item as Map<String, dynamic>;
      final displayDate = entry['displayDate'] as Map<String, dynamic>?;
      if (displayDate == null) continue;
      final date = DateTime(
        displayDate['year'] as int,
        displayDate['month'] as int,
        displayDate['day'] as int,
      );
      final daytime = entry['daytimeForecast'] as Map<String, dynamic>? ?? {};
      final weatherCondition =
          daytime['weatherCondition'] as Map<String, dynamic>? ?? {};
      final maxTemp = entry['maxTemperature'] as Map<String, dynamic>?;
      final minTemp = entry['minTemperature'] as Map<String, dynamic>?;

      days.add({
        'date': date,
        'maxTemp': (maxTemp?['degrees'] as num? ?? 0).toDouble(),
        'minTemp': (minTemp?['degrees'] as num? ?? 0).toDouble(),
        'humidity': (daytime['relativeHumidity'] as num? ?? 0).toInt(),
        'precipChance':
            (daytime['precipitation']?['probability']?['percent'] as num? ?? 0)
                .toInt(),
        'condition': _simplifyWeatherType(
            (weatherCondition['type'] as String? ?? '').toLowerCase()),
        'iconBase': weatherCondition['iconBaseUri'] as String? ?? '',
        'description':
            weatherCondition['description']?['text'] as String? ?? 'Unknown',
      });
    }

    final currentWeatherCondition =
        current['weatherCondition'] as Map<String, dynamic>? ?? {};

    setState(() {
      _locationLabel = label;
      _isCurrentLocation = isCurrentLocation;
      _dataAsOf = DateTime.now();
      _current = {
        'temp': (current['temperature']?['degrees'] as num? ?? 0).toDouble(),
        'feelsLike': (current['feelsLikeTemperature']?['degrees'] as num? ?? 0)
            .toDouble(),
        'humidity': (current['relativeHumidity'] as num? ?? 0).toInt(),
        'windSpeed':
            (current['wind']?['speed']?['value'] as num? ?? 0).toDouble(),
        'uvIndex': (current['uvIndex'] as num? ?? 0).toInt(),
        'clouds': (current['cloudCover'] as num? ?? 0).toInt(),
        'precipChance':
            (current['precipitation']?['probability']?['percent'] as num? ?? 0)
                .toInt(),
        'isDaytime': current['isDaytime'] as bool? ?? _isDaytimeNow(),
        'condition': _simplifyWeatherType(
            (currentWeatherCondition['type'] as String? ?? '').toLowerCase()),
        'iconBase': currentWeatherCondition['iconBaseUri'] as String? ?? '',
        'description':
            currentWeatherCondition['description']?['text'] as String? ??
                'Unknown',
      };
      _daily = days.take(5).toList();
      _errorMessage = null;
    });
  }

  bool _isDaytimeNow() {
    final h = DateTime.now().hour;
    return h >= 6 && h < 18;
  }

  // ─────────────────────────────────────────────────────────────
  // OFFLINE CACHE
  // ─────────────────────────────────────────────────────────────

  Future<void> _persistCache(double lat, double lon, String label) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'lat': lat,
        'lon': lon,
        'label': label,
        'current': _current,
        'daily': _daily
            .map((d) => {
                  ...d,
                  'date': (d['date'] as DateTime).toIso8601String(),
                })
            .toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (e) {
      _log.w('WeatherScreen: Failed to persist weather cache – $e');
    }
  }

  Future<bool> _loadCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final daily = (data['daily'] as List).map((d) {
        final m = Map<String, dynamic>.from(d as Map);
        m['date'] = DateTime.parse(m['date'] as String);
        return m;
      }).toList();

      if (!mounted) return false;
      setState(() {
        _current = Map<String, dynamic>.from(data['current'] as Map);
        _daily = daily.cast<Map<String, dynamic>>();
        _locationLabel = data['label'] as String?;
        _dataAsOf = DateTime.parse(data['cachedAt'] as String);
        _isCurrentLocation = true;
        _isOffline = true;
      });
      return true;
    } catch (e) {
      _log.w('WeatherScreen: Failed to load weather cache – $e');
      return false;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'unknown time';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Google's weatherCondition.type is a fine-grained enum (e.g. "LIGHT_RAIN",
  // "SCATTERED_THUNDERSTORMS", "MOSTLY_CLOUDY") — bucket it into coarse
  // categories the UI icon/gradient/color helpers understand.
  String _simplifyWeatherType(String type) {
    if (type.contains('thunder')) return 'storm';
    if (type.contains('snow') || type.contains('hail')) return 'snow';
    if (type.contains('rain') ||
        type.contains('shower') ||
        type.contains('drizzle')) {
      return 'rain';
    }
    if (type.contains('wind')) return 'wind';
    if (type.contains('fog') ||
        type.contains('haze') ||
        type.contains('mist')) {
      return 'fog';
    }
    if (type.contains('cloud')) return 'clouds';
    if (type.contains('clear') || type.contains('sun')) return 'clear';
    return 'unknown';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.brown[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VISUAL HELPERS
  // ─────────────────────────────────────────────────────────────

  IconData _iconFor(String condition) {
    switch (condition) {
      case 'clear':
        return Icons.wb_sunny_rounded;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'storm':
        return Icons.thunderstorm_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'wind':
        return Icons.air_rounded;
      case 'fog':
        return Icons.foggy;
      case 'clouds':
        return Icons.cloud_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  // Keep the app's coffee-brown identity in the header regardless of
  // condition — vary shade by condition/day-night for depth, but stay
  // within the brown family instead of switching to unrelated hues.
  List<Color> _gradientFor(String condition, bool isDaytime) {
    if (!isDaytime) {
      return const [Color(0xFF3E2723), Color(0xFF1B1210)];
    }
    switch (condition) {
      case 'rain':
      case 'storm':
        return const [Color(0xFF5D4037), Color(0xFF3E2723)];
      case 'snow':
      case 'fog':
        return const [Color(0xFF8D6E63), Color(0xFF5D4037)];
      case 'clouds':
        return const [Color(0xFF795548), Color(0xFF4E342E)];
      default:
        return const [Color(0xFFA1785C), Color(0xFF6D4C41)];
    }
  }

  Color _accentFor(String condition) {
    switch (condition) {
      case 'rain':
      case 'storm':
        return const Color(0xFF4E342E);
      case 'snow':
      case 'fog':
        return const Color(0xFF8D6E63);
      case 'clouds':
        return const Color(0xFF6D4C41);
      default:
        return Colors.brown[700]!;
    }
  }

  /// Practical, condition-based coffee-farming guidance — replaces the old
  /// "what did you personally observe" input with something actually useful.
  String _coffeeTip(String condition, double temp, int precipChance) {
    switch (condition) {
      case 'storm':
        return 'Thunderstorms expected — hold off on spraying and secure loose farm equipment.';
      case 'rain':
        return precipChance >= 60
            ? 'High chance of rain — good day for planting, but delay any pesticide or fertilizer application.'
            : 'Light rain possible — keep an eye on drainage around young seedlings.';
      case 'clear':
        return temp >= 28
            ? 'Hot and clear — check irrigation and shade cover to protect coffee cherries from heat stress.'
            : 'Clear skies — a good day for pruning, weeding, or sun-drying harvested cherries.';
      case 'wind':
        return 'Windy conditions — inspect young trees for lodging and secure any shade netting.';
      case 'fog':
        return 'Foggy and humid — monitor closely for coffee leaf rust and other fungal disease pressure.';
      case 'clouds':
        return 'Overcast skies — a comfortable day for fieldwork without excess heat stress on workers.';
      case 'snow':
        return 'Unusually cold conditions — protect young or exposed coffee plants from frost damage.';
      default:
        return 'Check back after refreshing for tailored guidance on today\'s farm work.';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final condition = _current?['condition'] as String? ?? 'default';
    final isDaytime = _current?['isDaytime'] as bool? ?? _isDaytimeNow();
    final gradient = _gradientFor(condition, isDaytime);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EE),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: gradient.last,
          onRefresh: () =>
              _isCurrentLocation ? _refreshCurrentLocation() : _search(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(gradient, condition)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildSearchBar(),
                ),
              ),
              SliverToBoxAdapter(
                child: _isLoading
                    ? _buildLoading()
                    : _errorMessage != null
                        ? _buildError()
                        : _current == null
                            ? _buildEmptyState()
                            : _buildWeatherContent(condition),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(List<Color> gradient, String condition) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative oversized weather icon watermark — fills the
            // otherwise-empty background so the header reads as designed
            // rather than blank, even before data loads.
            Positioned(
              right: -30,
              top: -10,
              child: Icon(
                _iconFor(condition),
                size: 160,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              left: -36,
              bottom: -30,
              child: Icon(
                Icons.local_cafe,
                size: 110,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const Expanded(
                      child: Text(
                        'Weather',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 6),
                if (_current != null)
                  _buildHeaderContent()
                else if (_isLoading)
                  _buildHeaderLoading()
                else
                  _buildHeaderPrompt(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCurrentLocation ? Icons.my_location : Icons.location_on,
              color: Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _locationLabel ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _WeatherIcon(
          iconBase: _current!['iconBase'] as String,
          fallback: _iconFor(_current!['condition'] as String),
          size: 80,
          color: Colors.white,
        ),
        Text(
          '${(_current!['temp'] as double).round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 60,
            fontWeight: FontWeight.w200,
            height: 1.0,
          ),
        ),
        Text(
          _current!['description'] as String,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _headerChip(Icons.thermostat,
                'Feels ${(_current!['feelsLike'] as double).round()}°'),
            const SizedBox(width: 10),
            _headerChip(Icons.water_drop, '${_current!['humidity']}%'),
            const SizedBox(width: 10),
            _headerChip(Icons.air,
                '${(_current!['windSpeed'] as double).round()} km/h'),
          ],
        ),
      ],
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHeaderLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: const [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
          SizedBox(height: 14),
          Text(
            'Fetching your local weather…',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.cloud_outlined, color: Colors.white70, size: 44),
          const SizedBox(height: 10),
          const Text(
            'Enable location or search a place\nto see live weather here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _locationController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: 'Search city or town…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Use my location',
            onPressed: _isLocating
                ? null
                : () {
                    _locationController.clear();
                    _refreshCurrentLocation();
                  },
            icon: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.my_location, color: Colors.brown[700]),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ── Loading / error / empty states ──────────────────────────
  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator(color: Color(0xFF6D4C41))),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: Colors.orange[400]),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshCurrentLocation,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox.shrink();
  }

  // ── Main content ────────────────────────────────────────────
  Widget _buildWeatherContent(String condition) {
    final accent = _accentFor(condition);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCurrentLocation)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _refreshCurrentLocation,
                  icon: Icon(Icons.my_location,
                      size: 15, color: Colors.brown[700]),
                  label: Text(
                    'Back to my location',
                    style: TextStyle(fontSize: 12, color: Colors.brown[700]),
                  ),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ),
            ),
          if (_isOffline)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — showing weather from ${_timeAgo(_dataAsOf)}',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          _buildDetailGrid(accent),
          const SizedBox(height: 20),
          if (_daily.isNotEmpty) ...[
            _sectionTitle('5-Day Forecast', Icons.date_range),
            const SizedBox(height: 10),
            _buildDailyStrip(),
            const SizedBox(height: 20),
          ],
          _buildCoffeeTipCard(condition, accent),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.brown[700]),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.brown[800],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid(Color accent) {
    final c = _current!;
    final items = [
      (_Metric(Icons.water_drop, 'Humidity', '${c['humidity']}%')),
      (_Metric(Icons.air, 'Wind',
          '${(c['windSpeed'] as double).toStringAsFixed(1)} km/h')),
      (_Metric(Icons.wb_sunny_outlined, 'UV Index', '${c['uvIndex']}')),
      (_Metric(Icons.cloud, 'Cloud Cover', '${c['clouds']}%')),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: items
            .map((m) => Expanded(
                  child: Column(
                    children: [
                      Icon(m.icon, size: 20, color: accent),
                      const SizedBox(height: 6),
                      Text(
                        m.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.label,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDailyStrip() {
    final today = DateTime.now();
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 132,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _daily.length,
        itemBuilder: (context, i) {
          final d = _daily[i];
          final date = d['date'] as DateTime;
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return Container(
            width: 92,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isToday ? Colors.brown[700] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isToday ? 'Today' : weekdayNames[date.weekday - 1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.brown[700],
                  ),
                ),
                const SizedBox(height: 8),
                _WeatherIcon(
                  iconBase: d['iconBase'] as String,
                  fallback: _iconFor(d['condition'] as String),
                  size: 30,
                  color: isToday
                      ? Colors.white
                      : _accentFor(d['condition'] as String),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(d['maxTemp'] as double).round()}° / ${(d['minTemp'] as double).round()}°',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.brown[800],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoffeeTipCard(String condition, Color accent) {
    final tempRaw = _current!['temp'];
    final temp = tempRaw is double ? tempRaw : 0.0;
    final precipChance = (_current!['precipChance'] as int?) ??
        (_daily.isNotEmpty ? (_daily.first['precipChance'] as int? ?? 0) : 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_cafe, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Guidance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.brown[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _coffeeTip(condition, temp, precipChance),
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  final IconData icon;
  final String label;
  final String value;
  const _Metric(this.icon, this.label, this.value);
}

/// Renders Google Weather API's iconBaseUri (needs a .png suffix appended)
/// with a graceful fallback to a Material icon if unavailable.
class _WeatherIcon extends StatelessWidget {
  final String iconBase;
  final IconData fallback;
  final double size;
  final Color color;

  const _WeatherIcon({
    required this.iconBase,
    required this.fallback,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (iconBase.isEmpty) {
      return Icon(fallback, size: size, color: color);
    }
    return Image.network(
      '$iconBase.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: color),
    );
  }
}
