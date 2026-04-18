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
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
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
      duration: const Duration(seconds: 1), // Plus rapide
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
      ResolutionPreset.max, // Résolution maximum pour plus de détails
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    
    _maxZoom = await _cameraController!.getMaxZoomLevel();
    // Zoom automatique à 2.0x pour éviter de s'approcher trop (évite le flou macro)
    _currentZoom = (_maxZoom > 2.0) ? 2.0 : 1.0;
    await _cameraController!.setZoomLevel(_currentZoom);
    
    await _cameraController!.setFocusMode(FocusMode.auto);
    await _cameraController!.setExposureMode(ExposureMode.auto);

    if (!mounted) return;
    setState(() => _isCameraInitialized = true);

    // Scan plus fréquent (toutes les 1.5 secondes)
    _autoScanTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_isScanning && _isCameraInitialized && !_showSuccessOverlay && !_showErrorOverlay) {
        _scanImage();
      }
    });
  }

  Future<void> _scanImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isEmpty) {
        setState(() => _isScanning = false);
        return;
      }

      final allText = recognizedText.text.toUpperCase();
      final RegExp matriculeRegex = RegExp(r'\b[A-Z]{1,4}[0-9]{1,5}\b');
      final List<String> candidates = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.toUpperCase();
          final matches = matriculeRegex.allMatches(text);
          for (final m in matches) {
            final val = m.group(0)!.replaceAll(RegExp(r'[^A-Z0-9]'), '');
            if (!candidates.contains(val)) candidates.add(val);
          }
          // Nettoyage agressif pour trouver des codes qui pourraient être mal lus
          final cleaned = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (cleaned.length >= 4 && cleaned.length <= 8) {
            if (!candidates.contains(cleaned)) candidates.add(cleaned);
          }
        }
      }

      if (candidates.isNotEmpty) {
        await _verifyMember(candidates);
      }
    } catch (e) {
      debugPrint("Scanner Error: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _verifyMember(List<String> candidates) async {
    try {
      DocumentSnapshot? foundDoc;
      for (var rawId in candidates) {
        final searchId = rawId.trim().toUpperCase();
        if (searchId.length < 3) continue;

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
        
        if (data['is_present'] ?? false) {
          HapticFeedback.vibrate();
          if (mounted) setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ DÉJÀ ENTRÉ !\n$foundName";
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showErrorOverlay = false);
          });
          return;
        }

        await foundDoc.reference.update({
          'is_present': true, 
          'last_scanned': FieldValue.serverTimestamp()
        });
        
        await FirebaseFirestore.instance.collection('scans_history').add({
          'name': foundName,
          'cardId': foundDoc.id,
          'zone': foundZone,
          'timestamp': FieldValue.serverTimestamp(),
        });

        HapticFeedback.heavyImpact();
        if (mounted) setState(() {
          _showSuccessOverlay = true;
          _scanResult = "✅ BIENVENU $foundName";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSuccessOverlay = false);
        });
      }
    } catch (e) {
      debugPrint("Verify Error: $e");
    }
  }

  Future<void> _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_cameraController == null) return;
    final offset = details.localPosition;
    final point = Offset(offset.dx / constraints.maxWidth, offset.dy / constraints.maxHeight);
    await _cameraController!.setFocusPoint(point);
    await _cameraController!.setExposurePoint(point);
    HapticFeedback.selectionClick();
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
    if (!_isCameraInitialized) return const Center(child: CircularProgressIndicator(color: Colors.red));

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _handleTapToFocus(details, constraints),
          child: Stack(
            children: [
              Positioned.fill(child: CameraPreview(_cameraController!)),
              
              // Frame Overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScanFramePainter(
                    success: _showSuccessOverlay,
                    error: _showErrorOverlay,
                  ),
                ),
              ),

              // Animated Scan Line
              if (!_showSuccessOverlay && !_showErrorOverlay)
                AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    final h = constraints.maxHeight;
                    final top = h * 0.35;
                    final frameH = h * 0.25;
                    return Positioned(
                      top: top + (_scanLineAnimation.value * frameH),
                      left: constraints.maxWidth * 0.15,
                      right: constraints.maxWidth * 0.15,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                        ),
                      ),
                    );
                  },
                ),

              // UI Buttons
              Positioned(
                top: 50, right: 20,
                child: Column(
                  children: [
                    _iconButton(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off, 
                      () async {
                        _isTorchOn = !_isTorchOn;
                        await _cameraController?.setFlashMode(_isTorchOn ? FlashMode.torch : FlashMode.off);
                        setState(() {});
                      },
                      color: _isTorchOn ? Colors.yellow : Colors.white
                    ),
                    const SizedBox(height: 20),
                    _iconButton(Icons.zoom_in, () async {
                      _currentZoom = (_currentZoom + 0.5).clamp(1.0, _maxZoom);
                      await _cameraController?.setZoomLevel(_currentZoom);
                      setState(() {});
                    }),
                    const SizedBox(height: 20),
                    _iconButton(Icons.zoom_out, () async {
                      _currentZoom = (_currentZoom - 0.5).clamp(1.0, _maxZoom);
                      await _cameraController?.setZoomLevel(_currentZoom);
                      setState(() {});
                    }),
                    const SizedBox(height: 20),
                    _iconButton(Icons.keyboard, () async {
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
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, searchController.text.trim().toUpperCase()),
                              child: const Text("Valider"),
                            ),
                          ],
                        ),
                      );
                      if (result != null && result.isNotEmpty) _verifyMember([result]);
                    }),
                  ],
                ),
              ),

              // Result Banner
              Positioned(
                bottom: 40, left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _scanResult,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final bool success;
  final bool error;
  _ScanFramePainter({required this.success, required this.error});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final frameW = size.width * 0.75;
    final frameH = size.height * 0.25;
    final left = (size.width - frameW) / 2;
    final top = size.height * 0.35;
    final frame = Rect.fromLTWH(left, top, frameW, frameH);

    // Overlay with hole
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(20)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = success ? Colors.green : (error ? Colors.red : Colors.white)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(20)), borderPaint);
    
    // Corners indicators
    if (!success && !error) {
       final cornerPaint = Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 8;
       const cornerSize = 40.0;
       // Top Left
       canvas.drawPath(Path()..moveTo(left, top + cornerSize)..lineTo(left, top)..lineTo(left + cornerSize, top), cornerPaint);
       // Top Right
       canvas.drawPath(Path()..moveTo(left + frameW - cornerSize, top)..lineTo(left + frameW, top)..lineTo(left + frameW, top + cornerSize), cornerPaint);
       // Bottom Left
       canvas.drawPath(Path()..moveTo(left, top + frameH - cornerSize)..lineTo(left, top + frameH)..lineTo(left + cornerSize, top + frameH), cornerPaint);
       // Bottom Right
       canvas.drawPath(Path()..moveTo(left + frameW - cornerSize, top + frameH)..lineTo(left + frameW, top + frameH)..lineTo(left + frameW, top + frameH - cornerSize), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
