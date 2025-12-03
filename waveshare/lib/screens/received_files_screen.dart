import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';  // ✅ ADD THIS
import 'dart:io';
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
  String _filter = 'all'; // 'all', 'organization', 'universal'

  @override
  void initState() {
    super.initState();
    _loadReceivedFiles();
  }

  Future<void> _loadReceivedFiles() async {
    setState(() => _isLoading = true);
    try {
      var files = await _mesh.getReceivedFiles();

      setState(() {
        _receivedFiles = files;
        _isLoading = false;
      });

      print('✅ Loaded ${files.length} received files');
    } catch (e) {
      print('❌ Error loading files: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredFiles {
    if (_filter == 'all') return _receivedFiles;

    return _receivedFiles.where((file) {
      String senderId = file['senderId'] ?? '';
      if (_filter == 'universal') {
        return senderId.startsWith('GUEST_');
      } else {
        return !senderId.startsWith('GUEST_');
      }
    }).toList();
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
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _receivedFiles.length),
                SizedBox(width: 8),
                _buildFilterChip(
                  'Organization',
                  'organization',
                  _receivedFiles.where((f) =>
                  !(f['senderId'] ?? '').startsWith('GUEST_')
                  ).length,
                ),
                SizedBox(width: 8),
                _buildFilterChip(
                  'Universal',
                  'universal',
                  _receivedFiles.where((f) =>
                      (f['senderId'] ?? '').startsWith('GUEST_')
                  ).length,
                ),
              ],
            ),
          ),

          // Files List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No files received yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadReceivedFiles,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredFiles.length,
                itemBuilder: (context, index) {
                  var file = _filteredFiles[index];
                  return _buildFileCard(file);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    bool isSelected = _filter == value;
    return Expanded(
      child: ChoiceChip(
        label: FittedBox(  // ✅ FIX: Prevent overflow
          fit: BoxFit.scaleDown,
          child: Text('$label ($count)'),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filter = value);
        },
        selectedColor: AppConstants.primaryBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,  // ✅ FIX: Smaller font
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    String fileName = file['fileName'] ?? 'Unknown';
    int fileSize = file['fileSize'] ?? 0;
    String senderName = file['senderName'] ?? 'Unknown';
    String senderType = file['senderType'] ?? '';
    String receivedAt = file['receivedAt'] ?? file['timestamp'] ?? '';
    bool isUniversal = (file['senderId'] ?? '').startsWith('GUEST_');

    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(receivedAt);
    } catch (e) {
      dateTime = DateTime.now();
    }

    String timeAgo = _getTimeAgo(dateTime);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUniversal ? Colors.orange[100] : Colors.blue[100],
          child: Icon(
            Icons.description,
            color: isUniversal ? Colors.orange : AppConstants.primaryBlue,
          ),
        ),
        title: Text(fileName, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('From: $senderName'),
            Text(
              '${_formatFileSize(fileSize)} • $timeAgo',
              style: TextStyle(fontSize: 12),
            ),
            if (isUniversal)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Universal Share',
                  style: TextStyle(fontSize: 10, color: Colors.orange[900]),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.share, color: Colors.green),
              onPressed: () => _shareFile(file),
            ),
            IconButton(
              icon: Icon(Icons.open_in_new, color: AppConstants.primaryBlue),
              onPressed: () => _openFile(file),
            ),
          ],
        ),
      ),
    );
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
        SnackBar(
          content: Text('❌ Cannot open file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareFile(Map<String, dynamic> file) async {
    try {
      String? localPath = file['localPath'];
      if (localPath == null || localPath.isEmpty) {
        throw Exception('File path not found');
      }

      File localFile = File(localPath);
      if (!await localFile.exists()) {
        throw Exception('File no longer exists');
      }

      // ✅ FIXED: Use XFile properly
      await Share.shareXFiles(
        [XFile(localPath)],
        text: 'Shared via WaveShare',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Cannot share file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}