import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  int _selectedZone = 1; // Default back to Zone 1


  @override
  void initState() {
    super.initState();
  }

  Future<void> _resetAttendance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réinitialiser ?"),
        content: const Text("Voulez-vous marquer tous les membres comme ABSENTS pour une nouvelle session ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OUI, RÉINITIALISER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final snapshot = await FirebaseFirestore.instance.collection('members').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'is_present': false});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Liste réinitialisée avec succès !")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.red.shade900,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "LISTE DES MEMBRES",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: "Réinitialiser la liste",
                onPressed: _resetAttendance,
              ),
              DropdownButton<int>(
                value: _selectedZone,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                underline: Container(height: 2, color: Colors.white),
                items: List.generate(14, (index) => index + 1).map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text("ZONE $value"),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedZone = newValue;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('members')
                .where('zone', isEqualTo: _selectedZone)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Erreur de chargement des données."));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data!.docs;
              final totalMembers = members.length;
              final presentCount = members.where((doc) => (doc.data() as Map<String, dynamic>)['is_present'] == true).length;
              final absentCount = totalMembers - presentCount;

              if (members.isEmpty) {
                return const Center(
                  child: Text(
                    "Aucun membre dans la base de données.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: [
                  // Stats Dashboard
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(context, "MEMBRES", totalMembers.toString(), Colors.blue),
                        _buildStatItem(context, "ENTRÉS", presentCount.toString(), Colors.green),
                        _buildStatItem(context, "RESTANT", absentCount.toString(), Colors.redAccent),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index].data() as Map<String, dynamic>;
                        final String name = member['name'] ?? 'Inconnu';
                        final String cardId = member['cardId'] ?? 'Pas d\'ID';
                        final bool isPresent = member['is_present'] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: isPresent ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isPresent ? Colors.green.withOpacity(0.5) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPresent ? Colors.green : Colors.grey[300],
                              child: Icon(
                                isPresent ? Icons.check : Icons.person_outline,
                                color: isPresent ? Colors.white : Colors.black38,
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isPresent 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              "ID: $cardId",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isPresent ? "PRÉSENT" : "ABSENT",
                                style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
