import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/skill_discovery_service.dart';
import '../services/exchange_request_service.dart';
import 'public_user_profile_screen.dart';

class SkillDiscoveryScreen extends StatefulWidget {
  const SkillDiscoveryScreen({super.key});

  @override
  State<SkillDiscoveryScreen> createState() => _SkillDiscoveryScreenState();
}

class _SkillDiscoveryScreenState extends State<SkillDiscoveryScreen> {
  final SkillDiscoveryService _discoveryService = SkillDiscoveryService();

  final ExchangeRequestService _exchangeRequestService =
      ExchangeRequestService();

  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';

  final Color primaryColor = const Color(0xFF5B5FEF);

  List<Map<String, dynamic>> _filterProfiles(
    List<Map<String, dynamic>> profiles,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return profiles.where((profile) {
      if (profile['uid'] == currentUid) {
        return false;
      }

      final name = (profile['name'] ?? '').toString().toLowerCase();
      final bio = (profile['bio'] ?? '').toString().toLowerCase();

      final teach = List<String>.from(profile['skillsToTeach'] ?? []);
      final learn = List<String>.from(profile['skillsToLearn'] ?? []);

      final teachMatch = teach.any(
        (skill) => skill.toLowerCase().contains(query),
      );

      final learnMatch = learn.any(
        (skill) => skill.toLowerCase().contains(query),
      );

      final textMatch =
          query.isEmpty ||
          name.contains(query) ||
          bio.contains(query) ||
          teachMatch ||
          learnMatch;

      bool filterMatch = true;

      if (_selectedFilter == 'Teaching') {
        filterMatch = teach.isNotEmpty && (query.isEmpty || teachMatch);
      } else if (_selectedFilter == 'Learning') {
        filterMatch = learn.isNotEmpty && (query.isEmpty || learnMatch);
      }

      return textMatch && filterMatch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text(
          'Discover Skills',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search name or skills...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Teaching'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Learning'),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _discoveryService.getPublicProfiles(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Unable to load profiles. Please try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final profiles = snapshot.data ?? [];
                  final filteredProfiles = _filterProfiles(profiles);

                  if (filteredProfiles.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No matching skills found.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Try another search or filter.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      return _buildProfileCard(filteredProfiles[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FILTER CHIP
  // ==========================================

  Widget _buildFilterChip(String label) {
    final selected = _selectedFilter == label;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? primaryColor : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  // ==========================================
  // SEND EXCHANGE REQUEST
  // ==========================================

  Future<void> _showExchangeRequestDialog(Map<String, dynamic> profile) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to send an exchange request.'),
        ),
      );
      return;
    }

    final receiverId = (profile['uid'] ?? '').toString();

    if (receiverId.isEmpty || receiverId == currentUser.uid) {
      return;
    }

    final receiverSkills = List<String>.from(profile['skillsToTeach'] ?? []);

    if (receiverSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has not added any teaching skills.'),
        ),
      );
      return;
    }

    Map<String, dynamic> ownProfile;

    try {
      ownProfile = await _exchangeRequestService.getCurrentUserProfile();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;

    final offeredSkills = List<String>.from(ownProfile['skillsToTeach'] ?? []);

    if (offeredSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add a skill in My Skills before sending a request.',
          ),
        ),
      );
      return;
    }

    String selectedOfferedSkill = offeredSkills.first;
    String selectedRequestedSkill = receiverSkills.first;

    final noteController = TextEditingController();

    bool isSending = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: !isSending,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Send Exchange Request',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send a skill exchange request to ${profile['name'] ?? 'this user'}.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your Offered Skill',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedOfferedSkill,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: offeredSkills.map((skill) {
                          return DropdownMenuItem(
                            value: skill,
                            child: Text(skill, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: isSending
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedOfferedSkill = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Skill You Want to Learn',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRequestedSkill,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: receiverSkills.map((skill) {
                          return DropdownMenuItem(
                            value: skill,
                            child: Text(skill, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: isSending
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedRequestedSkill = value;
                                  });
                                }
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
                        enabled: !isSending,
                        maxLength: 250,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write a short message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSending
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSending
                        ? null
                        : () async {
                            setDialogState(() {
                              isSending = true;
                            });

                            try {
                              await _exchangeRequestService.sendRequest(
                                receiverId: receiverId,
                                requestedSkill: selectedRequestedSkill,
                                offeredSkill: selectedOfferedSkill,
                                note: noteController.text.trim(),
                              );

                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.of(dialogContext).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Exchange request sent successfully.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                isSending = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSending
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
    } finally {
      noteController.dispose();
    }
  }

  // ==========================================
  // PROFILE CARD
  // ==========================================

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? 'SkillSwap User').toString();

    final bio = (profile['bio'] ?? 'No bio available').toString();

    final skillsToTeach = List<String>.from(profile['skillsToTeach'] ?? []);

    final skillsToLearn = List<String>.from(profile['skillsToLearn'] ?? []);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicUserProfileScreen(profile: profile),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withValues(alpha: 0.12),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
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
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Skills Teaching',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSkillTags(skillsToTeach),
              const SizedBox(height: 14),
              const Text(
                'Skills Learning',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSkillTags(skillsToLearn),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showExchangeRequestDialog(profile),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Send Exchange Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SKILL TAGS
  // ==========================================

  Widget _buildSkillTags(List<String> skills) {
    if (skills.isEmpty) {
      return const Text(
        'Not added yet',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            skill,
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
