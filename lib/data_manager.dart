import 'package:cloud_firestore/cloud_firestore.dart';

class DataManager {
  static Future<void> seedInitialMembers() async {
    final collection = FirebaseFirestore.instance.collection('members');
    
    print("Synchronisation des membres avec la base de données...");

    // 2. Sample data (Added members for testing)
    final List<Map<String, dynamic>> initialData = [
      {
        'cardId': 'AC001',
        'name': 'Laroui Souheib',
        'is_present': false,
        'matricule': 'AC001',
        'zone': 14,
      },
      {
        'cardId': 'ID001',
        'name': 'Test User ID001',
        'is_present': false,
        'matricule': 'ID001',
        'zone': 14,
      },
      {
        'cardId': 'AC010',
        'name': 'Lafri Nabil Riad',
        'is_present': false,
        'matricule': 'AC010',
        'zone': 14,
      },
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (var member in initialData) {
      batch.set(collection.doc(member['cardId']), {
        ...member,
        'last_scanned': null,
      });
    }
    
    await batch.commit();
    print("Base de données initialisée avec ${initialData.length} membres de test.");
  }
}
