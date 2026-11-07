import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  // REGISTER
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Account could not be created.');
    }

    try {
      await user.updateDisplayName(cleanName);

      final batch = _firestore.batch();

      final profileData = {
        'uid': user.uid,
        'name': cleanName,
        'bio': 'New SkillSwap learner',
        'skillsToLearn': <String>[],
        'skillsToTeach': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(_users.doc(user.uid), {...profileData, 'email': cleanEmail});

      batch.set(_publicProfiles.doc(user.uid), profileData);

      await batch.commit();
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    return credential;
  }

  // LOGIN
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Login failed.');
    }

    try {
      await ensureUserProfile(user);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    return credential;
  }

  // ENSURE OLD AND NEW USER PROFILES EXIST
  Future<void> ensureUserProfile(User user) async {
    final privateRef = _users.doc(user.uid);
    final publicRef = _publicProfiles.doc(user.uid);

    final privateSnapshot = await privateRef.get();
    final publicSnapshot = await publicRef.get();

    final privateData = privateSnapshot.data();
    final publicData = publicSnapshot.data();

    final email = user.email ?? '';

    final fallbackName = email.contains('@')
        ? email.split('@').first
        : 'SkillSwap User';

    final name =
        privateData?['name'] as String? ??
        publicData?['name'] as String? ??
        user.displayName ??
        fallbackName;

    final bio =
        privateData?['bio'] as String? ??
        publicData?['bio'] as String? ??
        'New SkillSwap learner';

    final skillsToLearn = List<String>.from(
      privateData?['skillsToLearn'] ?? publicData?['skillsToLearn'] ?? [],
    );

    final skillsToTeach = List<String>.from(
      privateData?['skillsToTeach'] ?? publicData?['skillsToTeach'] ?? [],
    );

    final createdAt = privateData?['createdAt'] ?? publicData?['createdAt'];

    final batch = _firestore.batch();

    if (!privateSnapshot.exists) {
      batch.set(privateRef, {
        'uid': user.uid,
        'name': name,
        'email': email,
        'bio': bio,
        'skillsToLearn': skillsToLearn,
        'skillsToTeach': skillsToTeach,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (!publicSnapshot.exists) {
      batch.set(publicRef, {
        'uid': user.uid,
        'name': name,
        'bio': bio,
        'skillsToLearn': skillsToLearn,
        'skillsToTeach': skillsToTeach,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      });
    }

    if (!privateSnapshot.exists || !publicSnapshot.exists) {
      await batch.commit();
    }
  }

  // GET CURRENT USER PRIVATE PROFILE
  Future<Map<String, dynamic>> getMyProfile() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    await ensureUserProfile(user);

    final snapshot = await _users.doc(user.uid).get();

    if (!snapshot.exists) {
      throw Exception('Profile not found.');
    }

    return snapshot.data()!;
  }

  // UPDATE NAME, BIO AND SKILLS IN BOTH COLLECTIONS
  Future<void> updateProfile({
    required String name,
    required String bio,
    required List<String> skillsToLearn,
    required List<String> skillsToTeach,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final cleanName = name.trim();
    final cleanBio = bio.trim();

    if (cleanName.isEmpty) {
      throw Exception('Name cannot be empty.');
    }

    if (cleanName.length > 50) {
      throw Exception('Name cannot exceed 50 characters.');
    }

    if (cleanBio.length > 250) {
      throw Exception('Bio cannot exceed 250 characters.');
    }

    final cleanLearn = _cleanSkills(skillsToLearn);
    final cleanTeach = _cleanSkills(skillsToTeach);

    if (cleanLearn.length > 20 || cleanTeach.length > 20) {
      throw Exception('You can add up to 20 skills in each category.');
    }

    await ensureUserProfile(user);

    final updateData = {
      'name': cleanName,
      'bio': cleanBio,
      'skillsToLearn': cleanLearn,
      'skillsToTeach': cleanTeach,
    };

    final batch = _firestore.batch();

    batch.update(_users.doc(user.uid), updateData);
    batch.update(_publicProfiles.doc(user.uid), updateData);

    await batch.commit();

    await user.updateDisplayName(cleanName);
  }

  // UPDATE TEACHING AND LEARNING SKILLS
  Future<void> updateSkills({
    required List<String> skillsToTeach,
    required List<String> skillsToLearn,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final profile = await getMyProfile();

    await updateProfile(
      name: profile['name'] ?? user.displayName ?? 'SkillSwap User',
      bio: profile['bio'] ?? '',
      skillsToLearn: skillsToLearn,
      skillsToTeach: skillsToTeach,
    );
  }

  // COMPATIBILITY METHOD FOR MY SKILLS SCREEN
  Future<void> updateMySkills({
    required List<String> skillsToLearn,
    required List<String> skillsToTeach,
  }) async {
    await updateSkills(
      skillsToTeach: skillsToTeach,
      skillsToLearn: skillsToLearn,
    );
  }

  // REMOVE DUPLICATES AND EMPTY SKILLS
  List<String> _cleanSkills(List<String> skills) {
    final result = <String>[];

    for (final skill in skills) {
      final clean = skill.trim();

      if (clean.isNotEmpty &&
          !result.any(
            (existing) => existing.toLowerCase() == clean.toLowerCase(),
          )) {
        result.add(clean);
      }
    }

    return result;
  }

  // FORGOT PASSWORD
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
