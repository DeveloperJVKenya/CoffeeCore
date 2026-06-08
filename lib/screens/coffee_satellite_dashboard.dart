import 'package:flutter/material.dart';

// =============================================================================
// COFFEE SATELLITE ADVISOR - ULTIMATE FARMER DASHBOARD v2
// All insights are computed from raw satellite numbers so nothing contradicts.
// =============================================================================

class CoffeeAgroMetrics {
  final DateTime date;
  final double avgTemp;
  final double minTemp;
  final double maxTemp;
  final double humidity;
  final double maxHumidity;
  final double rainfall;
  final double windSpeed;
  final double maxWindSpeed;
  final String soilStatus;
  final Color soilColor;
  final String diseaseRisk;
  final Color diseaseColor;
  final String pestRisk;
  final Color pestColor;
  final String weatherSummary;
  final IconData weatherIcon;
  final Color weatherColor;
  final List<String> soilActions;
  final List<String> diseaseActions;
  final List<String> pestActions;
  final List<String> positiveInsights;
  final List<String> riskAlerts;
  final int farmHealthScore;
  final List<HourlyBand> hourlyBands;

  CoffeeAgroMetrics({
    required this.date,
    required this.avgTemp,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.maxHumidity,
    required this.rainfall,
    required this.windSpeed,
    required this.maxWindSpeed,
    required this.soilStatus,
    required this.soilColor,
    required this.diseaseRisk,
    required this.diseaseColor,
    required this.pestRisk,
    required this.pestColor,
    required this.weatherSummary,
    required this.weatherIcon,
    required this.weatherColor,
    required this.soilActions,
    required this.diseaseActions,
    required this.pestActions,
    required this.positiveInsights,
    required this.riskAlerts,
    required this.farmHealthScore,
    required this.hourlyBands,
  });
}

class HourlyBand {
  final int hour;
  final double temp;
  final double humidity;
  final double rainfall;
  final double windSpeed;
  final String condition;

  HourlyBand({
    required this.hour,
    required this.temp,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.condition,
  });
}

class CoffeeSatelliteDashboard extends StatefulWidget {
  const CoffeeSatelliteDashboard({super.key});

  @override
  State<CoffeeSatelliteDashboard> createState() =>
      _CoffeeSatelliteDashboardState();
}

class _CoffeeSatelliteDashboardState extends State<CoffeeSatelliteDashboard>
    with SingleTickerProviderStateMixin {
  bool _isRealtimeSynced = false;
  bool _isLoading = false;
  int _selectedDayIndex = 6;
  late TabController _tabController;
  final Map<String, bool> _completedTasks = {};
  bool _showHourlyBands = true;

  late final List<CoffeeAgroMetrics> _weekData;
  final List<String> _weekDays = [
    "Mon 25",
    "Tue 26",
    "Wed 27",
    "Thu 28",
    "Fri 29",
    "Sat 30",
    "Sun 31"
  ];
  final List<double> _weeklyRainfall = [
    0.01,
    5.70,
    1.20,
    13.63,
    1.26,
    100.63,
    106.39
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _weekData = _buildWeekData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =============================================================================
  // SMART INSIGHT ENGINE — everything is computed from raw numbers so UI never
  // shows conflicting tags, alerts, or recommendations.
  // =============================================================================

  int _computeHealthScore(
      double maxTemp, double maxHumidity, double rainfall, double maxWind) {
    int score = 100;
    if (maxHumidity > 90) {
      score -= 25;
    } else if (maxHumidity > 85) {
      score -= 20;
    } else if (maxHumidity > 70) {
      score -= 12;
    }

    if (rainfall > 100) {
      score -= 30;
    } else if (rainfall > 50) {
      score -= 25;
    } else if (rainfall > 20) {
      score -= 15;
    } else if (rainfall > 10) {
      score -= 8;
    }

    if (maxTemp > 30) {
      score -= 15;
    } else if (maxTemp > 28) {
      score -= 10;
    }

    if (maxWind > 3.0) {
      score -= 15;
    } else if (maxWind > 2.5) {
      score -= 8;
    }

    return score.clamp(0, 100);
  }

  String _rainfallLabel(double rainfall) {
    if (rainfall > 100) return "🚨 Extreme Rain";
    if (rainfall > 50) return "🔴 Heavy Storm";
    if (rainfall > 20) return "⚠️ Heavy Rain";
    if (rainfall > 10) return "💧 Moderate Rain";
    if (rainfall > 0) return "🌦️ Light Showers";
    return "☀️ Dry";
  }

  Color _rainfallColor(double rainfall) {
    if (rainfall > 50) return Colors.red;
    if (rainfall > 20) return Colors.orange;
    if (rainfall > 10) return Colors.blue;
    if (rainfall > 0) return Colors.teal;
    return Colors.green;
  }

  String _humidityLabel(double avg, double max) {
    if (max > 90) return "🚨 Critical";
    if (max > 85) return "🔴 Fungal Risk";
    if (max > 70) return "⚠️ Elevated";
    if (avg > 60) return "✅ Moderate";
    return "✅ Low";
  }

  Color _humidityColor(double max) {
    if (max > 85) return Colors.red;
    if (max > 70) return Colors.orange;
    return Colors.blue;
  }

  String _tempLabel(double max) {
    if (max > 30) return "🔥 Heat Stress";
    if (max > 28) return "⚠️ Very Warm";
    if (max >= 18) return "✅ Optimal";
    return "❄️ Cold";
  }

  Color _tempColor(double max) {
    if (max > 30) return Colors.red;
    if (max > 28) return Colors.orange;
    if (max >= 18) return Colors.green;
    return Colors.blue;
  }

  String _windLabel(double max) {
    if (max > 3.0) return "🔴 Damaging";
    if (max > 2.5) return "⚠️ Strong";
    if (max >= 1.0) return "✅ Breeze";
    return "✅ Calm";
  }

  Color _windColor(double max) {
    if (max > 3.0) return Colors.red;
    if (max > 2.5) return Colors.orange;
    return Colors.blueGrey;
  }

  String _weatherSummary(double rainfall, double maxHumidity, double maxTemp) {
    if (rainfall > 50) return "⛈️ Heavy Storm";
    if (rainfall > 20) return "🌧️ Heavy Rain";
    if (rainfall > 10) return "🌦️ Moderate Rain";
    if (rainfall > 0) return "🌦️ Light Showers";
    if (maxHumidity > 85) return "💧 Very Humid";
    if (maxTemp > 28) return "☀️ Hot Day";
    return "☀️ Ideal Growing Day";
  }

  IconData _weatherIcon(double rainfall, double maxHumidity) {
    if (rainfall > 50) return Icons.thunderstorm;
    if (rainfall > 20) return Icons.umbrella;
    if (rainfall > 0) return Icons.water_drop;
    if (maxHumidity > 85) return Icons.water;
    return Icons.wb_sunny;
  }

  Color _weatherColor(double rainfall, double maxHumidity) {
    if (rainfall > 50) return Colors.red;
    if (rainfall > 20) return Colors.deepPurple;
    if (rainfall > 0) return Colors.blue;
    if (maxHumidity > 85) return Colors.indigo;
    return Colors.amber;
  }

  List<String> _soilActions(double rainfall) {
    if (rainfall > 50) {
      return [
        "🚨 Stop all fertilizer — nutrients will wash away",
        "🌊 Open all drainage lines immediately",
        "⛰️ Check terraces and slopes for erosion",
        "🌱 Look for standing water around roots",
      ];
    }
    if (rainfall > 20) {
      return [
        "🚫 Do not apply fertilizers today — risk of runoff",
        "🌾 Make sure drainage channels are open",
        "🌱 Check mulch is still in place after rain",
      ];
    }
    if (rainfall > 10) {
      return [
        "💧 Good soil moisture — check mulch integrity",
        "🌾 Monitor drainage for any blockages",
      ];
    }
    if (rainfall > 0) {
      return [
        "💧 Light rain helps dissolve nutrients in soil",
        "🌾 Check mulch integrity after showers",
      ];
    }
    return [
      "💧 Soil moisture is ideal for adding organic manure",
      "🌱 Perfect time to maintain mulch around roots",
      "🚜 Good conditions for general field work",
    ];
  }

  List<String> _diseaseActions(double maxHumidity) {
    if (maxHumidity > 85) {
      return [
        "🔴 High chance of Coffee Leaf Rust — act fast",
        "💉 Prepare copper spray to apply after rain stops",
        "🔍 Check lower branches daily for orange spots",
        "🍂 Remove fallen leaves near tree base",
      ];
    }
    if (maxHumidity > 70) {
      return [
        "⚠️ Fungal risk rising — scout every 5 days",
        "🍃 Look for early rust spots on lower branches",
        "✂️ Prune excess suckers to improve air flow",
      ];
    }
    return [
      "🔍 Continue normal fungal scouting every 7 days",
      "✂️ Prune excess water suckers for better air flow",
    ];
  }

  List<String> _pestActions(double rainfall, double maxHumidity) {
    if (rainfall > 50) {
      return [
        "🌧️ Heavy rain washed away most pests — no spray needed",
        "👷 Send workers to help with drainage instead",
      ];
    }
    if (rainfall > 20) {
      return [
        "🐞 Rain has reduced mite numbers — hold off spraying",
        "🪤 Check pheromone traps when weather clears",
      ];
    }
    return [
      "🐞 Inspect cherries for Coffee Berry Borer holes",
      "🪤 Set pheromone traps if borer damage is over 3%",
    ];
  }

  List<String> _riskAlerts(
      double maxTemp, double maxHumidity, double rainfall, double maxWind) {
    final List<String> alerts = [];
    if (rainfall > 50) {
      alerts.add(
          "🚨 ${rainfall.toStringAsFixed(1)}mm rain — soil is flooded and nutrients are washing away");
    } else if (rainfall > 20) {
      alerts.add(
          "⚠️ ${rainfall.toStringAsFixed(1)}mm rain — risk of soil runoff and waterlogging");
    }
    if (maxHumidity > 85) {
      alerts.add(
          "🚨 Humidity hit ${maxHumidity.toStringAsFixed(1)}% — Coffee Leaf Rust and CBD can spread fast");
    } else if (maxHumidity > 70) {
      alerts.add(
          "⚠️ Humidity reached ${maxHumidity.toStringAsFixed(1)}% — fungal risk threshold crossed");
    }
    if (maxTemp > 28) {
      alerts.add(
          "🔥 Max temperature ${maxTemp.toStringAsFixed(1)}°C — heat stress may damage cherries");
    }
    if (maxWind > 2.5) {
      alerts.add(
          "⚠️ Wind gusts ${maxWind.toStringAsFixed(1)} m/s — branches may break");
    }
    return alerts;
  }

  List<String> _positiveInsights(double avgTemp, double minTemp, double maxTemp,
      double humidity, double rainfall, double maxWind) {
    final List<String> insights = [];
    if (maxTemp <= 28 && minTemp >= 15) {
      insights.add("🌡️ Temperature stayed in healthy 15–28°C range all day");
    }
    if (humidity < 70) {
      insights.add(
          "💨 Humidity at ${humidity.toStringAsFixed(1)}% keeps fungal spores from growing");
    }
    if (rainfall >= 5 && rainfall <= 20) {
      insights.add(
          "🌧️ ${rainfall.toStringAsFixed(1)}mm rain is perfect for soil moisture without causing runoff");
    }
    if (maxWind < 2.5 && maxWind >= 0.5) {
      insights
          .add("🌬️ Gentle breeze helps pollination without stressing trees");
    }
    if (rainfall == 0) {
      insights.add("☀️ Dry weather is good for drying harvested cherries");
    }
    if (insights.isEmpty) {
      insights.add("📡 Satellite data is being monitored for your farm");
    }
    return insights;
  }

  String _soilStatus(double rainfall) {
    if (rainfall > 50) return "🚨 Flooded Soil";
    if (rainfall > 20) return "⚠️ Too Wet";
    if (rainfall > 10) return "💧 Wet";
    if (rainfall > 0) return "✅ Good Uptake";
    return "✅ Optimal Moisture";
  }

  Color _soilStatusColor(double rainfall) {
    if (rainfall > 50) return Colors.red;
    if (rainfall > 20) return Colors.orange;
    if (rainfall > 10) return Colors.blue;
    return Colors.green;
  }

  String _diseaseStatus(double maxHumidity) {
    if (maxHumidity > 85) return "🔴 High Risk";
    if (maxHumidity > 70) return "⚠️ Moderate Risk";
    return "🛡️ Low Risk";
  }

  Color _diseaseStatusColor(double maxHumidity) {
    if (maxHumidity > 85) return Colors.red;
    if (maxHumidity > 70) return Colors.orange;
    return Colors.green;
  }

  String _pestStatus(double rainfall) {
    if (rainfall > 50) return "🛡️ Very Low (Rain)";
    if (rainfall > 20) return "🛡️ Low (Rain)";
    return "⚠️ Moderate Activity";
  }

  Color _pestStatusColor(double rainfall) {
    if (rainfall > 20) return Colors.green;
    return Colors.orange;
  }

  // =============================================================================
  // BUILD WEEK DATA FROM RAW NASA POWER NUMBERS
  // =============================================================================

  List<CoffeeAgroMetrics> _buildWeekData() {
    final raw = [
      {
        'date': DateTime(2026, 5, 25),
        'avgTemp': 20.7,
        'minTemp': 15.2,
        'maxTemp': 26.2,
        'humidity': 58.6,
        'maxHumidity': 80.9,
        'rainfall': 0.01,
        'windSpeed': 0.96,
        'maxWindSpeed': 1.80
      },
      {
        'date': DateTime(2026, 5, 26),
        'avgTemp': 20.4,
        'minTemp': 14.6,
        'maxTemp': 26.2,
        'humidity': 62.1,
        'maxHumidity': 81.8,
        'rainfall': 5.70,
        'windSpeed': 0.89,
        'maxWindSpeed': 1.51
      },
      {
        'date': DateTime(2026, 5, 27),
        'avgTemp': 20.4,
        'minTemp': 14.4,
        'maxTemp': 26.1,
        'humidity': 64.7,
        'maxHumidity': 87.3,
        'rainfall': 1.20,
        'windSpeed': 0.82,
        'maxWindSpeed': 1.57
      },
      {
        'date': DateTime(2026, 5, 28),
        'avgTemp': 20.8,
        'minTemp': 15.8,
        'maxTemp': 26.1,
        'humidity': 65.9,
        'maxHumidity': 85.6,
        'rainfall': 13.63,
        'windSpeed': 0.77,
        'maxWindSpeed': 1.24
      },
      {
        'date': DateTime(2026, 5, 29),
        'avgTemp': 20.8,
        'minTemp': 14.5,
        'maxTemp': 26.5,
        'humidity': 63.8,
        'maxHumidity': 91.4,
        'rainfall': 1.26,
        'windSpeed': 0.82,
        'maxWindSpeed': 1.30
      },
      {
        'date': DateTime(2026, 5, 30),
        'avgTemp': 20.4,
        'minTemp': 16.0,
        'maxTemp': 25.9,
        'humidity': 73.4,
        'maxHumidity': 95.0,
        'rainfall': 100.63,
        'windSpeed': 0.85,
        'maxWindSpeed': 1.24
      },
      {
        'date': DateTime(2026, 5, 31),
        'avgTemp': 19.9,
        'minTemp': 15.4,
        'maxTemp': 26.0,
        'humidity': 77.0,
        'maxHumidity': 93.7,
        'rainfall': 106.39,
        'windSpeed': 0.90,
        'maxWindSpeed': 1.49
      },
    ];

    final may25Hourly = [
      HourlyBand(
          hour: 0,
          temp: 16.6,
          humidity: 71.2,
          rainfall: 0.0,
          windSpeed: 0.4,
          condition: "calm"),
      HourlyBand(
          hour: 3,
          temp: 15.2,
          humidity: 75.8,
          rainfall: 0.0,
          windSpeed: 0.2,
          condition: "calm"),
      HourlyBand(
          hour: 6,
          temp: 20.7,
          humidity: 58.2,
          rainfall: 0.0,
          windSpeed: 1.2,
          condition: "breeze"),
      HourlyBand(
          hour: 9,
          temp: 25.4,
          humidity: 40.6,
          rainfall: 0.0,
          windSpeed: 2.2,
          condition: "breeze"),
      HourlyBand(
          hour: 12,
          temp: 26.0,
          humidity: 39.1,
          rainfall: 0.0,
          windSpeed: 1.9,
          condition: "breeze"),
      HourlyBand(
          hour: 15,
          temp: 22.9,
          humidity: 65.9,
          rainfall: 0.0,
          windSpeed: 0.5,
          condition: "calm"),
      HourlyBand(
          hour: 18,
          temp: 20.2,
          humidity: 59.2,
          rainfall: 0.0,
          windSpeed: 0.5,
          condition: "calm"),
      HourlyBand(
          hour: 21,
          temp: 17.8,
          humidity: 69.7,
          rainfall: 0.0,
          windSpeed: 0.7,
          condition: "calm"),
    ];

    final may31Hourly = [
      HourlyBand(
          hour: 0,
          temp: 16.2,
          humidity: 93.7,
          rainfall: 0.2,
          windSpeed: 0.5,
          condition: "rainy"),
      HourlyBand(
          hour: 3,
          temp: 15.4,
          humidity: 91.9,
          rainfall: 0.0,
          windSpeed: 0.5,
          condition: "damp"),
      HourlyBand(
          hour: 6,
          temp: 20.4,
          humidity: 68.3,
          rainfall: 0.0,
          windSpeed: 1.0,
          condition: "cloudy"),
      HourlyBand(
          hour: 9,
          temp: 25.2,
          humidity: 52.9,
          rainfall: 5.4,
          windSpeed: 1.5,
          condition: "storm"),
      HourlyBand(
          hour: 12,
          temp: 25.8,
          humidity: 50.5,
          rainfall: 7.1,
          windSpeed: 1.9,
          condition: "storm"),
      HourlyBand(
          hour: 15,
          temp: 21.5,
          humidity: 79.0,
          rainfall: 10.3,
          windSpeed: 0.5,
          condition: "heavy_rain"),
      HourlyBand(
          hour: 18,
          temp: 18.4,
          humidity: 89.3,
          rainfall: 8.4,
          windSpeed: 0.4,
          condition: "heavy_rain"),
      HourlyBand(
          hour: 21,
          temp: 16.8,
          humidity: 91.1,
          rainfall: 0.2,
          windSpeed: 0.4,
          condition: "rainy"),
    ];

    return raw.map((r) {
      final double maxTemp = r['maxTemp'] as double;
      final double maxHumidity = r['maxHumidity'] as double;
      final double rainfall = r['rainfall'] as double;
      final double maxWind = r['maxWindSpeed'] as double;
      final double avgTemp = r['avgTemp'] as double;
      final double minTemp = r['minTemp'] as double;
      final double humidity = r['humidity'] as double;
      final double windSpeed = r['windSpeed'] as double;
      final DateTime date = r['date'] as DateTime;

      //final bool hasHourly = (date.day == 25 || date.day == 31);
      final List<HourlyBand> hourly =
          date.day == 25 ? may25Hourly : (date.day == 31 ? may31Hourly : []);

      return CoffeeAgroMetrics(
        date: date,
        avgTemp: avgTemp,
        minTemp: minTemp,
        maxTemp: maxTemp,
        humidity: humidity,
        maxHumidity: maxHumidity,
        rainfall: rainfall,
        windSpeed: windSpeed,
        maxWindSpeed: maxWind,
        soilStatus: _soilStatus(rainfall),
        soilColor: _soilStatusColor(rainfall),
        diseaseRisk: _diseaseStatus(maxHumidity),
        diseaseColor: _diseaseStatusColor(maxHumidity),
        pestRisk: _pestStatus(rainfall),
        pestColor: _pestStatusColor(rainfall),
        weatherSummary: _weatherSummary(rainfall, maxHumidity, maxTemp),
        weatherIcon: _weatherIcon(rainfall, maxHumidity),
        weatherColor: _weatherColor(rainfall, maxHumidity),
        soilActions: _soilActions(rainfall),
        diseaseActions: _diseaseActions(maxHumidity),
        pestActions: _pestActions(rainfall, maxHumidity),
        positiveInsights: _positiveInsights(
            avgTemp, minTemp, maxTemp, humidity, rainfall, maxWind),
        riskAlerts: _riskAlerts(maxTemp, maxHumidity, rainfall, maxWind),
        farmHealthScore:
            _computeHealthScore(maxTemp, maxHumidity, rainfall, maxWind),
        hourlyBands: hourly,
      );
    }).toList();
  }

  void _simulateSync() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isRealtimeSynced = true;
      _selectedDayIndex = 6;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.satellite_alt, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
                child: Text(
                    "NASA POWER Live Stream Connected!\nData refreshed: 31 May 2026 23:00 UTC")),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  CoffeeAgroMetrics get currentData => _weekData[_selectedDayIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: _isLoading
          ? _buildLoadingScreen()
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDaySelector(),
                      _buildHeroStatusCard(),
                      _buildFarmHealthScore(),
                      _buildMetricsGrid(),
                      if (_showHourlyBands &&
                          currentData.hourlyBands.isNotEmpty)
                        _buildHourlyTimeline(),
                      _buildRiskAlertsSection(),
                      _buildPositiveInsights(),
                      _buildTrendChartSection(),
                      _buildActionTabs(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _simulateSync,
        backgroundColor: _isRealtimeSynced
            ? const Color(0xFF2E7D32)
            : const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        icon: Icon(_isRealtimeSynced ? Icons.sync : Icons.satellite_alt),
        label: Text(_isRealtimeSynced ? "Live Sync ON" : "Connect Satellite"),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D4C41)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            "Fetching NASA POWER Satellite Data...",
            style: TextStyle(
                color: Colors.brown[800], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "MERRA-2 Model | 0.5° × 0.625° Resolution",
            style: TextStyle(color: Colors.brown[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF4E342E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          "CoffeeCore Satellite Advisor",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4E342E), Color(0xFF3E2723)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.coffee,
                    size: 120, color: Colors.white.withValues(alpha: 0.05)),
              ),
              Positioned(
                bottom: 60,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isRealtimeSynced
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              _isRealtimeSynced ? Colors.green : Colors.amber,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color:
                                _isRealtimeSynced ? Colors.green : Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRealtimeSynced
                                ? "LIVE SYNC ACTIVE"
                                : "STATIC PREVIEW",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isRealtimeSynced
                                  ? Colors.green[100]
                                  : Colors.amber[100],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: _showMetadataDialog,
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 7,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          final data = _weekData[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4E342E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.brown.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekDays[index].split(" ")[0],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_weeklyRainfall[index].toStringAsFixed(1)}mm",
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : (_weeklyRainfall[index] > 50
                              ? Colors.red
                              : Colors.grey[500]),
                      fontWeight: _weeklyRainfall[index] > 50
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: data.farmHealthScore > 80
                          ? Colors.green
                          : data.farmHealthScore > 60
                              ? Colors.orange
                              : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroStatusCard() {
    final data = currentData;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.farmHealthScore > 80
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : data.farmHealthScore > 60
                  ? [const Color(0xFFF57F17), const Color(0xFFEF6C00)]
                  : [const Color(0xFFC62828), const Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: data.farmHealthScore > 80
                ? Colors.green.withValues(alpha: 0.3)
                : data.farmHealthScore > 60
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(data.weatherIcon, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.weatherSummary,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${data.date.day} May 2026 | Nandi Hills, Kenya",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  "Last satellite update: 23:00 UTC | Next: 00:00 UTC",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmHealthScore() {
    final score = currentData.farmHealthScore;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    score > 80
                        ? Colors.green
                        : score > 60
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                Center(
                  child: Text(
                    "$score",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: score > 80
                          ? Colors.green[800]
                          : score > 60
                              ? Colors.orange[800]
                              : Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Farm Health Score",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.brown[900]),
                ),
                const SizedBox(height: 4),
                Text(
                  score > 80
                      ? "✅ Conditions are excellent for coffee growth. Continue current practices."
                      : score > 60
                          ? "⚠️ Some risk factors present. Review action items below."
                          : "🚨 Critical conditions detected. Immediate farmer intervention required.",
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // COMPACT METRIC CARDS — tight padding, no wasted space, content-wrapped
  // =============================================================================

  Widget _buildMetricsGrid() {
    final data = currentData;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      childAspectRatio: 1.55,
      children: [
        _buildMetricCard(
          label: "🌡️ Air Temp",
          value: "${data.avgTemp.toStringAsFixed(1)}°C",
          range:
              "${data.minTemp.toStringAsFixed(1)}° — ${data.maxTemp.toStringAsFixed(1)}°",
          icon: Icons.thermostat,
          iconColor: _tempColor(data.maxTemp),
          tag: _tempLabel(data.maxTemp),
          tagColor: _tempColor(data.maxTemp),
        ),
        _buildMetricCard(
          label: "💧 Humidity",
          value: "${data.humidity.toStringAsFixed(1)}%",
          range: "Peak: ${data.maxHumidity.toStringAsFixed(1)}%",
          icon: Icons.water_drop,
          iconColor: _humidityColor(data.maxHumidity),
          tag: _humidityLabel(data.humidity, data.maxHumidity),
          tagColor: _humidityColor(data.maxHumidity),
        ),
        _buildMetricCard(
          label: "🌧️ Rainfall",
          value: "${data.rainfall.toStringAsFixed(1)} mm",
          range: data.rainfall > 0 ? "Total today" : "No rain",
          icon: Icons.umbrella,
          iconColor: _rainfallColor(data.rainfall),
          tag: _rainfallLabel(data.rainfall),
          tagColor: _rainfallColor(data.rainfall),
        ),
        _buildMetricCard(
          label: "🌬️ Wind",
          value: "${data.windSpeed.toStringAsFixed(1)} m/s",
          range: "Gusts: ${data.maxWindSpeed.toStringAsFixed(1)} m/s",
          icon: Icons.air,
          iconColor: _windColor(data.maxWindSpeed),
          tag: _windLabel(data.maxWindSpeed),
          tagColor: _windColor(data.maxWindSpeed),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String range,
    required IconData icon,
    required Color iconColor,
    required String tag,
    required Color tagColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            range,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyTimeline() {
    final bands = currentData.hourlyBands;
    if (bands.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "⏰ 24-Hour Weather Bands",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _showHourlyBands = !_showHourlyBands),
                child: Text(_showHourlyBands ? "Hide" : "Show",
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: bands.length,
              itemBuilder: (context, index) {
                final band = bands[index];
                return Container(
                  width: 68,
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "${band.temp.toStringAsFixed(0)}°",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: band.temp > 28
                                    ? Colors.red
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: (band.temp - 10).clamp(4, 60).toDouble(),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: band.temp > 28
                                      ? [Colors.red[300]!, Colors.red[600]!]
                                      : band.temp > 24
                                          ? [
                                              Colors.orange[300]!,
                                              Colors.orange[600]!
                                            ]
                                          : [
                                              Colors.blue[300]!,
                                              Colors.blue[600]!
                                            ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: band.rainfall > 5
                              ? Colors.red[50]
                              : band.rainfall > 0
                                  ? Colors.blue[50]
                                  : Colors.grey[50],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: band.rainfall > 5
                              ? Text("🌧️",
                                  style: const TextStyle(fontSize: 11))
                              : band.rainfall > 0
                                  ? Text("💧",
                                      style: const TextStyle(fontSize: 11))
                                  : Text("☀️",
                                      style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (band.humidity / 100).clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: band.humidity > 85
                                  ? Colors.red
                                  : band.humidity > 70
                                      ? Colors.orange
                                      : Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${band.hour.toString().padLeft(2, '0')}:00",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(Colors.green, "<70% RH"),
              const SizedBox(width: 12),
              _buildLegendDot(Colors.orange, "70-85%"),
              const SizedBox(width: 12),
              _buildLegendDot(Colors.red, ">85% Risk"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRiskAlertsSection() {
    final alerts = currentData.riskAlerts;
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "Risk Alerts (${alerts.length})",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red[800]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("•",
                        style: TextStyle(
                            color: Colors.red[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert,
                        style: TextStyle(
                            fontSize: 13, color: Colors.red[900], height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPositiveInsights() {
    final insights = currentData.positiveInsights;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "Positive Conditions (${insights.length})",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green[800]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("✓",
                        style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[900],
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 7-Day Rainfall Trend (mm)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_weeklyRainfall.length, (index) {
                double val = _weeklyRainfall[index];
                double maxVal = _weeklyRainfall.reduce((a, b) => a > b ? a : b);
                double pct = maxVal > 0 ? (val / maxVal) : 0;
                bool isSelected = index == _selectedDayIndex;
                bool isCritical = val > 50;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          val > 10 ? val.toStringAsFixed(0) : val.toString(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.red : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 70 * pct,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCritical
                                  ? [Colors.red[300]!, Colors.red[600]!]
                                  : isSelected
                                      ? [Colors.brown[300]!, Colors.brown[600]!]
                                      : [Colors.blue[200]!, Colors.blue[400]!],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                            border: isSelected
                                ? Border.all(
                                    color: Colors.brown[800]!, width: 2)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weekDays[index].split(" ")[0],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.brown[800]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Tap a bar to view detailed farm insights for that day",
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // ENRICHED TABBED ACTION SECTION
  // =============================================================================

  Widget _buildActionTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4E342E),
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: const Color(0xFF4E342E),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.grass), text: "Soil"),
              Tab(icon: Icon(Icons.coronavirus_outlined), text: "Disease"),
              Tab(icon: Icon(Icons.bug_report_outlined), text: "Pests"),
            ],
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSoilTab(),
                _buildDiseaseTab(),
                _buildPestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilTab() {
    final data = currentData;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTabHeader(
          icon: Icons.grass,
          status: data.soilStatus,
          color: data.soilColor,
          description: data.rainfall > 50
              ? "Soil is flooded. Roots may suffocate and all fertilizer will wash away."
              : data.rainfall > 20
                  ? "Soil is very wet. Avoid adding fertilizer and check drainage."
                  : data.rainfall > 10
                      ? "Soil has good moisture. Check that mulch is still in place."
                      : "Soil moisture is good for farm work and adding manure.",
        ),
        const SizedBox(height: 12),
        const Text(
          "What to do today:",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ...data.soilActions.map((action) => _buildCheckItem(action)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.brown[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.brown[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tip: Coffee roots need air. If soil stays flooded for more than 2 days, tree health drops fast.",
                  style: TextStyle(
                      fontSize: 11, color: Colors.brown[700], height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseTab() {
    final data = currentData;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTabHeader(
          icon: Icons.coronavirus_outlined,
          status: data.diseaseRisk,
          color: data.diseaseColor,
          description: data.maxHumidity > 85
              ? "Very high humidity lets Coffee Leaf Rust and Coffee Berry Disease spread quickly."
              : data.maxHumidity > 70
                  ? "Humidity is high enough for fungus to grow. Scout trees more often."
                  : "Humidity is low. Fungal spores find it hard to grow today.",
        ),
        const SizedBox(height: 12),
        const Text(
          "Disease prevention tasks:",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ...data.diseaseActions.map((action) => _buildCheckItem(action)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 16, color: Colors.orange[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tip: Rust shows first as small orange spots under leaves. Catch it early and spray within 48 hours.",
                  style: TextStyle(
                      fontSize: 11, color: Colors.orange[900], height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPestTab() {
    final data = currentData;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTabHeader(
          icon: Icons.bug_report_outlined,
          status: data.pestRisk,
          color: data.pestColor,
          description: data.rainfall > 50
              ? "Heavy rain has washed most pests away. Focus workers on other urgent tasks."
              : data.rainfall > 20
                  ? "Rain has reduced pest numbers. Hold off chemical sprays and check traps later."
                  : "Pests are active. Check trees for Coffee Berry Borer and leaf-eating insects.",
        ),
        const SizedBox(height: 12),
        const Text(
          "Pest control tasks:",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ...data.pestActions.map((action) => _buildCheckItem(action)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.green[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tip: Pheromone traps catch male borers before they mate. One trap per 50 trees is enough.",
                  style: TextStyle(
                      fontSize: 11, color: Colors.green[900], height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabHeader({
    required IconData icon,
    required String status,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style:
                TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _completedTasks[action] ?? false,
              activeColor: const Color(0xFF4E342E),
              onChanged: (bool? value) {
                setState(() {
                  _completedTasks[action] = value ?? false;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.35,
                decoration: (_completedTasks[action] ?? false)
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMetadataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.satellite_alt, color: Color(0xFF4E342E)),
            SizedBox(width: 10),
            Text("Satellite Engine",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "🛰️ Data Source: NASA POWER Native Hourly (MERRA-2)\n"
          "📍 Location: 0.5685°N, 35.6643°E (Nandi/Eldoret, Kenya)\n"
          "📐 Resolution: 0.5° × 0.625° grid\n"
          "⛰️ Elevation: 1,842m above sea level\n\n"
          "Farming thresholds used:\n"
          "• Temp above 28°C = Heat stress risk\n"
          "• Humidity above 70% = Fungal disease risk\n"
          "• Humidity above 85% = Coffee Leaf Rust warning\n"
          "• Rain above 50mm/day = Flooding and nutrient loss\n"
          "• Wind above 3 m/s = Branch damage risk\n\n"
          "This system turns complex satellite weather data into simple, useful advice for farmers.",
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understood",
                style: TextStyle(
                    color: Color(0xFF4E342E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
