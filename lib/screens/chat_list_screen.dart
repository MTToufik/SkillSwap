import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  late Stream<List<Map<String, dynamic>>> _chatsStream;

  bool _isSyncing = false;
  String? _syncError;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    _chatsStream = _chatService.getChats();

    if (_currentUid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncChats();
      });
    }
  }


  // SYNC ACCEPTED CHATS


  Future<void> _syncChats() async {
    if (_currentUid.isEmpty || _isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    try {
      await _chatService.syncAcceptedChats();

      if (!mounted) return;

      setState(() {
        _syncError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _syncError = e.toString();
      });

      debugPrint('CHAT SYNC ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }


  // REFRESH


  Future<void> _refreshChats() async {
    await _syncChats();
  }


  // GET OTHER USER ID
 

  String _otherUserId(Map<String, dynamic> chat) {
    final ids = List<String>.from(chat['participantIds'] ?? []);

    return ids.firstWhere((id) => id != _currentUid, orElse: () => '');
  }


  // GET OTHER USER NAME


  String _otherUserName(Map<String, dynamic> chat) {
    final otherId = _otherUserId(chat);

    final names = Map<String, dynamic>.from(chat['participantNames'] ?? {});

    return (names[otherId] ?? 'SkillSwap User').toString();
  }


  // FORMAT TIME
 

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    return '${date.day}/${date.month}/${date.year}';
  }


  // OPEN CHAT
 

  void _openChat(Map<String, dynamic> chat) {
    final otherId = _otherUserId(chat);
    final otherName = _otherUserName(chat);
    final chatId = chat['chatId']?.toString() ?? '';

    if (otherId.isEmpty || chatId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: otherId,
          otherUserName: otherName,
        ),
      ),
    );
  }


  // SYNC ERROR BANNER


  Widget _buildSyncError() {
    if (_syncError == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chat synchronization failed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            _syncError!,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isSyncing ? null : _syncChats,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  
  // EMPTY CHAT LIST


  Widget _buildEmptyChats() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 110),
        Icon(Icons.chat_bubble_outline, size: 65, color: Colors.grey),
        SizedBox(height: 18),
        Center(
          child: Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 35),
            child: Text(
              'Accept an exchange request or learning session to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

 
  // CHAT LIST ITEM


  Widget _buildChatItem(Map<String, dynamic> chat) {
    final otherName = _otherUserName(chat);

    final unreadCounts = Map<String, dynamic>.from(chat['unreadCounts'] ?? {});

    final unread = (unreadCounts[_currentUid] as num?)?.toInt() ?? 0;

    final lastMessage = (chat['lastMessage'] ?? '').toString();
    final lastSenderId = (chat['lastSenderId'] ?? '').toString();

    final preview = lastMessage.isEmpty
        ? 'Start a conversation'
        : lastSenderId == _currentUid
        ? 'You: $lastMessage'
        : lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: CircleAvatar(
        radius: 27,
        backgroundColor: const Color(0xFF5B5FEF),
        child: Text(
          otherName.isNotEmpty ? otherName[0].toUpperCase() : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      title: Text(
        otherName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread > 0 ? const Color(0xFF333344) : Colors.grey,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat['lastMessageAt']),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 7),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xFF5B5FEF),
                shape: BoxShape.circle,
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => _openChat(chat),
    );
  }


  // BUILD
  

  @override
  Widget build(BuildContext context) {
    if (_currentUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login to access chats.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          if (_isSyncing)
            const LinearProgressIndicator(
              color: Color(0xFF5B5FEF),
              minHeight: 2,
            ),

          _buildSyncError(),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5B5FEF)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 45,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load conversations.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _chatsStream = _chatService.getChats();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshChats,
                    child: _buildEmptyChats(),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshChats,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 78),
                    itemBuilder: (context, index) {
                      return _buildChatItem(chats[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
