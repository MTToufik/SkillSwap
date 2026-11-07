import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/exchange_request_service.dart';

class ExchangeRequestsScreen extends StatefulWidget {
  const ExchangeRequestsScreen({super.key});

  @override
  State<ExchangeRequestsScreen> createState() => _ExchangeRequestsScreenState();
}

class _ExchangeRequestsScreenState extends State<ExchangeRequestsScreen> {
  final ExchangeRequestService _service = ExchangeRequestService();

  static const Color primaryColor = Color(0xFF5B5FEF);

  // ==========================================
  // SEND EXCHANGE REQUEST
  // ==========================================

  Future<void> _openRequestDialog(
    Map<String, dynamic> profile,
    String requestedSkill,
  ) async {
    final receiverId = profile['uid'] as String?;

    if (receiverId == null) return;

    Map<String, dynamic> myProfile;

    try {
      myProfile = await _service.getMyProfile();
    } catch (e) {
      _showMessage(e.toString());
      return;
    }

    final mySkills = List<String>.from(myProfile['skillsToTeach'] ?? []);

    String selectedOfferSkill = mySkills.isNotEmpty ? mySkills.first : '';

    final noteController = TextEditingController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool sending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Send Exchange Request'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You want to learn:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 6),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        requestedSkill,
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'You can teach in exchange:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedOfferSkill,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No skill to offer'),
                        ),
                        ...mySkills.map(
                          (skill) => DropdownMenuItem(
                            value: skill,
                            child: Text(skill),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedOfferSkill = value ?? '';
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Message (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: noteController,
                      maxLength: 250,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write a short message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const Text(
                      'Your request will be sent to the selected user.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          setDialogState(() {
                            sending = true;
                          });

                          try {
                            await _service.sendRequest(
                              receiverId: receiverId,
                              requestedSkill: requestedSkill,
                              offeredSkill: selectedOfferSkill,
                              note: noteController.text,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            _showMessage('Exchange request sent successfully!');
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                            });

                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  // ==========================================
  // FIND PARTNERS
  // ==========================================

  Widget _buildFindPartners() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.streamProfiles(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load users.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUid = _service.currentUser?.uid;

        final profiles =
            snapshot.data?.docs.where((doc) {
              return doc.id != currentUid;
            }).toList() ??
            [];

        if (profiles.isEmpty) {
          return const Center(child: Text('No other users found yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final profile = profiles[index].data();

            final name = profile['name'] ?? 'SkillSwap User';
            final bio = profile['bio'] ?? '';

            final skills = List<String>.from(profile['skillsToTeach'] ?? []);

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFEDEEF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: primaryColor.withValues(alpha: 0.12),
                        child: Text(
                          name.toString().isNotEmpty
                              ? name.toString()[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            if (bio.toString().isNotEmpty)
                              Text(
                                bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Skills to Teach',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  if (skills.isEmpty)
                    const Text(
                      'No teaching skills added yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((skill) {
                        return ActionChip(
                          avatar: const Icon(Icons.swap_horiz, size: 17),
                          label: Text(skill),
                          onPressed: () {
                            _openRequestDialog(profile, skill);
                          },
                          backgroundColor: primaryColor.withValues(alpha: 0.08),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),

                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Tap a skill to send an exchange request.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // REQUEST LIST
  // ==========================================

  Widget _buildRequestList({required bool received}) {
    final stream = received
        ? _service.streamReceivedRequests()
        : _service.streamSentRequests();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load requests.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs.toList() ?? [];

        requests.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;

          return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
            aTime?.millisecondsSinceEpoch ?? 0,
          );
        });

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  received ? Icons.inbox_outlined : Icons.send_outlined,
                  size: 55,
                  color: Colors.grey.shade400,
                ),

                const SizedBox(height: 12),

                Text(
                  received ? 'No Received Requests' : 'No Sent Requests',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Your exchange requests will appear here.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data();

            final status = data['status'] ?? 'pending';

            final personName = received
                ? data['senderName'] ?? 'SkillSwap User'
                : data['receiverName'] ?? 'SkillSwap User';

            final requestedSkill = data['requestedSkill'] ?? '';

            final offeredSkill = data['offeredSkill'] ?? '';

            final note = data['note'] ?? '';

            return _buildRequestCard(
              requestId: doc.id,
              personName: personName,
              requestedSkill: requestedSkill,
              offeredSkill: offeredSkill,
              note: note,
              status: status,
              received: received,
            );
          },
        );
      },
    );
  }

  // ==========================================
  // REQUEST CARD
  // ==========================================

  Widget _buildRequestCard({
    required String requestId,
    required String personName,
    required String requestedSkill,
    required String offeredSkill,
    required String note,
    required String status,
    required bool received,
  }) {
    Color statusColor;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: primaryColor),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  personName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _infoRow('Wants to learn', requestedSkill),

          const SizedBox(height: 8),

          _infoRow(
            'Offers to teach',
            offeredSkill.isEmpty ? 'Not specified' : offeredSkill,
          ),

          if (note.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Message: $note',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],

          if (status == 'pending') ...[
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 5),

            if (received)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _updateStatus(requestId, 'rejected');
                      },
                      child: const Text('Reject'),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _updateStatus(requestId, 'accepted');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _updateStatus(requestId, 'cancelled');
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel Request'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            '$title:',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // UPDATE STATUS
  // ==========================================

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      await _service.updateRequestStatus(requestId: requestId, status: status);

      if (!mounted) return;

      _showMessage('Request $status successfully.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // MAIN SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (_service.currentUser == null) {
      return const Center(
        child: Text('Please login to access exchange requests.'),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              isScrollable: true,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.people_outline), text: 'Find Partners'),
                Tab(icon: Icon(Icons.inbox_outlined), text: 'Received'),
                Tab(icon: Icon(Icons.send_outlined), text: 'Sent'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [
                _buildFindPartners(),
                _buildRequestList(received: true),
                _buildRequestList(received: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
