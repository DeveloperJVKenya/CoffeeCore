import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:coffeecore/config.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _locationController = TextEditingController();
  String? _selectedActualWeather;
  Map<String, List<Map<String, dynamic>>>? _dailyForecast;
  bool _isLoading = false;
  final logger = Logger(printer: PrettyPrinter());
  static final Color coffeeBrown = Colors.brown[700]!; // Coffee theme color
  static const String _weatherBase = 'https://weather.googleapis.com/v1';

  Future<Map<String, double>?> _getCoordinates(String location) async {
    final geoUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$location&key=${Config.weatherApiKey}');
    try {
      final response = await http.get(geoUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (data['status'] == 'OK' && results != null && results.isNotEmpty) {
          final loc = results[0]['geometry']['location'];
          return {'lat': (loc['lat'] as num).toDouble(), 'lon': (loc['lng'] as num).toDouble()};
        }
        throw Exception('No valid coordinates found (${data['status']})');
      }
      throw Exception('Geocoding API error: ${response.statusCode}');
    } catch (e) {
      logger.e('Error fetching coordinates: $e');
      return null;
    }
  }

  Future<void> _fetchDailyForecast() async {
    final location = _locationController.text.trim();
    if (!RegExp(r'^[a-zA-Z\s,]+$').hasMatch(location) || location.isEmpty) {
      _showSnackBar('Please enter a valid location (letters and spaces only)');
      return;
    }

    setState(() => _isLoading = true);
    final coordinates = await _getCoordinates(location);
    if (coordinates == null) {
      setState(() {
        _dailyForecast = null;
        _isLoading = false;
      });
      _showSnackBar('Could not find location: $location');
      return;
    }

    final url = Uri.parse(
        '$_weatherBase/forecast/hours:lookup?key=${Config.weatherApiKey}'
        '&location.latitude=${coordinates['lat']}&location.longitude=${coordinates['lon']}'
        '&hours=120&unitsSystem=METRIC');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['forecastHours'] != null && data['forecastHours'] is List) {
          _processDailyForecast(data['forecastHours']);
        } else {
          throw Exception('Invalid forecast data');
        }
      } else {
        throw Exception('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _dailyForecast = null;
      });
      _showSnackBar('Failed to fetch forecast: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processDailyForecast(List<dynamic> forecastList) {
    Map<String, List<Map<String, dynamic>>> groupedForecast = {};
    for (var forecast in forecastList) {
      final displayDateTime = forecast['displayDateTime'];
      if (displayDateTime == null || forecast['temperature'] == null) continue;
      DateTime dateTime = DateTime(
        displayDateTime['year'],
        displayDateTime['month'],
        displayDateTime['day'],
        (displayDateTime['hours'] as num?)?.toInt() ?? 0,
      );
      String date = dateTime.toLocal().toString().split(' ')[0];
      String formattedTime = '${dateTime.hour.toString().padLeft(2, '0')}:00';
      double temp = (forecast['temperature']['degrees'] as num?)?.toDouble() ?? 0.0;
      int humidity = (forecast['relativeHumidity'] as num?)?.toInt() ?? 0;
      int clouds = (forecast['cloudCover'] as num?)?.toInt() ?? 0;
      final qpf = forecast['precipitation']?['qpf'];
      double rainfall = (qpf?['quantity'] as num?)?.toDouble() ?? 0.0;
      String weatherType =
          (forecast['weatherCondition']?['type'] as String?)?.toLowerCase() ?? '';
      String weather = _simplifyWeatherType(weatherType);

      groupedForecast.putIfAbsent(date, () => []).add({
        'time': formattedTime,
        'temp': temp,
        'humidity': humidity,
        'clouds': clouds,
        'rainfall': rainfall,
        'weather': weather,
      });
    }
    setState(() {
      _dailyForecast = groupedForecast.isNotEmpty ? groupedForecast : null;
    });
  }

  // Google's weatherCondition.type is a fine-grained enum (e.g. "LIGHT_RAIN",
  // "SCATTERED_THUNDERSTORMS", "MOSTLY_CLOUDY") — bucket it into the coarse
  // categories the UI icon/color helpers below understand.
  String _simplifyWeatherType(String type) {
    if (type.contains('rain') ||
        type.contains('shower') ||
        type.contains('thunder') ||
        type.contains('hail') ||
        type.contains('snow')) {
      return 'rain';
    }
    if (type.contains('wind')) return 'wind';
    if (type.contains('cloud')) return 'clouds';
    if (type.contains('clear') || type.contains('sun')) return 'clear';
    return 'unknown';
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  IconData _getWeatherIcon(String weather) {
    switch (weather) {
      case 'clear':
        return Icons.wb_sunny;
      case 'rain':
        return Icons.water_drop;
      case 'clouds':
        return Icons.cloud;
      case 'wind':
        return Icons.air;
      default:
        return Icons.help_outline;
    }
  }

  Color _getWeatherColor(String weather) {
    switch (weather) {
      case 'clear':
        return Colors.yellow;
      case 'rain':
        return Colors.blue;
      case 'clouds':
        return Colors.grey;
      case 'wind':
        return Colors.cyan;
      default:
        return Colors.black54;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.brown, // Coffee brown as primary swatch
        scaffoldBackgroundColor: Colors.blueGrey[50], // Original background unchanged
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold), // Original blue titles unchanged
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: coffeeBrown, // Coffee brown buttons
            foregroundColor: Colors.white, // White text/icons on buttons
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          prefixIconColor: coffeeBrown, // Coffee brown for location icon
          labelStyle: const TextStyle(color: Colors.black54), // Original label color
          hintStyle: const TextStyle(color: Colors.grey), // Original hint color
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Weather Forecast',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          backgroundColor: coffeeBrown, // Coffee brown AppBar
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedActualWeather,
                items: const [
                  DropdownMenuItem(value: 'sunny', child: Text('Sunny')),
                  DropdownMenuItem(value: 'rainy', child: Text('Rainy')),
                  DropdownMenuItem(value: 'windy', child: Text('Windy')),
                  DropdownMenuItem(value: 'cloudy', child: Text('Cloudy')),
                ],
                onChanged: (value) => setState(() => _selectedActualWeather = value),
                decoration: const InputDecoration(
                  labelText: 'Your Observed Weather',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Nairobi',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchDailyForecast,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) const CircularProgressIndicator(color: Colors.white),
                    if (!_isLoading) const Icon(Icons.cloud_download),
                    const SizedBox(width: 8),
                    Text(_isLoading ? 'Fetching...' : 'Get Forecast'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent)) // Original blue spinner
                    : _dailyForecast != null
                        ? ListView.builder(
                            itemCount: _dailyForecast!.length,
                            itemBuilder: (context, index) {
                              final entry = _dailyForecast!.entries.elementAt(index);
                              final date = entry.key;
                              final forecasts = entry.value;
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(date, style: Theme.of(context).textTheme.titleLarge),
                                      if (_selectedActualWeather != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'You observed: $_selectedActualWeather | API says: ${forecasts[0]['weather']}',
                                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      ...forecasts.map((forecast) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getWeatherIcon(forecast['weather']),
                                                  color: _getWeatherColor(forecast['weather']),
                                                  size: 28,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${forecast['time']}:',
                                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.thermostat, color: Colors.red, size: 20), // Original red
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            '${forecast['temp'].toStringAsFixed(1)}°C',
                                                            style: const TextStyle(fontSize: 16),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.water, color: Colors.blueGrey, size: 20), // Original blueGrey
                                                          const SizedBox(width: 8),
                                                          Text('Humidity: ${forecast['humidity']}%'),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.cloud, color: Colors.grey, size: 20), // Original grey
                                                          const SizedBox(width: 8),
                                                          Text('Clouds: ${forecast['clouds']}%'),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.water_drop, color: Colors.blue, size: 20), // Original blue
                                                          const SizedBox(width: 8),
                                                          Text('Rain: ${forecast['rainfall'].toStringAsFixed(1)} mm'),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text(
                              'Enter a location to see the forecast',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}