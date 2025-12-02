import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'admin_file_share_screen.dart';

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

  // Stats from hierarchy
  int totalMembers = 0;
  int totalStudents = 0;
  int totalFaculty = 0;
  int totalStaff = 0;
  bool hasCSVUploaded = false;

  // ✅ FIX: Declare fullHierarchy variable
  Map<String, dynamic>? fullHierarchy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      print('📥 Dashboard received args: $args');

      orgName = args['orgName'] ?? 'Organization';
      adminName = args['adminName'] ?? 'Admin';
      orgCode = args['orgCode'];
      orgId = args['orgId'];
      adminId = args['adminId'];

      totalMembers = args['totalMembers'] ?? 0;
      totalStudents = args['totalStudents'] ?? 0;
      totalFaculty = args['totalFaculty'] ?? 0;
      totalStaff = args['totalStaff'] ?? 0;
      hasCSVUploaded = args['hasCSVUploaded'] ?? false;

      // ✅ GET HIERARCHY
      fullHierarchy = args['hierarchy'] as Map<String, dynamic>?;

      // ✅ DEBUG PRINTS
      print('📊 Stats loaded:');
      print('   Total Members: $totalMembers');
      print('   Total Students: $totalStudents');
      print('   Total Faculty: $totalFaculty');
      print('   CSV Uploaded: $hasCSVUploaded');
      print('   ✅ Has Hierarchy: ${fullHierarchy != null}');
      if (fullHierarchy != null) {
        print('   ✅ Departments: ${fullHierarchy!['departments']?.length ?? 0}');
        print('   ✅ Total in hierarchy: ${fullHierarchy!['totalMembers']}');
      } else {
        print('   ❌ Hierarchy is NULL!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                (adminName?.isNotEmpty == true)
                    ? adminName![0].toUpperCase()
                    : 'A',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            // Organization Info
            Text(
              orgName ?? 'Organization',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              adminName ?? 'Admin',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (orgCode != null) ...[
              const SizedBox(height: 4),
              Text(
                'Code: $orgCode',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppConstants.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                        '👥 $totalMembers',
                        'Total Members',
                      ),
                      _buildStatItem(
                        '👨‍🎓 $totalStudents',
                        'Students',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        '👨‍🏫 $totalFaculty',
                        'Faculty',
                      ),
                      _buildStatItem(
                        hasCSVUploaded ? '✅ Uploaded' : '⚠️ Not Uploaded',
                        'CSV Status',
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

            // Actions Grid with all buttons
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
                    if (orgId != null && adminId != null) {
                      // ✅ FIX: Pass full hierarchy correctly
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminFileShareScreen(
                            orgId: orgId!,
                            adminId: adminId!,
                            orgName: orgName ?? 'Organization',
                            adminName: adminName ?? 'Admin',
                            hierarchy: fullHierarchy,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildActionCard(
                  icon: Icons.download,
                  label: 'Received Files',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    Navigator.pushNamed(context, '/received-files');
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
                  icon: Icons.people,
                  label: 'View Members',
                  color: const Color(0xFFE3F2FD),
                  iconColor: AppConstants.primaryBlue,
                  onTap: () {
                    _showComingSoon('Members List');
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
      // ✅ Bottom Navigation Bar
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
        const SizedBox(height: 4),
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
  }
}