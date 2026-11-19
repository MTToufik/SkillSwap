import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/review_service.dart';

class RatingReviewScreen extends StatefulWidget {
  final String sessionId;
  final String revieweeId;
  final String revieweeName;
  final String skill;

  const RatingReviewScreen({
    super.key,
    required this.sessionId,
    required this.revieweeId,
    required this.revieweeName,
    required this.skill,
  });

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();

  static const Color primaryColor = Color(0xFF5B5FEF);

  int _rating = 5;
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await _reviewService.createReview(
        sessionId: widget.sessionId,
        revieweeId: widget.revieweeId,
        revieweeName: widget.revieweeName,
        skill: widget.skill,
        rating: _rating,
        comment: _commentController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your review has been submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit review: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStars({
    required int rating,
    required ValueChanged<int>? onChanged,
    double size = 34,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;

        return IconButton(
          onPressed: onChanged == null ? null : () => onChanged(starNumber),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            starNumber <= rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }

  Widget _buildReviewList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviewService.streamReviewsForUser(widget.revieweeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load reviews.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!.docs.toList();

        reviews.sort((a, b) {
          final aDate = a.data()['createdAt'] as Timestamp?;
          final bDate = b.data()['createdAt'] as Timestamp?;

          return (bDate?.compareTo(aDate ?? Timestamp(0, 0)) ?? 0);
        });

        if (reviews.isEmpty) {
          return const Text(
            'No reviews yet.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: reviews.map((document) {
            final data = document.data();
            final rating = (data['rating'] as num?)?.toInt() ?? 0;
            final reviewerName =
                data['reviewerName'] as String? ?? 'SkillSwap User';
            final comment = data['comment'] as String? ?? '';
            final skill = data['skill'] as String? ?? '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E9F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reviewerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildStars(rating: rating, onChanged: null, size: 19),
                    ],
                  ),
                  if (skill.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Session: $skill',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(comment),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Rating & Reviews'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _reviewService.getMyReview(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final alreadyReviewed =
                    snapshot.hasData && snapshot.data!.exists;

                if (alreadyReviewed) {
                  final data = snapshot.data!.data()!;
                  final oldRating = (data['rating'] as num?)?.toInt() ?? 0;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You have already reviewed this session.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildStars(rating: oldRating, onChanged: null),
                        if ((data['comment'] as String? ?? '').isNotEmpty)
                          Text(data['comment'] as String),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Text('Could not check your review status.');
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review ${widget.revieweeName}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Completed session: ${widget.skill}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your Rating',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _buildStars(
                        rating: _rating,
                        onChanged: (value) {
                          setState(() => _rating = value);
                        },
                        size: 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_rating out of 5 stars',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Write a Review (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Share your learning experience...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitReview,
                          icon: const Icon(Icons.send),
                          label: Text(
                            _isSubmitting ? 'Submitting...' : 'Submit Review',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 13),
            _buildReviewList(),
          ],
        ),
      ),
    );
  }
}
