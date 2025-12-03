import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class MySharedFilesScreen extends StatefulWidget {
  const MySharedFilesScreen({super.key});

  @override
  State<MySharedFilesScreen> createState() => _MySharedFilesScreenState();
}

class _MySharedFilesScreenState extends State<MySharedFilesScreen> {
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
      var files = await _mesh.getSharedFiles();
      setState(() {
        _sharedFiles = files;
        _isLoading = false;
      });
      print('✅ Loaded ${files.length} shared files');
    } catch (e) {
      print('❌ Error loading files: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Shared Files'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _sharedFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No files shared yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadSharedFiles,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _sharedFiles.length,
          itemBuilder: (context, index) {
            var file = _sharedFiles[index];
            return _buildFileCard(file);
          },
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    String fileName = file['fileName'] ?? 'Unknown';
    int fileSize = file['fileSize'] ?? 0;
    String sharedAt = file['sharedAt'] ?? file['timestamp'] ?? '';
    String targetInfo = _getTargetInfo(file['targetCriteria']);

    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(sharedAt);
    } catch (e) {
      dateTime = DateTime.now();
    }

    String timeAgo = _getTimeAgo(dateTime);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.description, color: AppConstants.primaryBlue),
        ),
        title: Text(fileName, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('${_formatFileSize(fileSize)} • $timeAgo'),
            Text('Shared to: $targetInfo', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.open_in_new, color: AppConstants.primaryBlue),
          onPressed: () => _openFile(file),
        ),
      ),
    );
  }

  String _getTargetInfo(dynamic criteria) {
    if (criteria == null) return 'Everyone';

    String level = criteria['level'] ?? 'all';
    if (level == 'all') return 'All Organization';
    if (level == 'department') return '${criteria['department']} Department';
    if (level == 'branch') return '${criteria['branch']} Branch';
    if (level == 'semester') return 'Semester ${criteria['semester']}';
    if (level == 'section') return 'Section ${criteria['section']}';
    return 'Unknown';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getTimeAgo(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    try {
      String? localPath = file['localPath'];
      if (localPath == null || localPath.isEmpty) {
        throw Exception('File path not found');
      }

      File localFile = File(localPath);
      if (!await localFile.exists()) {
        throw Exception('File no longer exists');
      }

      await OpenFile.open(localPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Cannot open file: $e'), backgroundColor: Colors.red),
      );
    }
  }
}