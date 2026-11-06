import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Registration + Private and Public Profile Creation
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

      final privateRef = _firestore.collection('users').doc(user.uid);
      final publicRef = _firestore.collection('publicProfiles').doc(user.uid);

      final profileData = {
        'uid': user.uid,
        'name': cleanName,
        'bio': 'New SkillSwap learner',
        'skillsToLearn': <String>[],
        'skillsToTeach': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(privateRef, {...profileData, 'email': cleanEmail});

      batch.set(publicRef, profileData);

      await batch.commit();
    } on FirebaseException {
      await _auth.signOut();
      rethrow;
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    return credential;
  }

  // Login + Ensure Both Profiles Exist
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

  // Create Missing Private/Public Profiles
  Future<void> ensureUserProfile(User user) async {
    final privateRef = _firestore.collection('users').doc(user.uid);
    final publicRef = _firestore.collection('publicProfiles').doc(user.uid);

    final privateSnapshot = await privateRef.get();
    final publicSnapshot = await publicRef.get();

    final email = user.email ?? '';

    final fallbackName = email.contains('@')
        ? email.split('@').first
        : 'SkillSwap User';

    final privateData = privateSnapshot.data();

    final name =
        (privateData?['name'] as String?) ?? user.displayName ?? fallbackName;

    final bio = (privateData?['bio'] as String?) ?? 'New SkillSwap learner';

    final skillsToLearn = List<String>.from(
      privateData?['skillsToLearn'] ?? [],
    );

    final skillsToTeach = List<String>.from(
      privateData?['skillsToTeach'] ?? [],
    );

    final createdAt = privateData?['createdAt'];

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

  // Forgot Password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
