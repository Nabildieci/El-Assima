import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class ScannerPlatformImplementation extends StatefulWidget {
  const ScannerPlatformImplementation({super.key});

  @override
  State<ScannerPlatformImplementation> createState() => _ScannerPlatformImplementationState();
}

class _ScannerPlatformImplementationState extends State<ScannerPlatformImplementation>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isCameraInitialized = false;
  bool _isScanning = false;
  bool _isTorchOn = false;
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _scanResult = "Placez la carte dans le cadre";
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  Timer? _autoScanTimer;

  // Animation
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _scanResult = "Aucune caméra trouvée.");
        return;
      }
      // Préférer la caméra arrière
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          _selectedCameraIndex = i;
          break;
        }
      }
      await _startCamera();
    } catch (e) {
      if (mounted) setState(() => _scanResult = "Accès caméra refusé.");
    }
  }

  Future<void> _startCamera() async {
    final camera = _cameras[_selectedCameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    
    // Autofocus continu pour une mise au point nette
    await _cameraController!.setFocusMode(FocusMode.auto);
    await _cameraController!.setExposureMode(ExposureMode.auto);

    if (!mounted) return;
    setState(() => _isCameraInitialized = true);

    // Scan automatique toutes les 2.5 secondes
    _autoScanTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!_isScanning && _isCameraInitialized) _scanImage();
    });
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _autoScanTimer?.cancel();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() => _isCameraInitialized = false);
    await _startCamera();
  }

  Future<void> _toggleTorch() async {
    try {
      _isTorchOn = !_isTorchOn;
      await _cameraController?.setFlashMode(_isTorchOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (_) {}
  }

  Future<void> _scanImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      // Forcer l'autofocus avant de scanner
      await _cameraController!.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 300));
      await _cameraController!.setFocusMode(FocusMode.auto);

      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isEmpty) {
        setState(() => _isScanning = false);
        return;
      }

      final allText = recognizedText.text.toUpperCase();
      
      // Extraction intelligente des matricules (format AC001, USMA123, etc.)
      final RegExp matriculeRegex = RegExp(r'\b[A-Z]{1,4}[0-9]{1,5}\b');
      final List<String> candidates = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final cleaned = line.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final matches = matriculeRegex.allMatches(line.text.toUpperCase());
          for (final m in matches) {
            final val = m.group(0)!.replaceAll(RegExp(r'[^A-Z0-9]'), '');
            if (!candidates.contains(val) && val.length >= 3) candidates.add(val);
          }
          if (cleaned.length >= 3 && cleaned.length <= 10 && !candidates.contains(cleaned)) {
            candidates.add(cleaned);
          }
        }
      }

      // Aussi chercher dans le texte brut
      final rawMatches = matriculeRegex.allMatches(allText);
      for (final m in rawMatches) {
        final val = m.group(0)!.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (!candidates.contains(val) && val.length >= 3) candidates.add(val);
      }

      if (candidates.isNotEmpty) {
        await _verifyMember(candidates);
      }
    } catch (e) {
      // Silencieux pour ne pas perturber le scan auto
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _verifyMember(List<String> candidates) async {
    try {
      DocumentSnapshot? foundDoc;

      for (var rawId in candidates) {
        final searchId = rawId.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
        if (searchId.length < 2) continue;

        // Recherche directe par ID du document (le plus rapide et fiable)
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
          if (mounted) setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ DÉJÀ ENTRÉ !\nNOM : $foundName\nZONE : $foundZone";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _showErrorOverlay = false);
          });
          return;
        }

        await foundDoc.reference.update({'is_present': true, 'last_scanned': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('scans_history').add({
          'name': foundName,
          'cardId': foundMatricule,
          'zone': foundZone,
          'timestamp': FieldValue.serverTimestamp(),
        });

        HapticFeedback.heavyImpact();
        if (mounted) setState(() {
          _showSuccessOverlay = true;
          _scanResult = "✅ $foundName\nZONE : $foundZone";
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccessOverlay = false);
        });
      }
    } catch (e) {
      // Silencieux
    }
  }

  Future<void> _showManualSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    bool isLoading = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.search, color: Colors.red),
              SizedBox(width: 8),
              Text("Saisir Matricule", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: "Matricule (ex: AC010)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            onSubmitted: (v) => Navigator.pop(context, v.trim().toUpperCase()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, searchController.text.trim().toUpperCase()),
              child: const Text("RECHERCHER"),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _isScanning = true;
        _scanResult = "Vérification de $result...";
      });
      await _verifyMember([result]);
      setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _scanLineController.dispose();
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
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text("Initialisation de la caméra..."),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera full screen
        Positioned.fill(child: CameraPreview(_cameraController!)),

        // Overlay sombre avec cadre de scan
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanFramePainter(
              successOverlay: _showSuccessOverlay,
              errorOverlay: _showErrorOverlay,
            ),
          ),
        ),

        // Ligne de scan animée dans le cadre
        if (!_showSuccessOverlay && !_showErrorOverlay)
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, child) {
              final screenH = MediaQuery.of(context).size.height;
              final frameTop = screenH * 0.28;
              final frameH = screenH * 0.22;
              return Positioned(
                top: frameTop + (_scanLineAnimation.value * frameH),
                left: MediaQuery.of(context).size.width * 0.1,
                right: MediaQuery.of(context).size.width * 0.1,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.red.shade400, Colors.transparent],
                    ),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
              );
            },
          ),

        // Overlay succès / erreur
        if (_showSuccessOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.green.withOpacity(0.7),
              child: const Center(
                child: Icon(Icons.check_circle_outline, color: Colors.white, size: 120),
              ),
            ),
          ),
        if (_showErrorOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.red.withOpacity(0.7),
              child: const Center(
                child: Icon(Icons.cancel_outlined, color: Colors.white, size: 120),
              ),
            ),
          ),

        // Boutons droite (torche + caméra + manuel)
        Positioned(
          top: 16, right: 16,
          child: Column(
            children: [
              _controlButton(
                icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? Colors.yellow : Colors.white,
                onTap: _toggleTorch,
              ),
              const SizedBox(height: 12),
              if (_cameras.length > 1)
                _controlButton(icon: Icons.flip_camera_ios, color: Colors.white, onTap: _toggleCamera),
              const SizedBox(height: 12),
              _controlButton(icon: Icons.keyboard_alt_outlined, color: Colors.white, onTap: _showManualSearchDialog),
            ],
          ),
        ),

        // Texte résultat en bas
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.9), Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                Text(
                  _scanResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isScanning)
                  const SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(color: Colors.red, backgroundColor: Colors.white24),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final bool successOverlay;
  final bool errorOverlay;
  const _ScanFramePainter({required this.successOverlay, required this.errorOverlay});

  @override
  void paint(Canvas canvas, Size size) {
    final frameW = size.width * 0.8;
    final frameH = size.height * 0.22;
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = size.height * 0.28;
    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);
    final rrect = RRect.fromRectAndRadius(frameRect, const Radius.circular(16));

    // Assombrir tout sauf le cadre
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Couleur du cadre selon l'état
    Color frameColor = successOverlay ? Colors.green : (errorOverlay ? Colors.red : Colors.white);

    // Coins du cadre
    final cornerPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    final corners = [
      [frameLeft, frameTop],
      [frameLeft + frameW, frameTop],
      [frameLeft, frameTop + frameH],
      [frameLeft + frameW, frameTop + frameH],
    ];

    for (int i = 0; i < corners.length; i++) {
      final x = corners[i][0];
      final y = corners[i][1];
      final dx = i % 2 == 0 ? cornerLen : -cornerLen;
      final dy = i < 2 ? cornerLen : -cornerLen;
      canvas.drawLine(Offset(x, y), Offset(x + dx, y), cornerPaint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.successOverlay != successOverlay || oldDelegate.errorOverlay != errorOverlay;
}
