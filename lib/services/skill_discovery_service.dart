import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SkillDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // GET ALL PUBLIC PROFILES
  // ==========================================

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

  // ==========================================
  // GET CURRENT USER PROFILE
  // ==========================================

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final snapshot = await _firestore
        .collection('publicProfiles')
        .doc(user.uid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return {...snapshot.data()!, 'uid': snapshot.id};
  }

  // ==========================================
  // GET ONE USER PROFILE
  // ==========================================

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

  // ==========================================
  // CONVERT FIRESTORE SKILLS TO STRING LIST
  // ==========================================

  List<String> _getSkills(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .where((skill) => skill != null)
        .map((skill) => skill.toString().trim())
        .where((skill) => skill.isNotEmpty)
        .toSet()
        .toList();
  }

  // ==========================================
  // FIND COMMON SKILLS
  // CASE-INSENSITIVE MATCHING
  // ==========================================

  List<String> _findCommonSkills(
    List<String> firstSkills,
    List<String> secondSkills,
  ) {
    final secondSkillMap = {
      for (final skill in secondSkills) skill.toLowerCase().trim(): skill,
    };

    final matchedSkills = <String>[];

    for (final skill in firstSkills) {
      final key = skill.toLowerCase().trim();

      if (secondSkillMap.containsKey(key)) {
        matchedSkills.add(skill);
      }
    }

    return matchedSkills.toSet().toList();
  }

  // ==========================================
  // CALCULATE COMPLEMENTARY MATCH
  // ==========================================

  Map<String, dynamic> calculateMatch(
    Map<String, dynamic> currentProfile,
    Map<String, dynamic> otherProfile,
  ) {
    final currentTeachSkills = _getSkills(currentProfile['skillsToTeach']);

    final currentLearnSkills = _getSkills(currentProfile['skillsToLearn']);

    final otherTeachSkills = _getSkills(otherProfile['skillsToTeach']);

    final otherLearnSkills = _getSkills(otherProfile['skillsToLearn']);

    // Current user teaches what the other user wants to learn.
    final teachToLearn = _findCommonSkills(
      currentTeachSkills,
      otherLearnSkills,
    );

    // Current user wants to learn what the other user teaches.
    final learnFromTeach = _findCommonSkills(
      currentLearnSkills,
      otherTeachSkills,
    );

    int score = 0;

    if (teachToLearn.isNotEmpty) {
      score += 50;
    }

    if (learnFromTeach.isNotEmpty) {
      score += 50;
    }

    return {
      'score': score,
      'teachToLearn': teachToLearn,
      'learnFromTeach': learnFromTeach,
      'isPerfectMatch': score == 100,
      'hasMatch': score > 0,
    };
  }

  // ==========================================
  // GET MATCH SCORE ONLY
  // ==========================================

  int getMatchScore(
    Map<String, dynamic> currentProfile,
    Map<String, dynamic> otherProfile,
  ) {
    final result = calculateMatch(currentProfile, otherProfile);

    return result['score'] as int;
  }
}
