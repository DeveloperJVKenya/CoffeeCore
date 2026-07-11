import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Horizontal 5-day forecast strip. Each entry in [days] is the map shape
/// returned by `ClimateSatelliteService.fetchFiveDayForecast`
/// (`date`, `temp`, `humidity`, `description`, `icon`).
class ForecastStrip extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const ForecastStrip({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: FarmTheme.spaceSm),
        itemBuilder: (context, index) {
          final day = days[index];
          final DateTime date = day['date'] as DateTime;
          final double temp = (day['temp'] as num).toDouble();
          final String description = day['description'] as String? ?? '';
          return Container(
            width: 84,
            padding: const EdgeInsets.all(FarmTheme.spaceSm),
            decoration:
                FarmTheme.cardDecoration(color: FarmTheme.cardBackground),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_weekday(date.weekday),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: FarmTheme.spaceXs),
                Text('${temp.toStringAsFixed(0)}°C',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: FarmTheme.spaceXs),
                Text(
                  description,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _weekday(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
