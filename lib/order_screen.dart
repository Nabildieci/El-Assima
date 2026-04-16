import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String? _selectedSize;
  final TextEditingController _memberIdController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL'];

  Future<void> _submitOrder() async {
    final memberId = _memberIdController.text.trim().toUpperCase();
    
    if (memberId.isEmpty || _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs (ID et Taille).")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Verify member exists
      final memberDoc = await FirebaseFirestore.instance.collection('members').doc(memberId).get();
      if (!memberDoc.exists) {
        throw "Membre introuvable. Veuillez vérifier l'ID.";
      }

      // 2. Check if already ordered
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(memberId).get();
      if (orderDoc.exists) {
        throw "Vous avez déjà passé une commande (Limite: 1 par membre).";
      }

      // 3. Save order
      await FirebaseFirestore.instance.collection('orders').doc(memberId).set({
        'memberId': memberId,
        'memberName': memberDoc.data()?['name'] ?? 'Inconnu',
        'zone': memberDoc.data()?['zone'] ?? 0, // IMPORTANT: Saving zone for stats
        'size': _selectedSize,
        'product': 'Maillot Officiel EL ASSIMA',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'En attente',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            content: const Text(
              "Commande validée !\nVotre maillot est réservé.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("SUPER"),
              )
            ],
          ),
        );
        _memberIdController.clear();
        setState(() => _selectedSize = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
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
          const Text(
            "BOUTIQUE OFFICIELLE",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red),
          ),
          const Text(
            "Réservez votre maillot exclusif EL ASSIMA",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Jersey Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey[100],
                      child: Image.asset(
                        'assets/images/maillot.png', // User should add the generated image here
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Icon(Icons.sports_soccer, size: 100, color: Colors.red),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Maillot Officiel 2026",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "5500 DA",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Qualité Premium - Respirant - Édition Limitée Zone 14.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Order Form
          const Text(
            "VOTRE COMMANDE",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _memberIdController,
            decoration: InputDecoration(
              labelText: "Identifiant Membre (ID)",
              hintText: "Ex: AC010",
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white70,
            ),
          ),
          
          const SizedBox(height: 20),
          
          const Text("Choisir votre taille :", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _sizes.map((size) {
              final bool isSelected = _selectedSize == size;
              return ChoiceChip(
                label: Text(size),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedSize = selected ? size : null);
                },
                selectedColor: Colors.red,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 40),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("VALIDER LA COMMANDE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
