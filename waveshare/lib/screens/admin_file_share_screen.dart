import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class AdminFileShareScreen extends StatefulWidget {
  final String orgId;
  final String adminId;
  final String orgName;
  final String adminName;

  const AdminFileShareScreen({
    required this.orgId,
    required this.adminId,
    required this.orgName,
    required this.adminName,
    super.key,
  });

  @override
  State<AdminFileShareScreen> createState() => _AdminFileShareScreenState();
}

class _AdminFileShareScreenState extends State<AdminFileShareScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();

  File? _selectedFile;
  String? _selectedFileName;
  int _nearbyDevices = 0;
  bool _isSharing = false;
  double _shareProgress = 0.0;
  List<Map<String, dynamic>> _sharedFiles = [];
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeMesh();
  }

  Future<void> _initializeMesh() async {
    try {
      setState(() => _statusMessage = 'Requesting permissions...');

      // Request all necessary permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
      ].request();

      print('📋 Permission statuses:');
      statuses.forEach((permission, status) {
        print('   $permission: $status');
      });

      setState(() => _statusMessage = 'Initializing mesh network...');

      // Initialize mesh service with admin name
      await _mesh.initialize(
        widget.orgId,
        widget.adminId,
        'admin',
        name: widget.adminName,
      );

      // Set callbacks
      _mesh.onDevicesFound = (devices) {
        setState(() {
          _nearbyDevices = devices.length;
          _statusMessage = 'Found $_nearbyDevices devices';
        });
        print('📱 Devices found: $_nearbyDevices');
      };

      _mesh.onError = (error) {
        print('❌ Mesh error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      };

      setState(() => _statusMessage = 'Starting discovery...');

      // Start advertising this device
      await _mesh.startAdvertising();

      // Start scanning for other devices
      await _mesh.startScanning();

      setState(() => _statusMessage = 'Ready to share!');

      // Load previously shared files
      _loadSharedFiles();

      print('✅ Mesh network ready');
      print('   Organization: ${widget.orgName}');
      print('   Admin: ${widget.adminName}');

    } catch (e) {
      print('❌ Mesh initialization error: $e');
      setState(() => _statusMessage = 'Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Initialization failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadSharedFiles() async {
    try {
      List<Map<String, dynamic>> files = await _mesh.getSharedFiles();
      setState(() {
        _sharedFiles = files;
      });
      print('📚 Loaded ${files.length} shared files');
    } catch (e) {
      print('❌ Error loading files: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
        print('📄 File selected: $_selectedFileName');
      }
    } catch (e) {
      print('❌ File picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selection failed: $e')),
      );
    }
  }

  Future<void> _shareFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    if (_nearbyDevices == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No nearby devices found. Make sure other devices are on same WiFi.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSharing = true;
      _shareProgress = 0.0;
      _statusMessage = 'Sharing file...';
    });

    try {
      print('🚀 Starting file share...');
      print('   File: $_selectedFileName');
      print('   Path: ${_selectedFile!.path}');
      print('   Target devices: $_nearbyDevices');

      // Share to ALL organization members
      List<String> targetUsers = ['ALL'];

      await _mesh.shareFile(
        filePath: _selectedFile!.path,
        fileName: _selectedFileName!,
        targetUserIds: targetUsers,
        onProgress: (progress) {
          setState(() {
            _shareProgress = progress;
            _statusMessage = 'Sharing: ${(progress * 100).toInt()}%';
          });
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ File shared to $_nearbyDevices devices'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload files list
      await _loadSharedFiles();

      // Reset
      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
        _isSharing = false;
        _shareProgress = 0.0;
        _statusMessage = 'Ready to share!';
      });

      print('✅ Share complete!');

    } catch (e) {
      print('❌ Share error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Share failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSharing = false;
        _statusMessage = 'Share failed';
      });
    }
  }

  @override
  void dispose() {
    _mesh.stopScanning();
    _mesh.stopAdvertising();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share File'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _nearbyDevices > 0 ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _nearbyDevices > 0 ? Icons.wifi : Icons.wifi_off,
                    size: 40,
                    color: _nearbyDevices > 0 ? Colors.blue : Colors.orange,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Nearby Devices: $_nearbyDevices',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // File Selection Button
            ElevatedButton.icon(
              onPressed: _isSharing ? null : _pickFile,
              icon: Icon(Icons.attach_file),
              label: Text('Select File'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: AppConstants.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),

            if (_selectedFileName != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFileName!,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                          _selectedFileName = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 24),

            // Share Button
            ElevatedButton(
              onPressed: _isSharing ? null : _shareFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.all(16),
              ),
              child: _isSharing
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'Share to All Members',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),

            if (_isSharing) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(value: _shareProgress),
              SizedBox(height: 8),
              Text(
                '${(_shareProgress * 100).toInt()}% Complete',
                textAlign: TextAlign.center,
              ),
            ],

            SizedBox(height: 32),

            // Previously Shared Files
            Text(
              'Previously Shared Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: _sharedFiles.isEmpty
                  ? Center(child: Text('No files shared yet'))
                  : ListView.builder(
                itemCount: _sharedFiles.length,
                itemBuilder: (context, index) {
                  var file = _sharedFiles[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.description,
                        color: AppConstants.primaryBlue,
                      ),
                      title: Text(file['fileName'] ?? 'Unknown'),
                      subtitle: Text(
                        'Shared: ${file['timestamp']?.toString().substring(0, 16) ?? 'Unknown'}',
                      ),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}