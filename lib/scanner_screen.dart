import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';


class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isCameraInitialized = false;
  bool _isScanning = false;
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _scanResult = "Placez la carte dans l'objectif et lancez l'analyse.";


  
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;


  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _scanResult = "Aucune caméra trouvée.");
        return;
      }
      
      // Try to find the back camera by default if not already selected
      if (_cameraController == null) {
        for (int i = 0; i < _cameras.length; i++) {
          if (_cameras[i].lensDirection == CameraLensDirection.back) {
            _selectedCameraIndex = i;
            break;
          }
        }
      }

      final camera = _cameras[_selectedCameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.veryHigh, // Higher resolution for better OCR
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (mounted) setState(() => _scanResult = "Veuillez autoriser l'accès à la caméra.");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _isCameraInitialized = false;
    });
    _initializeCamera();
  }

  Future<void> _scanImage() async {
    if (kIsWeb) {
      setState(() => _scanResult = "⚠️ Le scanner OCR n'est pas supporté sur la version Web. Veuillez utiliser l'application Android.");
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResult = "Analyse en cours via OCR...";
    });

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String extracted = recognizedText.text;
      
      if (extracted.trim().isNotEmpty) {
        // Collect all potential card candidates from the text
        final allText = extracted.toUpperCase();
        final words = allText.split(RegExp(r'[\s\n\-\.\,]+'));
        
        List<String> candidates = [];
        
        // Strategy 1: Look for exact Matricule pattern (e.g. AC001, AC010)
        final matriculeRegex = RegExp(r'[A-Z]+[0-9]{1,5}'); // More flexible: 1 to 5 digits
        final matches = matriculeRegex.allMatches(allText);
        for (var match in matches) {
          candidates.add(match.group(0)!);
        }

        // Strategy 2: Collect other alphanumeric strings of length 3-10
        for (var word in words) {
          final clean = word.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (clean.length >= 3 && clean.length <= 10 && !candidates.contains(clean)) {
            candidates.add(clean);
          }
        }

        if (candidates.isNotEmpty) {
          await _verifyMember(candidates, fullText: extracted);
        } else {
          await _verifyMember([extracted.trim()], fullText: extracted);
        }
      } else {
        setState(() {
          _scanResult = "❌ Aucun texte détecté. Rapprochez la carte.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanResult = "Erreur OCR : $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _showManualSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recherche Manuelle"),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: "Matricule (Ex: AC010)",
            hintText: "Ex de matricule : AC010",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, searchController.text.trim()),
            child: const Text("RECHERCHER"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _verifyMember([result]);
    }
  }

  Future<void> _verifyMember(List<String> candidates, {String? fullText}) async {
    try {
      String? foundName;
      String? foundZone;
      String? foundMatricule;
      DocumentSnapshot? foundDoc;
      
      setState(() {
        _scanResult = "Vérification en cours...";
      });

      // 1. Try exact matches for all candidates
      for (var rawId in candidates) {
        final searchId = rawId.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
        if (searchId.isEmpty) continue;

        var querySnapshot = await FirebaseFirestore.instance
            .collection('members')
            .where('cardId', isEqualTo: searchId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          foundDoc = querySnapshot.docs.first;
          break;
        }
        
        // Also try searching by 'matricule' field specifically
        querySnapshot = await FirebaseFirestore.instance
            .collection('members')
            .where('matricule', isEqualTo: searchId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          foundDoc = querySnapshot.docs.first;
          break;
        }
      }

      // 2. Fallback: Fuzzy searching by name in the full text
      if (foundDoc == null && fullText != null) {
        final normalizedFull = fullText.toLowerCase();
        final allMembers = await FirebaseFirestore.instance.collection('members').get();
        
        for (var doc in allMembers.docs) {
          final fullName = (doc.data()['name'] ?? '').toString().toLowerCase();
          if (fullName.length < 4) continue;
          
          if (normalizedFull.contains(fullName)) {
            foundDoc = doc;
            break;
          }
          
          // Partial name matching
          final nameParts = fullName.split(' ').where((s) => s.length > 3).toList();
          if (nameParts.isNotEmpty) {
            int matches = 0;
            for (var part in nameParts) {
              if (normalizedFull.contains(part)) matches++;
            }
            if (matches >= nameParts.length) {
              foundDoc = doc;
              break;
            }
          }
        }
      }

      if (foundDoc != null) {
        final data = foundDoc.data() as Map<String, dynamic>;
        foundName = data['name'] ?? 'Supporter';
        foundZone = (data['zone'] ?? '?').toString();
        foundMatricule = data['matricule'] ?? data['cardId'] ?? '?';
        
        final bool isAlreadyPresent = data['is_present'] ?? false;
        
        if (isAlreadyPresent) {
          if (mounted) {
            HapticFeedback.vibrate();
            setState(() {
              _showErrorOverlay = true;
              _scanResult = "⚠️ DÉJÀ ENTRÉ !\n\nNOM : $foundName\nMATRICULE : $foundMatricule\nZONE : $foundZone";
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _showErrorOverlay = false);
            });
          }
          return;
        }

        await foundDoc.reference.update({
          'is_present': true,
          'last_scanned': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('scans_history').add({
          'name': foundName,
          'cardId': foundMatricule,
          'zone': foundZone,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          HapticFeedback.vibrate();
          setState(() {
            _showSuccessOverlay = true;
            _scanResult = "✅ $foundName\nZONE : $foundZone\nMATRICULE : $foundMatricule";
          });
          
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showSuccessOverlay = false);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _showErrorOverlay = true;
            final bestAttempt = candidates.isNotEmpty ? candidates.first : "?";
            _scanResult = "❌ AUCUN MEMBRE TROUVÉ\n\nMatricule détecté : $bestAttempt\n\nVérifiez la carte ou essayez la recherche manuelle.";
          });
          
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _showErrorOverlay = false);
          });
        }
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _scanResult = "Erreur système : $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Initialisation de la caméra...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),
                // Decorative Frame
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (_showSuccessOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.green.withOpacity(0.6),
                      child: const Center(
                        child: Icon(Icons.check_circle, color: Colors.white, size: 100),
                      ),
                    ),
                  ),
                if (_showErrorOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.red.withOpacity(0.6),
                      child: const Center(
                        child: Icon(Icons.cancel, color: Colors.white, size: 100),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      if (_cameras.length > 1)
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            onPressed: _toggleCamera,
                          ),
                        ),
                      const SizedBox(height: 10),
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _showManualSearchDialog,
                          tooltip: "Recherche manuelle",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _scanResult,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _scanResult.contains("✅") ? 28 : 16,
                        letterSpacing: 0.5,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                        color: _scanResult.contains("✅") 
                            ? Colors.green.shade700 
                            : (_scanResult.contains("❌") || _scanResult.contains("⚠️") ? Colors.red : Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanImage,
                  icon: _isScanning 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.document_scanner),
                  label: Text(_isScanning ? 'Scan en cours...' : 'Analyser la carte'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
