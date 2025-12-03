import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class StudentFileShareScreen extends StatefulWidget {
  const StudentFileShareScreen({super.key});

  @override
  State<StudentFileShareScreen> createState() => _StudentFileShareScreenState();
}

class _StudentFileShareScreenState extends State<StudentFileShareScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();
  File? _selectedFile;
  String? _selectedFileName;
  bool _isSharing = false;
  double _shareProgress = 0.0;
  int _nearbyDevices = 0;

  String _targetLevel = 'section'; // Default to section

  @override
  void initState() {
    super.initState();
    _initializeMesh();
  }

  Future<void> _initializeMesh() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String userId = prefs.getString('user_id') ?? '';
    String userName = prefs.getString('user_name') ?? '';

    await _mesh.initialize(orgId, userId, 'student', name: userName);

    _mesh.onDevicesFound = (devices) {
      setState(() => _nearbyDevices = devices.length);
    };

    await _mesh.startAdvertising();
    await _mesh.startScanning();
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

  Future<void> _shareFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() {
      _isSharing = true;
      _shareProgress = 0.0;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String department = prefs.getString('user_department') ?? '';
      String branch = prefs.getString('user_branch') ?? '';
      String year = prefs.getString('user_year') ?? '';
      String semester = prefs.getString('user_semester') ?? '';
      String section = prefs.getString('user_section') ?? '';

      // ✅ STRICT CRITERIA BASED ON SELECTION
      Map<String, dynamic> targetCriteria = {
        'level': _targetLevel,
        'department': department,
      };

      if (_targetLevel == 'section') {
        targetCriteria['branch'] = branch;
        targetCriteria['year'] = int.tryParse(year);
        targetCriteria['semester'] = int.tryParse(semester);
        targetCriteria['section'] = section;
      } else if (_targetLevel == 'semester') {
        targetCriteria['branch'] = branch;
        targetCriteria['year'] = int.tryParse(year);
        targetCriteria['semester'] = int.tryParse(semester);
      } else if (_targetLevel == 'branch') {
        targetCriteria['branch'] = branch;
      }

      print('🎯 SHARING TO: ${targetCriteria['level']}');
      print('   Dept: ${targetCriteria['department']}');
      if (targetCriteria['branch'] != null) print('   Branch: ${targetCriteria['branch']}');
      if (targetCriteria['semester'] != null) print('   Semester: ${targetCriteria['semester']}');
      if (targetCriteria['section'] != null) print('   Section: ${targetCriteria['section']}');

      await _mesh.shareFile(
        filePath: _selectedFile!.path,
        fileName: _selectedFileName!,
        targetUserIds: ['ALL'],
        targetCriteria: targetCriteria,
        onProgress: (progress) {
          setState(() => _shareProgress = progress);
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ File shared successfully'), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
        _isSharing = false;
      });
    } catch (e) {
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
        title: Text('Share to Classmates'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi, size: 40, color: Colors.blue),
                  SizedBox(height: 8),
                  Text('Ready to Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Nearby Devices: $_nearbyDevices'),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Target Selection
            Text('Share with:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),

            RadioListTile<String>(
              title: Text('My Section (Classmates)'),
              value: 'section',
              groupValue: _targetLevel,
              onChanged: (value) => setState(() => _targetLevel = value!),
            ),
            RadioListTile<String>(
              title: Text('My Semester'),
              value: 'semester',
              groupValue: _targetLevel,
              onChanged: (value) => setState(() => _targetLevel = value!),
            ),
            RadioListTile<String>(
              title: Text('My Branch'),
              value: 'branch',
              groupValue: _targetLevel,
              onChanged: (value) => setState(() => _targetLevel = value!),
            ),

            SizedBox(height: 24),

            // File Picker
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

            // Share Button
            ElevatedButton(
              onPressed: _isSharing ? null : _shareFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.all(16),
              ),
              child: _isSharing
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Share Now', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),

            if (_isSharing) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(value: _shareProgress),
              SizedBox(height: 8),
              Text('${(_shareProgress * 100).toInt()}% Complete', textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}