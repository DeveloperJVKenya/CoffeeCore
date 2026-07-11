import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class CoffeePricesWidget extends StatefulWidget {
  const CoffeePricesWidget({super.key});

  @override
  CoffeePricesWidgetState createState() => CoffeePricesWidgetState();
}

class CoffeePricesWidgetState extends State<CoffeePricesWidget> {
  final logger = Logger(printer: PrettyPrinter());
  String? _selectedCooperative;
  String? _selectedCoffeeVariety;
  double? _predictedPrice;
  bool _isLoading = false;
  bool _isCoopSelected = false;

  static final Color coffeeBrown = Colors.brown[700]!;

  Future<List<String>> _fetchCooperatives() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('cooperatives').get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<List<String>> _fetchVarieties() async {
    if (_selectedCooperative == null) return [];
    String formattedCoopId = _selectedCooperative!.replaceAll(' ', '_');
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('${formattedCoopId}_coffeeprices')
        .get();
    return snapshot.docs
        .map((doc) => doc['variety'] as String)
        .toSet()
        .toList();
  }

  Future<bool> _checkIfUserInCooperative() async {
    if (_userId == null) return false;
    final coopDocs =
        await FirebaseFirestore.instance.collection('cooperatives').get();
    for (var doc in coopDocs.docs) {
      String formattedCoopName = doc['name'].replaceAll(' ', '_');
      final userDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(_userId)
          .get();
      if (userDoc.exists) {
        setState(() {
          _selectedCooperative = doc['name'];
          _isCoopSelected = true;
        });
        return true;
      }
    }
    return false;
  }

  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _checkIfUserInCooperative();
  }

  Future<void> _registerUserToCooperative(String cooperative) async {
    if (_userId == null) {
      _showLogger('Please log in to select a cooperative.');
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_userId)
          .get();
      if (!userDoc.exists) throw 'User not found';
      final userData = userDoc.data() as Map<String, dynamic>;
      String formattedCoopName = cooperative.replaceAll(' ', '_');

      await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(_userId)
          .set({
        'fullName': userData['fullName'] ?? '',
        'county': userData['county'] ?? '',
        'constituency': userData['constituency'] ?? '',
        'ward': userData['ward'] ?? '',
        'phoneNumber': userData['phoneNumber'] ?? '',
        'email': userData['email'] ?? '',
        'uid': _userId,
      });
      setState(() {
        _isCoopSelected = true;
        _selectedCooperative = cooperative;
      });
      _showLogger('Successfully registered to $cooperative!');
    } catch (e) {
      logger.e('Error registering to cooperative: $e');
      _showLogger('Error registering to cooperative: $e');
    }
  }

  void _showPredictedPrice() async {
    if (_selectedCooperative == null || _selectedCoffeeVariety == null) {
      _showLogger('Please select a cooperative and coffee variety.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      String formattedCoopId = _selectedCooperative!.replaceAll(' ', '_');
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopId}_coffeeprices')
          .doc(_selectedCoffeeVariety)
          .get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _predictedPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      } else {
        _showLogger(
            'No price available for $_selectedCoffeeVariety in $_selectedCooperative.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      logger.e('Error fetching price: $e');
      _showLogger('Error fetching price: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showLogger(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.brown[50],
        textTheme: TextTheme(
          bodyMedium: const TextStyle(color: Colors.black87),
          titleLarge:
              TextStyle(color: coffeeBrown, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: coffeeBrown,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coffee Prices',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          elevation: 0,
          backgroundColor: coffeeBrown,
          foregroundColor: Colors.white,
        ),
        body: Container(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<List<String>>(
                  future: _fetchCooperatives(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No cooperatives added yet.');
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCooperative,
                      items: snapshot.data!
                          .map((coop) =>
                              DropdownMenuItem(value: coop, child: Text(coop)))
                          .toList(),
                      onChanged: _isCoopSelected
                          ? null
                          : (value) {
                              setState(() {
                                _selectedCooperative = value;
                                _selectedCoffeeVariety =
                                    null; // Reset variety when coop changes
                                _predictedPrice = null; // Reset price
                              });
                              _registerUserToCooperative(value!);
                            },
                      decoration: InputDecoration(
                        labelText: 'Select Cooperative',
                        prefixIcon: Icon(Icons.group, color: coffeeBrown),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        enabled: !_isCoopSelected,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<String>>(
                  future: _fetchVarieties(),
                  builder: (context, varietySnapshot) {
                    if (varietySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (!varietySnapshot.hasData ||
                        varietySnapshot.data!.isEmpty) {
                      return const Text(
                          'No varieties available for this cooperative.');
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCoffeeVariety,
                      items: varietySnapshot.data!
                          .map((variety) => DropdownMenuItem(
                              value: variety, child: Text(variety)))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedCoffeeVariety = value;
                        _predictedPrice =
                            null; // Reset price when variety changes
                      }),
                      decoration: InputDecoration(
                        labelText: 'Select Coffee Variety',
                        prefixIcon: Icon(Icons.local_cafe, color: coffeeBrown),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showPredictedPrice,
                  icon: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.visibility, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Loading...' : 'Show Price',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                if (_predictedPrice != null)
                  Row(
                    children: [
                      Icon(Icons.price_check, color: coffeeBrown, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Price: Ksh ${_predictedPrice!.toStringAsFixed(2)}/kg',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
