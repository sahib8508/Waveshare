import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/mesh_network_service.dart';
import 'received_files_screen.dart';
import 'student_file_share_screen.dart';
import 'universal_share_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String? userName;
  String? department;
  String? branch;
  String? section;
  String? semester;
  int nearbyDevices = 0;
  int availableFiles = 0;
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
      userName = prefs.getString('user_name') ?? 'Student';
      department = prefs.getString('user_department') ?? '';
      branch = prefs.getString('user_branch') ?? '';
      section = prefs.getString('user_section') ?? '';
      semester = prefs.getString('user_semester') ?? '';
    });
  }

  Future<void> _initializeMesh() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String userId = prefs.getString('user_id') ?? '';
    String userName = prefs.getString('user_name') ?? 'Student';

    await _mesh.initialize(orgId, userId, 'student', name: userName);

    _mesh.onDevicesFound = (devices) {
      setState(() => nearbyDevices = devices.length);
    };

    _mesh.onTransferComplete = (fileId) async {
      var files = await _mesh.getReceivedFiles();
      setState(() => availableFiles = files.length);
      _loadRecentActivity();
    };

    await _mesh.startAdvertising();
    await _mesh.startScanning();

    var files = await _mesh.getReceivedFiles();
    setState(() => availableFiles = files.length);
  }

  Future<void> _loadRecentActivity() async {
    var files = await _mesh.getReceivedFiles();

    files.sort((a, b) {
      DateTime timeA = DateTime.parse(a['receivedAt'] ?? a['timestamp']);
      DateTime timeB = DateTime.parse(b['receivedAt'] ?? b['timestamp']);
      return timeB.compareTo(timeA);
    });

    setState(() {
      _recentActivity = files.take(3).toList();
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
        title: Text('WaveShare'),
        backgroundColor: AppConstants.primaryBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Welcome, ${userName ?? 'Student'}!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$department / $branch / Year ${semester != null && semester!.isNotEmpty ? ((int.tryParse(semester!) ?? 1 + 1) ~/ 2) : ''} / Semester $semester / Section $section',
                    style: TextStyle(fontSize: 14, color: Colors.blue[900], fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nearby Devices: $nearbyDevices students', style: TextStyle(fontSize: 12)),
                          SizedBox(height: 4),
                          Text('Available Files: $availableFiles', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: availableFiles > 0 ? Colors.red : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$availableFiles new',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
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
              childAspectRatio: 1.2,
              children: [
                _buildActionCard(
                  icon: Icons.upload_file,
                  label: 'Share File',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StudentFileShareScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.folder,
                  label: 'Browse Files',
                  color: Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReceivedFilesScreen()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.chat_bubble,
                  label: 'Classmates Chat',
                  color: Color(0xFFE3F2FD),
                  onTap: () => _showComingSoon('Classmates Chat'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
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

            SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReceivedFilesScreen()),
                  );
                },
                child: Text('View All Files'),
              ),
            ),
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => ReceivedFilesScreen()));
          } else if (index == 2 || index == 3) {
            _showComingSoon(index == 2 ? 'Chat' : 'Settings');
          }
        },
      ),
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
            Icon(icon, size: 40, color: AppConstants.primaryBlue),
            SizedBox(height: 8),
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
    String senderName = activity['senderName'] ?? 'Unknown';
    String timestamp = activity['receivedAt'] ?? activity['timestamp'] ?? '';

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
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.person, color: AppConstants.primaryBlue),
        ),
        title: Text('$senderName shared', style: TextStyle(fontSize: 14)),
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