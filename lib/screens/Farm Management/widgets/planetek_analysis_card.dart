import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/planetek_analysis_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Displays a [PlanetekAnalysisData] verdict — Planetek's signed, certified
/// EUDR deforestation analysis. Sibling to [EudrCard] (GFW screening), not
/// a replacement; both can be shown for the same farm.
class PlanetekAnalysisCard extends StatelessWidget {
  final PlanetekAnalysisData data;
  final VoidCallback? onRefresh;

  const PlanetekAnalysisCard({super.key, required this.data, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final bool certified = data.deforestationCertified ?? false;
    final Color statusColor =
        certified ? FarmTheme.accentGood : FarmTheme.accentBad;

    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                certified ? Icons.verified : Icons.warning_amber_rounded,
                color: statusColor,
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Expanded(
                child: Text(
                  certified
                      ? 'Certified Deforestation-Free'
                      : 'Certified Deforestation Risk',
                  style: FarmTheme.cardTitle.copyWith(color: statusColor),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Row(
            children: [
              Icon(
                data.signatureVerified
                    ? Icons.verified_user
                    : Icons.gpp_maybe_outlined,
                size: 16,
                color: data.signatureVerified
                    ? FarmTheme.accentGood
                    : Colors.orange,
              ),
              const SizedBox(width: FarmTheme.spaceXs),
              Expanded(
                child: Text(
                  data.signatureVerified
                      ? 'Signature verified — result is authentic'
                      : data.signatureNote,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: data.signatureVerified
                        ? Colors.black54
                        : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          if (data.forestArea2020Ha != null)
            Text(
              'Forest area (2020 baseline): ${data.forestArea2020Ha!.toStringAsFixed(2)} ha',
              style: const TextStyle(fontSize: 13),
            ),
          if (data.deforestedAreaHa != null && data.deforestedAreaHa! > 0.01)
            Text(
              'Deforested area: ${data.deforestedAreaHa!.toStringAsFixed(2)} ha '
              '(${data.deforestedPercentage?.toStringAsFixed(2) ?? '?'}%)',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: FarmTheme.spaceXs),
          Text(
            'Source: KSA Certified Deforestation Analysis'
            '${data.algorithmVersion != null ? ' v${data.algorithmVersion}' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
