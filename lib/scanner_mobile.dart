import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class ScannerPlatformImplementation extends StatefulWidget {
  const ScannerPlatformImplementation({super.key});

  @override
  State<ScannerPlatformImplementation> createState() => _ScannerPlatformImplementationState();
}

class _ScannerPlatformImplementationState extends State<ScannerPlatformImplementation> {
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
        ResolutionPreset.veryHigh,
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
    setState(() => _isCameraInitialized = false);
    _initializeCamera();
  }

  Future<void> _scanImage() async {
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
        final allText = extracted.toUpperCase();
        final words = allText.split(RegExp(r'[\s\n\-\.\,]+'));
        
        List<String> candidates = [];
        final matriculeRegex = RegExp(r'[A-Z]+[0-9]{1,5}');
        final matches = matriculeRegex.allMatches(allText);
        for (var match in matches) candidates.add(match.group(0)!);

        for (var word in words) {
          final clean = word.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (clean.length >= 3 && clean.length <= 10 && !candidates.contains(clean)) candidates.add(clean);
        }

        await _verifyMember(candidates.isNotEmpty ? candidates : [extracted.trim()], fullText: extracted);
      } else {
        setState(() => _scanResult = "❌ Aucun texte détecté. Rapprochez la carte.");
      }
    } catch (e) {
      if (mounted) setState(() => _scanResult = "Erreur OCR : $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _verifyMember(List<String> candidates, {String? fullText}) async {
    try {
      DocumentSnapshot? foundDoc;
      setState(() => _scanResult = "Vérification en cours...");

      for (var rawId in candidates) {
        final searchId = rawId.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
        if (searchId.isEmpty) continue;
        
        // Recherche UNIQUEMENT par ID direct (identique à la Boutique)
        final docRef = await FirebaseFirestore.instance.collection('members').doc(searchId).get();
        if (docRef.exists) {
          foundDoc = docRef;
          break;
        }
      }

      if (foundDoc != null) {
        final data = foundDoc.data() as Map<String, dynamic>;
        final String foundName = data['name'] ?? 'Supporter';
        final String foundZone = (data['zone'] ?? '?').toString();
        final String foundMatricule = data['matricule'] ?? data['cardId'] ?? foundDoc.id;
        
        if (data['is_present'] ?? false) {
          HapticFeedback.vibrate();
          setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ DÉJÀ ENTRÉ !\n\nNOM : $foundName\nZONE : $foundZone";
          });
          Future.delayed(const Duration(seconds: 4), () => setState(() => _showErrorOverlay = false));
          return;
        }

        await foundDoc.reference.update({'is_present': true, 'last_scanned': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('scans_history').add({
          'name': foundName, 'cardId': foundMatricule, 'zone': foundZone, 'timestamp': FieldValue.serverTimestamp(),
        });

        HapticFeedback.vibrate();
        setState(() {
          _showSuccessOverlay = true;
          _scanResult = "✅ $foundName\nZONE : $foundZone";
        });
        Future.delayed(const Duration(seconds: 3), () => setState(() => _showSuccessOverlay = false));
      } else {
        setState(() {
          _showErrorOverlay = true;
          _scanResult = "❌ AUCUN MEMBRE TROUVÉ";
        });
        Future.delayed(const Duration(seconds: 4), () => setState(() => _showErrorOverlay = false));
      }
    } catch (e) {
      if (mounted) setState(() => _scanResult = "Erreur système : $e");
    }
  }

  Future<void> _showManualSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recherche Manuelle"),
        content: TextField(controller: searchController, decoration: const InputDecoration(labelText: "Matricule")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(onPressed: () => Navigator.pop(context, searchController.text.trim()), child: const Text("RECHERCHER")),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) _verifyMember([result]);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Positioned.fill(child: CameraPreview(_cameraController!)),
              if (_showSuccessOverlay) Positioned.fill(child: Container(color: Colors.green.withOpacity(0.6), child: const Icon(Icons.check_circle, color: Colors.white, size: 100))),
              if (_showErrorOverlay) Positioned.fill(child: Container(color: Colors.red.withOpacity(0.6), child: const Icon(Icons.cancel, color: Colors.white, size: 100))),
              Positioned(
                top: 10, right: 10,
                child: Column(
                  children: [
                    if (_cameras.length > 1) CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: _toggleCamera)),
                    const SizedBox(height: 10),
                    CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: _showManualSearchDialog)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(child: SingleChildScrollView(child: Text(_scanResult, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanImage,
                  icon: const Icon(Icons.document_scanner),
                  label: Text(_isScanning ? 'Scan...' : 'Scanner'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red, foregroundColor: Colors.white),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
