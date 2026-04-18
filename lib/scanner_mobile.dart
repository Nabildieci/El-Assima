import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ScannerPlatformImplementation extends StatefulWidget {
  const ScannerPlatformImplementation({super.key});

  @override
  State<ScannerPlatformImplementation> createState() => _ScannerPlatformImplementationState();
}

class _ScannerPlatformImplementationState extends State<ScannerPlatformImplementation> {
  bool _isProcessing = false;
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _scanResult = "Appuyez sur SCAN pour commencer";

  Future<void> _scanNative() async {
    if (_isProcessing) return;
    try {
      final barcode = await FlutterBarcodeScanner.scanBarcode(
          '#D32F2F', 'ANNULER', true, ScanMode.BARCODE);
          
      if (barcode != '-1' && barcode.trim().isNotEmpty) {
         if (mounted) setState(() => _isProcessing = true);
         await _verifyMember(barcode.trim().toUpperCase());
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du lancement du scanner.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _verifyMember(String searchId) async {
    try {
      if (searchId.length < 3) return;

      final docRef = await FirebaseFirestore.instance.collection('members').doc(searchId).get();
      
      if (!docRef.exists) {
        if (mounted) {
          setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ MEMBRE INTROUVABLE !\nMatricule: $searchId";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() { 
              _showErrorOverlay = false;
              _scanResult = "Appuyez sur SCAN pour commencer";
            });
          });
        }
        return;
      }

      final data = docRef.data() as Map<String, dynamic>;
      final String foundName = data['name'] ?? 'Supporter';
      final String foundZone = (data['zone'] ?? '?').toString();
      
      if (data['is_present'] ?? false) {
        HapticFeedback.vibrate();
        if (mounted) setState(() {
          _showErrorOverlay = true;
          _scanResult = "⚠️ DÉJÀ ENTRÉ !\n$foundName ($searchId)";
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() {
            _showErrorOverlay = false;
            _scanResult = "Appuyez sur SCAN pour commencer";
          });
        });
        return;
      }

      await docRef.reference.update({
        'is_present': true, 
        'last_scanned': FieldValue.serverTimestamp()
      });
      
      await FirebaseFirestore.instance.collection('scans_history').add({
        'name': foundName,
        'cardId': docRef.id,
        'zone': foundZone,
        'timestamp': FieldValue.serverTimestamp(),
      });

      HapticFeedback.heavyImpact();
      if (mounted) setState(() {
        _showSuccessOverlay = true;
        _scanResult = "✅ BIENVENU $foundName";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() {
           _showSuccessOverlay = false;
           _scanResult = "Appuyez sur SCAN pour commencer";
        });
      });
      
      // Relancer le scan automatiquement si on veut un flow rapide :
      // Future.delayed(const Duration(seconds: 1), () => _scanNative());
      
    } catch (e) {
      debugPrint("Verify Error: $e");
      if (mounted) {
          setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ ERREUR RESEAU !";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() {
              _showErrorOverlay = false;
              _scanResult = "Appuyez sur SCAN pour commencer";
            });
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey.shade900;
    if (_showSuccessOverlay) statusColor = Colors.green.shade800;
    if (_showErrorOverlay) statusColor = Colors.red.shade900;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
                ]
              ),
              child: _isProcessing 
                ? const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Vérification...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ],
                  )
                : Text(
                    _scanResult,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
            ),
            
            const SizedBox(height: 50),
            
            // Scan Button
            GestureDetector(
              onTap: _scanNative,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 40, spreadRadius: 10)
                  ],
                  border: Border.all(color: Colors.red, width: 8)
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 70, color: Colors.black),
                    SizedBox(height: 10),
                    Text("SCANNER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
             // Manual Entry Button
            TextButton.icon(
              onPressed: () async {
                final TextEditingController searchController = TextEditingController();
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Entrer Matricule"),
                    content: TextField(
                      controller: searchController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: "Ex: AC010"),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, searchController.text.trim().toUpperCase()),
                        child: const Text("Valider", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  if (mounted) setState(() => _isProcessing = true);
                  await _verifyMember(result);
                }
              },
              icon: const Icon(Icons.keyboard, color: Colors.white54),
              label: const Text("SAISIE MANUELLE", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
