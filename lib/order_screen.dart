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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez saisir votre ID membre.")));
      return;
    }

    if (_selectedProduct == 'Maillot' && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez choisir une taille pour le maillot.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final memberDoc = await FirebaseFirestore.instance.collection('members').doc(memberId).get();
      if (!memberDoc.exists) {
        throw "Membre introuvable. Veuillez vérifier l'ID.";
      }

      if (_selectedProduct == 'Maillot') {
        // Check if already ordered jersey
        final existingJersey = await FirebaseFirestore.instance
            .collection('orders')
            .where('memberId', isEqualTo: memberId)
            .where('product', isEqualTo: 'Maillot Officiel EL ASSIMA')
            .get();
            
        if (existingJersey.docs.isNotEmpty) {
          throw "Vous avez déjà commandé un maillot (Limite: 1).";
        }
      }

      // Save order with a unique ID for keychains to allow multiple
      final orderId = _selectedProduct == 'Maillot' 
          ? memberId 
          : "${memberId}_KEY_${DateTime.now().millisecondsSinceEpoch}";

      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'memberId': memberId,
        'memberName': memberDoc.data()?['name'] ?? 'Inconnu',
        'zone': memberDoc.data()?['zone'] ?? 0,
        'size': _selectedProduct == 'Maillot' ? _selectedSize : 'N/A',
        'quantity': _selectedProduct == 'Maillot' ? 1 : _quantity,
        'product': _selectedProduct == 'Maillot' ? 'Maillot Officiel EL ASSIMA' : 'Porte-clé Officiel',
        'price': _selectedProduct == 'Maillot' ? 5000 : 500,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'En attente',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            content: Text(
              "Commande validée !\nVotre ${_selectedProduct} est réservé.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("SUPER"))],
          ),
        );
        _memberIdController.clear();
        setState(() {
          _selectedSize = null;
          _quantity = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BOUTIQUE OFFICIELLE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red)),
          const Text("Sélectionnez vos articles EL ASSIMA", style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          
          // Product Switcher
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedProduct = 'Maillot'),
                  child: _buildProductCard('Maillot', '5000 DA', 'arriere_plan.jpg', _selectedProduct == 'Maillot'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedProduct = 'Porte-clé'),
                  child: _buildProductCard('Porte-clé', '500 DA', 'porte clé new.jpg', _selectedProduct == 'Porte-clé'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          const Text("VOTRE COMMANDE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          TextField(
            controller: _memberIdController,
            decoration: InputDecoration(
              labelText: "Identifiant Membre (ID)",
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white70,
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (_selectedProduct == 'Maillot') ...[
            const Text("Choisir votre taille :", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sizes.map((size) {
                  final bool isSelected = _selectedSize == size;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(size),
                      selected: isSelected,
                      onSelected: (selected) => setState(() => _selectedSize = selected ? size : null),
                      selectedColor: Colors.red,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const Text("Quantité :", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text(_quantity.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _quantity < 10 ? () => setState(() => _quantity++) : null, icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
          ],
          
          const SizedBox(height: 40),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("VALIDER LA COMMANDE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProductCard(String name, String price, String imageName, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: (imageName == 'maillot.png' || imageName == '') 
                ? const Icon(Icons.checkroom, size: 60, color: Colors.grey)
                : Image.asset('assets/images/$imageName', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag, size: 40)),
            ),
          ),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(price, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
