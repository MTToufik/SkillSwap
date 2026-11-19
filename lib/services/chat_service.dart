import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return user.uid;
  }

  // CHAT LIST STREAM

  Stream<List<Map<String, dynamic>>> getChats() {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: _uid)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map((doc) {
            return {...doc.data(), 'chatId': doc.id};
          }).toList();

          chats.sort((a, b) {
            final aTime = a['updatedAt'] as Timestamp?;
            final bTime = b['updatedAt'] as Timestamp?;

            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });

          return chats;
        });
  }

  // SYNC ACCEPTED CHATS

  Future<void> syncAcceptedChats() async {
    final uid = _uid;

    try {
      // STEP 1: Get sent requests.
      final sentRequests = await _firestore
          .collection('exchangeRequests')
          .where('senderId', isEqualTo: uid)
          .get();

      // STEP 2: Get received requests.
      final receivedRequests = await _firestore
          .collection('exchangeRequests')
          .where('receiverId', isEqualTo: uid)
          .get();

      // STEP 3: Process accepted sent requests.
      for (final doc in sentRequests.docs) {
        final data = doc.data();

        if (data['status'] == 'accepted') {
          await _createChatFromExchangeRequest(doc.id, data);
        }
      }

      // STEP 4: Process accepted received requests.
      for (final doc in receivedRequests.docs) {
        final data = doc.data();

        if (data['status'] == 'accepted') {
          await _createChatFromExchangeRequest(doc.id, data);
        }
      }

      // STEP 5: Get learning sessions.
      final sessions = await _firestore
          .collection('sessions')
          .where('participantIds', arrayContains: uid)
          .get();

      // STEP 6: Process accepted/completed sessions.
      for (final doc in sessions.docs) {
        final data = doc.data();

        if (data['status'] == 'accepted' || data['status'] == 'completed') {
          await _createChatFromSession(doc.id, data);
        }
      }
    } on FirebaseException catch (e) {
      throw Exception('Chat sync failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Chat sync failed: $e');
    }
  }

  // CREATE CHAT FROM EXCHANGE REQUEST

  Future<void> _createChatFromExchangeRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;

    await _createOrGetChat(
      firstUserId: senderId,
      firstUserName: (data['senderName'] ?? 'SkillSwap User').toString(),
      secondUserId: receiverId,
      secondUserName: (data['receiverName'] ?? 'SkillSwap User').toString(),
      sourceType: 'exchangeRequest',
      sourceId: requestId,
    );
  }

  // CREATE CHAT FROM SESSION

  Future<void> _createChatFromSession(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    final learnerId = data['learnerId'] as String;
    final teacherId = data['teacherId'] as String;

    await _createOrGetChat(
      firstUserId: learnerId,
      firstUserName: (data['learnerName'] ?? 'SkillSwap User').toString(),
      secondUserId: teacherId,
      secondUserName: (data['teacherName'] ?? 'SkillSwap User').toString(),
      sourceType: 'session',
      sourceId: sessionId,
    );
  }

  // CREATE OR GET CHAT

  Future<String> _createOrGetChat({
    required String firstUserId,
    required String firstUserName,
    required String secondUserId,
    required String secondUserName,
    required String sourceType,
    required String sourceId,
  }) async {
    if (firstUserId == secondUserId) {
      throw Exception('A chat requires two different users.');
    }

    final ids = [firstUserId, secondUserId]..sort();

    final chatId = '${ids[0]}__${ids[1]}';

    final chatRef = _firestore.collection('chats').doc(chatId);

    final names = <String, String>{
      ids[0]: ids[0] == firstUserId ? firstUserName : secondUserName,
      ids[1]: ids[1] == firstUserId ? firstUserName : secondUserName,
    };

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(chatRef);

        // Do not overwrite an existing conversation.
        if (snapshot.exists) {
          final existingData = snapshot.data();

          if (existingData == null ||
              !(existingData['participantIds'] as List).contains(_uid)) {
            throw Exception('You are not a participant in this chat.');
          }

          return;
        }

        transaction.set(chatRef, {
          'participantIds': ids,
          'participantNames': names,
          'sourceType': sourceType,
          'sourceId': sourceId,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadCounts': {ids[0]: 0, ids[1]: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Could not create chat ($sourceType/$sourceId): '
        '${e.code} - ${e.message}',
      );
    }

    return chatId;
  }

  // GET MESSAGES STREAM

  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {...doc.data(), 'messageId': doc.id};
          }).toList();
        });
  }

  // SEND MESSAGE

  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String text,
  }) async {
    final uid = _uid;
    final messageText = text.trim();

    if (messageText.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    if (messageText.length > 2000) {
      throw Exception('Message is too long.');
    }

    if (receiverId == uid) {
      throw Exception('You cannot message yourself.');
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _firestore.batch();

    batch.set(messageRef, {
      'senderId': uid,
      'receiverId': receiverId,
      'text': messageText,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
    });

    batch.update(chatRef, {
      'lastMessage': messageText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$uid': 0,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Message sending failed: ${e.code} - ${e.message}');
    }
  }

  // MARK MESSAGES AS READ

  Future<void> markMessagesAsRead(String chatId) async {
    final uid = _uid;

    final chatRef = _firestore.collection('chats').doc(chatId);

    try {
      final unreadMessages = await chatRef
          .collection('messages')
          .where('receiverId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      // Update messages in batches of 450.
      for (var i = 0; i < unreadMessages.docs.length; i += 450) {
        final end = (i + 450 < unreadMessages.docs.length)
            ? i + 450
            : unreadMessages.docs.length;

        final batch = _firestore.batch();

        for (final doc in unreadMessages.docs.sublist(i, end)) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      // Reset current user's unread count.
      final chatSnapshot = await chatRef.get();

      if (!chatSnapshot.exists) return;

      final unreadCounts = Map<String, dynamic>.from(
        chatSnapshot.data()?['unreadCounts'] ?? {},
      );

      final currentUnread = (unreadCounts[uid] as num?)?.toInt() ?? 0;

      if (currentUnread > 0) {
        await chatRef.update({
          'unreadCounts': {...unreadCounts, uid: 0},
        });
      }
    } on FirebaseException catch (e) {
      throw Exception('Marking messages read failed: ${e.code} - ${e.message}');
    }
  }
}
