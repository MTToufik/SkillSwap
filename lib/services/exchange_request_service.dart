import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExchangeRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('exchangeRequests');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('publicProfiles');

  // GET CURRENT USER PROFILE


  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    final snapshot = await _profiles.doc(user.uid).get();

    if (!snapshot.exists) {
      throw Exception('User profile not found.');
    }

    return snapshot.data() ?? {};
  }


  // GET MY PROFILE


  Future<Map<String, dynamic>> getMyProfile() async {
    return getCurrentUserProfile();
  }

 
  // STREAM PUBLIC PROFILES


  Stream<QuerySnapshot<Map<String, dynamic>>> streamProfiles() {
    return _profiles.snapshots();
  }

 
  // STREAM RECEIVED REQUESTS
 

  Stream<QuerySnapshot<Map<String, dynamic>>> streamReceivedRequests() {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _requests.where('receiverId', isEqualTo: user.uid).snapshots();
  }


  // STREAM SENT REQUESTS
  

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSentRequests() {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _requests.where('senderId', isEqualTo: user.uid).snapshots();
  }

  
  // SEND EXCHANGE REQUEST


  Future<void> sendRequest({
    required String receiverId,
    required String requestedSkill,
    required String offeredSkill,
    required String note,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    if (receiverId.trim().isEmpty || receiverId == user.uid) {
      throw Exception('Invalid receiver.');
    }

    final cleanRequestedSkill = requestedSkill.trim();
    final cleanOfferedSkill = offeredSkill.trim();
    final cleanNote = note.trim();

    if (cleanRequestedSkill.isEmpty || cleanOfferedSkill.isEmpty) {
      throw Exception('Please select both skills.');
    }

    if (cleanRequestedSkill.length > 40 || cleanOfferedSkill.length > 40) {
      throw Exception('Skill name cannot exceed 40 characters.');
    }

    if (cleanNote.length > 250) {
      throw Exception('Message cannot exceed 250 characters.');
    }

    // Get sender and receiver profiles.
    final senderSnapshot = await _profiles.doc(user.uid).get();
    final receiverSnapshot = await _profiles.doc(receiverId).get();

    if (!senderSnapshot.exists || !receiverSnapshot.exists) {
      throw Exception('User profile not found.');
    }

    final senderData = senderSnapshot.data() ?? {};
    final receiverData = receiverSnapshot.data() ?? {};

    final senderName = (senderData['name'] ?? 'SkillSwap User').toString();

    final receiverName = (receiverData['name'] ?? 'SkillSwap User').toString();

    final senderSkills = List<String>.from(senderData['skillsToTeach'] ?? []);

    final receiverSkills = List<String>.from(
      receiverData['skillsToTeach'] ?? [],
    );

    // Validate offered skill.
    if (!senderSkills.contains(cleanOfferedSkill)) {
      throw Exception('You cannot offer a skill you do not teach.');
    }

    // Validate requested skill.
    if (!receiverSkills.contains(cleanRequestedSkill)) {
      throw Exception('Selected skill is not available from this user.');
    }

    // Prevent duplicate pending requests.
    final duplicate = await _requests
        .where('senderId', isEqualTo: user.uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('requestedSkill', isEqualTo: cleanRequestedSkill)
        .where('status', isEqualTo: 'pending')
        .get();

    if (duplicate.docs.isNotEmpty) {
      throw Exception('You already have a pending request for this skill.');
    }

    // Create request.
    await _requests.add({
      'senderId': user.uid,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'offeredSkill': cleanOfferedSkill,
      'requestedSkill': cleanRequestedSkill,
      'note': cleanNote,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  // ACCEPT, REJECT OR CANCEL REQUEST
  

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    const allowedStatuses = ['accepted', 'rejected', 'cancelled'];

    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid request status.');
    }

    final requestRef = _requests.doc(requestId);
    final snapshot = await requestRef.get();

    if (!snapshot.exists) {
      throw Exception('Request not found.');
    }

    final data = snapshot.data()!;

    final senderId = data['senderId'];
    final receiverId = data['receiverId'];
    final currentStatus = data['status'];

    // Receiver can accept or reject pending requests.
    if (status == 'accepted' || status == 'rejected') {
      if (user.uid != receiverId || currentStatus != 'pending') {
        throw Exception('You cannot update this request.');
      }
    }

    // Sender can cancel pending requests.
    if (status == 'cancelled') {
      if (user.uid != senderId || currentStatus != 'pending') {
        throw Exception('You cannot cancel this request.');
      }
    }

    await requestRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
