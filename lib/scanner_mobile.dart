import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  
  late MobileScannerController _scannerController;
  
  bool _isProcessing = false;
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _scanResult = "Placez la carte dans le cadre";
  
  // Animation
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _showSuccessOverlay || _showErrorOverlay) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue.trim().isNotEmpty) {
      if (mounted) {
        setState(() => _isProcessing = true);
      }
      // Pass rawValue to verify
      await _verifyMember(rawValue.trim().toUpperCase());
      if (mounted) {
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
            _showErrorOverlay = true;
            _scanResult = "⚠️ MEMBRE INTROUVABLE !\nMatricule: $searchId";
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showErrorOverlay = false);
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
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showErrorOverlay = false);
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
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() {
           _showSuccessOverlay = false;
           _scanResult = "Placez la carte dans le cadre";
        });
      });
      
    } catch (e) {
      debugPrint("Verify Error: $e");
      if (mounted) {
          setState(() {
            _showErrorOverlay = true;
            _scanResult = "⚠️ ERREUR RESEAU !";
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showErrorOverlay = false);
          });
      }
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcode,
              ),
            ),
            
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
                    Icons.flash_on, 
                    () => _scannerController.toggleTorch(),
                  ),
                  const SizedBox(height: 20),
                  _iconButton(
                    Icons.cameraswitch_outlined, 
                    () => _scannerController.switchCamera(),
                  ),
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
                    if (result != null && result.isNotEmpty) _verifyMember(result);
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
