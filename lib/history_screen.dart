import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends StatefulWidget {
  final bool isAdmin;
  const HistoryScreen({super.key, required this.isAdmin});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Effacer l'historique ?"),
        content: const Text("Cette action supprimera définitivement tous les enregistrements de scans."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("EFFACER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final snapshot = await FirebaseFirestore.instance.collection('scans_history').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Historique effacé.")));
      }
    }
  }

  Future<void> _exportToCSV() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('scans_history')
        .orderBy('timestamp', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("L'historique est vide.")));
      }
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(["Nom", "Zone", "Matricule", "Date", "Heure"]);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      rows.add([
        data['name'] ?? 'Inconnu',
        data['zone'] ?? '?',
        data['cardId'] ?? '?',
        DateFormat('dd/MM/yyyy').format(timestamp),
        DateFormat('HH:mm:ss').format(timestamp),
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    await Share.share(csvData, subject: 'Historique_Scans.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "HISTORIQUE DES SCANS",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.greenAccent),
                    tooltip: "Exporter en CSV",
                    onPressed: _exportToCSV,
                  ),
                  if (widget.isAdmin) // PROTECTING DELETE BUTTON
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                      tooltip: "Effacer l'historique",
                      onPressed: _clearHistory,
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('scans_history')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Erreur de chargement."));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final scans = snapshot.data!.docs;
              if (scans.isEmpty) return const Center(child: Text("Aucun scan enregistré.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                itemCount: scans.length,
                itemBuilder: (context, index) {
                  final scan = scans[index].data() as Map<String, dynamic>;
                  final DateTime timestamp = (scan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final String dateStr = DateFormat('dd MMMM yyyy').format(timestamp);
                  final String timeStr = DateFormat('HH:mm:ss').format(timestamp);

                  bool showHeader = false;
                  if (index == 0) showHeader = true;
                  else {
                    final prevScan = scans[index - 1].data() as Map<String, dynamic>;
                    final DateTime prevTimestamp = (prevScan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    if (DateFormat('yyyy-MM-dd').format(timestamp) != DateFormat('yyyy-MM-dd').format(prevTimestamp)) showHeader = true;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200],
                          child: Text("JOURNÉE DU $dateStr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        ),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.black12, child: Icon(Icons.history, color: Colors.black)),
                        title: Text(scan['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Zone ${scan['zone'] ?? '?'} • $timeStr"),
                        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ),
                      const Divider(height: 1, indent: 70),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
