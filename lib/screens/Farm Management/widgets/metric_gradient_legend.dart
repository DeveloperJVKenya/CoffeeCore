import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

enum MapMetric { ndvi, ndwi }

/// A gradient legend bar for NDVI/NDWI, built from the same stop/color
/// lists [FarmTheme.colorForNdvi]/[colorForNdwi] use, so the ramp shown here
/// can never drift from the colors actually painted on the map. Optionally
/// marks the current value's position on the bar and shows a short
/// reference blurb citing the color convention's source.
class MetricGradientLegend extends StatelessWidget {
  final MapMetric metric;
  final double? currentValue;

  const MetricGradientLegend({
    super.key,
    required this.metric,
    this.currentValue,
  });

  List<double> get _stops =>
      metric == MapMetric.ndvi ? FarmTheme.ndviStops : FarmTheme.ndwiStops;
  List<Color> get _colors =>
      metric == MapMetric.ndvi ? FarmTheme.ndviColors : FarmTheme.ndwiColors;

  String get _title => metric == MapMetric.ndvi
      ? 'NDVI — Vegetation Index'
      : 'NDWI — Moisture Index';

  String get _description => metric == MapMetric.ndvi
      ? 'NDVI (Normalized Difference Vegetation Index) ranges from -1 to 1. '
          'Values above 0.5 indicate dense, healthy vegetation; below 0.2 '
          'indicates sparse cover or stressed crops (EOS/USGS/Sentinel-2 '
          'convention).'
      : 'NDWI (McFeeters, 1996) highlights canopy and surface moisture using '
          'Sentinel-2 Green/NIR bands (B03/B08). Higher (blue) values '
          'indicate more moisture; negative (brown) values indicate dry '
          'conditions.';

  @override
  Widget build(BuildContext context) {
    final double min = _stops.first;
    final double max = _stops.last;
    final double? clampedValue = currentValue?.clamp(min, max);

    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title, style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          LayoutBuilder(builder: (context, constraints) {
            final double width = constraints.maxWidth;
            return SizedBox(
              height: 28,
              child: Stack(
                children: [
                  Container(
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: LinearGradient(
                        colors: _colors,
                        stops:
                            _stops.map((s) => (s - min) / (max - min)).toList(),
                      ),
                    ),
                  ),
                  if (clampedValue != null)
                    Positioned(
                      left: (width * (clampedValue - min) / (max - min) - 6)
                          .clamp(0, width - 12),
                      top: 0,
                      child: const Icon(Icons.arrow_drop_down,
                          size: 22, color: Colors.black87),
                    ),
                ],
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _stops
                .where((s) => s == min || s == max || s == 0.0)
                .map((s) =>
                    Text(s.toStringAsFixed(1), style: FarmTheme.statLabel))
                .toList(),
          ),
          if (currentValue != null) ...[
            const SizedBox(height: FarmTheme.spaceXs),
            Text(
              'Current value: ${currentValue!.toStringAsFixed(3)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: FarmTheme.spaceSm),
          Text(_description, style: FarmTheme.statLabel),
        ],
      ),
    );
  }
}
