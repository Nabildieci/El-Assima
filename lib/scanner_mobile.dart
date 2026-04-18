import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ScannerPlatformImplementation extends StatefulWidget {
  const ScannerPlatformImplementation({super.key});

  @override
  State<ScannerPlatformImplementation> createState() => _ScannerPlatformImplementationState();
}

class _ScannerPlatformImplementationState extends State<ScannerPlatformImplementation> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _manualController = TextEditingController();
  
  bool _isProcessing = false;
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _scanResult = "Appuyez sur SCAN pour scanner la carte";
  
  Set<String> _validMembersList = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }
  
  Future<void> _loadMembers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('members').get();
      _validMembersList = snapshot.docs.map((d) => d.id.toUpperCase()).toSet();
    } catch (e) {
      debugPrint("Load members error: $e");
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _scanNative() async {
    if (_isProcessing) return;
    
    try {
      if (mounted) setState(() => _isProcessing = true);
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, 
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      
      final InputImage inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Recharger la liste si vide
      if (_validMembersList.isEmpty) await _loadMembers();

      String? foundMatricule;
      final fullText = recognizedText.text.toUpperCase();
      
      // 1. Oter les espaces pour la vérification robuste
      final cleanText = fullText.replaceAll(RegExp(r'\s+'), '');
      
      // 2. Tenter l'extraction intelligente par motif (2 lettres suivies de chiffres, ex: AC010)
      // On prend aussi en compte les "O" de l'OCR vus comme des zéros
      final regex = RegExp(r'([A-Z]{2})([O0-9]{2,4})');
      final match = regex.firstMatch(cleanText);
      if (match != null) {
         // Reconvertir le potentiel 'O' lu par erreur en '0' pour les matricules
         foundMatricule = match.group(1)! + match.group(2)!.replaceAll('O', '0').replaceAll('Q', '0');
      }
      
      // 3. Fallback : Vérifier par présence stricte si le regex rate
      if (foundMatricule == null) {
        if (_validMembersList.isEmpty) await _loadMembers();
        for (String validId in _validMembersList) {
          if (cleanText.contains(validId) || fullText.contains(validId)) {
            foundMatricule = validId;
            break;
          }
        }
      }

      if (foundMatricule != null) {
        await _verifyMember(foundMatricule);
      } else {
        if (mounted) {
          setState(() {
            _showErrorOverlay = true;
            // On affiche ce que l'IA a lu pour comprendre l'erreur
            String lu = cleanText.length > 30 ? "${cleanText.substring(0, 30)}..." : cleanText;
            _scanResult = "⚠️ INTROUVABLE !\nTexte lu par l'IA :\n$lu";
            _isProcessing = false;
          });
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) setState(() { 
              _showErrorOverlay = false;
              _scanResult = "Appuyez sur SCAN pour scanner la carte";
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Caméra: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _verifyMember(String searchId) async {
    try {
      if (searchId.length < 3) return;

      final docRef = await FirebaseFirestore.instance.collection('members').doc(searchId).get();
      
      if (!docRef.exists) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _showErrorOverlay = true;
            _scanResult = "⚠️ MEMBRE INTROUVABLE !\nMatricule: $searchId";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() { 
              _showErrorOverlay = false;
              _scanResult = "Appuyez sur SCAN pour scanner la carte";
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
          _isProcessing = false;
          _showErrorOverlay = true;
          _scanResult = "⚠️ DÉJÀ ENTRÉ !\n$foundName ($searchId)";
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() {
            _showErrorOverlay = false;
            _scanResult = "Appuyez sur SCAN pour scanner la carte";
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
        _isProcessing = false;
        _showSuccessOverlay = true;
        _scanResult = "✅ BIENVENU $foundName";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() {
           _showSuccessOverlay = false;
           _scanResult = "Appuyez sur SCAN pour scanner la carte";
        });
      });
      
    } catch (e) {
      debugPrint("Verify Error: $e");
      if (mounted) {
          setState(() {
            _isProcessing = false;
            _showErrorOverlay = true;
            _scanResult = "⚠️ ERREUR RESEAU !";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() {
              _showErrorOverlay = false;
              _scanResult = "Appuyez sur SCAN pour scanner la carte";
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
                      Text("Lecture de la carte...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ],
                  )
                : Text(
                    _scanResult,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
            ),
            
            const SizedBox(height: 50),
            
            // Scan Photo Button
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
                    Icon(Icons.document_scanner_outlined, size: 70, color: Colors.black),
                    SizedBox(height: 10),
                    Text("PHOTOGRAPHIER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Persistent Manual Entry
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10)
              ),
              child: Column(
                children: [
                   const Text("SAISIE MANUELLE", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                   const SizedBox(height: 15),
                   TextField(
                      controller: _manualController,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: "ExCode: AC010",
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 18),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 35),
                          onPressed: () {
                            if (_manualController.text.isNotEmpty) {
                              if (mounted) setState(() => _isProcessing = true);
                              _verifyMember(_manualController.text.trim().toUpperCase());
                              _manualController.clear();
                            }
                          },
                        )
                      ),
                      onSubmitted: (val) {
                        if (val.isNotEmpty) {
                          if (mounted) setState(() => _isProcessing = true);
                          _verifyMember(val.trim().toUpperCase());
                          _manualController.clear();
                        }
                      },
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
