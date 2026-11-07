import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  final AuthService _authService = AuthService();

  List<String> _skillsToTeach = [];
  List<String> _skillsToLearn = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    try {
      final profile = await _authService.getMyProfile();

      if (!mounted) return;

      setState(() {
        _skillsToTeach = List<String>.from(profile['skillsToTeach'] ?? []);

        _skillsToLearn = List<String>.from(profile['skillsToLearn'] ?? []);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not load skills: $e', isError: true);
    }
  }

  // ADD SKILL
  Future<void> _addSkill(bool isTeaching) async {
    if (_isSaving) return;

    final skill = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _AddSkillDialog(isTeaching: isTeaching);
      },
    );

    if (!mounted || skill == null) return;

    final cleanSkill = skill.trim();

    if (cleanSkill.isEmpty) return;

    final target = isTeaching ? _skillsToTeach : _skillsToLearn;

    final alreadyExists = target.any(
      (item) => item.toLowerCase() == cleanSkill.toLowerCase(),
    );

    if (alreadyExists) {
      _showMessage('This skill already exists.', isError: true);
      return;
    }

    setState(() {
      if (isTeaching) {
        _skillsToTeach.add(cleanSkill);
      } else {
        _skillsToLearn.add(cleanSkill);
      }
    });
  }

  // REMOVE SKILL
  void _removeSkill(bool isTeaching, String skill) {
    if (_isSaving) return;

    setState(() {
      if (isTeaching) {
        _skillsToTeach.remove(skill);
      } else {
        _skillsToLearn.remove(skill);
      }
    });
  }

  // SAVE SKILLS
  Future<void> _saveSkills() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.updateMySkills(
        skillsToLearn: _skillsToLearn,
        skillsToTeach: _skillsToTeach,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Could not save skills: $e', isError: true);
    }
  }

  // SHOW MESSAGE
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // SKILL SECTION
  Widget _buildSkillSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> skills,
    required bool isTeaching,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => _addSkill(isTeaching),
                icon: Icon(Icons.add_circle, color: color, size: 29),
                tooltip: 'Add Skill',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (skills.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No skills added yet. Tap + to add one.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: color.withValues(alpha: 0.10),
                  side: BorderSide.none,
                  deleteIcon: const Icon(Icons.close, size: 17),
                  onDeleted: _isSaving
                      ? null
                      : () => _removeSkill(isTeaching, skill),
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'My Skills',
          style: TextStyle(
            color: Color(0xFF22223A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF22223A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Your Skills',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Tell the community what you can teach and what you want to learn.',
                    style: TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 25),
                  _buildSkillSection(
                    title: 'Skills I Can Teach',
                    subtitle: 'Share your knowledge with others',
                    icon: Icons.school_outlined,
                    color: const Color(0xFF5B5FEF),
                    skills: _skillsToTeach,
                    isTeaching: true,
                  ),
                  _buildSkillSection(
                    title: 'Skills I Want to Learn',
                    subtitle: 'Discover what you want to learn',
                    icon: Icons.lightbulb_outline,
                    color: const Color(0xFF10B981),
                    skills: _skillsToLearn,
                    isTeaching: false,
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSkills,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B5FEF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save My Skills',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// SEPARATE ADD SKILL DIALOG
class _AddSkillDialog extends StatefulWidget {
  final bool isTeaching;

  const _AddSkillDialog({required this.isTeaching});

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isEmpty) return;

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isTeaching ? 'Add Teaching Skill' : 'Add Learning Skill',
      ),
      content: TextField(
        controller: _controller,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Example: Flutter Development',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
