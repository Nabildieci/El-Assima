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
      for (var doc in snapshot.docs) batch.delete(doc.reference);
      await batch.commit();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commandes effacées."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Colors.grey[900] : Colors.white;

    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: Colors.black, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    isScrollable: true,
                    indicatorColor: Colors.red,
                    indicatorWeight: 4, labelColor: Colors.white, unselectedLabelColor: Colors.white38,
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    tabs: [
                      Tab(icon: Icon(Icons.checkroom_outlined, size: 20), text: "MAILLOTS"),
                      Tab(icon: Icon(Icons.vpn_key_outlined, size: 20), text: "P. CLÉ"),
                      Tab(icon: Icon(Icons.push_pin_outlined, size: 20), text: "PINS"),
                      Tab(icon: Icon(Icons.sell_outlined, size: 20), text: "STICKERS"),
                      Tab(icon: Icon(Icons.face_retouching_natural, size: 20), text: "BÉRETS"),
                      Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: "TAILLES"),
                      Tab(icon: Icon(Icons.grid_view_outlined, size: 20), text: "ZONES"),
                    ],
                  ),
                ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 22), onPressed: () => _clearOrders(context)),
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
                if (allOrders.isEmpty) return _buildEmptyState();

                final jerseyOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Maillot') ?? false).toList();
                final keychainOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Porte-clé') ?? false).toList();
                final pinsOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Pins') ?? false).toList();
                final stickersOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Stickers') ?? false).toList();
                final beretsOrders = allOrders.where((d) => (d.data() as Map)['product']?.toString().contains('Béret') ?? false).toList();

                return TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildJerseyOrders(context, jerseyOrders, cardBgColor),
                    _buildGenericOrders(context, keychainOrders, 'PORTE-CLÉS', Icons.vpn_key_outlined, Colors.amber.shade800, cardBgColor),
                    _buildGenericOrders(context, pinsOrders, 'PINS', Icons.push_pin_outlined, Colors.blue, cardBgColor),
                    _buildGenericOrders(context, stickersOrders, 'STICKERS', Icons.sell_outlined, Colors.purple, cardBgColor),
                    _buildGenericOrders(context, beretsOrders, 'BÉRETS', Icons.face_retouching_natural, Colors.green, cardBgColor),
                    _buildStatsBySize(jerseyOrders, cardBgColor),
                    _buildStatsByZone(allOrders, cardBgColor),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJerseyOrders(BuildContext context, List<QueryDocumentSnapshot> orders, Color? cardBg) {
    return Column(
      children: [
        _buildSummaryHeader("TOTAL MAILLOTS", "${orders.length} UNITÉS", Colors.red),
        Expanded(
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final clientName = data['client'] ?? data['memberName'] ?? 'Inconnu';
              return _buildBaseOrderCard(context, clientName, "Zone ${data['zone']}", data['size'] ?? 'N/A', Icons.checkroom_outlined, Colors.red, cardBg, () async {
                final confirm = await _showConfirmDelete(context, clientName);
                if (confirm == true) await FirebaseFirestore.instance.collection('orders').doc(orders[index].id).delete();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenericOrders(BuildContext context, List<QueryDocumentSnapshot> orders, String title, IconData icon, Color color, Color? cardBg) {
    Map<String, Map<String, dynamic>> grouped = {};
    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final clientName = data['client'] ?? data['memberName'] ?? 'Inconnu';
      grouped.putIfAbsent(clientName, () => {'name': clientName, 'zone': data['zone'], 'totalQty': 0, 'docIds': <String>[]});
      grouped[clientName]!['totalQty'] += (data['quantity'] ?? 1) as int;
      (grouped[clientName]!['docIds'] as List<String>).add(doc.id);
    }
    final sortedItems = grouped.values.toList();
    return Column(
      children: [
        _buildSummaryHeader("TOTAL $title", "${sortedItems.fold(0, (p, c) => (p as int) + (c['totalQty'] as int))} PCS", color),
        Expanded(
          child: ListView.builder(
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return _buildBaseOrderCard(context, item['name'], "Zone ${item['zone']}", "${item['totalQty']} PCS", icon, color, cardBg, () async {
                final confirm = await _showConfirmDelete(context, item['name']);
                if (confirm == true) {
                  final batch = FirebaseFirestore.instance.batch();
                  for (var id in item['docIds']) batch.delete(FirebaseFirestore.instance.collection('orders').doc(id));
                  await batch.commit();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBaseOrderCard(BuildContext context, String title, String subtitle, String trailing, IconData icon, Color color, Color? cardBg, VoidCallback onDelete) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black, borderRadius: BorderRadius.circular(8)), child: Text(trailing, style: TextStyle(color: isDark ? Colors.red : Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
            if (isAdmin)
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.red.shade300, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(String label, String value, Color color) {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24), decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border(bottom: BorderSide(color: color.withOpacity(0.1)))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13, letterSpacing: 1)), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)))]));
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text("AUCUNE COMMANDE ACTIVE", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900, letterSpacing: 1))]));
  }

  Future<bool?> _showConfirmDelete(BuildContext context, String? name) {
    return showDialog<bool>(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text("Annuler commande"), content: Text("Confirmez-vous la suppression de la commande de $name ?"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("IGNORER")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ANNULER LA COMMANDE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]));
  }

  Widget _buildStatsBySize(List<QueryDocumentSnapshot> orders, Color? cardBg) {
    Map<int, Map<String, int>> statsByZone = {};
    for (var doc in orders) {
      final d = doc.data() as Map<String, dynamic>;
      final size = d['size']?.toString() ?? 'Unknown';
      if (size == 'N/A' || size == 'Unknown') continue; 
      final z = d['zone'] ?? 0;
      statsByZone.putIfAbsent(z, () => {});
      statsByZone[z]![size] = (statsByZone[z]![size] ?? 0) + 1;
    }
    
    final sortedZones = statsByZone.keys.toList()..sort();
    
    if (sortedZones.isEmpty) {
      return const Center(child: Text("AUCUNE TAILLE ENREGISTRÉE", style: TextStyle(fontWeight: FontWeight.bold)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedZones.length,
      itemBuilder: (context, index) {
        final z = sortedZones[index];
        final sizes = statsByZone[z]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ZONE $z", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sizes.entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${e.key} :", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text("${e.value}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsByZone(List<QueryDocumentSnapshot> orders, Color? cardBg) {
    Map<int, Map<String, int>> stats = {};
    for (var doc in orders) {
      final d = doc.data() as Map<String, dynamic>;
      final z = d['zone'] ?? 0;
      stats.putIfAbsent(z, () => {'Maillots': 0, 'Porte-clés': 0, 'Pins': 0, 'Stickers': 0, 'Bérets': 0});
      if (d['product']?.toString().contains('Maillot') ?? false) stats[z]!['Maillots'] = (stats[z]!['Maillots'] ?? 0) + 1;
      else if (d['product']?.toString().contains('Porte-clé') ?? false) stats[z]!['Porte-clés'] = (stats[z]!['Porte-clés'] ?? 0) + (d['quantity'] as int);
      else if (d['product']?.toString().contains('Pins') ?? false) stats[z]!['Pins'] = (stats[z]!['Pins'] ?? 0) + (d['quantity'] as int);
      else if (d['product']?.toString().contains('Stickers') ?? false) stats[z]!['Stickers'] = (stats[z]!['Stickers'] ?? 0) + (d['quantity'] as int);
      else if (d['product']?.toString().contains('Béret') ?? false) stats[z]!['Bérets'] = (stats[z]!['Bérets'] ?? 0) + (d['quantity'] as int);
    }
    final sorted = stats.keys.toList()..sort();
    return ListView.builder(padding: const EdgeInsets.all(20), itemCount: sorted.length, itemBuilder: (context, index) {
      final z = sorted[index];
      final p = stats[z]!;
      return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("ZONE $z", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), 
        const SizedBox(height: 16), 
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _miniStat("MAILLOTS", p['Maillots']!, Colors.red), 
            _miniStat("P. CLÉS", p['Porte-clés']!, Colors.amber.shade700),
            _miniStat("PINS", p['Pins']!, Colors.blue),
            _miniStat("STICKERS", p['Stickers']!, Colors.purple),
            _miniStat("BÉRETS", p['Bérets']!, Colors.green),
          ]
        )
      ]));
    });
  }

  Widget _miniStat(String l, int v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)), Text("$v", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c))]);
}
