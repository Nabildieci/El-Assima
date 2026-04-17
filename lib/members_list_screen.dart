import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MembersListScreen extends StatefulWidget {
  final bool isAdmin;
  const MembersListScreen({super.key, required this.isAdmin});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  int _selectedZone = 1;

  Future<void> _resetAttendance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Réinitialiser ?", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
        content: const Text("Voulez-vous marquer tous les membres comme ABSENTS pour cette session ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OUI, RÉINITIALISER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
          const SnackBar(content: Text("Liste réinitialisée avec succès !"), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "GESTION DES ZONES",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                    ),
                    Text(
                      "Suivi des entrées en temps réel",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedZone,
                    dropdownColor: Colors.black,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    items: List.generate(14, (index) => index + 1).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("ZONE $value"),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) setState(() => _selectedZone = newValue);
                    },
                  ),
                ),
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
              if (snapshot.hasError) return const Center(child: Text("Erreur de données."));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));

              final members = snapshot.data!.docs;
              final totalMembers = members.length;
              final presentCount = members.where((doc) => (doc.data() as Map<String, dynamic>)['is_present'] == true).length;
              final absentCount = totalMembers - presentCount;

              return Column(
                children: [
                  // Dashboard Stats Card
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard("MEMBRES", totalMembers.toString(), Icons.people_outline, Colors.blue),
                        _buildStatCard("EN SALLE", presentCount.toString(), Icons.login_outlined, Colors.green),
                        _buildStatCard("ABSENTS", absentCount.toString(), Icons.logout_outlined, Colors.red),
                      ],
                    ),
                  ),

                  // List Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "MEMBRES DE LA ZONE ($_selectedZone)",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey),
                        ),
                        if (widget.isAdmin)
                          TextButton.icon(
                            onPressed: _resetAttendance,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text("REINIT.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index].data() as Map<String, dynamic>;
                        final bool isPresent = member['is_present'] ?? false;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isPresent ? Colors.green.withOpacity(0.1) : cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPresent ? Colors.green.withOpacity(0.5) : (isDark ? Colors.white12 : Colors.grey.shade100),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: isPresent ? Colors.green.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.grey.shade100),
                              child: Icon(
                                isPresent ? Icons.person : Icons.person_outline,
                                color: isPresent ? Colors.green : (isDark ? Colors.white54 : Colors.grey),
                              ),
                            ),
                            title: Text(
                              member['name'] ?? 'Inconnu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: isPresent ? Colors.green : textColor
                              ),
                            ),
                            subtitle: Text(
                              "ID: ${member['cardId'] ?? 'N/A'}", 
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade600)
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPresent ? "PRÉSENT" : "ABSENT",
                                style: TextStyle(
                                  color: isPresent ? Colors.white : Colors.red.shade800,
                                  fontWeight: FontWeight.w900,
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
