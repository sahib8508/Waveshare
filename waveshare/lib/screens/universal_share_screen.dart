import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';
import 'received_files_screen.dart';

class UniversalShareScreen extends StatefulWidget {
  const UniversalShareScreen({super.key});

  @override
  State<UniversalShareScreen> createState() => _UniversalShareScreenState();
}

class _UniversalShareScreenState extends State<UniversalShareScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();
  File? _selectedFile;
  String? _selectedFileName;
  bool _isScanning = false;
  bool _isSharing = false;
  double _shareProgress = 0.0;
  List<NearbyDevice> _nearbyDevices = [];
  List<String> _selectedDeviceIds = [];

  @override
  void initState() {
    super.initState();
    _initializeMesh();
  }

  Future<void> _initializeMesh() async {
    await _mesh.initialize(
      'UNIVERSAL',
      'GUEST_${DateTime.now().millisecondsSinceEpoch}',
      'guest',
      name: 'Guest User',
    );

    _mesh.onDevicesFound = (devices) {
      if (mounted) {
        setState(() => _nearbyDevices = devices);
      }
    };

    // ✅ NEW: Handle incoming files
    _mesh.onTransferComplete = (fileId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ File received!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceivedFilesScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    };

    await _mesh.startAdvertising();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selection failed: $e')),
      );
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _nearbyDevices.clear();
      _selectedDeviceIds.clear();
    });

    await _mesh.startScanning();

    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _shareFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    if (_selectedDeviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one recipient')),
      );
      return;
    }

    setState(() {
      _isSharing = true;
      _shareProgress = 0.0;
    });

    try {
      print('🚀 Starting Universal Share...');
      print('   File: $_selectedFileName');
      print('   Recipients: ${_selectedDeviceIds.length}');

      await _mesh.shareFile(
        filePath: _selectedFile!.path,
        fileName: _selectedFileName!,
        targetUserIds: _selectedDeviceIds,
        targetCriteria: {'level': 'universal'},  // ✅ CRITICAL: Mark as universal
        onProgress: (progress) {
          setState(() => _shareProgress = progress);
        },
      );

      print('✅ Universal Share completed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ File shared successfully!'), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
        _selectedDeviceIds.clear();
        _isSharing = false;
      });
    } catch (e) {
      print('❌ Universal Share failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Share failed: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSharing = false);
    }
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
        title: Text('Universal Share'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.share, size: 40, color: AppConstants.primaryBlue),
                  SizedBox(height: 8),
                  Text(
                    'Share with anyone using WaveShare',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No organization membership needed',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

// ✅ ADD THIS BUTTON
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReceivedFilesScreen()),
                );
              },
              icon: Icon(Icons.download),
              label: Text('View Received Files'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 24),

            // File Picker
            ElevatedButton.icon(
              onPressed: _isSharing ? null : _pickFile,
              icon: Icon(Icons.attach_file),
              label: Text('Select File to Share'),
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
                    Expanded(child: Text(_selectedFileName!)),
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

            // Scan Button
            ElevatedButton.icon(
              onPressed: _isScanning || _isSharing ? null : _scanForDevices,
              icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.radar),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Nearby Devices'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 16),

            // Devices List
            if (_nearbyDevices.isNotEmpty) ...[
              Text(
                'Found ${_nearbyDevices.length} WaveShare users nearby',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ...List.generate(
                _nearbyDevices.length,
                    (index) => _buildDeviceCard(_nearbyDevices[index]),
              ),
            ],

            if (_nearbyDevices.isEmpty && _isScanning) ...[
              Center(child: CircularProgressIndicator()),
              SizedBox(height: 16),
              Text('Searching for devices...', textAlign: TextAlign.center),
            ],

            if (_selectedDeviceIds.isNotEmpty) ...[
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selected: ${_selectedDeviceIds.length} recipients',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSharing ? null : _shareFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.all(16),
                ),
                child: _isSharing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Send File', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],

            if (_isSharing) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(value: _shareProgress),
              SizedBox(height: 8),
              Text(
                '${(_shareProgress * 100).toInt()}% Complete',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(NearbyDevice device) {
    bool isSelected = _selectedDeviceIds.contains(device.userId);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedDeviceIds.add(device.userId);
            } else {
              _selectedDeviceIds.remove(device.userId);
            }
          });
        },
        secondary: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.person, color: AppConstants.primaryBlue),
        ),
        title: Text(device.name, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(device.userType == 'guest' ? 'Anonymous mode' : 'From: ${device.orgId}'),
            Text('Distance: ~${_estimateDistance(device)} away', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _estimateDistance(NearbyDevice device) {
    return '${(5 + (device.userId.hashCode % 50))}m';
  }
}