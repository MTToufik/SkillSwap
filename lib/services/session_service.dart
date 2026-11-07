import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('sessions');

  // Current user's sessions as learner or teacher.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMySessions() {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _sessions
        .where('participantIds', arrayContains: user.uid)
        .snapshots();
  }

  // Create a new session request.
  Future<void> createSession({
    required String teacherId,
    required String teacherName,
    required String skill,
    required DateTime scheduledAt,
    required String note,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    if (teacherId == user.uid) {
      throw Exception('You cannot schedule a session with yourself.');
    }

    if (scheduledAt.isBefore(DateTime.now())) {
      throw Exception('Please select a future date and time.');
    }

    final learnerSnapshot = await _firestore
        .collection('publicProfiles')
        .doc(user.uid)
        .get();

    final learnerName =
        learnerSnapshot.data()?['name'] as String? ??
        user.displayName ??
        user.email?.split('@').first ??
        'SkillSwap User';

    final cleanSkill = skill.trim();

    if (cleanSkill.isEmpty) {
      throw Exception('Skill name cannot be empty.');
    }

    await _sessions.add({
      'learnerId': user.uid,
      'learnerName': learnerName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'skill': cleanSkill,
      'note': note.trim(),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': 60,
      'status': 'pending',
      'participantIds': [user.uid, teacherId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept, reject, cancel or complete a session.
  Future<void> updateSessionStatus({
    required String sessionId,
    required String status,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    const allowedStatuses = ['accepted', 'rejected', 'cancelled', 'completed'];

    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid session status.');
    }

    await _sessions.doc(sessionId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
