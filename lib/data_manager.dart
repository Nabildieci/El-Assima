import 'package:cloud_firestore/cloud_firestore.dart';

class DataManager {
  static Future<void> seedInitialMembers() async {
    final collection = FirebaseFirestore.instance.collection('members');
    
    // 1. Clean up potential duplicates (Optional but recommended since user complained)
    // We only keep ac001 and ac010. We delete anything else for now to reset.
    final snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      if (doc.id != 'ac001' && doc.id != 'AC010' && doc.id != 'ac010') {
        await doc.reference.delete();
      }
    }

    // 2. Seed Souheib
    await collection.doc('ac001').set({
      'name': 'Laroui Souheib',
      'cardId': 'ac001',
      'is_present': false,
      'matricule': 'ac001',
      'zone': 14,
    }, SetOptions(merge: true));

    // 3. Seed Nabil (Updated from Card Photo)
    // We use AC010 to match the ID on the card exactly
    await collection.doc('AC010').set({
      'name': 'Lafri Nabil Riad',
      'cardId': 'AC010',
      'is_present': false,
      'matricule': 'AC010',
      'zone': 14,
    }, SetOptions(merge: true));
    
    print("Database cleaned and initial members seeded (Souheib & Nabil only).");
  }
}
