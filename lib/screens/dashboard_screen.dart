import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'skill_discovery_screen.dart';
import 'chat_list_screen.dart';
import 'edit_profile_screen.dart';
import 'my_skills_screen.dart';
import 'sessions_screen.dart';
import 'exchange_requests_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final AuthService _authService = AuthService();

  final List<Map<String, dynamic>> _skills = [
    {
      'title': 'Flutter Development',
      'category': 'Programming',
      'teacher': 'Alex Morgan',
      'description': 'Learn mobile app development with Flutter.',
      'icon': Icons.phone_android,
      'color': const Color(0xFF5B5FEF),
    },
    {
      'title': 'Web Development',
      'category': 'Programming',
      'teacher': 'Sarah Johnson',
      'description': 'Learn HTML, CSS and JavaScript.',
      'icon': Icons.code,
      'color': const Color(0xFF0EA5E9),
    },
    {
      'title': 'Graphic Design',
      'category': 'Design',
      'teacher': 'David Wilson',
      'description': 'Learn creative graphic design skills.',
      'icon': Icons.palette_outlined,
      'color': const Color(0xFFEC4899),
    },
    {
      'title': 'Digital Marketing',
      'category': 'Marketing',
      'teacher': 'Emma Brown',
      'description': 'Learn social media and digital marketing.',
      'icon': Icons.campaign_outlined,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Python Programming',
      'category': 'Programming',
      'teacher': 'Michael Lee',
      'description': 'Start learning Python programming.',
      'icon': Icons.terminal,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Photography',
      'category': 'Creative',
      'teacher': 'Olivia Smith',
      'description': 'Improve your photography skills.',
      'icon': Icons.camera_alt_outlined,
      'color': const Color(0xFF8B5CF6),
    },
  ];

  bool get _isLoggedIn => _authService.currentUser != null;

  String get _userName {
    final user = _authService.currentUser;

    if (user == null) return 'Guest';

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!;
    }

    if (user.email != null) {
      return user.email!.split('@').first;
    }

    return 'SkillSwap User';
  }

  String get _userEmail {
    return _authService.currentUser?.email ?? '';
  }

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();

      if (!mounted) return;

      setState(() {
        _selectedIndex = 0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not logout. Please try again.')),
      );
    }
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Login Required'),
          content: const Text(
            'Please login or create an account to access this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openLogin();
              },
              child: const Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openRegister();
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  // CHAT, SESSIONS, REQUESTS AND PROFILE REQUIRE LOGIN.
  void _onItemTapped(int index) {
    if (index >= 2 && !_isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePage(),
      _buildExplorePage(),
      const ChatListScreen(),
      _buildSessionsPage(),
      const ExchangeRequestsScreen(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5B5FEF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SkillSwap',
              style: TextStyle(
                color: Color(0xFF22223A),
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoggedIn)
            IconButton(
              onPressed: () => _showComingSoon('Notifications'),
              icon: const Icon(
                Icons.notifications_none,
                color: Color(0xFF22223A),
              ),
            )
          else ...[
            TextButton(onPressed: _openLogin, child: const Text('Login')),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _openRegister,
                child: const Text('Register'),
              ),
            ),
          ],
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF5B5FEF),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz),
              activeIcon: Icon(Icons.swap_horiz),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // HOME PAGE

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _isLoggedIn
                ? 'Welcome back, $_userName!'
                : 'Hello, Welcome to SkillSwap!',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF22223A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoggedIn
                ? 'Continue your learning journey.'
                : 'Learn something new. Share what you know.',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B5FEF), Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exchange Skills,\nGrow Together!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Discover new skills and connect with people who love learning.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5B5FEF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Explore Skills',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Skills', '06', Icons.lightbulb_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Community',
                  'Growing',
                  Icons.groups_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('Popular Skills', 'Explore', () {
            setState(() {
              _selectedIndex = 1;
            });
          }),
          const SizedBox(height: 15),
          SizedBox(
            height: 205,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _skills.length,
              itemBuilder: (context, index) {
                return _buildSkillCard(_skills[index], horizontal: true);
              },
            ),
          ),
          const SizedBox(height: 28),
          if (!_isLoggedIn)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8E9F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Become a SkillSwap Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account to connect with learners, teach skills and schedule learning sessions.',
                    style: TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B5FEF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create Free Account'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  // EXPLORE PAGE

  Widget _buildExplorePage() {
    return const SkillDiscoveryScreen();
  }

  // SESSIONS PAGE

  Widget _buildSessionsPage() {
    return const SessionsScreen();
  }

  // PROFILE PAGE

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF22223A),
            ),
          ),
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFF5B5FEF),
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _userEmail,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 18),
                const Divider(),
                _buildProfileOption(
                  Icons.person_outline,
                  'Edit Profile',
                  () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );

                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
                _buildProfileOption(
                  Icons.school_outlined,
                  'My Skills',
                  () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MySkillsScreen(),
                      ),
                    );

                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
                _buildProfileOption(
                  Icons.settings_outlined,
                  'Settings',
                  () => _showComingSoon('Settings'),
                ),
                _buildProfileOption(
                  Icons.info_outline,
                  'About SkillSwap',
                  _showAboutDialog,
                ),
                const Divider(),
                _buildProfileOption(
                  Icons.logout,
                  'Logout',
                  _logout,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // REUSABLE WIDGETS

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF5B5FEF), size: 25),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String actionText,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF22223A),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionText)),
      ],
    );
  }

  Widget _buildSkillCard(
    Map<String, dynamic> skill, {
    bool horizontal = false,
  }) {
    return Container(
      width: horizontal ? 175 : double.infinity,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (skill['color'] as Color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              skill['icon'] as IconData,
              color: skill['color'] as Color,
              size: 25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            skill['title'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 5),
          Text(
            skill['category'] as String,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          Text(
            'By ${skill['teacher']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5B5FEF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color color = const Color(0xFF333344),
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 15,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  // DIALOGS

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature feature is coming soon.')));
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'SkillSwap',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.swap_horiz,
        color: Color(0xFF5B5FEF),
        size: 35,
      ),
      children: const [
        Text(
          'SkillSwap is a skill exchange platform where people can learn new skills and share their knowledge with others.',
        ),
      ],
    );
  }
}
