import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        ResolutionPreset.high,
        enableAudio: false,
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
      
      // Real checking logic
      if (extracted.trim().isNotEmpty) {
        await _verifyMember(extracted.trim());
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

  Future<void> _verifyMember(String rawData) async {
    try {
      // Normalize rawData for searching (e.g. searching by ID or Name)
      // Usually membership cards have a unique ID or a specific format.
      // We search in the 'members' collection.
      
      // Search by cardId
      var querySnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('cardId', isEqualTo: rawData)
          .get();

      // If not found by ID, try searching by name within the text
      if (querySnapshot.docs.isEmpty) {
        final allMembers = await FirebaseFirestore.instance.collection('members').get();
        for (var doc in allMembers.docs) {
          final name = (doc.data()['name'] ?? '').toString().toLowerCase();
          if (rawData.toLowerCase().contains(name) || name.contains(rawData.toLowerCase())) {
            querySnapshot = await FirebaseFirestore.instance.collection('members').where(FieldPath.documentId, isEqualTo: doc.id).get();
            break;
          }
        }
      }

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final String name = data['name'] ?? 'Supporter';
        final dynamic zone = data['zone'] ?? '?';
        
        // Update presence
        await doc.reference.update({
          'is_present': true,
          'last_scanned': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _scanResult = "✓ Membre reconnu :\n\nNOM : $name\nZONE : $zone\nBIENVENU AU STADE !";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _scanResult = "❌ Membre non trouvé dans la base.\nScan: $rawData";
          });
        }
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _scanResult = "Erreur base de données : $e";
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
                if (_cameras.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: _toggleCamera,
                      ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _scanResult.contains("✓") 
                            ? Colors.green 
                            : (_scanResult.contains("❌") ? Colors.red : Colors.black87),
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
