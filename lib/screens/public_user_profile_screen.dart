import 'package:flutter/material.dart';

class PublicUserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const PublicUserProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = (profile['name'] ?? 'SkillSwap User').toString();

    final bio = (profile['bio'] ?? 'No bio available').toString();

    final skillsToTeach = List<String>.from(profile['skillsToTeach'] ?? []);

    final skillsToLearn = List<String>.from(profile['skillsToLearn'] ?? []);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    const primaryColor = Color(0xFF5B5FEF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 48,
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),

            const SizedBox(height: 30),

            _buildSection(
              title: 'Skills I Can Teach',
              skills: skillsToTeach,
              icon: Icons.school_outlined,
            ),

            const SizedBox(height: 18),

            _buildSection(
              title: 'Skills I Want to Learn',
              skills: skillsToLearn,
              icon: Icons.menu_book_outlined,
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Connect and exchange skills with the SkillSwap community.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> skills,
    required IconData icon,
  }) {
    const primaryColor = Color(0xFF5B5FEF);

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
          Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (skills.isEmpty)
            const Text(
              'No skills added yet.',
              style: TextStyle(color: Colors.grey),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: primaryColor.withValues(alpha: 0.09),
                  labelStyle: const TextStyle(color: primaryColor),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
