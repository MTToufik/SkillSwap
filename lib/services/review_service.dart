import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  String _reviewDocumentId(String sessionId, String reviewerId) {
    return '${sessionId}_$reviewerId';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMyReview(
    String sessionId,
  ) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _reviews.doc(_reviewDocumentId(sessionId, user.uid)).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamReviewsForUser(
    String userId,
  ) {
    return _reviews.where('revieweeId', isEqualTo: userId).snapshots();
  }

  Future<void> createReview({
    required String sessionId,
    required String revieweeId,
    required String revieweeName,
    required String skill,
    required int rating,
    required String comment,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }

    final cleanComment = comment.trim();

    if (cleanComment.length > 500) {
      throw Exception('Review cannot exceed 500 characters.');
    }

    if (revieweeId == user.uid) {
      throw Exception('You cannot review yourself.');
    }

    final sessionSnapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (!sessionSnapshot.exists) {
      throw Exception('Session not found.');
    }

    final session = sessionSnapshot.data()!;

    if (session['status'] != 'completed') {
      throw Exception('You can review only completed sessions.');
    }

    final participantIds = List<String>.from(session['participantIds'] ?? []);

    if (!participantIds.contains(user.uid) ||
        !participantIds.contains(revieweeId)) {
      throw Exception('You are not allowed to review this user.');
    }

    final reviewerNameSnapshot = await _firestore
        .collection('publicProfiles')
        .doc(user.uid)
        .get();

    final reviewerName =
        reviewerNameSnapshot.data()?['name'] as String? ??
        user.displayName ??
        'SkillSwap User';

    final reviewId = _reviewDocumentId(sessionId, user.uid);
    final reviewRef = _reviews.doc(reviewId);

    // Create-only: an existing review cannot be overwritten.
    await _firestore.runTransaction((transaction) async {
      final existingReview = await transaction.get(reviewRef);

      if (existingReview.exists) {
        throw Exception('You have already reviewed this session.');
      }

      transaction.set(reviewRef, {
        'sessionId': sessionId,
        'reviewerId': user.uid,
        'reviewerName': reviewerName,
        'revieweeId': revieweeId,
        'revieweeName': revieweeName,
        'skill': skill,
        'rating': rating,
        'comment': cleanComment,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
