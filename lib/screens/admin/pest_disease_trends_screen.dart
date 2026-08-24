import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/models/follow_up_outcome.dart';
import 'package:coffeecore/models/intervention_category.dart';
import 'package:coffeecore/screens/diseases/disease_firestore_service.dart';
import 'package:coffeecore/screens/pests/pest_firestore_service.dart';
import 'package:logger/logger.dart';

Color categoryColor(InterventionCategory category) {
  switch (category) {
    case InterventionCategory.chemical:
      return const Color(0xFFB0763F);
    case InterventionCategory.mechanical:
      return const Color(0xFF5B7FA6);
    case InterventionCategory.biological:
      return const Color(0xFF5B8A4A);
    case InterventionCategory.other:
      return Colors.grey.shade600;
  }
}

final Logger _logger = Logger(printer: PrettyPrinter());

// ─────────────────────────────────────────────────────────────────────────────
// PEST & DISEASE TRENDS SCREEN
//
// One screen shared by Main Admin and Coop Admin. Diagnoses live in
// per-user sub-collections (pest_diagnoses/{userId}/diagnoses), so seeing
// "every diagnosis visible to me" means first resolving WHICH user IDs are
// visible (every user for a Main Admin, only the cooperative's users for a
// Coop Admin — both reads are already permitted by existing rules on
// Users / {coop}_users), then reading each of those known, specific
// sub-collection paths directly. This deliberately avoids a
// collectionGroup('diagnoses') scan — Firestore's security-rule evaluation
// for collectionGroup queries requires the rule to be provable for the
// query as a whole and does not reliably honour a plain isAdmin()-style
// rule the way a query against a single, known parent path does.
// ─────────────────────────────────────────────────────────────────────────────

class PestDiseaseTrendsScreen extends StatefulWidget {
  const PestDiseaseTrendsScreen({super.key});

  @override
  State<PestDiseaseTrendsScreen> createState() =>
      _PestDiseaseTrendsScreenState();
}

class _PestDiseaseTrendsScreenState extends State<PestDiseaseTrendsScreen> {
  static const Color _darkBrown = Color(0xFF3E2723);

  late final Future<List<String>> _visibleUserIdsFuture =
      _resolveVisibleUserIds();

  /// Main Admin → every user's UID (Users collection).
  /// Coop Admin → only their cooperative's users ({coop}_users collection).
  /// Anyone else → empty list.
  Future<List<String>> _resolveVisibleUserIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final db = FirebaseFirestore.instance;

    final adminDoc = await db.collection('Admins').doc(uid).get();
    if (adminDoc.exists) {
      _logger.i('Resolving trend scope: Main Admin — every user');
      final usersSnap = await db.collection('Users').get();
      return usersSnap.docs.map((d) => d.id).toList();
    }

    final coopAdminDoc = await db.collection('CoopAdmins').doc(uid).get();
    if (coopAdminDoc.exists) {
      final cooperative = coopAdminDoc.data()?['cooperative'] as String?;
      if (cooperative == null || cooperative.isEmpty) return [];
      _logger.i('Resolving trend scope: Coop Admin — cooperative '
          '"$cooperative"');
      final usersSnap = await db.collection('${cooperative}_users').get();
      return usersSnap.docs.map((d) => d.id).toList();
    }

    _logger.w('Resolving trend scope — caller is neither Main Admin nor '
        'Coop Admin, returning empty scope.');
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pest & Disease Trends',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: _darkBrown,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                  text: 'Prevalent Pests',
                  icon: Icon(Icons.bug_report_rounded)),
              Tab(
                  text: 'Prevalent Diseases',
                  icon: Icon(Icons.coronavirus_rounded)),
              Tab(text: 'Common Methods', icon: Icon(Icons.healing_rounded)),
              Tab(text: 'Effectiveness', icon: Icon(Icons.insights_rounded)),
            ],
          ),
        ),
        body: FutureBuilder<List<String>>(
          future: _visibleUserIdsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _logger.e('Error resolving visible user scope',
                  error: snapshot.error);
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final userIds = snapshot.data ?? [];
            return TabBarView(
              children: [
                _PrevalentPestsTab(userIds: userIds),
                _PrevalentDiseasesTab(userIds: userIds),
                const _CommonMethodsTab(),
                const _EffectivenessTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared aggregation + chart rendering
// ─────────────────────────────────────────────────────────────────────────────

/// Counts occurrences of [key] across [items] and returns the top [limit]
/// entries, sorted by count descending. Blank keys are skipped.
List<MapEntry<String, int>> _topCounts<T>(
  List<T> items,
  String Function(T) key, {
  int limit = 8,
}) {
  final counts = <String, int>{};
  final displayText = <String, String>{};
  for (final item in items) {
    final raw = key(item).trim();
    if (raw.isEmpty) continue;
    final bucket = raw.toLowerCase();
    counts[bucket] = (counts[bucket] ?? 0) + 1;
    displayText.putIfAbsent(bucket, () => raw);
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted
      .take(limit)
      .map((e) => MapEntry(displayText[e.key] ?? e.key, e.value))
      .toList();
}

class _TrendCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> data;
  final Color barColor;

  const _TrendCard({
    required this.title,
    required this.data,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No data recorded yet.')),
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data.first.value + 1).toDouble(),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 64,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= data.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  data[index].key,
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      for (var i = 0; i < data.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: data[i].value.toDouble(),
                            color: barColor,
                            width: 18,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Prevalent Pests
// ─────────────────────────────────────────────────────────────────────────────

class _PrevalentPestsTab extends StatelessWidget {
  final List<String> userIds;

  const _PrevalentPestsTab({required this.userIds});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PestDiagnosisRecord>>(
      future: PestFirestoreService.diagnosesForUsers(userIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error fetching pest diagnoses', error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final diagnoses = snapshot.data ?? [];
        final topPests = _topCounts(diagnoses, (d) => d.pestName);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TrendCard(
              title:
                  'Most Diagnosed Pests (${diagnoses.length} diagnoses total)',
              data: topPests,
              barColor: const Color(0xFF6F4E37),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Prevalent Diseases
// ─────────────────────────────────────────────────────────────────────────────

class _PrevalentDiseasesTab extends StatelessWidget {
  final List<String> userIds;

  const _PrevalentDiseasesTab({required this.userIds});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DiseaseDiagnosisRecord>>(
      future: DiseaseFirestoreService.diagnosesForUsers(userIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error fetching disease diagnoses', error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final diagnoses = snapshot.data ?? [];
        final topDiseases = _topCounts(diagnoses, (d) => d.diseaseName);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TrendCard(
              title:
                  'Most Diagnosed Diseases (${diagnoses.length} diagnoses total)',
              data: topDiseases,
              barColor: const Color(0xFF5B8A4A),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — Common Applied Methods
//
// Redesigned as a segmented pest/disease switch over a single animated,
// ranked horizontal-bar list. Horizontal bars (not a vertical fl_chart with
// rotated labels) because intervention text is free-form and often long —
// "Copper oxychloride spray on affected leaves" reads fine on a left-aligned
// row but collides badly as a rotated axis tick.
// ─────────────────────────────────────────────────────────────────────────────

class _CommonMethodsTab extends StatefulWidget {
  const _CommonMethodsTab();

  @override
  State<_CommonMethodsTab> createState() => _CommonMethodsTabState();
}

class _MethodRecord {
  final String name;
  final String text;
  final InterventionCategory category;

  const _MethodRecord(
      {required this.name, required this.text, required this.category});
}

class _CommonMethodsTabState extends State<_CommonMethodsTab> {
  static const Color _pestColor = Color(0xFF6F4E37);
  static const Color _diseaseColor = Color(0xFF5B8A4A);

  int _segment = 0; // 0 = pests, 1 = diseases
  String? _selectedPestName;
  String? _selectedDiseaseName;

  String? get _selectedName =>
      _segment == 0 ? _selectedPestName : _selectedDiseaseName;

  set _selectedName(String? value) {
    if (_segment == 0) {
      _selectedPestName = value;
    } else {
      _selectedDiseaseName = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPest = _segment == 0;
    final accent = isPest ? _pestColor : _diseaseColor;
    final nameField = isPest ? 'pestName' : 'diseaseName';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _SegmentToggle(
            value: _segment,
            colorFor: (i) => i == 0 ? _pestColor : _diseaseColor,
            labels: const ['Pest Methods', 'Disease Methods'],
            icons: const [Icons.bug_report_rounded, Icons.coronavirus_rounded],
            onChanged: (v) => setState(() => _segment = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_segment),
            stream: FirebaseFirestore.instance
                .collection(isPest
                    ? 'coffee_pest_interventions'
                    : 'coffee_disease_interventions')
                .where('isDeleted', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _logger.e(
                    'Error fetching ${isPest ? 'pest' : 'disease'} interventions',
                    error: snapshot.error);
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final records = (snapshot.data?.docs ?? [])
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    final text = (data?['intervention'] as String?)?.trim();
                    final name = data?[nameField] as String?;
                    if (text == null || text.isEmpty || name == null) {
                      return null;
                    }
                    return _MethodRecord(
                      name: name,
                      text: text,
                      category: InterventionCategory.fromName(
                          data?['category'] as String?),
                    );
                  })
                  .whereType<_MethodRecord>()
                  .toList();

              if (records.isEmpty) {
                return _EmptyMethodsState(isPest: isPest, accent: accent);
              }

              final distinctNames = records.map((r) => r.name).toSet().toList()
                ..sort();
              final selectedName = _selectedName;
              final filtered = selectedName == null
                  ? records
                  : records.where((r) => r.name == selectedName).toList();

              final categoryCounts = <InterventionCategory, int>{};
              final categoryForLabel = <String, InterventionCategory>{};
              for (final r in filtered) {
                categoryCounts[r.category] =
                    (categoryCounts[r.category] ?? 0) + 1;
                categoryForLabel.putIfAbsent(
                    r.text.toLowerCase(), () => r.category);
              }

              final ranked = _topCounts(filtered, (r) => r.text, limit: 10);

              return ListView(
                key: ValueKey('$_segment-list'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _NameSelectorChips(
                    names: distinctNames,
                    selected: selectedName,
                    accent: accent,
                    onSelected: (n) => setState(() => _selectedName = n),
                  ),
                  const SizedBox(height: 14),
                  _MethodsSummaryHeader(
                    total: filtered.length,
                    distinctMethods: ranked.length,
                    accent: accent,
                  ),
                  const SizedBox(height: 14),
                  _CategoryDonutChart(
                    categoryCounts: categoryCounts,
                    total: filtered.length,
                    title: selectedName == null
                        ? 'Method Type Breakdown — All $nameField'
                        : 'Method Type Breakdown — $selectedName',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    selectedName == null
                        ? 'Specific methods logged'
                        : 'Specific methods used against $selectedName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < ranked.length; i++)
                    _RankedMethodRow(
                      rank: i + 1,
                      label: ranked[i].key,
                      count: ranked[i].value,
                      fraction: ranked[i].value / ranked.first.value,
                      percentOfTotal: filtered.isEmpty
                          ? 0
                          : ranked[i].value / filtered.length * 100,
                      accent: categoryColor(
                          categoryForLabel[ranked[i].key.toLowerCase()] ??
                              InterventionCategory.other),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pest / disease name selector — built from names actually present in the
// current stream, plus an "All" option (default).
// ─────────────────────────────────────────────────────────────────────────────

class _NameSelectorChips extends StatelessWidget {
  final List<String> names;
  final String? selected;
  final Color accent;
  final ValueChanged<String?> onSelected;

  const _NameSelectorChips({
    required this.names,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All', style: TextStyle(fontSize: 12)),
              selected: selected == null,
              selectedColor: accent.withValues(alpha: 0.2),
              side: BorderSide(
                  color: selected == null ? accent : Colors.grey.shade300),
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name, style: const TextStyle(fontSize: 12)),
                selected: selected == name,
                selectedColor: accent.withValues(alpha: 0.2),
                side: BorderSide(
                    color: selected == name ? accent : Colors.grey.shade300),
                onSelected: (_) => onSelected(name),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category ratio donut — chemical / mechanical / biological / other, in
// that fixed order (never re-sorted by size — color follows category
// identity, not rank).
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryDonutChart extends StatelessWidget {
  final Map<InterventionCategory, int> categoryCounts;
  final int total;
  final String title;

  const _CategoryDonutChart({
    required this.categoryCounts,
    required this.total,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final c in InterventionCategory.values)
        if ((categoryCounts[c] ?? 0) > 0) MapEntry(c, categoryCounts[c]!),
    ];

    if (entries.isEmpty || total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value.toDouble(),
                      color: categoryColor(e.key),
                      title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                      radius: 52,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: categoryColor(e.key), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${e.key.label} · ${e.value}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pest / Disease segmented toggle
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentToggle extends StatelessWidget {
  final int value;
  final List<String> labels;
  final List<IconData> icons;
  final Color Function(int) colorFor;
  final ValueChanged<int> onChanged;

  const _SegmentToggle({
    required this.value,
    required this.labels,
    required this.icons,
    required this.colorFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAE2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == value;
          final color = colorFor(i);
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icons[i],
                        size: 16,
                        color: selected
                            ? Colors.white
                            : color.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header — grounds the ranking in real totals
// ─────────────────────────────────────────────────────────────────────────────

class _MethodsSummaryHeader extends StatelessWidget {
  final int total;
  final int distinctMethods;
  final Color accent;

  const _MethodsSummaryHeader({
    required this.total,
    required this.distinctMethods,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Text('interventions logged',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5)),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$distinctMethods',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              Text('distinct methods',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One ranked, animated horizontal bar row — tap for detail
// ─────────────────────────────────────────────────────────────────────────────

class _RankedMethodRow extends StatelessWidget {
  final int rank;
  final String label;
  final int count;
  final double fraction;
  final double percentOfTotal;
  final Color accent;

  const _RankedMethodRow({
    required this.rank,
    required this.label,
    required this.count,
    required this.fraction,
    required this.percentOfTotal,
    required this.accent,
  });

  Color get _badgeColor {
    switch (rank) {
      case 1:
        return const Color(0xFFC9962C); // gold
      case 2:
        return const Color(0xFF9AA5B1); // silver
      case 3:
        return const Color(0xFFB0763F); // bronze
      default:
        return accent.withValues(alpha: 0.55);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8DDD4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _badgeColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('$rank',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3E2723)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: accent.withValues(alpha: 0.10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
                          duration: Duration(milliseconds: 500 + (rank * 60)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      accent.withValues(alpha: 0.65),
                                      accent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentOfTotal.toStringAsFixed(1)}% of logged interventions',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.brown[300],
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration:
                      BoxDecoration(color: _badgeColor, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('#$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailStat(
                      label: 'Times logged', value: '$count', accent: accent),
                ),
                Expanded(
                  child: _DetailStat(
                      label: 'Share of total',
                      value: '${percentOfTotal.toStringAsFixed(1)}%',
                      accent: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _DetailStat(
      {required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.brown[400])),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMethodsState extends StatelessWidget {
  final bool isPest;
  final Color accent;

  const _EmptyMethodsState({required this.isPest, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPest ? Icons.bug_report_rounded : Icons.coronavirus_rounded,
              size: 48,
              color: accent.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${isPest ? 'pest' : 'disease'} interventions logged yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.brown[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — Effectiveness
//
// Built entirely from farmer-submitted follow-up check-ins
// (followUpCompleted + followUpOutcome on each intervention, captured ~1
// week after logging — see PestFollowUpCheckinPage / DiseaseFollowUpCheckinPage).
// Rescanned check-ins with no picked outcome (followUpOutcome == null) are
// excluded from scoring — there's no farmer-reported outcome to average.
// ─────────────────────────────────────────────────────────────────────────────

class _EffectivenessRecord {
  final String name;
  final String text;
  final InterventionCategory category;
  final int score;

  const _EffectivenessRecord({
    required this.name,
    required this.text,
    required this.category,
    required this.score,
  });
}

class _EffectivenessEntry {
  final String label;
  final double avgScore;
  final int count;
  final InterventionCategory category;

  const _EffectivenessEntry({
    required this.label,
    required this.avgScore,
    required this.count,
    required this.category,
  });
}

Color effectivenessColor(double score) {
  if (score >= 75) return const Color(0xFF5B8A4A);
  if (score >= 50) return const Color(0xFFB0763F);
  return const Color(0xFFC0392B);
}

class _EffectivenessTab extends StatefulWidget {
  const _EffectivenessTab();

  @override
  State<_EffectivenessTab> createState() => _EffectivenessTabState();
}

class _EffectivenessTabState extends State<_EffectivenessTab> {
  static const Color _pestColor = Color(0xFF6F4E37);
  static const Color _diseaseColor = Color(0xFF5B8A4A);

  int _segment = 0; // 0 = pests, 1 = diseases
  String? _selectedPestName;
  String? _selectedDiseaseName;

  String? get _selectedName =>
      _segment == 0 ? _selectedPestName : _selectedDiseaseName;

  set _selectedName(String? value) {
    if (_segment == 0) {
      _selectedPestName = value;
    } else {
      _selectedDiseaseName = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPest = _segment == 0;
    final accent = isPest ? _pestColor : _diseaseColor;
    final nameField = isPest ? 'pestName' : 'diseaseName';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _SegmentToggle(
            value: _segment,
            colorFor: (i) => i == 0 ? _pestColor : _diseaseColor,
            labels: const ['Pest Effectiveness', 'Disease Effectiveness'],
            icons: const [Icons.bug_report_rounded, Icons.coronavirus_rounded],
            onChanged: (v) => setState(() => _segment = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_segment),
            stream: FirebaseFirestore.instance
                .collection(isPest
                    ? 'coffee_pest_interventions'
                    : 'coffee_disease_interventions')
                .where('isDeleted', isEqualTo: false)
                .where('followUpCompleted', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _logger.e(
                    'Error fetching ${isPest ? 'pest' : 'disease'} follow-ups',
                    error: snapshot.error);
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final records = (snapshot.data?.docs ?? [])
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    final text = (data?['intervention'] as String?)?.trim();
                    final name = data?[nameField] as String?;
                    final outcome = FollowUpOutcome.fromName(
                        data?['followUpOutcome'] as String?);
                    if (text == null ||
                        text.isEmpty ||
                        name == null ||
                        outcome == null) {
                      return null;
                    }
                    return _EffectivenessRecord(
                      name: name,
                      text: text,
                      category: InterventionCategory.fromName(
                          data?['category'] as String?),
                      score: outcome.score,
                    );
                  })
                  .whereType<_EffectivenessRecord>()
                  .toList();

              if (records.isEmpty) {
                return _EmptyEffectivenessState(isPest: isPest, accent: accent);
              }

              final distinctNames = records.map((r) => r.name).toSet().toList()
                ..sort();
              final selectedName = _selectedName;
              final filtered = selectedName == null
                  ? records
                  : records.where((r) => r.name == selectedName).toList();

              final grouped = <String, List<_EffectivenessRecord>>{};
              final displayText = <String, String>{};
              for (final r in filtered) {
                final key = r.text.toLowerCase();
                grouped.putIfAbsent(key, () => []).add(r);
                displayText.putIfAbsent(key, () => r.text);
              }

              final ranked = grouped.entries.map((e) {
                final avg = e.value.fold<int>(0, (t, r) => t + r.score) /
                    e.value.length;
                return _EffectivenessEntry(
                  label: displayText[e.key] ?? e.key,
                  avgScore: avg,
                  count: e.value.length,
                  category: e.value.first.category,
                );
              }).toList()
                ..sort((a, b) => b.avgScore.compareTo(a.avgScore));

              final overallAvg = filtered.isEmpty
                  ? 0.0
                  : filtered.fold<int>(0, (t, r) => t + r.score) /
                      filtered.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _NameSelectorChips(
                    names: distinctNames,
                    selected: selectedName,
                    accent: accent,
                    onSelected: (n) => setState(() => _selectedName = n),
                  ),
                  const SizedBox(height: 14),
                  _EffectivenessSummaryHeader(
                    overallAvg: overallAvg,
                    checkIns: filtered.length,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    selectedName == null
                        ? 'Method effectiveness (avg. of farmer check-ins)'
                        : 'Method effectiveness for $selectedName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in ranked) _EffectivenessBar(entry: entry),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EffectivenessSummaryHeader extends StatelessWidget {
  final double overallAvg;
  final int checkIns;

  const _EffectivenessSummaryHeader(
      {required this.overallAvg, required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final color = effectivenessColor(overallAvg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overallAvg.toStringAsFixed(0),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Text('avg. effectiveness score / 100',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5)),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$checkIns',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              Text('farmer check-ins',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EffectivenessBar extends StatelessWidget {
  final _EffectivenessEntry entry;

  const _EffectivenessBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = effectivenessColor(entry.avgScore);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                    color: categoryColor(entry.category),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E2723)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.avgScore.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: color.withValues(alpha: 0.10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (entry.avgScore / 100).clamp(0, 1)),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.65), color]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'from ${entry.count} check-in${entry.count == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 10.5,
                color: Colors.brown[300],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _EmptyEffectivenessState extends StatelessWidget {
  final bool isPest;
  final Color accent;

  const _EmptyEffectivenessState({required this.isPest, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded,
                size: 48, color: accent.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'No completed follow-up check-ins yet for '
              '${isPest ? 'pests' : 'diseases'}.\nEffectiveness scores appear '
              'once farmers respond to their week-later reminder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.brown[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
