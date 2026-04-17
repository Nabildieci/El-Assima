import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'scanner_screen.dart';
import 'members_list_screen.dart';
import 'history_screen.dart';
import 'data_manager.dart';
import 'order_screen.dart';
import 'admin_orders_screen.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    DataManager.seedInitialMembers().catchError((e) => print(e));
  } catch (e) {
    print("Erreur Firebase: $e");
  }
  runApp(const ClubApp());
}

class ClubApp extends StatefulWidget {
  const ClubApp({super.key});

  @override
  State<ClubApp> createState() => _ClubAppState();
}

class _ClubAppState extends State<ClubApp> {
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EL ASSIMA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD32F2F),
          onPrimary: Colors.white,
          secondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD32F2F),
          onPrimary: Colors.white,
          secondary: Colors.grey,
          surface: Color(0xFF121212),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: _isAuthenticated 
        ? MainScreen(isAdmin: _isAdmin, onLogout: _onLogout) 
        : LoginScreen(onLoginSuccess: (isAdmin) {
            setState(() {
              _isAdmin = isAdmin;
              _isAuthenticated = true;
            });
          }),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.isAdmin, required this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [];
    final List<NavigationDestination> destinations = [];

    if (widget.isAdmin) {
      // Admin: Access to everything
      pages.addAll([
        const ScannerScreen(),
        MembersListScreen(isAdmin: true),
        const OrderScreen(),
        const AdminOrdersScreen(isAdmin: true),
        const HistoryScreen(isAdmin: true),
      ]);
      destinations.addAll([
        const NavigationDestination(icon: Icon(Icons.qr_code_scanner), selectedIcon: Icon(Icons.camera_alt, color: Colors.red), label: 'Scanner'),
        const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: Colors.red), label: 'ZONES'),
        const NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag, color: Colors.red), label: 'BOUTIQUE'),
        const NavigationDestination(icon: Icon(Icons.shopping_cart_checkout_outlined), selectedIcon: Icon(Icons.shopping_cart_checkout, color: Colors.red), label: 'COMMANDE'),
        const NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: Colors.red), label: 'Historique'),
      ]);
    } else {
      // User 0101: ONLY BOUTIQUE (Zones removed as requested)
      pages.add(const OrderScreen());
      destinations.add(const NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag, color: Colors.red), label: 'BOUTIQUE'));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('assets/images/logo_2.jpg', height: 45),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/arriere_plan.jpg"),
            fit: BoxFit.cover,
            opacity: 0.10,
          ),
        ),
        child: pages[_currentIndex],
      ),
      // Hide bottom navigation if only one tab is available
      bottomNavigationBar: destinations.length > 1 ? NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        indicatorColor: Colors.red.withOpacity(0.2),
        destinations: destinations,
      ) : null,
    );
  }
}
