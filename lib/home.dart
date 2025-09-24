import 'dart:async';
import 'package:coffeecore/screens/Cooperative%20Section/coffee_prices.dart';
import 'package:coffeecore/screens/Cooperative%20Section/coop_admin_management_screen.dart';
import 'package:coffeecore/screens/Cooperative%20Section/market_manager_screen.dart';
import 'package:coffeecore/screens/Cooperative%20Section/produce_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/coffee_management_screen.dart';
import 'package:coffeecore/screens/Field%20Data/coffee_soil_home_page.dart';
import 'package:coffeecore/screens/admin/admin_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:coffeecore/models/user_model.dart';
import 'package:coffeecore/screens/learn_coffee_farming.dart';
import 'package:coffeecore/screens/manuals_screen.dart';
import 'package:coffeecore/screens/pests_diseases_home.dart';
import 'package:coffeecore/screens/user_profile.dart';
import 'package:coffeecore/screens/weather_screen.dart';
import 'package:coffeecore/authentication/login.dart';
import 'package:coffeecore/settings/notifications_settings_screen.dart';
import 'package:coffeecore/settings/settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  Uint8List? _profileImageBytes;
  bool _isMainAdmin = false;
  bool _isCoopAdmin = false;
  bool _isMarketManager = false;
  bool _isCoopRegistered = false;
  String? _cooperativeName;
  final logger = Logger(printer: PrettyPrinter());
  String? _userId;
  List<String> _userCooperatives = [];
  StreamSubscription<User?>? _authSubscription;
  final List<StreamSubscription> _firestoreSubscriptions = [];

  final List<String> _carouselImages = [
    'assets/coffee_weather.jpg',
    'assets/coffee_field_data.jpg',
    'assets/coffee_pestdisease_management.jpg',
    'assets/coffee_funds_management.jpg',
    'assets/coffee_manuals.jpg',
    'assets/coffee_farming_tips.jpg',
    'assets/coffee_soil.jpg',
  ];

  @override
  void initState() {
    super.initState();
    logger.i('HomePage initState called');
    _initializeUserData();
    _listenToAuthState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    for (var subscription in _firestoreSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      await _fetchUserData();
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _fetchUserData({int retryCount = 0, int maxRetries = 3}) async {
    if (_userId == null) return;

    try {
      logger.i('Fetching user data for UID: $_userId');
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_userId)
          .get();
      if (!userSnapshot.exists) {
        logger.w('User document not found in Users collection for UID: $_userId');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User account not found. Please log in again.')),
          );
        }
        return;
      }
      AppUser appUser = AppUser.fromFirestore(
          userSnapshot as DocumentSnapshot<Map<String, dynamic>>, null);

      logger.i('Checking Admin role for UID: $_userId');
      DocumentSnapshot adminSnapshot = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(_userId)
          .get();
      bool isAdmin = adminSnapshot.exists;

      logger.i('Checking CoopAdmin role for UID: $_userId');
      DocumentSnapshot coopAdminSnapshot = await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(_userId)
          .get();
      bool isCoopAdmin = coopAdminSnapshot.exists;
      String? coopAdminCoop = isCoopAdmin
          ? coopAdminSnapshot['cooperative']?.replaceAll('_', ' ')
          : null;

      bool isMarketManager = false;
      bool isCoopRegistered = false;
      String? cooperativeName;
      List<String> userCooperatives = [];

      logger.i('Fetching cooperatives for UID: $_userId');
      QuerySnapshot coopSnapshot =
          await FirebaseFirestore.instance.collection('cooperatives').get();
      for (var coopDoc in coopSnapshot.docs) {
        String coopId = coopDoc.id;
        String formattedCoopName = coopId.replaceAll('_', ' ');
        try {
          logger.i('Checking Market Manager role for coop: $coopId, UID: $_userId');
          DocumentSnapshot managerSnapshot = await FirebaseFirestore.instance
              .collection('${coopId}_marketmanagers')
              .doc(_userId)
              .get();
          if (managerSnapshot.exists) {
            isMarketManager = true;
            cooperativeName = formattedCoopName;
            isCoopRegistered = true;
            userCooperatives.add(coopId);
            break;
          }

          if (!isCoopRegistered) {
            logger.i('Checking cooperative registration for coop: $coopId, UID: $_userId');
            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('${coopId}_users')
                .doc(_userId)
                .get();
            if (userDoc.exists) {
              isCoopRegistered = true;
              cooperativeName = formattedCoopName;
              userCooperatives.add(coopId);
            }
          }
        } catch (e) {
          logger.e('Error checking cooperative $coopId: $e');
        }
      }

      // For MainAdmins, set a default cooperative if none is set
      if (isAdmin && cooperativeName == null && userCooperatives.isNotEmpty) {
        cooperativeName = userCooperatives.first.replaceAll('_', ' ');
      }

      String? profileImageBase64 = appUser.profileImage;
      Uint8List? decodedImage;
      try {
        if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
          decodedImage = base64Decode(profileImageBase64);
        }
      } catch (e) {
        logger.e('Error decoding profile image: $e');
      }

      if (mounted) {
        setState(() {
          _userData = appUser.toMap();
          _profileImageBytes = decodedImage;
          _isMainAdmin = isAdmin;
          _isCoopAdmin = isCoopAdmin;
          _isMarketManager = isMarketManager;
          _isCoopRegistered = isCoopRegistered;
          _cooperativeName = isCoopAdmin
              ? coopAdminCoop
              : (isMarketManager || isCoopRegistered
                  ? cooperativeName
                  : null);
          _userCooperatives = userCooperatives;
          logger.i(
              'Fetched data - UserId: $_userId, UserData: $_userData, IsAdmin: $_isMainAdmin, IsCoopAdmin: $_isCoopAdmin, IsMarketManager: $_isMarketManager, IsCoopRegistered: $_isCoopRegistered, Cooperative: $_cooperativeName, UserCooperatives: $_userCooperatives');
        });
      }
    } catch (e) {
      logger.e('Error fetching user data (attempt ${retryCount + 1}/$maxRetries): $e');
      if (retryCount < maxRetries && e.toString().contains('Unexpected state')) {
        await Future.delayed(const Duration(seconds: 2));
        return _fetchUserData(retryCount: retryCount + 1, maxRetries: maxRetries);
      }
      if (mounted) {
        String errorMsg = 'Error fetching user data. Please try again.';
        if (e.toString().contains('unavailable')) {
          errorMsg = 'Connect to internet to access better features';
        } else if (e.toString().contains('permission-denied')) {
          errorMsg = 'Permission denied. Please contact support.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  void _listenToAuthState() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        logger.i('Auth state changed - User logged in: ${user.uid}');
        if (mounted) {
          setState(() {
            _userId = user.uid;
          });
          _fetchUserData();
          _listenToUserAndRoleStatus();
        }
      } else {
        logger.w('Auth state changed - No user logged in');
      }
    });
  }

  void _listenToUserAndRoleStatus() {
    if (_userId == null) return;

    for (var subscription in _firestoreSubscriptions) {
      subscription.cancel();
    }
    _firestoreSubscriptions.clear();

    _firestoreSubscriptions.add(
      FirebaseFirestore.instance
          .collection('Users')
          .doc(_userId)
          .snapshots()
          .listen((userSnapshot) {
        if (mounted) {
          AppUser appUser = AppUser.fromFirestore(userSnapshot, null);
          setState(() {
            _userData = appUser.toMap();
            _profileImageBytes = appUser.profileImage != null &&
                    appUser.profileImage!.isNotEmpty
                ? base64Decode(appUser.profileImage!)
                : null;
          });
        }
      }, onError: (e) {
        logger.e('Error listening to user data: $e');
      }),
    );

    _firestoreSubscriptions.add(
      FirebaseFirestore.instance
          .collection('Admins')
          .doc(_userId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() => _isMainAdmin = snapshot.exists);
        }
      }, onError: (e) {
        logger.e('Error listening to Admin role: $e');
      }),
    );

    _firestoreSubscriptions.add(
      FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(_userId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _isCoopAdmin = snapshot.exists;
            _cooperativeName = snapshot.exists &&
                    snapshot.data()?['cooperative'] != null
                ? snapshot['cooperative'].replaceAll('_', ' ')
                : _cooperativeName;
            if (snapshot.exists &&
                snapshot.data()?['cooperative'] != null &&
                !_userCooperatives.contains(snapshot['cooperative'])) {
              _userCooperatives.add(snapshot['cooperative']);
            }
          });
        }
      }, onError: (e) {
        logger.e('Error listening to CoopAdmin role: $e');
      }),
    );

    for (String coopId in _userCooperatives) {
      _firestoreSubscriptions.add(
        FirebaseFirestore.instance
            .collection('${coopId}_marketmanagers')
            .doc(_userId)
            .snapshots()
            .listen((snapshot) {
          if (mounted) {
            bool isMarketManager = snapshot.exists;
            String? coopName =
                isMarketManager ? coopId.replaceAll('_', ' ') : _cooperativeName;
            setState(() {
              _isMarketManager = isMarketManager;
              if (isMarketManager) {
                _isCoopRegistered = true;
                _cooperativeName = coopName;
              }
            });
            logger.i(
                'Market Manager status updated for $coopId: $_isMarketManager');
          }
        }, onError: (e) {
          logger.e('Error listening to Market Manager for $coopId: $e');
        }),
      );
    }

    _firestoreSubscriptions.add(
      FirebaseFirestore.instance
          .collection('cooperatives')
          .snapshots()
          .listen((coopSnapshot) async {
        List<String> newCooperatives = [];
        bool foundCoopRegistered = false;
        String? tempCoopName;

        for (var coopDoc in coopSnapshot.docs) {
          String coopId = coopDoc.id;
          String formattedCoopName = coopId.replaceAll('_', ' ');
          if (!_userCooperatives.contains(coopId)) {
            try {
              DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
                  .collection('${coopId}_users')
                  .doc(_userId)
                  .get();
              if (userSnapshot.exists && mounted) {
                newCooperatives.add(coopId);
                foundCoopRegistered = true;
                tempCoopName = formattedCoopName;
              }
            } catch (e) {
              logger.i('Not registered in $coopId: $e');
            }
          }
        }

        if (mounted && newCooperatives.isNotEmpty) {
          setState(() {
            _userCooperatives.addAll(newCooperatives);
            if (foundCoopRegistered && !_isMarketManager && !_isCoopAdmin) {
              _isCoopRegistered = true;
              _cooperativeName = tempCoopName;
            }
          });
        }
      }, onError: (e) {
        logger.e('Error listening to cooperatives: $e');
      }),
    );
  }

  Future<void> _handleLogout() async {
    logger.i('Starting logout process for user: $_userId');
    try {
      logger.i('Canceling ${_firestoreSubscriptions.length} Firestore subscriptions');
      for (var subscription in _firestoreSubscriptions) {
        subscription.cancel();
      }
      _firestoreSubscriptions.clear();
      logger.i('Signing out from Firebase Auth');
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        logger.w('Widget not mounted, skipping navigation');
        return;
      }
      logger.i('Navigating to LoginScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      logger.e('Error logging out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  String _getRoleSubtitle() {
    if (_isMainAdmin) return 'Admin';
    if (_isCoopAdmin) return 'Co-op Admin ($_cooperativeName)';
    if (_isMarketManager) return 'Market Manager ($_cooperativeName)';
    if (_isCoopRegistered) return 'User ($_cooperativeName)';
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.10),
          child: AppBar(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CoffeeCore',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  _getRoleSubtitle(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.brown[700],
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 40),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white, size: 40),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const NotificationsSettingsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 40),
                onPressed: () {},
              ),
            ],
          ),
        ),
        drawer: _buildDrawer(),
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Container(
            color: Colors.grey[200],
            child: Column(
              children: [
                Flexible(
                  child: _buildCarousel(),
                ),
                _buildClickableSections(),
                _buildRoleBasedButtons(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildRoleBasedButtons() {
    logger.i('Building role-based buttons - isMainAdmin: $_isMainAdmin, isCoopAdmin: $_isCoopAdmin, isMarketManager: $_isMarketManager, isCoopRegistered: $_isCoopRegistered, cooperativeName: $_cooperativeName');
    if (_isMainAdmin) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildAdminButton(),
      );
    } else if (_isCoopAdmin) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildCoopAdminButton(),
      );
    } else if (_isMarketManager) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _buildMenuButton(context)),
            const SizedBox(width: 16.0),
            Expanded(child: _buildMarketManagerButton()),
          ],
        ),
      );
    } else if (_isCoopRegistered) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _buildMenuButton(context)),
            const SizedBox(width: 16.0),
            Expanded(child: _buildProduceButton()),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildMenuButton(context),
      );
    }
  }

  Widget _buildAdminButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminManagementScreen()),
        );
      },
      icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
      label: const Text('Admin Management', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        backgroundColor: Colors.brown[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCoopAdminButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const CoopAdminManagementScreen()),
        );
      },
      icon: const Icon(Icons.group, color: Colors.white),
      label: const Text('Co-op Admin Management',
          style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        backgroundColor: Colors.brown[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildMarketManagerButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MarketManagerScreen()),
        );
      },
      icon: const Icon(Icons.storefront_sharp, color: Colors.white),
      label: const Text('Market Operations', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        backgroundColor: Colors.brown[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProduceButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (_cooperativeName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProduceScreen(cooperativeName: _cooperativeName!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cooperative assigned')),
          );
        }
      },
      icon: const Icon(Icons.landscape, color: Colors.white),
      label: const Text('Produce', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        backgroundColor: Colors.brown[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext scaffoldContext) {
    return Builder(
      builder: (context) => ElevatedButton.icon(
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
        icon: const Icon(Icons.menu, color: Colors.white),
        label: const Text('Menu', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          backgroundColor: Colors.brown[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.35,
      child: CarouselSlider(
        options: CarouselOptions(
          height: MediaQuery.of(context).size.height * 0.35,
          autoPlay: true,
          enlargeCenterPage: true,
          aspectRatio: 16 / 9,
          autoPlayCurve: Curves.fastOutSlowIn,
          enableInfiniteScroll: true,
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          viewportFraction: 0.8,
        ),
        items: _carouselImages.map((image) {
          int index = _carouselImages.indexOf(image);
          List<String> labels = [
            'Get Weather Forecasts',
            'Record Coffee Field Data',
            'Manage Pests & Diseases',
            'Manage Coffee Farming',
            'Coffee Farming Manuals',
            'Get Coffee Farming Tips',
            'Explore Coffee Soil Insights',
          ];
          return Stack(
            children: [
              Container(
                margin: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(labels[index],
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClickableSections() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildClickableCard('Coffee Farming Tips', Icons.lightbulb, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LearnCoffeeFarming()));
          }),
          _buildClickableCard('Coffee Prices', Icons.shopping_cart, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CoffeePricesWidget()));
          }),
        ],
      ),
    );
  }

  Widget _buildClickableCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.brown[50],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade500.withAlpha(128),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.brown[700]),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Manuals'),
        BottomNavigationBarItem(icon: Icon(Icons.supervisor_account), label: 'F-Management'),
        BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Tips'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.brown[700],
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        switch (index) {
          case 0:
            // Already on Home (dashboard)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManualsScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CoffeeManagementScreen()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LearnCoffeeFarming()),
            );
            break;
        }
      },
    );
  }

  List<Widget> _buildDrawerItems() {
    List<Widget> items = [
      GestureDetector(
        onTap: () {
          logger.i('Navigating to UserProfileScreen');
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const UserProfileScreen()));
        },
        child: UserAccountsDrawerHeader(
          decoration: BoxDecoration(color: Colors.brown[700]),
          accountName: Text(
            _userData?['fullName'] ?? 'Loading...',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: _profileImageBytes != null
                ? ClipOval(
                    child: Image.memory(
                      _profileImageBytes!,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, size: 40, color: Colors.brown[700]),
                    ),
                  )
                : Icon(Icons.person, size: 40, color: Colors.brown[700]),
          ),
          accountEmail: null,
        ),
      ),
      _buildDrawerItem(Icons.home, 'Home', () {
        Navigator.pop(context);
        setState(() {});
      }),
      _buildDrawerItem(Icons.cloud, 'Weather', () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WeatherScreen()));
      }),
      _buildDrawerItem(Icons.input, 'Field Data (Soil)', () {
        logger.i('Navigating to CoffeeSoilHomePage, userId: $_userId');
        if (_userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CoffeeSoilHomePage()),
          );
        } else {
          logger.w('User ID is null, attempting refresh');
          _fetchUserData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID not available. Retrying...')),
          );
        }
      }),
      _buildDrawerItem(Icons.pest_control, 'Pests & Diseases', () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PestDiseaseHomePage()));
      }),
    ];

    // Add Produce item for Admins, CoopAdmins, and MarketManagers
    if (_isMainAdmin || _isCoopAdmin || _isMarketManager) {
      items.add(_buildDrawerItem(Icons.landscape, 'Produce', () {
        logger.i('Navigating to ProduceScreen with cooperative: $_cooperativeName');
        String? coopName = _cooperativeName ??
            (_userCooperatives.isNotEmpty
                ? _userCooperatives.first.replaceAll('_', ' ')
                : null);
        if (coopName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProduceScreen(cooperativeName: coopName)),
          );
        } else {
          logger.w('No cooperative assigned for ProduceScreen navigation');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cooperative assigned')),
          );
        }
      }));
    }

    items.addAll([
      _buildDrawerItem(Icons.supervisor_account, 'Farm Management', () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CoffeeManagementScreen()));
      }),
      _buildDrawerItem(Icons.book, 'Coffee Manuals', () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManualsScreen()));
      }),
      _buildDrawerItem(Icons.settings, 'Settings', () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsScreen()));
      }),
      _buildDrawerItem(Icons.logout, 'Logout', _handleLogout),
    ]);

    return items;
  }

  Widget _buildDrawer() {
    logger.i('Building drawer - isMainAdmin: $_isMainAdmin, isCoopAdmin: $_isCoopAdmin, isMarketManager: $_isMarketManager, cooperativeName: $_cooperativeName');
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: _buildDrawerItems(),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        logger.i('Drawer item tapped: $title');
        try {
          onTap();
        } catch (e, stackTrace) {
          logger.e('Error navigating from drawer item $title: $e\nStack trace: $stackTrace');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error navigating to $title: $e')),
          );
        }
      },
    );
  }
}