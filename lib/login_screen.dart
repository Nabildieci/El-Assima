import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool isAdmin) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _error = "";

  void _checkPin() {
    final code = _pinController.text;
    if (code == "2020") {
      widget.onLoginSuccess(true); // Is Admin
    } else if (code == "0101") {
      widget.onLoginSuccess(false); // Is Standard User
    } else {
      setState(() {
        _error = "Code incorrect. Veuillez réessayer.";
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.red.shade900],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/images/logo_2.jpg', height: 100),
            ),
            const SizedBox(height: 30),
            const Text(
              "ACCÈS SÉCURISÉ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Entrez le code d'accès EL ASSIMA",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            
            // PIN Input
            Container(
              width: 200,
              child: TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 10),
                decoration: InputDecoration(
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  hintText: "••••",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                onChanged: (val) {
                  if (val.length == 4) _checkPin();
                },
              ),
            ),
            
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(_error, style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
              ),
              
            const SizedBox(height: 60),
            
            ElevatedButton(
              onPressed: _checkPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("ENTRER", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
