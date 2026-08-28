import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/models/traced_submission.dart';
import 'package:coffeecore/screens/Cooperative%20Section/produce_qr_scan_screen.dart';
import 'package:coffeecore/services/produce_traceability_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Cooperative-wide produce traceability table. Reached only from screens
/// that are already role-gated (MarketManagerScreen, CoopAdminManagementScreen),
/// so [canScan] is trusted from the caller rather than re-derived — same
/// reasoning as ProduceQrScanScreen.
class ProduceTraceabilityScreen extends StatelessWidget {
  final String cooperativeName;
  final bool canScan;

  const ProduceTraceabilityScreen({
    super.key,
    required this.cooperativeName,
    required this.canScan,
  });

  static final Color coffeeBrown = Colors.brown[700]!;

  @override
  Widget build(BuildContext context) {
    final service = ProduceTraceabilityService();
    final coopId = sanitizeCoopId(cooperativeName);

    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: const Text('Produce Traceability',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: canScan
          ? FloatingActionButton.extended(
              backgroundColor: coffeeBrown,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProduceQrScanScreen(cooperativeName: cooperativeName),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<TracedSubmission>>(
        stream: service.tracedSubmissionsForCoop(coopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final traced = snapshot.data ?? [];
          if (traced.isEmpty) {
            return const Center(
              child: Text('No produce submissions yet.',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(
                      label: Text('Farmer',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Variety',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Kg',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Current Stage',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: traced.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.submission.farmerName)),
                      DataCell(Text(t.submission.variety.isEmpty
                          ? '-'
                          : t.submission.variety)),
                      DataCell(
                          Text(t.submission.totalAmount.toStringAsFixed(1))),
                      DataCell(Text(t.stage.label)),
                    ],
                    onSelectChanged: (_) =>
                        _showTimeline(context, service, coopId, t),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
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
              final history = snapshot.data ?? [];
              final steps = <Widget>[
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 12),
                  title: const Text('Received'),
                  subtitle: Text(traced.submission.submissionDate),
                ),
              ];
              steps.addAll(history.map((h) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 12),
                    title: Text(h.stage.label),
                    subtitle: Text(
                      '${DateFormat('yyyy-MM-dd HH:mm').format(h.timestamp.toDate())}'
                      '${h.note.isNotEmpty ? " · ${h.note}" : ""}',
                    ),
                  )));
              return SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: steps),
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
