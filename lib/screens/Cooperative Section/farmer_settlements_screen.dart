import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_deduction.dart';
import 'package:coffeecore/models/farmer_payout.dart';
import 'package:coffeecore/models/farmer_settlement.dart';
import 'package:coffeecore/services/farmer_settlement_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Farmer settlement ledger: gross coffee value (kg × price snapshotted at
/// submission) minus cooperative-side deductions (input supplies, transport,
/// processing costs) minus amounts already paid out = balance due. A
/// MarketManager records deductions/payouts for every farmer in the
/// cooperative; a CoopAdmin gets the same cooperative-wide table read-only;
/// a Farmer sees only their own statement. Role is self-detected the same
/// way ProduceScreen does it, rather than trusted from the caller.
class FarmerSettlementsScreen extends StatefulWidget {
  final String cooperativeName;

  const FarmerSettlementsScreen({super.key, required this.cooperativeName});

  @override
  State<FarmerSettlementsScreen> createState() =>
      _FarmerSettlementsScreenState();
}

class _FarmerSettlementsScreenState extends State<FarmerSettlementsScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  final Logger logger = Logger(printer: PrettyPrinter());
  final FarmerSettlementService _service = FarmerSettlementService();

  String? _userId;
  String? _farmerName;
  String? _phoneNumber;
  String? _userRole; // Farmer, CoopAdmin, MarketManager, MainAdmin
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    if (_userId == null) {
      setState(() => _feedbackMessage = 'No user logged in');
      return;
    }
    try {
      final formattedCoopName = sanitizeCoopId(widget.cooperativeName);
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(_userId)
          .get();
      if (!mounted) return;
      if (adminDoc.exists) {
        setState(() => _userRole = 'MainAdmin');
        return;
      }

      final coopAdminDoc = await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(_userId)
          .get();
      final marketManagerDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_marketmanagers')
          .doc(_userId)
          .get();
      final userDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(_userId)
          .get();
      if (!mounted) return;

      if (coopAdminDoc.exists &&
          coopAdminDoc.data()?['cooperative'] == formattedCoopName) {
        setState(() => _userRole = 'CoopAdmin');
      } else if (marketManagerDoc.exists) {
        setState(() => _userRole = 'MarketManager');
      } else if (userDoc.exists) {
        setState(() {
          _userRole = 'Farmer';
          _farmerName = userDoc.data()?['fullName']?.toString() ?? '-';
          _phoneNumber = userDoc.data()?['phoneNumber']?.toString() ?? '-';
        });
      } else {
        setState(() => _feedbackMessage = 'User not found in cooperative');
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching user role: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _feedbackMessage = 'Error loading user details: $e');
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      final formattedCoopId = sanitizeCoopId(widget.cooperativeName);
      await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(formattedCoopId)
          .collection('logs')
          .add({
        'action': action,
        'timestamp': Timestamp.now(),
        'userId': _userId,
        'role': _userRole,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    final formattedCoopId = sanitizeCoopId(widget.cooperativeName);

    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: const Text('Farmer Settlements',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _userRole == null
          ? const Center(child: CircularProgressIndicator())
          : _userRole == 'Farmer'
              ? _FarmerOwnSettlementView(
                  service: _service,
                  coopId: formattedCoopId,
                  userId: _userId!,
                  farmerName: _farmerName ?? '-',
                  phoneNumber: _phoneNumber ?? '-',
                )
              : _CoopSettlementsTable(
                  service: _service,
                  coopId: formattedCoopId,
                  cooperativeName: widget.cooperativeName,
                  editable: _userRole == 'MarketManager',
                  onLogActivity: _logActivity,
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Farmer's own view — read-only, no farmer picker.
// ─────────────────────────────────────────────────────────────────────────

class _FarmerOwnSettlementView extends StatelessWidget {
  final FarmerSettlementService service;
  final String coopId;
  final String userId;
  final String farmerName;
  final String phoneNumber;

  const _FarmerOwnSettlementView({
    required this.service,
    required this.coopId,
    required this.userId,
    required this.farmerName,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FarmerSettlement>(
      stream: service.settlementForFarmer(coopId, userId, {
        'fullName': farmerName,
        'phoneNumber': phoneNumber,
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final settlement = snapshot.data;
        if (settlement == null) {
          return const Center(child: Text('No settlement data yet.'));
        }
        return SettlementDetailBody(
          service: service,
          coopId: coopId,
          settlement: settlement,
          editable: false,
          onLogActivity: null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Cooperative-wide table — MarketManager (editable) / CoopAdmin (read-only).
// ─────────────────────────────────────────────────────────────────────────

class _CoopSettlementsTable extends StatelessWidget {
  final FarmerSettlementService service;
  final String coopId;
  final String cooperativeName;
  final bool editable;
  final Future<void> Function(String action) onLogActivity;

  const _CoopSettlementsTable({
    required this.service,
    required this.coopId,
    required this.cooperativeName,
    required this.editable,
    required this.onLogActivity,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FarmerSettlement>>(
      stream: service.settlementForCoop(coopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final settlements = snapshot.data ?? [];
        if (settlements.isEmpty) {
          return const Center(
            child: Text('No farmers in this cooperative yet.',
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
                    label: Text('Gross (Ksh)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Deductions (Ksh)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Paid Out (Ksh)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Balance Due (Ksh)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: settlements.map((s) {
                return DataRow(
                  cells: [
                    DataCell(Text(s.farmerName)),
                    DataCell(Text(s.grossEarned.toStringAsFixed(2))),
                    DataCell(Text(s.totalDeductions.toStringAsFixed(2))),
                    DataCell(Text(s.totalPaidOut.toStringAsFixed(2))),
                    DataCell(Text(s.balanceDue.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  onSelectChanged: (_) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FarmerSettlementDetailScreen(
                          service: service,
                          coopId: coopId,
                          cooperativeName: cooperativeName,
                          settlement: s,
                          editable: editable,
                          onLogActivity: onLogActivity,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Admin/manager drill-down for one farmer, pushed as its own page.
// ─────────────────────────────────────────────────────────────────────────

class _FarmerSettlementDetailScreen extends StatelessWidget {
  final FarmerSettlementService service;
  final String coopId;
  final String cooperativeName;
  final FarmerSettlement settlement;
  final bool editable;
  final Future<void> Function(String action) onLogActivity;

  const _FarmerSettlementDetailScreen({
    required this.service,
    required this.coopId,
    required this.cooperativeName,
    required this.settlement,
    required this.editable,
    required this.onLogActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(settlement.farmerName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<FarmerSettlement>(
        stream: service.settlementForFarmer(coopId, settlement.userId, {
          'fullName': settlement.farmerName,
          'phoneNumber': settlement.contact,
        }),
        builder: (context, snapshot) {
          final live = snapshot.data ?? settlement;
          return SettlementDetailBody(
            service: service,
            coopId: coopId,
            settlement: live,
            editable: editable,
            onLogActivity: onLogActivity,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared detail body: summary cards + itemized deductions/payouts, reused
// by both the farmer's own view and the admin/manager drill-down.
// ─────────────────────────────────────────────────────────────────────────

class SettlementDetailBody extends StatelessWidget {
  final FarmerSettlementService service;
  final String coopId;
  final FarmerSettlement settlement;
  final bool editable;
  final Future<void> Function(String action)? onLogActivity;

  const SettlementDetailBody({
    super.key,
    required this.service,
    required this.coopId,
    required this.settlement,
    required this.editable,
    required this.onLogActivity,
  });

  static final Color coffeeBrown = Colors.brown[700]!;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(),
          if (settlement.unpricedSubmissionCount > 0) ...[
            const SizedBox(height: 12),
            _buildUnpricedNotice(),
          ],
          if (editable) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white),
                    label: const Text('Add Deduction',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => _showAddDeductionDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700]),
                    icon: const Icon(Icons.payments_outlined,
                        color: Colors.white),
                    label: const Text('Record Payout',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => _showRecordPayoutDialog(context),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text('Deductions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: coffeeBrown)),
          const SizedBox(height: 8),
          _buildDeductionsList(context),
          const SizedBox(height: 20),
          Text('Payouts',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: coffeeBrown)),
          const SizedBox(height: 8),
          _buildPayoutsList(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Gross Earned', settlement.grossEarned),
            _summaryRow('Deductions', -settlement.totalDeductions),
            _summaryRow('Paid Out', -settlement.totalPaidOut),
            const Divider(),
            _summaryRow('Balance Due', settlement.balanceDue, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 16 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('Ksh ${value.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: bold ? 16 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? coffeeBrown : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildUnpricedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text(
        '${settlement.unpricedSubmissionCount} submission(s) have no '
        'recorded variety/price and are excluded from Gross Earned.',
        style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
      ),
    );
  }

  Widget _buildDeductionsList(BuildContext context) {
    return StreamBuilder<List<FarmerDeduction>>(
      stream: service.deductionsForFarmer(coopId, settlement.userId),
      builder: (context, snapshot) {
        final deductions = snapshot.data ?? [];
        if (deductions.isEmpty) {
          return const Text('No deductions recorded.',
              style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: deductions.map((d) {
            return Card(
              child: ListTile(
                title: Text('${d.category.label} — Ksh '
                    '${d.amount.toStringAsFixed(2)}'),
                subtitle: Text(
                    '${d.date}${d.description.isNotEmpty ? " · ${d.description}" : ""}'),
                trailing: editable
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _confirmDeleteDeduction(context, d),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPayoutsList(BuildContext context) {
    return StreamBuilder<List<FarmerPayout>>(
      stream: service.payoutsForFarmer(coopId, settlement.userId),
      builder: (context, snapshot) {
        final payouts = snapshot.data ?? [];
        if (payouts.isEmpty) {
          return const Text('No payouts recorded.',
              style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: payouts.map((p) {
            return Card(
              child: ListTile(
                title: Text('Ksh ${p.amount.toStringAsFixed(2)}'),
                subtitle:
                    Text('${p.date}${p.note.isNotEmpty ? " · ${p.note}" : ""}'),
                trailing: editable
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _confirmDeletePayout(context, p),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _confirmDeleteDeduction(
      BuildContext context, FarmerDeduction deduction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete deduction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteDeduction(coopId, settlement.userId, deduction.id!);
      await onLogActivity?.call(
          'Deleted deduction of Ksh ${deduction.amount} for ${settlement.farmerName}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _confirmDeletePayout(
      BuildContext context, FarmerPayout payout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete payout record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deletePayout(coopId, settlement.userId, payout.id!);
      await onLogActivity?.call(
          'Deleted payout of Ksh ${payout.amount} for ${settlement.farmerName}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _showAddDeductionDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DeductionCategory category = DeductionCategory.seedlings;
    bool isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Deduction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DeductionCategory>(
                  initialValue: category,
                  items: DeductionCategory.values
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (Ksh)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        setDialogState(
                            () => errorText = 'Enter a valid amount.');
                        return;
                      }
                      final recordedBy = FirebaseAuth.instance.currentUser?.uid;
                      if (recordedBy == null) {
                        setDialogState(() => errorText =
                            'You are signed out — please sign in again.');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        await service.addDeduction(
                          coopId,
                          FarmerDeduction(
                            userId: settlement.userId,
                            category: category,
                            description: descCtrl.text.trim(),
                            amount: amount,
                            date:
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            recordedBy: recordedBy,
                            timestamp: Timestamp.now(),
                          ),
                        );
                        await onLogActivity?.call(
                            'Added deduction of Ksh $amount (${category.label}) '
                            'for ${settlement.farmerName}');
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = 'Failed to save: $e';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordPayoutDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Payout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (Ksh)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        setDialogState(
                            () => errorText = 'Enter a valid amount.');
                        return;
                      }
                      final recordedBy = FirebaseAuth.instance.currentUser?.uid;
                      if (recordedBy == null) {
                        setDialogState(() => errorText =
                            'You are signed out — please sign in again.');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        await service.addPayout(
                          coopId,
                          FarmerPayout(
                            userId: settlement.userId,
                            amount: amount,
                            date:
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            note: noteCtrl.text.trim(),
                            recordedBy: recordedBy,
                            timestamp: Timestamp.now(),
                          ),
                        );
                        await onLogActivity
                            ?.call('Recorded payout of Ksh $amount for '
                                '${settlement.farmerName}');
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = 'Failed to save: $e';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}
