import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/screens/Cooperative%20Section/farmer_settlements_screen.dart';
import 'package:coffeecore/screens/Cooperative%20Section/produce_traceability_screen.dart';
import 'package:coffeecore/screens/Cooperative%20Section/receive_produce_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/services/pdf_download_helper.dart';
import 'package:coffeecore/services/qr_tag_pdf_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

class MarketManagerScreen extends StatefulWidget {
  const MarketManagerScreen({super.key});

  @override
  State<MarketManagerScreen> createState() => _MarketManagerScreenState();
}

class _MarketManagerScreenState extends State<MarketManagerScreen>
    with SingleTickerProviderStateMixin {
  static final Color coffeeBrown = Colors.brown[700]!;
  final Logger logger = Logger(printer: PrettyPrinter());
  String? _cooperativeName;
  String? _feedbackMessage;
  late AnimationController _animationController;
  late Animation<int> _currencyAnimation;

  final List<Map<String, String>> _userDetails = [];
  String? _selectedUserId;
  final TextEditingController _produceAmountController =
      TextEditingController();

  // Lightweight count for the dashboard's "at a glance" stats strip only —
  // the full variety/price list now lives in ReceiveProduceScreen, which
  // owns the "add produce -> generate tag" flow end to end.
  int _varietyCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCooperativeName();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _currencyAnimation = IntTween(begin: 0, end: 8).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _fetchCooperativeName() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _feedbackMessage = 'No user logged in';
      });
      logger.w('No user logged in');
      return;
    }

    try {
      QuerySnapshot coopSnapshot =
          await FirebaseFirestore.instance.collection('cooperatives').get();
      if (!mounted) return;
      logger.i('Fetched cooperatives: ${coopSnapshot.docs.length} found');
      for (var coopDoc in coopSnapshot.docs) {
        String coopId = coopDoc.id;
        DocumentSnapshot managerDoc = await FirebaseFirestore.instance
            .collection('${coopId}_marketmanagers')
            .doc(userId)
            .get();
        if (!mounted) return;
        logger.i(
            'Checking market manager document for user $userId in ${coopId}_marketmanagers');
        if (managerDoc.exists) {
          setState(() {
            _cooperativeName = coopIdToDisplayName(coopId);
          });
          await _fetchUsers(coopId);
          return;
        }
      }
      setState(() {
        _feedbackMessage =
            'Not registered as a Market Manager in any cooperative';
      });
      logger.w(
          'User $userId not found in any {coopId}_marketmanagers collection');
    } catch (e, stackTrace) {
      logger.e('Error fetching cooperative: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Error loading cooperative: $e';
      });
    }
  }

  Future<void> _fetchUsers(String coopId) async {
    try {
      logger.i('Fetching users from collection: ${coopId}_users');
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('${coopId}_users').get();
      if (!mounted) return;
      logger.i('Fetched users: ${userSnapshot.docs.length} found');

      _userDetails.clear();
      for (var doc in userSnapshot.docs) {
        String userId = doc.id;
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        String fullName = data?['fullName']?.toString() ?? 'Unknown';
        String phoneNumber = data?['phoneNumber']?.toString() ?? 'N/A';

        _userDetails.add({
          'id': userId,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
        });
      }

      final priceSnapshot = await FirebaseFirestore.instance
          .collection('${coopId}_coffeeprices')
          .get();
      if (!mounted) return;
      _varietyCount = priceSnapshot.docs.length;

      setState(() {});
    } catch (e, stackTrace) {
      logger.e('Error fetching users: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Error loading users: $e';
      });
    }
  }

  Future<void> _editProduceSubmission(String userId, String submissionId,
      double currentAmount, double pricePerKg) async {
    String formattedCoopId = sanitizeCoopId(_cooperativeName!);
    _produceAmountController.text = currentAmount.toString();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Produce Amount'),
        content: TextField(
          controller: _produceAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount (kg)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: coffeeBrown),
            onPressed: () {
              if (_produceAmountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              double? newAmount =
                  double.tryParse(_produceAmountController.text);
              if (newAmount == null || newAmount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Please enter a valid amount greater than zero')),
                );
                return;
              }
              Navigator.pop(
                  dialogContext, _produceAmountController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        double newAmount = double.parse(result);
        await FirebaseFirestore.instance
            .collection('${formattedCoopId}_FarmerProduce')
            .doc(userId)
            .collection('submissions')
            .doc(submissionId)
            .update({
          'totalAmount': newAmount,
          // grossValue must stay in sync with the corrected weight — the
          // settlement ledger sums grossValue directly, so leaving it at
          // its old value would over/under-pay the farmer relative to the
          // corrected amount.
          'grossValue': newAmount * pricePerKg,
          'timestamp': Timestamp.now(),
        });
        logger.i(
            'Successfully updated produce data for user $userId at ${formattedCoopId}_FarmerProduce/$userId/submissions/$submissionId');
        await _logActivity(
            'Updated produce to $newAmount kg for user $userId in cooperative $_cooperativeName');
        setState(() {
          _feedbackMessage = 'Produce amount updated to $newAmount kg';
        });
      } catch (e, stackTrace) {
        logger.e(
            'Error updating produce submission: $e\nStack trace: $stackTrace\nPath: ${formattedCoopId}_FarmerProduce/$userId/submissions/$submissionId');
        setState(() {
          _feedbackMessage = 'Error updating produce submission: $e';
        });
      }
    }
    _produceAmountController.clear();
  }

  Future<void> _logActivity(String action) async {
    try {
      String formattedCoopId = sanitizeCoopId(_cooperativeName!);
      await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(formattedCoopId)
          .collection('logs')
          .doc() // Use auto-generated ID
          .set({
        'action': action,
        'timestamp': Timestamp.now(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'role': 'market_manager',
      });
    } catch (e, stackTrace) {
      logger.e('Error logging activity: $e\nStack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _produceAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Market Manager Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _cooperativeName == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: Colors.brown[50],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 20),
                    _buildHeroAction(),
                    const SizedBox(height: 20),
                    _buildQuickActionsGrid(),
                    const SizedBox(height: 28),
                    Text('Recent Submissions',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown)),
                    const SizedBox(height: 10),
                    _buildFarmerFilter(),
                    const SizedBox(height: 12),
                    _buildProduceTable(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [coffeeBrown, Colors.brown[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: coffeeBrown.withValues(alpha: .3),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cooperativeName ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Market Manager',
                    style: TextStyle(color: Colors.brown[100], fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                        Icons.groups, '${_userDetails.length}', 'Farmers'),
                    const SizedBox(width: 10),
                    _buildStatChip(
                        Icons.local_cafe, '$_varietyCount', 'Varieties'),
                  ],
                ),
              ],
            ),
          ),
          _buildCurrencyAnimation(),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text('$value $label',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCurrencyAnimation() {
    final List<String> currencies = [
      '\$',
      '€',
      '£',
      '₹',
      'Ksh',
      'ETB',
      'Tsh',
      'Ush',
      'A\$',
    ];
    return AnimatedBuilder(
      animation: _currencyAnimation,
      builder: (context, child) {
        return Text(
          currencies[_currencyAnimation.value],
          style: TextStyle(
            fontSize: 36,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: const Color.fromRGBO(0, 0, 0, 0.3),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  /// The primary, highest-frequency action — receiving a farmer's coffee —
  /// gets a featured hero button rather than blending into the grid below,
  /// since this is now the ONLY path to recording a submission and it
  /// always ends with a generated QR tag (see ReceiveProduceScreen).
  Widget _buildHeroAction() {
    return _AnimatedEntrance(
      index: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReceiveProduceScreen(cooperativeName: _cooperativeName!),
            ),
          );
          if (mounted) _fetchUsers(sanitizeCoopId(_cooperativeName!));
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.green.withValues(alpha: .3),
                  blurRadius: 12,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.agriculture,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receive Produce',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Weigh in, record, and print the bag tag',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final tiles = <_QuickAction>[
      _QuickAction('Price List', Icons.list_alt, Colors.deepOrange, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PriceListScreen(cooperativeName: _cooperativeName!),
          ),
        );
      }),
      _QuickAction('Add Variety', Icons.add_circle_outline, Colors.teal,
          () async {
        await _showAddVarietyDialog(context);
        if (mounted) _fetchUsers(sanitizeCoopId(_cooperativeName!));
      }),
      _QuickAction('Submissions', Icons.table_chart, Colors.indigo, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubmissionListScreen(cooperativeName: _cooperativeName!),
          ),
        );
      }),
      _QuickAction('Settlements', Icons.account_balance_wallet, Colors.purple,
          () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FarmerSettlementsScreen(cooperativeName: _cooperativeName!),
          ),
        );
      }),
      // Sole entry point for scanning a bag's QR — the standalone "Scan
      // Produce Tag" dashboard card was removed since it duplicated this.
      _QuickAction('Traceability', Icons.route, Colors.brown, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProduceTraceabilityScreen(
              cooperativeName: _cooperativeName!,
              canScan: true,
            ),
          ),
        );
      }),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, i) => _AnimatedEntrance(
            index: i + 1,
            child: _QuickActionTile(action: tiles[i]),
          ),
        );
      },
    );
  }

  Widget _buildFarmerFilter() {
    if (_userDetails.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      initialValue: _selectedUserId,
      hint: const Text('Select a farmer to view their submissions'),
      isExpanded: true,
      items: _userDetails
          .map((u) => DropdownMenuItem<String>(
              value: u['id'], child: Text(u['fullName']!)))
          .toList(),
      onChanged: (value) => setState(() => _selectedUserId = value),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProduceTable() {
    if (_cooperativeName == null || _selectedUserId == null) {
      return const Center(
        child: Text(
          'Select a farmer above to view their submissions.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }
    String formattedCoopId = sanitizeCoopId(_cooperativeName!);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('${formattedCoopId}_FarmerProduce')
          .doc(_selectedUserId)
          .collection('submissions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          logger.e(
              'Error loading produce data: ${snapshot.error}\nStack trace: ${StackTrace.current}\nPath: ${formattedCoopId}_FarmerProduce/$_selectedUserId/submissions');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No produce submissions for this user.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        final produceData = snapshot.data!.docs
            .map((doc) => FarmerProduce.fromDocument(doc))
            .toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(
                  label: Text('Farmer Name',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Contact',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Date',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Amount (kg)',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Actions',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: produceData.map((data) {
              return DataRow(cells: [
                DataCell(Text(data.farmerName)),
                DataCell(Text(data.contact)),
                DataCell(Text(data.submissionDate)),
                DataCell(Text(data.totalAmount.toStringAsFixed(2))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _editProduceSubmission(data.id, data.submissionId,
                              data.totalAmount, data.pricePerKg);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code, color: Colors.brown),
                        tooltip: 'Reprint Tag',
                        onPressed: () => _printQrTag(data),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _printQrTag(FarmerProduce data) async {
    if (_cooperativeName == null) return;
    try {
      final bytes = await QrTagPdfService.buildTag(
        cooperativeName: _cooperativeName!,
        farmerName: data.farmerName,
        submissionDate: data.submissionDate,
        kg: data.totalAmount,
        variety: data.variety.isEmpty ? 'Unspecified' : data.variety,
        coopId: sanitizeCoopId(_cooperativeName!),
        userId: data.id,
        submissionId: data.submissionId,
      );
      final fileName = QrTagPdfService.fileName(
        cooperativeName: _cooperativeName!,
        farmerName: data.farmerName,
        submissionDate: data.submissionDate,
        submissionId: data.submissionId,
      );
      final file = await PdfDownloadHelper.saveBytes(bytes, fileName);
      if (!mounted) return;
      if (file != null) {
        await PdfDownloadHelper.share(file,
            text: 'Produce tag for ${data.farmerName}');
      }
      setState(() => _feedbackMessage = 'QR tag ready for ${data.farmerName}');
    } catch (e, stackTrace) {
      logger.e('Error generating QR tag: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _feedbackMessage = 'Error generating QR tag: $e');
    }
  }

  Future<void> _showAddVarietyDialog(BuildContext context) async {
    final varietyController = TextEditingController();
    final priceController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _feedbackMessage = 'No user logged in';
      });
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Coffee Variety & Price'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: varietyController,
                decoration: InputDecoration(
                  labelText: 'Variety Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price (Ksh/kg)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: coffeeBrown),
            onPressed: () {
              if (varietyController.text.trim().isEmpty ||
                  priceController.text.trim().isEmpty) {
                Navigator.pop(dialogContext, 'Fill all fields');
                return;
              }
              double? price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                Navigator.pop(dialogContext, 'Invalid price');
                return;
              }
              Navigator.pop(dialogContext, varietyController.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null &&
        result != 'Fill all fields' &&
        result != 'Invalid price') {
      try {
        String newVariety = result;
        double price = double.parse(priceController.text);
        String formattedCoopId = sanitizeCoopId(_cooperativeName!);
        await FirebaseFirestore.instance
            .collection('${formattedCoopId}_coffeeprices')
            .doc(newVariety)
            .set({
          'variety': newVariety,
          'price': price,
          'updatedBy': user.uid,
          'timestamp': Timestamp.now(),
        });
        setState(() {
          _feedbackMessage = '$newVariety added with price Ksh $price/kg';
        });
      } catch (e, stackTrace) {
        logger.e('Error adding variety: $e\nStack trace: $stackTrace');
        setState(() {
          _feedbackMessage = 'Error adding variety: $e';
        });
      }
    } else if (result == 'Fill all fields' || result == 'Invalid price') {
      setState(() {
        _feedbackMessage = result;
      });
    }
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction(this.label, this.icon, this.color, this.onTap);
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple staggered fade + rise entrance for dashboard tiles — each index
/// starts its animation slightly after the previous one for a modern,
/// engaging feel without pulling in an animation package.
class _AnimatedEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, widgetChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: widgetChild,
          ),
        );
      },
      child: child,
    );
  }
}

class PriceListScreen extends StatefulWidget {
  final String cooperativeName;

  const PriceListScreen({super.key, required this.cooperativeName});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  String? _feedbackMessage;
  final logger = Logger(printer: PrettyPrinter());

  Future<void> _showEditDialog(String variety, double currentPrice) async {
    final priceController =
        TextEditingController(text: currentPrice.toString());
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _feedbackMessage = 'No user logged in';
      });
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Price for $variety'),
        content: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Price (Ksh/kg)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: coffeeBrown),
            onPressed: () {
              double? price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Invalid price')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        double price = double.parse(priceController.text);
        String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
        await FirebaseFirestore.instance
            .collection('${formattedCoopId}_coffeeprices')
            .doc(variety)
            .update({
          'price': price,
          'updatedBy': user.uid,
          'timestamp': Timestamp.now(),
        });
        setState(() =>
            _feedbackMessage = 'Price for $variety updated to Ksh $price/kg');
      } catch (e, stackTrace) {
        logger.e('Error updating price: $e\nStack trace: $stackTrace');
        setState(() => _feedbackMessage = 'Error updating price: $e');
      }
    }
  }

  Future<void> _deletePrice(String variety) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $variety'),
        content: const Text(
            'Are you sure you want to delete this variety and price?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
        await FirebaseFirestore.instance
            .collection('${formattedCoopId}_coffeeprices')
            .doc(variety)
            .delete();
        setState(() => _feedbackMessage = '$variety deleted');
      } catch (e, stackTrace) {
        logger.e('Error deleting price: $e\nStack trace: $stackTrace');
        setState(() => _feedbackMessage = 'Error deleting price: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Price List - ${widget.cooperativeName}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('${formattedCoopId}_coffeeprices')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            logger.e(
                'Error loading prices: ${snapshot.error}\nStack trace: ${StackTrace.current}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No varieties added yet for ${widget.cooperativeName}.',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          final prices = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'variety': data['variety'] as String? ?? 'Unknown',
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList();

          return SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(
                    label: Text('Variety',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Price (Ksh/kg)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: prices.map((price) {
                return DataRow(cells: [
                  DataCell(Text(price['variety'] as String)),
                  DataCell(Text((price['price'] as double).toStringAsFixed(2))),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          await _showEditDialog(price['variety'] as String,
                              price['price'] as double);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _deletePrice(price['variety']! as String);
                        },
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class SubmissionListScreen extends StatefulWidget {
  final String cooperativeName;

  const SubmissionListScreen({super.key, required this.cooperativeName});

  @override
  State<SubmissionListScreen> createState() => _SubmissionListScreenState();
}

class _SubmissionListScreenState extends State<SubmissionListScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  final Logger logger = Logger(printer: PrettyPrinter());
  String? _feedbackMessage;
  List<Map<String, String>> _userDetails = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopId}_users')
          .get();
      if (!mounted) return;
      logger.i('Fetched users: ${userSnapshot.docs.length} found');
      _userDetails = userSnapshot.docs.map((doc) {
        String userId = doc.id;
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        return {
          'id': userId,
          'fullName': data?['fullName']?.toString() ?? 'Unknown',
          'phoneNumber': data?['phoneNumber']?.toString() ?? 'N/A',
        };
      }).toList();
      setState(() {});
    } catch (e, stackTrace) {
      logger.e('Error fetching users: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _editProduceSubmission(String userId, String submissionId,
      double currentAmount, double pricePerKg) async {
    String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
    final TextEditingController amountController =
        TextEditingController(text: currentAmount.toString());
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Produce Amount'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount (kg)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: coffeeBrown),
            onPressed: () {
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              double? newAmount = double.tryParse(amountController.text);
              if (newAmount == null || newAmount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Please enter a valid amount greater than zero')),
                );
                return;
              }
              Navigator.pop(dialogContext, amountController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        double newAmount = double.parse(result);
        await FirebaseFirestore.instance
            .collection('${formattedCoopId}_FarmerProduce')
            .doc(userId)
            .collection('submissions')
            .doc(submissionId)
            .update({
          'totalAmount': newAmount,
          // Keep grossValue in sync with the corrected weight — see the
          // same fix in MarketManagerScreen._editProduceSubmission.
          'grossValue': newAmount * pricePerKg,
          'timestamp': Timestamp.now(),
        });
        logger.i(
            'Successfully updated produce data for user $userId at ${formattedCoopId}_FarmerProduce/$userId/submissions/$submissionId');
        setState(() {
          _feedbackMessage = 'Produce amount updated to $newAmount kg';
        });
      } catch (e, stackTrace) {
        logger.e(
            'Error updating produce submission: $e\nStack trace: $stackTrace\nPath: ${formattedCoopId}_FarmerProduce/$userId/submissions/$submissionId');
        setState(() {
          _feedbackMessage = 'Error updating produce submission: $e';
        });
      }
    }
    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    String formattedCoopId = sanitizeCoopId(widget.cooperativeName);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Submission List - ${widget.cooperativeName}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _userDetails.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<QuerySnapshot>>(
              stream: CombineLatestStream.list(
                _userDetails
                    .map((user) => FirebaseFirestore.instance
                        .collection('${formattedCoopId}_FarmerProduce')
                        .doc(user['id'])
                        .collection('submissions')
                        .where('submissionDate', isGreaterThan: '')
                        .orderBy('submissionDate', descending: true)
                        .snapshots())
                    .toList(),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  logger.e(
                      'Error loading submissions: ${snapshot.error}\nStack trace: ${StackTrace.current}\nPath: ${formattedCoopId}_FarmerProduce/*/submissions');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData ||
                    snapshot.data!.every((s) => s.docs.isEmpty)) {
                  return const Center(
                    child: Text(
                      'No submissions found.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                final submissions = snapshot.data!
                    .expand((s) => s.docs)
                    .map((doc) => FarmerProduce.fromDocument(doc))
                    .toList();

                // Date columns are derived from the live submissions stream
                // itself (not a separately fetched, one-shot list) so a
                // brand-new submission's date always has a column the
                // moment it's written, without needing to reopen this
                // screen.
                final dates = submissions
                    .map((s) => s.submissionDate)
                    .toSet()
                    .toList()
                  ..sort((a, b) => b.compareTo(a));

                List<DataColumn> columns = [
                  const DataColumn(
                      label: Text('Farmer Name',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ];
                columns.addAll(dates.map((date) => DataColumn(
                      label: Text(date,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    )));

                List<DataRow> rows = _userDetails.map((user) {
                  List<DataCell> cells = [
                    DataCell(Text(user['fullName']!)),
                  ];
                  for (String date in dates) {
                    // A farmer can deliver more than once on the same day —
                    // each becomes its own submission doc — so this must
                    // collect every match for the cell, not just the first.
                    final daySubmissions = submissions
                        .where((s) =>
                            s.id == user['id'] && s.submissionDate == date)
                        .toList();
                    if (daySubmissions.isEmpty) {
                      cells.add(const DataCell(Text('-')));
                    } else if (daySubmissions.length == 1) {
                      final submission = daySubmissions.first;
                      cells.add(DataCell(
                        Row(
                          children: [
                            Text(submission.totalAmount.toStringAsFixed(2)),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 20),
                              onPressed: () {
                                _editProduceSubmission(
                                    submission.id,
                                    submission.submissionId,
                                    submission.totalAmount,
                                    submission.pricePerKg);
                              },
                            ),
                          ],
                        ),
                      ));
                    } else {
                      final total = daySubmissions.fold<double>(
                          0.0, (t, s) => t + s.totalAmount);
                      cells.add(DataCell(
                        InkWell(
                          onTap: () => _showDaySubmissions(daySubmissions),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '${total.toStringAsFixed(2)} (${daySubmissions.length})'),
                              const SizedBox(width: 4),
                              const Icon(Icons.list,
                                  size: 16, color: Colors.blue),
                            ],
                          ),
                        ),
                      ));
                    }
                  }
                  return DataRow(cells: cells);
                }).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: columns,
                      rows: rows,
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Multiple deliveries from the same farmer on the same day collapse into
  /// one table cell (a summed total) — this lists each individual
  /// submission so it can still be viewed/edited on its own.
  Future<void> _showDaySubmissions(List<FarmerProduce> daySubmissions) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${daySubmissions.first.submissionDate} deliveries'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: daySubmissions.length,
            itemBuilder: (context, i) {
              final s = daySubmissions[i];
              return ListTile(
                title: Text('${s.totalAmount.toStringAsFixed(2)} kg'
                    '${s.variety.isNotEmpty ? " · ${s.variety}" : ""}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _editProduceSubmission(
                        s.id, s.submissionId, s.totalAmount, s.pricePerKg);
                  },
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
