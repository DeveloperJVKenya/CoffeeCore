import 'package:flutter/material.dart';
import 'package:coffeecore/models/agripoints.dart';
import 'package:coffeecore/models/farmer_compliance_score.dart';
import 'package:coffeecore/services/farmer_compliance_service.dart';

/// A farmer's own IPM (Integrated Pest, Disease & Fertilizer Management)
/// standing — never compared against other farmers by name here (that would
/// need a published leaderboard computed server-side, which is a later,
/// separate piece of infrastructure). Headlined by AgriPoints + award level
/// (gamified, gives farmers something to build toward); the underlying
/// percentage breakdown stays below as the "how this is calculated" detail.
/// Never punitive — missed follow-ups simply earn no points, never a penalty.
class FarmerComplianceScreen extends StatefulWidget {
  const FarmerComplianceScreen({super.key});

  @override
  State<FarmerComplianceScreen> createState() => _FarmerComplianceScreenState();
}

class _FarmerComplianceScreenState extends State<FarmerComplianceScreen> {
  static const Color _brand = Color(0xFF6F4E37);

  late Future<(AgriPointsSummary, FarmerComplianceScore)> _dataFuture =
      _loadData();

  Future<(AgriPointsSummary, FarmerComplianceScore)> _loadData() async {
    final results = await Future.wait([
      FarmerComplianceService.computeAgriPointsForCurrentUser(),
      FarmerComplianceService.computeForCurrentUser(),
    ]);
    return (
      results[0] as AgriPointsSummary,
      results[1] as FarmerComplianceScore,
    );
  }

  Future<void> _refresh() async {
    setState(() => _dataFuture = _loadData());
    await _dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My IPM Score',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<(AgriPointsSummary, FarmerComplianceScore)>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final (points, score) = snapshot.data!;
            if (!score.hasEnoughData && points.total == 0) {
              return _buildEmptyState();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AgriPointsHeader(points: points),
                const SizedBox(height: 16),
                _AwardStrip(currentLevel: points.level),
                const SizedBox(height: 20),
                if (score.hasEnoughData) ...[
                  const Text('How this is calculated',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  _ComponentRow(
                    label: 'Uses suggested methods',
                    description:
                        'Interventions logged with a clear category (chemical, '
                        'mechanical or biological) rather than left uncategorized',
                    value: score.categorizationRate,
                    color: const Color(0xFFB0763F),
                  ),
                  _ComponentRow(
                    label: 'Follow-up check-ins completed',
                    description:
                        'Of the check-ins the system scheduled a week after an '
                        'intervention, how many you actually completed',
                    value: score.followUpCompletionRate,
                    color: const Color(0xFF5B7FA6),
                  ),
                  _ComponentRow(
                    label: 'Average effectiveness reported',
                    description:
                        'Average outcome from your completed check-ins '
                        '(fully recovered → spread further)',
                    value: score.averageEffectiveness,
                    color: const Color(0xFF5B8A4A),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${score.totalInterventions} interventions logged · '
                    '${score.completedCheckIns} check-ins completed',
                    style: TextStyle(fontSize: 11.5, color: Colors.brown[300]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_outlined, size: 56, color: Colors.brown[200]),
                  const SizedBox(height: 16),
                  const Text(
                    'Log your first pest or disease intervention — or track a '
                    'fertilization plan — to start earning AgriPoints.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgriPointsHeader extends StatelessWidget {
  final AgriPointsSummary points;

  const _AgriPointsHeader({required this.points});

  Color get _color {
    switch (points.level) {
      case AwardLevel.sprout:
        return Colors.blueGrey;
      case AwardLevel.grower:
        return const Color(0xFF5B8A4A);
      case AwardLevel.cultivator:
        return const Color(0xFFB0763F);
      case AwardLevel.harvestMaster:
        return const Color(0xFF5B7FA6);
      case AwardLevel.ipmChampion:
        return const Color(0xFFC9962C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = points.level.next;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color, _color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(points.level.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('${points.total}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800)),
          const Text('AgriPoints',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Text(points.level.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          if (next != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: points.progressToNextLevel,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${points.pointsToNextLevel} points to ${next.label} ${next.emoji}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Top level reached — outstanding consistency!',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}

class _AwardStrip extends StatelessWidget {
  final AwardLevel currentLevel;

  const _AwardStrip({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    final currentIndex = AwardLevel.values.indexOf(currentLevel);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final level in AwardLevel.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _AwardBadge(
                level: level,
                achieved: AwardLevel.values.indexOf(level) <= currentIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _AwardBadge extends StatelessWidget {
  final AwardLevel level;
  final bool achieved;

  const _AwardBadge({required this.level, required this.achieved});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: achieved ? 1.0 : 0.35,
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: achieved ? const Color(0xFFB0763F) : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(level.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(level.label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            Text('${level.minPoints}+',
                style: const TextStyle(fontSize: 9, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final String label;
  final String description;
  final double? value;
  final Color color;

  const _ComponentRow({
    required this.label,
    required this.description,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(
                value == null
                    ? 'Not enough data'
                    : '${value!.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: value == null ? Colors.grey : color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          if (value != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value! / 100).clamp(0, 1),
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
