import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/mesh_network_service.dart';
import 'supervisor_file_share_screen.dart';
import 'my_shared_files_screen.dart';
import 'received_files_screen.dart';
import 'my_students_screen.dart';
import 'universal_share_screen.dart';
import 'dart:convert';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  String? userName;
  String? userId;
  String? department;
  int nearbyDevices = 0;
  int myStudentsOnline = 0;
  int totalStudents = 0;
  final MeshNetworkService _mesh = MeshNetworkService();

  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeMesh();
    _loadRecentActivity();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'Supervisor';
      userId = prefs.getString('user_id') ?? '';
      department = prefs.getString('user_department') ?? '';
    });
    _loadStudentCount();
  }

  Future<void> _loadStudentCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String orgId = prefs.getString('org_id') ?? '';
      String supervisorDept = prefs.getString('user_department') ?? '';
      String? csvData = prefs.getString('offline_csv_$orgId');

      if (csvData != null) {
        List<dynamic> allMembers = json.decode(csvData);
        int count = allMembers.where((m) =>
        m['role']?.toString().toLowerCase() == 'student' &&
            m['department'] == supervisorDept
        ).length;

        setState(() => totalStudents = count);
      }
    } catch (e) {
      print('Error loading student count: $e');
    }
  }

  Future<void> _initializeMesh() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String userId = prefs.getString('user_id') ?? '';
    String userName = prefs.getString('user_name') ?? 'Supervisor';

    await _mesh.initialize(orgId, userId, 'supervisor', name: userName);

    _mesh.onDevicesFound = (devices) {
      setState(() {
        nearbyDevices = devices.length;
        myStudentsOnline = devices.where((d) =>
        d.userType == 'student' && d.orgId == orgId
        ).length;
      });
    };

    await _mesh.startAdvertising();
    await _mesh.startScanning();
  }

  Future<void> _loadRecentActivity() async {
    var sharedFiles = await _mesh.getSharedFiles();

    sharedFiles.sort((a, b) {
      DateTime timeA = DateTime.parse(a['sharedAt'] ?? a['timestamp']);
      DateTime timeB = DateTime.parse(b['sharedAt'] ?? b['timestamp']);
      return timeB.compareTo(timeA);
    });

    setState(() {
      _recentActivity = sharedFiles.take(3).toList();
    });
  }

  @override
  void dispose() {
    _mesh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Supervisor Dashboard'),
        backgroundColor: AppConstants.primaryBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person, size: 35, color: AppConstants.primaryBlue),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName ?? 'Supervisor',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${department ?? ''} Faculty',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Stats Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Department: $department',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('$totalStudents', 'Your Students'),
                      _buildStatItem('$myStudentsOnline', 'Online Now'),
                      _buildStatItem('$nearbyDevices', 'Nearby'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionCard(
                  icon: Icons.upload_file,
                  label: 'Share to Students',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupervisorFileShareScreen(
                          supervisorDepartment: department,
                          supervisorUserId: userId,
                          supervisorName: userName,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.folder,
                  label: 'My Shared Files',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MySharedFilesScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.download,
                  label: 'Received Files',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReceivedFilesScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.people,
                  label: 'My Students',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyStudentsScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.shield,
                  label: 'Moderate Content',
                  color: Color(0xFFE3F2FD),
                  onTap: () => _showComingSoon('Content Moderation'),
                ),
                _buildActionCard(
                  icon: Icons.upload,
                  label: 'Universal Share',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UniversalShareScreen()),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 24),

            // Recent Activity
            Text(
              'Recent Student Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            if (_recentActivity.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No recent activity', style: TextStyle(color: Colors.grey)),
                ),
              ),

            if (_recentActivity.isNotEmpty)
              ..._recentActivity.map((activity) => _buildActivityCard(activity)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryBlue,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MySharedFilesScreen()));
          } else if (index == 2 || index == 3) {
            _showComingSoon(index == 2 ? 'Chat' : 'Settings');
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: AppConstants.primaryBlue),
            SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    String fileName = activity['fileName'] ?? 'Unknown';
    String timestamp = activity['sharedAt'] ?? activity['timestamp'] ?? '';

    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(timestamp);
    } catch (e) {
      dateTime = DateTime.now();
    }

    String timeAgo = _getTimeAgo(dateTime);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.file_present, color: Colors.green),
        ),
        title: Text('You shared', style: TextStyle(fontSize: 14)),
        subtitle: Text(fileName, style: TextStyle(fontSize: 12)),
        trailing: Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Coming Soon')),
    );
  }
}