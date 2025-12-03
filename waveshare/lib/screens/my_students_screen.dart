import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';

class MyStudentsScreen extends StatefulWidget {
  const MyStudentsScreen({super.key});

  @override
  State<MyStudentsScreen> createState() => _MyStudentsScreenState();
}

class _MyStudentsScreenState extends State<MyStudentsScreen> {
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSemester;

  Set<String> _branches = {};
  Set<String> _years = {};
  Set<String> _semesters = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String orgId = prefs.getString('org_id') ?? '';
      String supervisorDept = prefs.getString('user_department') ?? '';
      String? csvData = prefs.getString('offline_csv_$orgId');

      if (csvData == null) {
        throw Exception('No student data found');
      }

      List<dynamic> allMembers = json.decode(csvData);
      List<Map<String, dynamic>> students = [];

      for (var member in allMembers) {
        if (member['role']?.toString().toLowerCase() == 'student' &&
            member['department'] == supervisorDept) {
          students.add(Map<String, dynamic>.from(member));

          if (member['branch'] != null) _branches.add(member['branch'].toString());
          if (member['year'] != null) _years.add(member['year'].toString());
          if (member['semester'] != null) _semesters.add(member['semester'].toString());
        }
      }

      setState(() {
        _allStudents = students;
        _filteredStudents = students;
        _isLoading = false;
      });

      print('✅ Loaded ${students.length} students from $supervisorDept department');
    } catch (e) {
      print('❌ Error loading students: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterStudents() {
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        bool matchesSearch = _searchQuery.isEmpty ||
            student['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            student['unique_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        bool matchesBranch = _selectedBranch == null || student['branch'] == _selectedBranch;
        bool matchesYear = _selectedYear == null || student['year']?.toString() == _selectedYear;
        bool matchesSemester = _selectedSemester == null || student['semester']?.toString() == _selectedSemester;

        return matchesSearch && matchesBranch && matchesYear && matchesSemester;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Students (${_filteredStudents.length})'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _filteredStudents.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No students found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or ID',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              _searchQuery = value;
              _filterStudents();
            },
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBranch,
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All')),
                    ..._branches.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (value) {
                    _selectedBranch = value;
                    _filterStudents();
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All')),
                    ..._years.map((y) => DropdownMenuItem(value: y, child: Text('Y$y'))),
                  ],
                  onChanged: (value) {
                    _selectedYear = value;
                    _filterStudents();
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSemester,
                  decoration: InputDecoration(
                    labelText: 'Sem',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All')),
                    ..._semesters.map((s) => DropdownMenuItem(value: s, child: Text('S$s'))),
                  ],
                  onChanged: (value) {
                    _selectedSemester = value;
                    _filterStudents();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            student['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
            style: TextStyle(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(student['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('ID: ${student['unique_id'] ?? 'N/A'}'),
            Text(
              '${student['branch'] ?? ''} • Year ${student['year'] ?? ''} • Sem ${student['semester'] ?? ''} • Sec ${student['section'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: () => _showStudentDetails(student),
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student['name'] ?? 'Student Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Unique ID', student['unique_id']),
            _buildDetailRow('Email', student['email']),
            _buildDetailRow('Phone', student['phone']),
            _buildDetailRow('Branch', student['branch']),
            _buildDetailRow('Year', student['year']?.toString()),
            _buildDetailRow('Semester', student['semester']?.toString()),
            _buildDetailRow('Section', student['section']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }
}