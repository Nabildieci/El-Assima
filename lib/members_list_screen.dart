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
        // Header (Text "GESTION DES ZONES" REMOVED AS REQUESTED)
        // GLOBAL STATS SUMMARY
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.black,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('members').snapshots(),
            builder: (context, snapshot) {
              int total = 0;
              int present = 0;
              if (snapshot.hasData) {
                total = snapshot.data!.docs.length;
                present = snapshot.data!.docs.where((d) => (d.data() as Map)['is_present'] == true).length;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGlobalStat("TOTAL RÉSERVATIONS", total.toString(), Colors.blue),
                  Container(width: 1, height: 30, color: Colors.white12),
                  _buildGlobalStat("PRÉSENTS TOTAL", present.toString(), Colors.red),
                ],
              );
            },
          ),
        ),

        // 14 ZONES GRID
        Container(
          height: 120, // Reduced height for the horizontal grid
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 14,
            itemBuilder: (context, index) {
              final zoneId = index + 1;
              final bool isSelected = _selectedZone == zoneId;
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('members').where('zone', isEqualTo: zoneId).snapshots(),
                builder: (context, snapshot) {
                  int zTotal = 0;
                  int zPresent = 0;
                  if (snapshot.hasData) {
                    zTotal = snapshot.data!.docs.length;
                    zPresent = snapshot.data!.docs.where((d) => (d.data() as Map)['is_present'] == true).length;
                  }

                  return GestureDetector(
                    onTap: () => setState(() => _selectedZone = zoneId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.shade900 : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? Colors.red : Colors.white10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("ZONE $zoneId", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("$zPresent/$zTotal", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: zTotal > 0 ? zPresent / zTotal : 0,
                              backgroundColor: Colors.white10,
                              color: isSelected ? Colors.white : Colors.red,
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
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
                          "DÉTAILS DES ENTRÉES - ZONE $_selectedZone",
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

  Widget _buildGlobalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
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
