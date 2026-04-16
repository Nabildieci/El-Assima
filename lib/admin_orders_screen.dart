import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.red.shade900,
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(icon: Icon(Icons.pie_chart), text: "PAR TAILLE"),
                Tab(icon: Icon(Icons.map), text: "PAR ZONE"),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erreur."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final orders = snapshot.data!.docs;

                if (orders.isEmpty) {
                  return const Center(child: Text("Aucune commande enregistrée."));
                }

                return TabBarView(
                  children: [
                    _buildStatsBySize(orders),
                    _buildStatsByZone(orders),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBySize(List<QueryDocumentSnapshot> orders) {
    Map<String, int> stats = {};
    for (var doc in orders) {
      final size = doc['size'] as String;
      stats[size] = (stats[size] ?? 0) + 1;
    }

    final sortedSizes = ['S', 'M', 'L', 'XL', 'XXL'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "RÉCAPITULATIF DES TAILLES",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            textAlign: TextAlign.center,
          ),
        ),
        ...sortedSizes.map((size) {
          final count = stats[size] ?? 0;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: count > 0 ? Colors.red : Colors.grey[200],
                child: Text(size, style: TextStyle(color: count > 0 ? Colors.white : Colors.black54)),
              ),
              title: Text("Taille $size", style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                "$count Commandes",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blue),
              ),
            ),
          );
        }),
        const Divider(height: 40),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "TOTAL : ${orders.length} MAILLOTS",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsByZone(List<QueryDocumentSnapshot> orders) {
    Map<int, int> stats = {};
    for (var doc in orders) {
      final zone = doc['zone'] as int;
      stats[zone] = (stats[zone] ?? 0) + 1;
    }

    final sortedZones = stats.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "RÉPARTITION PAR ZONE",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            textAlign: TextAlign.center,
          ),
        ),
        ...sortedZones.map((zone) {
          final count = stats[zone] ?? 0;
          return ListTile(
            leading: const Icon(Icons.location_on, color: Colors.red),
            title: Text("ZONE $zone", style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              child: Text(
                "$count",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}
