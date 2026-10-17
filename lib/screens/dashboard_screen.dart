
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _skills = [
    {
      'title': 'UI/UX Design',
      'teacher': 'Alex Morgan',
      'category': 'Design',
      'icon': Icons.design_services_rounded,
      'color': Color(0xFFECEBFF),
      'rating': '4.9',
    },
    {
      'title': 'Flutter Development',
      'teacher': 'Jamie Lee',
      'category': 'Technology',
      'icon': Icons.phone_android_rounded,
      'color': Color(0xFFE2F4FF),
      'rating': '4.8',
    },
    {
      'title': 'Photography',
      'teacher': 'Taylor Smith',
      'category': 'Creative',
      'icon': Icons.camera_alt_rounded,
      'color': Color(0xFFFFECDD),
      'rating': '4.7',
    },
    {
      'title': 'English Speaking',
      'teacher': 'Jordan Kim',
      'category': 'Language',
      'icon': Icons.record_voice_over_rounded,
      'color': Color(0xFFE1F7EB),
      'rating': '4.9',
    },
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showFeatureMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available in a future update.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'SkillSwap Learner';
    final firstName = email.contains('@')
        ? email.split('@').first
        : email;

    final filteredSkills = _skills.where((skill) {
      final query = _searchQuery.trim().toLowerCase();

      return skill['title'].toString().toLowerCase().contains(query) ||
          skill['category'].toString().toLowerCase().contains(query) ||
          skill['teacher'].toString().toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: Color(0xFF5B5FEF),
              size: 30,
            ),
            SizedBox(width: 8),
            Text(
              'SkillSwap',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF20213A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _showFeatureMessage('Notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHome(firstName, filteredSkills),
          _buildExplore(filteredSkills),
          _buildSessions(),
          _buildProfile(email),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(
    String firstName,
    List<Map<String, dynamic>> skills,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B5FEF), Color(0xFF8588FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LEARN • SHARE • GROW',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hello, $firstName!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Discover new skills and share what you know.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedIndex = 1);
                },
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore skills'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        TextField(
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          decoration: const InputDecoration(
            hintText: 'Search skills or mentors',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 26),
        _sectionHeading('Explore categories', 'Find your interest'),
        const SizedBox(height: 16),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _category('Technology', Icons.code_rounded,
                  const Color(0xFFE2F4FF)),
              _category('Design', Icons.palette_outlined,
                  const Color(0xFFECEBFF)),
              _category('Language', Icons.translate_rounded,
                  const Color(0xFFE1F7EB)),
              _category('Creative', Icons.camera_alt_outlined,
                  const Color(0xFFFFECDD)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _sectionHeading('Recommended skills', 'Learn something new'),
        const SizedBox(height: 16),
        if (skills.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No skills match your search.'),
            ),
          )
        else
          ...skills.map(_skillCard),
        const SizedBox(height: 26),
        _sectionHeading('Your learning journey', 'Keep growing'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EAF2)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFECEBFF),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF5B5FEF),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Every expert was once a beginner.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Choose a skill and start learning today.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildExplore(List<Map<String, dynamic>> skills) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Explore Skills',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find people who can help you learn.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),
        TextField(
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          decoration: const InputDecoration(
            hintText: 'Search by skill, category or mentor',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 20),
        if (skills.isEmpty)
          const Center(child: Text('No matching skills found.'))
        else
          ...skills.map(_skillCard),
      ],
    );
  }

  Widget _buildSessions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'My Sessions',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep track of your learning activities.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 56,
                color: Color(0xFF5B5FEF),
              ),
              SizedBox(height: 16),
              Text(
                'No upcoming sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your scheduled learning sessions will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => setState(() => _selectedIndex = 1),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Explore skills'),
        ),
      ],
    );
  }

  Widget _buildProfile(String email) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'My Profile',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFFECEBFF),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : 'S',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B5FEF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'SkillSwap member',
            style: TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 28),
        _profileOption(
          Icons.person_outline_rounded,
          'Edit profile',
          () => _showFeatureMessage('Edit profile'),
        ),
        _profileOption(
          Icons.notifications_none_rounded,
          'Notifications',
          () => _showFeatureMessage('Notifications'),
        ),
        _profileOption(
          Icons.help_outline_rounded,
          'Help & support',
          () => _showFeatureMessage('Help & support'),
        ),
        _profileOption(
          Icons.logout_rounded,
          'Logout',
          _logout,
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF20213A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _category(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchQuery = title;
          _selectedIndex = 1;
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EAF2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Icon(icon, color: const Color(0xFF5B5FEF)),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skillCard(Map<String, dynamic> skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EAF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: skill['color'] as Color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              skill['icon'] as IconData,
              color: const Color(0xFF5B5FEF),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Mentor: ${skill['teacher']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  skill['category'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5B5FEF),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.star_rounded,
                  size: 19, color: Color(0xFFFFB400)),
              Text(
                skill['rating'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              IconButton(
                tooltip: 'View skill',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showFeatureMessage(
                  '${skill['title']} details',
                ),
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileOption(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5B5FEF)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
