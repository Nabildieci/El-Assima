import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'scanner_screen.dart';
import 'members_list_screen.dart';
import 'history_screen.dart';
import 'data_manager.dart';
import 'order_screen.dart';
import 'admin_orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialisation Firebase avec options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Lancement du seeding en arrière-plan (non bloquant)
    DataManager.seedInitialMembers().catchError((e) => print(e));
  } catch (e) {
    print("Erreur Firebase: $e");
  }
  runApp(const ClubApp()); // Votre application continue de tourner même si Firebase a un souci
}

class ClubApp extends StatelessWidget {
  const ClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASSIMA-10',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD32F2F), // Rouge USMA
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
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0x33D32F2F), // Translucent red
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD32F2F), // Rouge USMA
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
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Color(0x33D32F2F),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ScannerScreen(),
    const MembersListScreen(),
    const OrderScreen(),
    const AdminOrdersScreen(), // New Admin Tab
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'EL ASSIMA', 
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900, 
                letterSpacing: 3.5,
                fontSize: 20,
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
            opacity: 0.25, // Translucent enough for readability
          ),
        ),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'ZONES',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'BOUTIQUE',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'ADMIN',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
