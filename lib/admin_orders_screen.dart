import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersScreen extends StatelessWidget {
  final bool isAdmin;
  const AdminOrdersScreen({super.key, required this.isAdmin});

  Future<void> _clearOrders(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Vider les commandes ?", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
        content: const Text("Toutes les commandes seront supprimées définitivement."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OUI, TOUT SUPPRIMER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commandes effacées."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    indicatorColor: Colors.red,
                    indicatorWeight: 4,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    tabs: [
                      Tab(icon: Icon(Icons.checkroom_outlined, size: 20), text: "MAILLOTS"),
                      Tab(icon: Icon(Icons.vpn_key_outlined, size: 20), text: "P. CLÉ"),
                      Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: "TAILLES"),
                      Tab(icon: Icon(Icons.grid_view_outlined, size: 20), text: "ZONES"),
                    ],
                  ),
                ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 22),
                      tooltip: "Vider les commandes",
                      onPressed: () => _clearOrders(context),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erreur de synchronisation."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));

                final allOrders = snapshot.data!.docs;

                if (allOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("AUCUNE COMMANDE ACTIVE", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  );
                }

                final jerseyOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Maillot') ?? false).toList();
                final keychainOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Porte-clé') ?? false).toList();

                return TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildJerseyOrders(context, jerseyOrders),
                    _buildKeychainOrders(context, keychainOrders),
                    _buildStatsBySize(jerseyOrders),
                    _buildStatsByZone(allOrders),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJerseyOrders(BuildContext context, List<QueryDocumentSnapshot> orders) {
    return Column(
      children: [
        _buildSummaryHeader("TOTAL MAILLOTS", "${orders.length} UNITÉS", Colors.red),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildBaseOrderCard(
                context,
                data['memberName'] ?? 'Inconnu',
                "ID: ${data['memberId']} • Zone ${data['zone']}",
                data['size'] ?? 'N/A',
                Icons.checkroom_outlined,
                Colors.red,
                () async {
                  final confirm = await _showConfirmDelete(context, data['memberName']);
                  if (confirm == true) await FirebaseFirestore.instance.collection('orders').doc(doc.id).delete();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeychainOrders(BuildContext context, List<QueryDocumentSnapshot> orders) {
    Map<String, Map<String, dynamic>> grouped = {};
    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final String mId = data['memberId'] ?? 'unknown';
      final int qty = data['quantity'] ?? 1;
      
      if (!grouped.containsKey(mId)) {
        grouped[mId] = {
          'name': data['memberName'] ?? 'Inconnu',
          'zone': data['zone'],
          'totalQty': 0,
          'docIds': <String>[],
        };
      }
      grouped[mId]!['totalQty'] += qty;
      (grouped[mId]!['docIds'] as List<String>).add(doc.id);
    }

    final sortedItems = grouped.values.toList();
    int totalPcs = 0;
    for (var item in sortedItems) totalPcs += item['totalQty'] as int;

    return Column(
      children: [
        _buildSummaryHeader("TOTAL PORTE-CLÉS", "$totalPcs PCS", Colors.amber.shade800),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return _buildBaseOrderCard(
                context,
                item['name'],
                "ID: ${grouped.keys.elementAt(index)} • Zone ${item['zone']}",
                "${item['totalQty']} PCS",
                Icons.vpn_key_outlined,
                Colors.amber.shade800,
                () async {
                  final confirm = await _showConfirmDelete(context, item['name']);
                  if (confirm == true) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (var id in (item['docIds'] as List<String>)) {
                      batch.delete(FirebaseFirestore.instance.collection('orders').doc(id));
                    }
                    await batch.commit();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13, letterSpacing: 1)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseOrderCard(BuildContext context, String title, String subtitle, String trailing, IconData icon, Color color, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: Text(trailing, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.red.shade300, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDelete(BuildContext context, String? name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Annuler commande"),
        content: Text("Confirmez-vous la suppression de la commande de $name ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("IGNORER")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ANNULER LA COMMANDE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
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
      padding: const EdgeInsets.all(24),
      children: [
        const Text("RÉPARTITION PAR TAILLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
        const SizedBox(height: 20),
        ...sortedSizes.map((size) {
          final count = stats[size] ?? 0;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.black, radius: 18, child: Text(size, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    const SizedBox(width: 16),
                    const Text("Maillots", style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text("$count", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatsByZone(List<QueryDocumentSnapshot> orders) {
    Map<int, Map<String, int>> zoneProductStats = {};
    
    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final zone = data['zone'] ?? 0;
      final product = data['product']?.toString() ?? 'Inconnu';
      
      zoneProductStats.putIfAbsent(zone, () => {'Maillots': 0, 'Porte-clés': 0});
      if (product.contains('Maillot')) {
        zoneProductStats[zone]!['Maillots'] = (zoneProductStats[zone]!['Maillots'] ?? 0) + 1;
      } else if (product.contains('Porte-clé')) {
        final qty = data['quantity'] ?? 1;
        zoneProductStats[zone]!['Porte-clés'] = (zoneProductStats[zone]!['Porte-clés'] ?? 0) + (qty as int);
      }
    }

    final sortedZones = zoneProductStats.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedZones.length,
      itemBuilder: (context, index) {
        final zone = sortedZones[index];
        final products = zoneProductStats[zone]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("ZONE $zone", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Icon(Icons.analytics_rounded, color: Colors.blueGrey, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _miniStat("MAILLOTS", products['Maillots']!, Colors.red),
                  const SizedBox(width: 32),
                  _miniStat("P. CLÉS", products['Porte-clés']!, Colors.amber.shade700),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, int val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text("$val", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
