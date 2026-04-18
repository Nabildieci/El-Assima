import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String _selectedProduct = 'Maillot'; // 'Maillot' or 'Porte-clé'
  String? _selectedSize;
  int _quantity = 1;
  final TextEditingController _memberIdController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL'];

  Future<void> _submitOrder() async {
    final memberId = _memberIdController.text.trim().toUpperCase();
    
    if (memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir votre ID membre.")),
      );
      return;
    }

    if (_selectedProduct == 'Maillot' && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir une taille pour le maillot.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final memberDoc = await FirebaseFirestore.instance.collection('members').doc(memberId).get();
      if (!memberDoc.exists) {
        throw "Membre introuvable. Veuillez vérifier l'ID.";
      }

      if (_selectedProduct == 'Maillot') {
        final existingJersey = await FirebaseFirestore.instance
          .collection('orders')
          .where('memberId', isEqualTo: memberId)
          .where('product', isEqualTo: 'Maillot Officiel EL ASSIMA')
          .get();
          
        if (existingJersey.docs.isNotEmpty) {
          throw "Vous avez déjà commandé un maillot (Limite: 1).";
        }
      }

      final String timeKey = "${DateTime.now().millisecondsSinceEpoch}";
      final orderId = _selectedProduct == 'Maillot' 
          ? memberId 
          : "${memberId}_${_selectedProduct.toUpperCase()}_$timeKey";
          
      String productName = 'Maillot Officiel EL ASSIMA';
      int price = 5000;
      if (_selectedProduct == 'Porte-clé') { productName = 'Porte-clé Officiel'; price = 500; }
      else if (_selectedProduct == 'Pins') { productName = 'Pins Officiel'; price = 500; }
      else if (_selectedProduct == 'Stickers') { productName = 'Stickers Officiels'; price = 300; }
      else if (_selectedProduct == 'Béret') { productName = 'Béret Officiel'; price = 3000; } // Note: 3000 DA used here as typical price

      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'memberId': memberId,
        'memberName': memberDoc.data()?['name'] ?? 'Inconnu',
        'zone': memberDoc.data()?['zone'] ?? 0,
        'size': _selectedProduct == 'Maillot' ? _selectedSize : 'N/A',
        'quantity': _selectedProduct == 'Maillot' ? 1 : _quantity,
        'product': productName,
        'price': price,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'En attente',
      });

      if (mounted) {
        _showSuccessDialog();
        _memberIdController.clear();
        setState(() {
          _selectedSize = null;
          _quantity = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text("COMMANDE RÉUSSIE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ],
        ),
        content: Text(
          "Votre $_selectedProduct a été réservé avec succès.\nRendez-vous au point de retrait.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text("TERMINER", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.red, Color(0xFF8B0000)],
            ).createShader(bounds),
            child: const Text(
              "BOUTIQUE PREMIUM",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          Text(
            "ÉQUIPEZ-VOUS AUX COULEURS D'EL ASSIMA",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
          ),
          const SizedBox(height: 32),
          
          // Product Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: _buildEnhancedProductCard(
                    'Maillot', 
                    '5000 DA', 
                    'assets/images/arriere_plan.jpg', 
                    _selectedProduct == 'Maillot',
                    () => setState(() => _selectedProduct = 'Maillot'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: _buildEnhancedProductCard(
                    'Porte-clé', 
                    '500 DA', 
                    'assets/images/porte clé new.jpg', 
                    _selectedProduct == 'Porte-clé',
                    () => setState(() => _selectedProduct = 'Porte-clé'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: _buildEnhancedProductCard(
                    'Pins', 
                    '500 DA', 
                    'assets/images/PINS.png', 
                    _selectedProduct == 'Pins',
                    () => setState(() => _selectedProduct = 'Pins'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: _buildEnhancedProductCard(
                    'Stickers', 
                    '300 DA', 
                    'assets/images/STICKERS.jpeg', 
                    _selectedProduct == 'Stickers',
                    () => setState(() => _selectedProduct = 'Stickers'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: _buildEnhancedProductCard(
                    'Béret', 
                    '3000 DA', 
                    'assets/images/Béret 1.jpeg', 
                    _selectedProduct == 'Béret',
                    () => setState(() => _selectedProduct = 'Béret'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text("DÉTAILS DE LA COMMANDE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                  ],
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: _memberIdController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Identifiant Membre",
                    hintText: "Saisir ici : AC010",
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (_selectedProduct == 'Maillot') ...[
                  const Text("TAILLE DISPONIBLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _sizes.map((size) {
                      final bool isSelected = _selectedSize == size;
                      return ChoiceChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedSize = selected ? size : null),
                        selectedColor: Colors.red.shade700,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87, 
                          fontWeight: FontWeight.w800
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: isSelected ? 4 : 0,
                      );
                    }).toList(),
                  ),
                ] else ...[
                  const Text("QUANTITÉ (MAX 10)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _qtyBtn(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(_quantity.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                      _qtyBtn(Icons.add, _quantity < 10 ? () => setState(() => _quantity++) : null),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          Container(
            width: double.infinity,
            height: 65,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white) 
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, size: 20, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        "RÉSERVER MAINTENANT", 
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1.2,
                          color: Colors.white.withOpacity(0.95)
                        )
                      ),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildEnhancedProductCard(String title, String price, String img, bool isSelected, VoidCallback onTap) {
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? Colors.red.shade700 : Colors.grey.shade100,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? Colors.red.withOpacity(0.15) : Colors.black.withOpacity(0.03),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(img, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.shopping_bag_outlined, size: 50, color: Colors.grey))),
                      if (isSelected) 
                        Positioned(
                          top: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(price, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: onPressed == null ? Colors.grey : Colors.black),
      ),
    );
  }
}
