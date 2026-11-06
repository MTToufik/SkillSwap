import 'package:cloud_firestore/cloud_firestore.dart';

class SkillDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get All Public Profiles
  Stream<List<Map<String, dynamic>>> getPublicProfiles() {
    return _firestore
        .collection('publicProfiles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {...doc.data(), 'uid': doc.id};
          }).toList();
        });
  }

  // Get One User Profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snapshot = await _firestore
        .collection('publicProfiles')
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return {...snapshot.data()!, 'uid': snapshot.id};
  }
}
