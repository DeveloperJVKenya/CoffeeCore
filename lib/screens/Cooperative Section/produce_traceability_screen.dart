import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/models/traced_submission.dart';
import 'package:coffeecore/screens/Cooperative%20Section/produce_qr_scan_screen.dart';
import 'package:coffeecore/services/produce_traceability_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:coffeecore/widgets/produce_confirmation_chip.dart';
import 'package:coffeecore/widgets/produce_stage_chain.dart';
import 'package:flutter/material.dart';

enum _SortKey { coop, farmer, variety, kg, stage }

/// Produce traceability table — either scoped to one cooperative
/// ([cooperativeName] set: MarketManager/CoopAdmin) or spanning every
/// cooperative in the system with a filter to narrow it back down to one
/// ([cooperativeName] null: MainAdmin). Reached only from screens that are
/// already role-gated (MarketManagerScreen, CoopAdminManagementScreen,
/// AdminManagementScreen), so [canScan] is trusted from the caller rather
/// than re-derived — same reasoning as ProduceQrScanScreen. Scanning is
/// never offered in all-cooperative mode: a scan always belongs to exactly
/// one cooperative's Market Manager, never MainAdmin.
class ProduceTraceabilityScreen extends StatefulWidget {
  final String? cooperativeName;
  final bool canScan;

  const ProduceTraceabilityScreen({
    super.key,
    this.cooperativeName,
    required this.canScan,
  });

  @override
  State<ProduceTraceabilityScreen> createState() =>
      _ProduceTraceabilityScreenState();
}

class _ProduceTraceabilityScreenState extends State<ProduceTraceabilityScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  final _service = ProduceTraceabilityService();

  _SortKey _sortKey = _SortKey.farmer;
  bool _sortAscending = true;
  // Only meaningful in all-cooperative mode — null means "every cooperative".
  String? _coopFilter;

  bool get _isAllCoopMode => widget.cooperativeName == null;

  @override
  Widget build(BuildContext context) {
    final singleCoopId = widget.cooperativeName != null
        ? sanitizeCoopId(widget.cooperativeName!)
        : null;

    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(
            _isAllCoopMode
                ? 'Produce Traceability — All Cooperatives'
                : 'Produce Traceability',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: widget.canScan && widget.cooperativeName != null
          ? FloatingActionButton.extended(
              backgroundColor: coffeeBrown,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProduceQrScanScreen(
                      cooperativeName: widget.cooperativeName!),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<TracedSubmission>>(
        stream: _isAllCoopMode
            ? _service.tracedSubmissionsForAllCoops()
            : _service.tracedSubmissionsForCoop(singleCoopId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return const Center(
              child: Text('No produce submissions yet.',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          final filtered = (_isAllCoopMode && _coopFilter != null)
              ? all.where((t) => t.coopId == _coopFilter).toList()
              : all;
          final traced = _sortedList(filtered);

          return Column(
            children: [
              if (_isAllCoopMode) _buildCoopFilterBar(all),
              Expanded(
                child: traced.isEmpty
                    ? const Center(
                        child: Text('No submissions for this cooperative.',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildTable(traced),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Distinct cooperatives present in the live data, letting a MainAdmin
  /// swap between "All Cooperatives" and one specific one — cheaper than a
  /// separate query since the full cross-cooperative stream is already
  /// being fetched for the table itself.
  Widget _buildCoopFilterBar(List<TracedSubmission> all) {
    final coops = <String, String>{}; // coopId -> coopLabel
    for (final t in all) {
      coops[t.coopId] = t.coopLabel;
    }
    final entries = coops.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DropdownButtonFormField<String?>(
          initialValue: _coopFilter,
          isExpanded: false,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('All Cooperatives')),
            ...entries.map((e) =>
                DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: (value) => setState(() => _coopFilter = value),
        ),
      ),
    );
  }

  List<TracedSubmission> _sortedList(List<TracedSubmission> input) {
    int cmp(TracedSubmission a, TracedSubmission b) {
      switch (_sortKey) {
        case _SortKey.coop:
          return a.coopLabel.compareTo(b.coopLabel);
        case _SortKey.farmer:
          return a.submission.farmerName.compareTo(b.submission.farmerName);
        case _SortKey.variety:
          return a.submission.variety.compareTo(b.submission.variety);
        case _SortKey.kg:
          return a.submission.totalAmount.compareTo(b.submission.totalAmount);
        case _SortKey.stage:
          return a.stage.index.compareTo(b.stage.index);
      }
    }

    final list = [...input];
    list.sort((a, b) => _sortAscending ? cmp(a, b) : cmp(b, a));
    return list;
  }

  void _onSort(_SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  Widget _buildTable(List<TracedSubmission> traced) {
    // Built as (label, key) pairs so the sort-arrow column index always
    // matches whichever columns are actually shown — the "Cooperative"
    // column only exists in all-cooperative mode.
    final columnDefs = <(String, _SortKey?)>[
      if (_isAllCoopMode) ('Cooperative', _SortKey.coop),
      ('Farmer', _SortKey.farmer),
      ('Variety', _SortKey.variety),
      ('Kg', _SortKey.kg),
      ('Current Stage', _SortKey.stage),
      // Not sortable — there's no stable ProduceConfirmationStatus ordering
      // worth exposing, this is here purely for at-a-glance visibility.
      ('Confirmation', null),
      ('Track', null),
    ];
    final sortColumnIndex = columnDefs
        .indexWhere((c) => c.$2 == _sortKey)
        .clamp(0, columnDefs.length - 1);

    return DataTable(
      sortColumnIndex: sortColumnIndex,
      sortAscending: _sortAscending,
      columns: columnDefs
          .map((c) => DataColumn(
                label: Text(c.$1,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onSort: c.$2 == null ? null : (_, __) => _onSort(c.$2!),
              ))
          .toList(),
      rows: traced.map((t) {
        return DataRow(
          cells: [
            if (_isAllCoopMode) DataCell(Text(t.coopLabel)),
            DataCell(Text(t.submission.farmerName)),
            DataCell(Text(
                t.submission.variety.isEmpty ? '-' : t.submission.variety)),
            DataCell(Text(t.submission.totalAmount.toStringAsFixed(1))),
            DataCell(Text(t.stage.label)),
            DataCell(ProduceConfirmationChip(
                status: t.submission.confirmationStatus)),
            // An explicit button — DataTable's onSelectChanged row-tap
            // alone gives no visible hint that a row is tappable, so the
            // horizontal stage tracker dialog was going undiscovered.
            DataCell(
              IconButton(
                icon: const Icon(Icons.route, color: Colors.brown),
                tooltip: 'View stage tracker',
                onPressed: () => _showTimeline(
                    context,
                    _service,
                    t.coopId.isNotEmpty
                        ? t.coopId
                        : sanitizeCoopId(widget.cooperativeName!),
                    t),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _showTimeline(
    BuildContext context,
    ProduceTraceabilityService service,
    String coopId,
    TracedSubmission traced,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${traced.submission.farmerName} — Stage Timeline'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<ProduceTraceEntry>>(
            stream: service.stageHistory(
                coopId, traced.submission.id, traced.submission.submissionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: ProduceStageChain(
                  history: snapshot.data!,
                  submissionDate: traced.submission.submissionDate,
                  accentColor: coffeeBrown,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
