import 'package:flutter/material.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class AdminSharedFilesScreen extends StatefulWidget {
  const AdminSharedFilesScreen({super.key});

  @override
  State<AdminSharedFilesScreen> createState() => _AdminSharedFilesScreenState();
}

class _AdminSharedFilesScreenState extends State<AdminSharedFilesScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();
  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharedFiles();
  }

  Future<void> _loadSharedFiles() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> files = await _mesh.getSharedFiles();
      setState(() {
        _sharedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading shared files: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Files I Shared'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _sharedFiles.isEmpty
          ? Center(child: Text('No files shared yet'))
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _sharedFiles.length,
        itemBuilder: (context, index) {
          var file = _sharedFiles[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.description, color: AppConstants.primaryBlue),
              title: Text(file['fileName'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shared: ${_formatDate(file['sharedAt'])}'),
                  Text('Target: ${_getTargetString(file['targetCriteria'])}'),
                  Text('Size: ${_formatSize(file['fileSize'])}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime dt = DateTime.parse(timestamp);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getTargetString(Map<String, dynamic>? criteria) {
    if (criteria == null) return 'Unknown';
    if (criteria['level'] == 'all') return 'All Organization';
    if (criteria['level'] == 'department') return criteria['department'] ?? 'Unknown Dept';
    if (criteria['level'] == 'branch') return '${criteria['department']} - ${criteria['branch']}';
    return 'Specific Group';
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}