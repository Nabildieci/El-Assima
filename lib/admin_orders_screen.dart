import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  Future<void> _clearOrders(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Vider les commandes ?"),
        content: const Text("Toutes les commandes de maillots seront supprimées définitivement."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OUI, TOUT VIDER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 3 tabs now
      child: Column(
        children: [
          Container(
            color: Colors.red.shade900,
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(icon: Icon(Icons.list_alt), text: "DÉTAILS"),
                      Tab(icon: Icon(Icons.pie_chart), text: "TAILLES"),
                      Tab(icon: Icon(Icons.map), text: "ZONES"),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  tooltip: "Vider les commandes",
                  onPressed: () => _clearOrders(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erreur."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final orders = snapshot.data!.docs;

                if (orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("Aucune commande pour le moment.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    _buildOrdersList(orders),
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

  Widget _buildOrdersList(List<QueryDocumentSnapshot> orders) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final doc = orders[index];
        final data = doc.data() as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.person, color: Colors.white)),
            title: Text(data['memberName'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("ID: ${data['memberId']} • Zone ${data['zone']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    data['size'] ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Annuler cette commande ?"),
                        content: Text("Voulez-vous supprimer la commande de ${data['memberName']} ?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NON")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("OUI", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('orders').doc(doc.id).delete();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsBySize(List<QueryDocumentSnapshot> orders) {
    Map<String, int> stats = {};
    for (var doc in orders) {
      final size = (doc.data() as Map<String, dynamic>)['size'] ?? 'Unknown';
      stats[size] = (stats[size] ?? 0) + 1;
    }

    final sortedSizes = ['S', 'M', 'L', 'XL', 'XXL'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("TOTAL GÉNÉRAL PAR TAILLE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ...sortedSizes.map((size) {
          final count = stats[size] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
            child: ListTile(
              title: Text("Taille $size", style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text("$count", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.red)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatsByZone(List<QueryDocumentSnapshot> orders) {
    // Map<Zone, Map<Size, Count>>
    Map<int, Map<String, int>> zoneStats = {};
    
    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final zone = data['zone'] ?? 0;
      final size = data['size'] ?? 'Unknown';
      
      zoneStats.putIfAbsent(zone, () => {});
      zoneStats[zone]![size] = (zoneStats[zone]![size] ?? 0) + 1;
    }

    final sortedZones = zoneStats.keys.toList()..sort();
    final sortedSizes = ['S', 'M', 'L', 'XL', 'XXL'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedZones.length,
      itemBuilder: (context, index) {
        final zone = sortedZones[index];
        final sizes = zoneStats[zone]!;
        int totalInZone = sizes.values.fold(0, (sum, val) => sum + val);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ZONE $zone", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    Text("$totalInZone COMMANDES", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: sortedSizes.map((size) {
                    final count = sizes[size] ?? 0;
                    return Column(
                      children: [
                        Text(size, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: count > 0 ? Colors.black : Colors.grey[100],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              color: count > 0 ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
