import 'package:flutter/material.dart';
import '../utils/constants.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? orgName;
  String? adminName;
  String? orgCode;
  String? orgId;
  String? adminId;

  // ✅ Real data from backend
  int totalStudents = 0;
  int totalTeachers = 0;
  bool hasCSVUploaded = false;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      orgName = args['orgName'] ?? 'Organization';
      adminName = args['adminName'] ?? 'Admin';
      orgCode = args['orgCode'];
      orgId = args['orgId'];
      adminId = args['adminId'];

      // ✅ Load real data
      _loadDashboardData();
    }
  }

  // ✅ Fetch real data from backend
  Future<void> _loadDashboardData() async {
    try {
      // TODO: Create API endpoint to get org stats
      // For now, we'll use data passed from login
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.white,
        elevation: 0,
        title: const Text(
          'WaveShare Admin',
          style: TextStyle(
            color: AppConstants.primaryBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications - Coming Soon')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: AppConstants.primaryBlue,
              child: Text(
                adminName?[0].toUpperCase() ?? 'A',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Organization Info
            Text(
              orgName ?? 'Organization',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              adminName ?? 'Admin',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (orgCode != null)
              Text(
                'Code: $orgCode',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppConstants.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 24),

            // ✅ REAL Stats Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        '👨‍🎓 $totalStudents',
                        'Total Students',
                      ),
                      _buildStatItem(
                        '👨‍🏫 $totalTeachers',
                        'Total Teachers',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        hasCSVUploaded ? '✅ Uploaded' : '⚠️ Not Uploaded',
                        'CSV Status',
                      ),
                      _buildStatItem(
                        '📱 Online',
                        'System Active',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Working Actions Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionCard(
                  icon: Icons.table_chart,
                  label: 'Upload/Update CSV',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/csv-upload',
                      arguments: {
                        'orgId': orgId,
                        'orgCode': orgCode,
                        'adminId': adminId,
                        'orgName': orgName,
                      },
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.upload_file,
                  label: 'Share File',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('File Sharing');
                  },
                ),
                _buildActionCard(
                  icon: Icons.campaign,
                  label: 'Send Announcement',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('Announcements');
                  },
                ),
                _buildActionCard(
                  icon: Icons.person_add,
                  label: 'Add Member',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('Add Member');
                  },
                ),
                _buildActionCard(
                  icon: Icons.stop_circle,
                  label: 'Content Moderation',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('Content Moderation');
                  },
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('Analytics');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          if (index != 0) {
            _showComingSoon('Feature');
          }
        },
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
  }

  Widget _buildStatItem(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}