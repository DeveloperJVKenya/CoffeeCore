import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/models/agripoints.dart';
import 'package:coffeecore/models/follow_up_outcome.dart';
import 'package:coffeecore/screens/admin/pest_disease_trends_screen.dart';
import 'package:coffeecore/services/farmer_compliance_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';

/// Cooperative-wide at-a-glance dashboard for Coop Admins — replaces the
/// old "Combined Data" placeholder. Pulls the same intervention data the
/// Pest & Disease Trends screen uses, scoped to this one cooperative, and
/// surfaces it as headline stats rather than requiring the admin to open
/// Trends and pick through tabs just to answer "how are we doing overall".
class CoopOverviewScreen extends StatefulWidget {
  final String cooperativeName;

  const CoopOverviewScreen({required this.cooperativeName, super.key});

  @override
  State<CoopOverviewScreen> createState() => _CoopOverviewScreenState();
}

class _CoopOverviewStats {
  final int farmerCount;
  final int pestInterventionCount;
  final int diseaseInterventionCount;
  final String? topPest;
  final String? topDisease;
  final double? avgEffectiveness;
  final int scoredCheckIns;
  final List<_FarmerRanking> ranking;

  const _CoopOverviewStats({
    required this.farmerCount,
    required this.pestInterventionCount,
    required this.diseaseInterventionCount,
    required this.topPest,
    required this.topDisease,
    required this.avgEffectiveness,
    required this.scoredCheckIns,
    required this.ranking,
  });
}

class _FarmerRanking {
  final String userId;
  final String name;
  final AgriPointsSummary points;

  const _FarmerRanking(
      {required this.userId, required this.name, required this.points});
}

class _CoopOverviewScreenState extends State<CoopOverviewScreen> {
  static const Color _brand = Color(0xFF6F4E37);
  static const Color _leafGreen = Color(0xFF5B8A4A);

  late Future<_CoopOverviewStats> _statsFuture = _loadStats();

  Future<void> _refresh() async {
    setState(() => _statsFuture = _loadStats());
    await _statsFuture;
  }

  Future<_CoopOverviewStats> _loadStats() async {
    final db = FirebaseFirestore.instance;
    final formattedCoop = sanitizeCoopId(widget.cooperativeName);

    final usersSnap = await db.collection('${formattedCoop}_users').get();
    final userIds = usersSnap.docs.map((d) => d.id).toList();

    if (userIds.isEmpty) {
      return const _CoopOverviewStats(
        farmerCount: 0,
        pestInterventionCount: 0,
        diseaseInterventionCount: 0,
        topPest: null,
        topDisease: null,
        avgEffectiveness: null,
        scoredCheckIns: 0,
        ranking: [],
      );
    }

    final namesByUid = <String, String>{
      for (final d in usersSnap.docs)
        d.id: (d.data()['fullName'] as String?)?.trim().isNotEmpty == true
            ? d.data()['fullName'] as String
            : 'Unnamed farmer',
    };

    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      batches.add(userIds.sublist(
          i, i + batchSize > userIds.length ? userIds.length : i + batchSize));
    }

    final pestDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final diseaseDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final fertilizationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final batch in batches) {
      final results = await Future.wait([
        db
            .collection('coffee_pest_interventions')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
        db
            .collection('coffee_disease_interventions')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
        db
            .collection('fertilization_weeks')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
      ]);
      pestDocs.addAll(results[0].docs);
      diseaseDocs.addAll(results[1].docs);
      fertilizationDocs.addAll(results[2].docs);
    }

    String? topName(
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String field) {
      final counts = <String, int>{};
      for (final doc in docs) {
        final name = doc.data()[field] as String?;
        if (name == null || name.trim().isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    final scores = <int>[];
    for (final doc in [...pestDocs, ...diseaseDocs]) {
      final data = doc.data();
      if (data['followUpCompleted'] == true) {
        final outcome =
            FollowUpOutcome.fromName(data['followUpOutcome'] as String?);
        if (outcome != null) scores.add(outcome.score);
      }
    }
    for (final doc in fertilizationDocs) {
      final data = doc.data();
      if (data['completed'] == true) {
        final outcome = FollowUpOutcome.fromName(data['outcome'] as String?);
        if (outcome != null) scores.add(outcome.score);
      }
    }
    final avgEffectiveness = scores.isEmpty
        ? null
        : scores.fold<int>(0, (t, s) => t + s) / scores.length;

    final pointsByUser =
        await FarmerComplianceService.computeAgriPointsForUsers(userIds);
    final ranking = userIds
        .map((uid) => _FarmerRanking(
              userId: uid,
              name: namesByUid[uid] ?? 'Unnamed farmer',
              points: pointsByUser[uid]!,
            ))
        .toList()
      ..sort((a, b) => b.points.total.compareTo(a.points.total));

    return _CoopOverviewStats(
      farmerCount: userIds.length,
      pestInterventionCount: pestDocs.length,
      diseaseInterventionCount: diseaseDocs.length,
      topPest: topName(pestDocs, 'pestName'),
      topDisease: topName(diseaseDocs, 'diseaseName'),
      avgEffectiveness: avgEffectiveness,
      scoredCheckIns: scores.length,
      ranking: ranking,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cooperativeName} Overview',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_CoopOverviewStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatTile(
                      label: 'Registered Farmers',
                      value: '${stats.farmerCount}',
                      icon: Icons.groups_rounded,
                      color: _brand,
                    ),
                    _StatTile(
                      label: 'Interventions Logged',
                      value:
                          '${stats.pestInterventionCount + stats.diseaseInterventionCount}',
                      icon: Icons.edit_note_rounded,
                      color: _leafGreen,
                    ),
                    _StatTile(
                      label: 'Most Common Pest',
                      value: stats.topPest ?? 'No data yet',
                      icon: Icons.bug_report_rounded,
                      color: const Color(0xFFB0763F),
                      isTextValue: true,
                    ),
                    _StatTile(
                      label: 'Most Common Disease',
                      value: stats.topDisease ?? 'No data yet',
                      icon: Icons.coronavirus_rounded,
                      color: const Color(0xFF5B7FA6),
                      isTextValue: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8DDD4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommendation Effectiveness',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (stats.avgEffectiveness == null)
                        const Text(
                          'No completed follow-up check-ins yet from this '
                          "cooperative's farmers.",
                          style:
                              TextStyle(fontSize: 12.5, color: Colors.black54),
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(stats.avgEffectiveness!.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: _leafGreen)),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6, left: 4),
                              child: Text('/ 100 avg. across '
                                  'recommendations applied'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on ${stats.scoredCheckIns} completed '
                          'farmer check-ins',
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FarmerRankingCard(ranking: stats.ranking),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PestDiseaseTrendsScreen()),
                  ),
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text('Open full Pest & Disease Trends'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Surfaces individual farmer consistency (AgriPoints/award level) to the
/// Coop Admin — the counterpart to the farmer-facing "My IPM Score" screen
/// (lib/screens/farmer_compliance_screen.dart). Ranked so cooperatives can
/// see who is following through on system-suggested interventions and
/// scheduled follow-ups, not just aggregate method effectiveness.
class _FarmerRankingCard extends StatelessWidget {
  final List<_FarmerRanking> ranking;

  const _FarmerRankingCard({required this.ranking});

  static const Color _brand = Color(0xFF6F4E37);

  @override
  Widget build(BuildContext context) {
    final active = ranking.where((r) => r.points.total > 0).toList();
    final shown = active.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Farmer Consistency Ranking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Ranked by AgriPoints — on-time follow-ups and use of '
            'system-suggested methods.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text(
              "No farmer in this cooperative has earned AgriPoints yet — "
              'nothing logged has a completed follow-up or fertilization '
              'week yet.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            )
          else
            for (var i = 0; i < shown.length; i++)
              _FarmerRankRow(rank: i + 1, entry: shown[i]),
          if (active.length > shown.length) ...[
            const SizedBox(height: 6),
            Text(
              '+${active.length - shown.length} more farmer'
              '${active.length - shown.length == 1 ? '' : 's'} with '
              'AgriPoints',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
          if (ranking.length > active.length) ...[
            const SizedBox(height: 4),
            Text(
              '${ranking.length - active.length} farmer'
              '${ranking.length - active.length == 1 ? '' : 's'} in this '
              "cooperative haven't started logging yet",
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ],
      ),
    );
  }
}

class _FarmerRankRow extends StatelessWidget {
  final int rank;
  final _FarmerRanking entry;

  const _FarmerRankRow({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45)),
          ),
          Text(entry.points.level.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(entry.name,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text('${entry.points.total} pts',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _FarmerRankingCard._brand)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isTextValue;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isTextValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            value,
            maxLines: isTextValue ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: isTextValue ? 15 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3E2723)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
