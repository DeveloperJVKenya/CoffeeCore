import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      logger.i('Fetched cooperatives: ${coopSnapshot.docs.length} found');
      for (var coopDoc in coopSnapshot.docs) {
        String coopId = coopDoc.id;
        DocumentSnapshot managerDoc = await FirebaseFirestore.instance
            .collection('${coopId}_marketmanagers')
            .doc(userId)
            .get();
        logger.i(
            'Checking market manager document for user $userId in ${coopId}_marketmanagers');
        if (managerDoc.exists) {
          setState(() {
            _cooperativeName = coopId.replaceAll('_', ' ');
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

      setState(() {});
    } catch (e, stackTrace) {
      logger.e('Error fetching users: $e\nStack trace: $stackTrace');
      setState(() {
        _feedbackMessage = 'Error loading users: $e';
      });
    }
  }

  Future<void> _addProduceSubmission() async {
    if (_selectedUserId == null ||
        _produceAmountController.text.isEmpty ||
        _cooperativeName == null) {
      setState(() {
        _feedbackMessage = 'Please select a user and enter a valid amount';
      });
      logger.w(
          'Invalid input: userId=$_selectedUserId, amount=${_produceAmountController.text}, cooperativeName=$_cooperativeName');
      return;
    }

    double? amount = double.tryParse(_produceAmountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _feedbackMessage = 'Please enter a valid amount greater than zero';
      });
      logger.w('Invalid amount: ${_produceAmountController.text}');
      return;
    }

    String formattedCoopId = _cooperativeName!.replaceAll(' ', '_');
    String dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String? farmerName = _userDetails.firstWhere(
        (user) => user['id'] == _selectedUserId,
        orElse: () => {'fullName': 'Unknown'})['fullName'];
    String? contact = _userDetails.firstWhere(
        (user) => user['id'] == _selectedUserId,
        orElse: () => {'phoneNumber': 'N/A'})['phoneNumber'];

    try {
      final produceData = FarmerProduce(
        id: _selectedUserId!,
        farmerName: farmerName!,
        contact: contact!,
        totalAmount: amount,
        timestamp: Timestamp.now(),
        submissionDate: dateString,
        submissionId: FirebaseFirestore.instance.collection('dummy').doc().id,
      );

      await FirebaseFirestore.instance
          .collection('${formattedCoopId}_FarmerProduce')
          .doc(_selectedUserId)
          .collection('submissions')
          .doc(produceData.submissionId)
          .set(produceData.toMap());
      logger.i(
          'Successfully set produce data for user $_selectedUserId at ${formattedCoopId}_FarmerProduce/$_selectedUserId/submissions/${produceData.submissionId}');

      await _logActivity(
          'Added produce $amount kg for user $_selectedUserId in cooperative $_cooperativeName');
      setState(() {
        _feedbackMessage =
            'Produce submission of $amount kg added successfully';
        _produceAmountController.clear();
        _selectedUserId = null;
      });
    } catch (e, stackTrace) {
      logger.e(
          'Error adding produce submission: $e\nStack trace: $stackTrace\nPath: ${formattedCoopId}_FarmerProduce/$_selectedUserId/submissions');
      setState(() {
        _feedbackMessage = 'Error adding produce submission: $e';
      });
    }
  }

  Future<void> _editProduceSubmission(
      String userId, String submissionId, double currentAmount) async {
    String formattedCoopId = _cooperativeName!.replaceAll(' ', '_');
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
      String formattedCoopId = _cooperativeName!.replaceAll(' ', '_');
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
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCurrencyAnimation(),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      'View Price List',
                      Icons.list_alt,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PriceListScreen(
                                cooperativeName: _cooperativeName!),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      'Add Variety Price',
                      Icons.add_circle_outline,
                      () async {
                        await _showAddVarietyDialog(context);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      'Add Produce Submission',
                      Icons.add_box,
                      () => _showAddProduceDialog(context),
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      'View Submission Data',
                      Icons.table_chart,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmissionListScreen(
                                cooperativeName: _cooperativeName!),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildProduceTable(),
                  ],
                ),
              ),
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
            fontSize: 48,
            color: const Color.fromRGBO(121, 85, 72, 1.0),
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

  Widget _buildOptionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown[100]!, Colors.brown[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(121, 85, 72, 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: coffeeBrown),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: coffeeBrown,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProduceTable() {
    if (_cooperativeName == null || _selectedUserId == null) {
      return const Center(
        child: Text(
          'Select a user to view their submissions.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    String formattedCoopId = _cooperativeName!.replaceAll(' ', '_');
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
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      _editProduceSubmission(
                          data.id, data.submissionId, data.totalAmount);
                    },
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _showAddProduceDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Produce Submission'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUserId,
                      hint: const Text('Select User'),
                      items: _userDetails.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['fullName']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                user['phoneNumber']!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _userDetails.map<Widget>((user) {
                          return Text(
                            user['fullName']!,
                            style: const TextStyle(fontSize: 16),
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedUserId = value;
                          logger.i('Selected userId: $value');
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _produceAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (kg)',
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
                    Navigator.pop(dialogContext);
                    _addProduceSubmission();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
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
              if (price == null || price < 0) {
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
        String formattedCoopId = _cooperativeName!.replaceAll(' ', '_');
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
              if (price == null || price < 0) {
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
        String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
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
        String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
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

    String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
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
  List<String> _submissionDates = [];

  @override
  void initState() {
    super.initState();
    _fetchUsersAndDates();
  }

  Future<void> _fetchUsersAndDates() async {
    try {
      String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
      // Fetch users
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopId}_users')
          .get();
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

      // Fetch unique submission dates for the specific cooperative
      _submissionDates = [];
      for (var user in _userDetails) {
        QuerySnapshot submissionSnapshot = await FirebaseFirestore.instance
            .collection('${formattedCoopId}_FarmerProduce')
            .doc(user['id'])
            .collection('submissions')
            .where('submissionDate', isGreaterThan: '')
            .orderBy('submissionDate', descending: true)
            .get();
        logger.i(
            'Fetched ${submissionSnapshot.docs.length} submissions for user ${user['id']}');
        var dates = submissionSnapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['submissionDate']
                as String)
            .toSet()
            .toList();
        _submissionDates.addAll(dates);
      }
      _submissionDates = _submissionDates.toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      setState(() {});
    } catch (e, stackTrace) {
      logger.e('Error fetching users or dates: $e\nStack trace: $stackTrace');
      setState(() {
        _feedbackMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _editProduceSubmission(
      String userId, String submissionId, double currentAmount) async {
    String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
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

    String formattedCoopId = widget.cooperativeName.replaceAll(' ', '_');
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
      body: _userDetails.isEmpty || _submissionDates.isEmpty
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

                List<DataColumn> columns = [
                  const DataColumn(
                      label: Text('Farmer Name',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ];
                columns.addAll(_submissionDates.map((date) => DataColumn(
                      label: Text(date,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    )));

                List<DataRow> rows = _userDetails.map((user) {
                  List<DataCell> cells = [
                    DataCell(Text(user['fullName']!)),
                  ];
                  for (String date in _submissionDates) {
                    final submission = submissions.firstWhere(
                      (s) => s.id == user['id'] && s.submissionDate == date,
                      orElse: () => FarmerProduce(
                          id: '',
                          farmerName: '',
                          contact: '',
                          totalAmount: 0.0,
                          timestamp: Timestamp.now(),
                          submissionDate: '',
                          submissionId: ''),
                    );
                    if (submission.id.isNotEmpty) {
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
                                    submission.totalAmount);
                              },
                            ),
                          ],
                        ),
                      ));
                    } else {
                      cells.add(const DataCell(Text('-')));
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
}
