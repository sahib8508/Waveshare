import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mesh_network_service.dart';
import '../utils/constants.dart';

class SupervisorFileShareScreen extends StatefulWidget {
  final String? supervisorDepartment;
  final String? supervisorUserId;
  final String? supervisorName;

  const SupervisorFileShareScreen({
    super.key,
    this.supervisorDepartment,
    this.supervisorUserId,
    this.supervisorName,
  });

  @override
  State<SupervisorFileShareScreen> createState() => _SupervisorFileShareScreenState();
}

class _SupervisorFileShareScreenState extends State<SupervisorFileShareScreen> {
  final MeshNetworkService _mesh = MeshNetworkService();
  File? _selectedFile;
  String? _selectedFileName;
  bool _isSharing = false;
  double _shareProgress = 0.0;
  int _nearbyDevices = 0;
  String _statusMessage = 'Ready';
  String _targetLevel = 'department';

  // ✅ HIERARCHY DATA
  Map<String, dynamic>? _hierarchyData;
  List<String> _branches = [];
  List<int> _years = [];
  List<int> _semesters = [];
  List<String> _sections = [];

  String? _selectedBranch;
  int? _selectedYear;
  int? _selectedSemester;
  String? _selectedSection;

  int _targetStudentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeMesh();
    _loadHierarchyData();
  }

  Future<void> _loadHierarchyData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String? csvData = prefs.getString('offline_csv_$orgId');

    if (csvData != null) {
      List<dynamic> members = json.decode(csvData);

      // ✅ BUILD HIERARCHY FROM CSV
      Set<String> branchesSet = {};
      Set<int> yearsSet = {};
      Set<int> semestersSet = {};
      Set<String> sectionsSet = {};

      for (var member in members) {
        if (member['department'] == widget.supervisorDepartment &&
            member['role']?.toLowerCase() == 'student') {
          if (member['branch'] != null) branchesSet.add(member['branch'].toString());
          if (member['year'] != null) {
            int? yearVal = int.tryParse(member['year'].toString());
            if (yearVal != null) yearsSet.add(yearVal);
          }
          if (member['semester'] != null) {
            int? semVal = int.tryParse(member['semester'].toString());
            if (semVal != null) semestersSet.add(semVal);
          }
          if (member['section'] != null) sectionsSet.add(member['section'].toString());
        }
      }

      setState(() {
        _branches = branchesSet.toList()..sort();
        _years = yearsSet.toList()..sort();
        _semesters = semestersSet.toList()..sort();
        _sections = sectionsSet.toList()..sort();
      });

      _calculateTargetCount();

      print('✅ Hierarchy loaded: ${_branches.length} branches, ${_years.length} years');
    }
  }

  void _calculateTargetCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String? csvData = prefs.getString('offline_csv_$orgId');

    if (csvData == null) return;

    List<dynamic> members = json.decode(csvData);
    int count = 0;

    for (var member in members) {
      if (member['role']?.toLowerCase() != 'student') continue;
      if (member['department'] != widget.supervisorDepartment) continue;

      if (_targetLevel == 'department') {
        count++;
      } else if (_targetLevel == 'branch' && _selectedBranch != null) {
        if (member['branch'] == _selectedBranch) count++;
      } else if (_targetLevel == 'year' && _selectedBranch != null && _selectedYear != null) {
        if (member['branch'] == _selectedBranch &&
            int.tryParse(member['year']?.toString() ?? '') == _selectedYear) count++;
      } else if (_targetLevel == 'semester' && _selectedBranch != null &&
          _selectedYear != null && _selectedSemester != null) {
        if (member['branch'] == _selectedBranch &&
            int.tryParse(member['year']?.toString() ?? '') == _selectedYear &&
            int.tryParse(member['semester']?.toString() ?? '') == _selectedSemester) count++;
      } else if (_targetLevel == 'section' && _selectedBranch != null &&
          _selectedYear != null && _selectedSemester != null && _selectedSection != null) {
        if (member['branch'] == _selectedBranch &&
            int.tryParse(member['year']?.toString() ?? '') == _selectedYear &&
            int.tryParse(member['semester']?.toString() ?? '') == _selectedSemester &&
            member['section'] == _selectedSection) count++;
      }
    }

    setState(() => _targetStudentCount = count);
    print('🎯 Target count: $count students');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share to Students'),
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
                  Text(_statusMessage, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Nearby Devices: $_nearbyDevices'),
                  if (widget.supervisorDepartment != null)
                    Text('Your Department: ${widget.supervisorDepartment}',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(height: 24),

            // ✅ TARGET SELECTION WITH HIERARCHY
            Text('Share with:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),

            RadioListTile<String>(
              title: Text('All My Department Students'),
              subtitle: Text('${widget.supervisorDepartment ?? 'Unknown'} Department'),
              value: 'department',
              groupValue: _targetLevel,
              onChanged: (value) {
                setState(() {
                  _targetLevel = value!;
                  _selectedBranch = null;
                  _selectedYear = null;
                  _selectedSemester = null;
                  _selectedSection = null;
                  _calculateTargetCount();
                });
              },
            ),

            RadioListTile<String>(
              title: Text('Specific Branch'),
              value: 'branch',
              groupValue: _targetLevel,
              onChanged: (value) {
                setState(() {
                  _targetLevel = value!;
                  _calculateTargetCount();
                });
              },
            ),

            if (_targetLevel == 'branch' || _targetLevel == 'year' ||
                _targetLevel == 'semester' || _targetLevel == 'section') ...[
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedBranch,
                decoration: InputDecoration(
                  labelText: 'Select Branch',
                  border: OutlineInputBorder(),
                ),
                items: _branches.map((branch) => DropdownMenuItem(
                  value: branch,
                  child: Text(branch),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBranch = value;
                    _selectedYear = null;
                    _selectedSemester = null;
                    _selectedSection = null;
                    _calculateTargetCount();
                  });
                },
              ),
            ],

            RadioListTile<String>(
              title: Text('Specific Year'),
              value: 'year',
              groupValue: _targetLevel,
              onChanged: (value) {
                setState(() {
                  _targetLevel = value!;
                  _calculateTargetCount();
                });
              },
            ),

            if ((_targetLevel == 'year' || _targetLevel == 'semester' || _targetLevel == 'section')
                && _selectedBranch != null) ...[
              SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  labelText: 'Select Year',
                  border: OutlineInputBorder(),
                ),
                items: _years.map((year) => DropdownMenuItem(
                  value: year,
                  child: Text('Year $year'),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value;
                    _selectedSemester = null;
                    _selectedSection = null;
                    _calculateTargetCount();
                  });
                },
              ),
            ],

            RadioListTile<String>(
              title: Text('Specific Semester'),
              value: 'semester',
              groupValue: _targetLevel,
              onChanged: (value) {
                setState(() {
                  _targetLevel = value!;
                  _calculateTargetCount();
                });
              },
            ),

            if ((_targetLevel == 'semester' || _targetLevel == 'section') &&
                _selectedBranch != null && _selectedYear != null) ...[
              SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedSemester,
                decoration: InputDecoration(
                  labelText: 'Select Semester',
                  border: OutlineInputBorder(),
                ),
                items: _semesters.map((sem) => DropdownMenuItem(
                  value: sem,
                  child: Text('Semester $sem'),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSemester = value;
                    _selectedSection = null;
                    _calculateTargetCount();
                  });
                },
              ),
            ],

            RadioListTile<String>(
              title: Text('Specific Section'),
              value: 'section',
              groupValue: _targetLevel,
              onChanged: (value) {
                setState(() {
                  _targetLevel = value!;
                  _calculateTargetCount();
                });
              },
            ),

            if (_targetLevel == 'section' && _selectedBranch != null &&
                _selectedYear != null && _selectedSemester != null) ...[
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSection,
                decoration: InputDecoration(
                  labelText: 'Select Section',
                  border: OutlineInputBorder(),
                ),
                items: _sections.map((section) => DropdownMenuItem(
                  value: section,
                  child: Text('Section $section'),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSection = value;
                    _calculateTargetCount();
                  });
                },
              ),
            ],

            SizedBox(height: 16),

            // ✅ TARGET COUNT DISPLAY
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Target Recipients:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('$_targetStudentCount students',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
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

  Future<void> _initializeMesh() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String orgId = prefs.getString('org_id') ?? '';
    String userId = prefs.getString('user_id') ?? '';
    String userName = prefs.getString('user_name') ?? '';

    await _mesh.initialize(orgId, userId, 'supervisor', name: userName);

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

    if (_targetStudentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No students match your selection')),
      );
      return;
    }

    setState(() {
      _isSharing = true;
      _shareProgress = 0.0;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String department = widget.supervisorDepartment ?? prefs.getString('user_department') ?? '';

      Map<String, dynamic> targetCriteria = {
        'level': _targetLevel,
        'department': department,
        'branch': _selectedBranch,
        'year': _selectedYear,
        'semester': _selectedSemester,
        'section': _selectedSection,
      };

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
        SnackBar(
            content: Text('✅ File shared to $_targetStudentCount students'),
            backgroundColor: Colors.green),
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
}