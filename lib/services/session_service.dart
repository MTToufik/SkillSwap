import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('sessions');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMySessions() {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _sessions
        .where('participantIds', arrayContains: user.uid)
        .snapshots();
  }

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

    if (!scheduledAt.isAfter(DateTime.now())) {
      throw Exception('Please select a future date and time.');
    }

    final cleanSkill = skill.trim();
    final cleanNote = note.trim();

    if (cleanSkill.isEmpty || cleanSkill.length > 40) {
      throw Exception('Skill name must be between 1 and 40 characters.');
    }

    if (cleanNote.length > 250) {
      throw Exception('Note cannot exceed 250 characters.');
    }

    final teacherSnapshot = await _firestore
        .collection('publicProfiles')
        .doc(teacherId)
        .get();

    if (!teacherSnapshot.exists) {
      throw Exception('Teacher profile not found.');
    }

    final teacherData = teacherSnapshot.data() ?? {};
    final teacherSkills = List<String>.from(teacherData['skillsToTeach'] ?? []);

    if (!teacherSkills.contains(cleanSkill)) {
      throw Exception('This teacher does not offer this skill anymore.');
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

    await _sessions.add({
      'learnerId': user.uid,
      'learnerName': learnerName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'skill': cleanSkill,
      'note': cleanNote,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': 60,
      'status': 'pending',
      'participantIds': [user.uid, teacherId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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

    final sessionRef = _sessions.doc(sessionId);
    final sessionSnapshot = await sessionRef.get();

    if (!sessionSnapshot.exists) {
      throw Exception('Session not found.');
    }

    final data = sessionSnapshot.data()!;
    final learnerId = data['learnerId'] as String?;
    final teacherId = data['teacherId'] as String?;
    final currentStatus = data['status'] as String?;

    final isTeacher = user.uid == teacherId;
    final isLearner = user.uid == learnerId;

    if (!isTeacher && !isLearner) {
      throw Exception('You are not a participant of this session.');
    }

    final validAction =
        (isTeacher &&
            currentStatus == 'pending' &&
            (status == 'accepted' || status == 'rejected')) ||
        (isTeacher && currentStatus == 'accepted' && status == 'completed') ||
        (isLearner &&
            (currentStatus == 'pending' || currentStatus == 'accepted') &&
            status == 'cancelled');

    if (!validAction) {
      throw Exception('You are not allowed to perform this action.');
    }

    await sessionRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
