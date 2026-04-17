import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        ? MainScreen(isAdmin: _isAdmin) 
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
  const MainScreen({super.key, required this.isAdmin});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Hide scanner on Web since it doesn't work well
    final List<Widget> pages = [
      const ScannerScreen(),
      MembersListScreen(isAdmin: widget.isAdmin),
      const OrderScreen(),
      AdminOrdersScreen(isAdmin: widget.isAdmin),
      const HistoryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(2),
                child: Image.asset('assets/images/logo_2.jpg', height: 31, width: 31, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'EL ASSIMA', 
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900, 
                letterSpacing: 2,
                fontSize: 18,
              )
            ),
          ],
        ),
        elevation: 0,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        indicatorColor: Colors.red.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.camera_alt, color: Colors.red),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Colors.red),
            label: 'ZONES',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag, color: Colors.red),
            label: 'BOUTIQUE',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_checkout_outlined),
            selectedIcon: Icon(Icons.shopping_cart_checkout, color: Colors.red),
            label: 'COMMANDE', 
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Colors.red),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
