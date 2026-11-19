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

  late Future<Map<String, dynamic>?> _myProfileFuture;

  String _selectedFilter = 'All';

  final Color primaryColor = const Color(0xFF5B5FEF);

  // INITIALIZE

  @override
  void initState() {
    super.initState();

    _myProfileFuture = _discoveryService.getCurrentUserProfile();
  }

  // REFRESH CURRENT PROFILE

  void _refreshMyProfile() {
    setState(() {
      _myProfileFuture = _discoveryService.getCurrentUserProfile();
    });
  }

  // FILTER AND SORT PROFILES

  List<Map<String, dynamic>> _filterProfiles(
    List<Map<String, dynamic>> profiles,
    Map<String, dynamic> currentProfile,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final result = <Map<String, dynamic>>[];

    for (final profile in profiles) {
      // Do not show current user.
      if (profile['uid'] == currentUid) {
        continue;
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

      // Calculate complementary match.
      final matchDetails = _discoveryService.calculateMatch(
        currentProfile,
        profile,
      );

      final matchScore = matchDetails['score'] as int;

      bool filterMatch = true;

      if (_selectedFilter == 'Teaching') {
        filterMatch = teach.isNotEmpty && (query.isEmpty || teachMatch);
      } else if (_selectedFilter == 'Learning') {
        filterMatch = learn.isNotEmpty && (query.isEmpty || learnMatch);
      } else if (_selectedFilter == 'Matches') {
        filterMatch = matchScore > 0;
      }

      if (textMatch && filterMatch) {
        result.add({...profile, 'matchDetails': matchDetails});
      }
    }

    // Highest match score first.
    result.sort((a, b) {
      final scoreA = a['matchDetails']['score'] as int;

      final scoreB = b['matchDetails']['score'] as int;

      return scoreB.compareTo(scoreA);
    });

    return result;
  }

  // DISPOSE

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // BUILD

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
            // SEARCH FIELD
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  setState(() {});
                },
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

            // FILTER CHIPS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),

                    _buildFilterChip('Matches'),
                    const SizedBox(width: 8),

                    _buildFilterChip('Teaching'),
                    const SizedBox(width: 8),

                    _buildFilterChip('Learning'),
                  ],
                ),
              ),
            ),

            // PROFILE STREAM
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _myProfileFuture,

                builder: (context, myProfileSnapshot) {
                  if (myProfileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (myProfileSnapshot.hasError) {
                    return _buildErrorState('Unable to load your profile.');
                  }

                  final currentProfile = myProfileSnapshot.data;

                  if (currentProfile == null) {
                    return _buildMissingProfileState();
                  }

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _discoveryService.getPublicProfiles(),

                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(
                          'Unable to load profiles. Please try again.',
                        );
                      }

                      final profiles = snapshot.data ?? [];

                      final filteredProfiles = _filterProfiles(
                        profiles,
                        currentProfile,
                      );

                      if (filteredProfiles.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredProfiles.length,

                        itemBuilder: (context, index) {
                          return _buildProfileCard(filteredProfiles[index]);
                        },
                      );
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

  // ERROR STATE

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 55, color: Colors.redAccent),

            const SizedBox(height: 12),

            Text(message, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _refreshMyProfile,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // MISSING PROFILE STATE

  Widget _buildMissingProfileState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 60, color: Colors.grey),

            const SizedBox(height: 12),

            const Text(
              'Your public profile was not found.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 8),

            const Text(
              'Please complete your profile before discovering skill matches.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _refreshMyProfile,
              child: const Text('Refresh Profile'),
            ),
          ],
        ),
      ),
    );
  }

  // EMPTY STATE

  Widget _buildEmptyState() {
    final isMatchFilter = _selectedFilter == 'Matches';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),

            const SizedBox(height: 12),

            Text(
              isMatchFilter
                  ? 'No complementary matches found.'
                  : 'No matching skills found.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 6),

            const Text(
              'Try another search or update your skills.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // FILTER CHIP

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

  // MATCH SCORE COLOR

  Color _getMatchColor(int score) {
    if (score == 100) {
      return Colors.green;
    }

    if (score == 50) {
      return Colors.orange;
    }

    return Colors.grey;
  }

  // MATCH SCORE BADGE

  Widget _buildMatchBadge(int score) {
    final color = _getMatchColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 15),

          const SizedBox(width: 5),

          Text(
            '$score% Match',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // MATCH DETAILS DIALOG

  void _showMatchDetailsDialog(Map<String, dynamic> profile) {
    final matchDetails = Map<String, dynamic>.from(
      profile['matchDetails'] ?? {},
    );

    final score = matchDetails['score'] as int? ?? 0;

    final teachToLearn = List<String>.from(matchDetails['teachToLearn'] ?? []);

    final learnFromTeach = List<String>.from(
      matchDetails['learnFromTeach'] ?? [],
    );

    showDialog<void>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          title: const Text(
            'Match Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: _getMatchColor(score),
                        ),
                      ),

                      const Text(
                        'Compatibility Score',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildMatchDetailSection(
                  title: 'You Teach → They Learn',
                  skills: teachToLearn,
                  color: Colors.green,
                ),

                const SizedBox(height: 18),

                _buildMatchDetailSection(
                  title: 'They Teach → You Learn',
                  skills: learnFromTeach,
                  color: Colors.blue,
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Text(
                    score == 100
                        ? 'Excellent! Both users can teach and learn from each other.'
                        : score == 50
                        ? 'Partial match found. One direction of skill exchange is compatible.'
                        : 'No complementary skill exchange found yet.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // MATCH DETAIL SECTION

  Widget _buildMatchDetailSection({
    required String title,
    required List<String> skills,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),

        const SizedBox(height: 9),

        if (skills.isEmpty)
          const Text(
            'No matching skills.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,

            children: skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  skill,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // SEND EXCHANGE REQUEST

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
      await showDialog<void>(
        context: context,

        // Prevent accidental dismissal during sending.
        barrierDismissible: false,

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
                        : () {
                            Navigator.of(dialogContext).pop();
                          },

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

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Exchange request sent successfully.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!dialogContext.mounted) {
                                return;
                              }

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

  // PROFILE CARD

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? 'SkillSwap User').toString();

    final bio = (profile['bio'] ?? 'No bio available').toString();

    final skillsToTeach = List<String>.from(profile['skillsToTeach'] ?? []);

    final skillsToLearn = List<String>.from(profile['skillsToLearn'] ?? []);

    final matchDetails = Map<String, dynamic>.from(
      profile['matchDetails'] ?? {},
    );

    final matchScore = matchDetails['score'] as int? ?? 0;

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
              // USER INFORMATION
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

              // MATCH SCORE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    'Skill Compatibility',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  _buildMatchBadge(matchScore),
                ],
              ),

              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),

                child: LinearProgressIndicator(
                  value: matchScore / 100,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade200,
                  color: _getMatchColor(matchScore),
                ),
              ),

              const SizedBox(height: 4),

              Align(
                alignment: Alignment.centerRight,

                child: TextButton(
                  onPressed: () {
                    _showMatchDetailsDialog(profile);
                  },

                  child: const Text('View Match Details'),
                ),
              ),

              const SizedBox(height: 4),

              // TEACHING SKILLS
              const Text(
                'Skills Teaching',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              _buildSkillTags(skillsToTeach),

              const SizedBox(height: 14),

              // LEARNING SKILLS
              const Text(
                'Skills Learning',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              _buildSkillTags(skillsToLearn),

              const SizedBox(height: 16),

              // SEND REQUEST
              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  onPressed: () {
                    _showExchangeRequestDialog(profile);
                  },

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

  // SKILL TAGS

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
