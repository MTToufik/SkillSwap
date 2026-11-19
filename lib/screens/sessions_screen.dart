import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import 'rating_review_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final SessionService _sessionService = SessionService();
  final AuthService _authService = AuthService();
  final ReviewService _reviewService = ReviewService();

  static const Color primaryColor = Color(0xFF5B5FEF);

  String get _currentUid => _authService.currentUser?.uid ?? '';

  Future<void> _showMessage(String message, {bool error = false}) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _scheduleSession({
    required String teacherId,
    required String teacherName,
    required String skill,
  }) async {
    final noteController = TextEditingController();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    DateTime? scheduledAt;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Schedule Learning Session'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Teacher: $teacherName'),
                      const SizedBox(height: 6),
                      Text('Skill: $skill'),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );

                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Select Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedTime,
                          );

                          if (time != null) {
                            setDialogState(() => selectedTime = time);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(selectedTime.format(context)),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Message to Teacher (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        maxLength: 250,
                        decoration: const InputDecoration(
                          hintText: 'Write a short message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Text(
                        'Session duration: 60 minutes',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final dateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      if (!dateTime.isAfter(DateTime.now())) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Select a future date and time.'),
                          ),
                        );
                        return;
                      }

                      scheduledAt = dateTime;
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Send Request'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true || scheduledAt == null || !mounted) return;

      await _sessionService.createSession(
        teacherId: teacherId,
        teacherName: teacherName,
        skill: skill,
        scheduledAt: scheduledAt!,
        note: noteController.text,
      );

      await _showMessage('Session request sent successfully!');
    } catch (e) {
      await _showMessage('Could not schedule session: $e', error: true);
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _changeStatus(String sessionId, String status) async {
    try {
      await _sessionService.updateSessionStatus(
        sessionId: sessionId,
        status: status,
      );

      await _showMessage('Session updated successfully.');
    } catch (e) {
      await _showMessage('Could not update session: $e', error: true);
    }
  }

  Future<void> _openReview({
    required String sessionId,
    required String revieweeId,
    required String revieweeName,
    required String skill,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingReviewScreen(
          sessionId: sessionId,
          revieweeId: revieweeId,
          revieweeName: revieweeName,
          skill: skill,
        ),
      ),
    );
  }

  Widget _buildRatingSummary(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviewService.streamReviewsForUser(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Row(
            children: [
              Icon(Icons.star_border, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text(
                'No ratings yet',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          );
        }

        final reviews = snapshot.data!.docs;
        final total = reviews.fold<double>(
          0,
          (totalRating, review) =>
              totalRating +
              ((review.data()['rating'] as num?)?.toDouble() ?? 0),
        );

        final average = total / reviews.length;

        return Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              '${average.toStringAsFixed(1)} (${reviews.length} reviews)',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeacherDiscovery() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publicProfiles')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load teachers.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final teachers = snapshot.data!.docs.where((doc) {
          final skills = List<String>.from(doc.data()['skillsToTeach'] ?? []);

          return doc.id != _currentUid && skills.isNotEmpty;
        }).toList();

        if (teachers.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No teachers available yet. Ask other members to add their teaching skills.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: teachers.map((teacher) {
            final data = teacher.data();
            final name = data['name'] as String? ?? 'SkillSwap User';
            final skills = List<String>.from(data['skillsToTeach'] ?? []);

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E9F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withValues(alpha: 0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _buildRatingSummary(teacher.id),
                  const SizedBox(height: 15),
                  const Text(
                    'Teaching Skills',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((skill) {
                      return ActionChip(
                        label: Text(skill),
                        onPressed: () {
                          _scheduleSession(
                            teacherId: teacher.id,
                            teacherName: name,
                            skill: skill,
                          );
                        },
                        backgroundColor: primaryColor.withValues(alpha: 0.10),
                        labelStyle: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap a skill to schedule a learning session.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Date unavailable';

    final date = value.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} at $hour:$minute $period';
  }

  Widget _buildReviewAction({
    required String sessionId,
    required String revieweeId,
    required String revieweeName,
    required String skill,
  }) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _reviewService.getMyReview(sessionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.data!.exists) {
          return const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 19),
              SizedBox(width: 7),
              Text(
                'Review submitted',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return ElevatedButton.icon(
          onPressed: () => _openReview(
            sessionId: sessionId,
            revieweeId: revieweeId,
            revieweeName: revieweeName,
            skill: skill,
          ),
          icon: const Icon(Icons.star_outline),
          label: const Text('Rate & Review'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildSessionCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final learnerId = data['learnerId'] as String? ?? '';
    final teacherId = data['teacherId'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';

    final isTeacher = _currentUid == teacherId;
    final isLearner = _currentUid == learnerId;

    final otherId = isTeacher ? learnerId : teacherId;
    final otherName = isTeacher
        ? data['learnerName'] as String? ?? 'Learner'
        : data['teacherName'] as String? ?? 'Teacher';

    final skill = data['skill'] as String? ?? 'Unknown Skill';
    final note = data['note'] as String? ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  skill,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${isTeacher ? 'Learner' : 'Teacher'}: $otherName',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 17, color: Colors.grey),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDate(data['scheduledAt']),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Duration: 60 minutes',
            style: TextStyle(color: Colors.grey),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Message: $note',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 15),

          if (isTeacher && status == 'pending')
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton(
                  onPressed: () => _changeStatus(document.id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () => _changeStatus(document.id, 'rejected'),
                  child: const Text('Reject'),
                ),
              ],
            ),

          if (isLearner && (status == 'pending' || status == 'accepted'))
            OutlinedButton(
              onPressed: () => _changeStatus(document.id, 'cancelled'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Session'),
            ),

          if (isTeacher && status == 'accepted')
            ElevatedButton.icon(
              onPressed: () => _changeStatus(document.id, 'completed'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),

          if (status == 'completed') ...[
            const Divider(height: 25),
            _buildReviewAction(
              sessionId: document.id,
              revieweeId: otherId,
              revieweeName: otherName,
              skill: skill,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMySessions() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sessionService.streamMySessions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load sessions. Please try again.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs.toList();

        documents.sort((a, b) {
          final aDate = a.data()['scheduledAt'] as Timestamp?;
          final bDate = b.data()['scheduledAt'] as Timestamp?;

          return aDate?.compareTo(bDate ?? Timestamp(0, 0)) ?? 0;
        });

        if (documents.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_outlined, size: 45, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No Sessions Yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 7),
                Text(
                  'Your learning session requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(children: documents.map(_buildSessionCard).toList());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Scheduled Learning Sessions',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22223A),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Find teachers, schedule sessions and manage your learning requests.',
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 25),
            const Text(
              'Find a Teacher',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _buildTeacherDiscovery(),
            const SizedBox(height: 30),
            const Text(
              'My Sessions',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _buildMySessions(),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
