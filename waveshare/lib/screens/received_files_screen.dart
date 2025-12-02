import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class ReceivedFilesScreen extends StatefulWidget {
  const ReceivedFilesScreen({super.key});

  @override
  State<ReceivedFilesScreen> createState() => _ReceivedFilesScreenState();
}

class _ReceivedFilesScreenState extends State<ReceivedFilesScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();
  List<Map<String, dynamic>> _receivedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceivedFiles();
  }

  Future<void> _loadReceivedFiles() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> files = await _mesh.getReceivedFiles();
      setState(() {
        _receivedFiles = files;
        _isLoading = false;
      });
      print('📚 Loaded ${files.length} received files');
    } catch (e) {
      print('❌ Error loading files: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile(Map<String, dynamic> fileData) async {
    try {
      String? filePath = fileData['localPath'];

      if (filePath == null) {
        throw Exception('File path not found');
      }

      File file = File(filePath);

      if (!await file.exists()) {
        throw Exception('File not found on device');
      }

      // Open file with default app
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime dt = DateTime.parse(timestamp);
      DateTime now = DateTime.now();
      Duration diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  IconData _getFileIcon(String fileName) {
    String ext = fileName.split('.').last.toLowerCase();

    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return Icons.image;
    if (['mp4', 'avi', 'mkv'].contains(ext)) return Icons.video_file;
    if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audio_file;
    if (['doc', 'docx', 'txt'].contains(ext)) return Icons.description;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;

    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Received Files'),
        backgroundColor: AppConstants.primaryBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReceivedFiles,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _receivedFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No files received yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Files shared by others will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadReceivedFiles,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _receivedFiles.length,
          itemBuilder: (context, index) {
            var file = _receivedFiles[index];
            String fileName = file['fileName'] ?? 'Unknown';
            int fileSize = file['fileSize'] ?? 0;
            String senderName = file['senderName'] ?? 'Unknown';
            String timestamp = file['receivedAt'] ?? file['timestamp'];

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppConstants.primaryBlue.withOpacity(0.1),
                  child: Icon(
                    _getFileIcon(fileName),
                    color: AppConstants.primaryBlue,
                  ),
                ),
                title: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text('From: $senderName'),
                    Text('${_formatFileSize(fileSize)} • ${_formatDateTime(timestamp)}'),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openFile(file),
              ),
            );
          },
        ),
      ),
    );
  }
}