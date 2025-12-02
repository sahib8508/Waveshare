import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TargetSelector extends StatefulWidget {
  final Map<String, dynamic>? hierarchy;
  final Function(Map<String, dynamic>) onTargetSelected;

  const TargetSelector({
    required this.hierarchy,
    required this.onTargetSelected,
    super.key,
  });

  @override
  State<TargetSelector> createState() => _TargetSelectorState();
}

class _TargetSelectorState extends State<TargetSelector> {
  String targetLevel = 'all';

  String? selectedDept;
  String? selectedBranch;
  int? selectedYear;
  int? selectedSemester;
  String? selectedSection;

  int totalRecipients = 0;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Delay callback until after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateRecipients();
    });
  }

  void _calculateRecipients() {
    if (widget.hierarchy == null) return;

    int count = 0;

    if (targetLevel == 'all') {
      count = widget.hierarchy!['totalMembers'] ?? 0;
    } else if (targetLevel == 'department' && selectedDept != null) {
      var dept = _findDepartment(selectedDept!);
      count = dept?['totalMembers'] ?? 0;
    } else if (targetLevel == 'branch' && selectedBranch != null) {
      var branch = _findBranch(selectedDept!, selectedBranch!);
      count = branch?['totalMembers'] ?? 0;
    } else if (targetLevel == 'year' && selectedYear != null) {
      var year = _findYear(selectedDept!, selectedBranch!, selectedYear!);
      count = _countInYear(year);
    } else if (targetLevel == 'semester' && selectedSemester != null) {
      var semester = _findSemester(selectedDept!, selectedBranch!, selectedYear!, selectedSemester!);
      count = _countInSemester(semester);
    } else if (targetLevel == 'section' && selectedSection != null) {
      var section = _findSection(selectedDept!, selectedBranch!, selectedYear!, selectedSemester!, selectedSection!);
      count = section?['totalMembers'] ?? 0;
    }

    setState(() => totalRecipients = count);

    // Notify parent
    widget.onTargetSelected({
      'level': targetLevel,
      'department': selectedDept,
      'branch': selectedBranch,
      'year': selectedYear,
      'semester': selectedSemester,
      'section': selectedSection,
      'totalRecipients': totalRecipients,
    });
  }

  Map<String, dynamic>? _findDepartment(String name) {
    return (widget.hierarchy!['departments'] as List?)
        ?.firstWhere((d) => d['name'] == name, orElse: () => null);
  }

  Map<String, dynamic>? _findBranch(String dept, String branch) {
    var department = _findDepartment(dept);
    return (department?['branches'] as List?)
        ?.firstWhere((b) => b['name'] == branch, orElse: () => null);
  }

  Map<String, dynamic>? _findYear(String dept, String branch, int year) {
    var branchData = _findBranch(dept, branch);
    return (branchData?['years'] as List?)
        ?.firstWhere((y) => y['year'] == year, orElse: () => null);
  }

  Map<String, dynamic>? _findSemester(String dept, String branch, int year, int sem) {
    var yearData = _findYear(dept, branch, year);
    return (yearData?['semesters'] as List?)
        ?.firstWhere((s) => s['semester'] == sem, orElse: () => null);
  }

  Map<String, dynamic>? _findSection(String dept, String branch, int year, int sem, String section) {
    var semesterData = _findSemester(dept, branch, year, sem);
    return (semesterData?['sections'] as List?)
        ?.firstWhere((s) => s['section'] == section, orElse: () => null);
  }

  int _countInYear(Map<String, dynamic>? year) {
    if (year == null) return 0;
    int total = 0;
    for (var sem in (year['semesters'] as List? ?? [])) {
      total += _countInSemester(sem);
    }
    return total;
  }

  int _countInSemester(Map<String, dynamic>? semester) {
    if (semester == null) return 0;
    int total = 0;
    for (var sec in (semester['sections'] as List? ?? [])) {
      total += sec['totalMembers'] as int? ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hierarchy == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'No hierarchy data available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Please upload CSV file first',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select Recipients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),

        _buildLevelSelector(),
        SizedBox(height: 16),

        if (targetLevel != 'all') ...[
          _buildDepartmentDropdown(),
          if (selectedDept != null && targetLevel != 'department') ...[
            SizedBox(height: 12),
            _buildBranchDropdown(),
          ],
          if (selectedBranch != null && targetLevel != 'branch' && targetLevel != 'department') ...[
            SizedBox(height: 12),
            _buildYearDropdown(),
          ],
          if (selectedYear != null && targetLevel != 'year' && targetLevel != 'branch' && targetLevel != 'department') ...[
            SizedBox(height: 12),
            _buildSemesterDropdown(),
          ],
          if (selectedSemester != null && targetLevel == 'section') ...[
            SizedBox(height: 12),
            _buildSectionDropdown(),
          ],
        ],

        SizedBox(height: 16),

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Recipients:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('$totalRecipients members', style: TextStyle(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('All Organization'),
          selected: targetLevel == 'all',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'all';
              _resetSelections();
              _calculateRecipients();
            });
          },
        ),
        ChoiceChip(
          label: Text('Department'),
          selected: targetLevel == 'department',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'department';
              _resetSelections();
            });
          },
        ),
        ChoiceChip(
          label: Text('Branch'),
          selected: targetLevel == 'branch',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'branch';
              _resetSelections();
            });
          },
        ),
        ChoiceChip(
          label: Text('Year'),
          selected: targetLevel == 'year',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'year';
              _resetSelections();
            });
          },
        ),
        ChoiceChip(
          label: Text('Semester'),
          selected: targetLevel == 'semester',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'semester';
              _resetSelections();
            });
          },
        ),
        ChoiceChip(
          label: Text('Section'),
          selected: targetLevel == 'section',
          onSelected: (selected) {
            setState(() {
              targetLevel = 'section';
              _resetSelections();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    List<String> departments = (widget.hierarchy!['departments'] as List)
        .map((d) => d['name'] as String)
        .toList();

    return DropdownButtonFormField<String>(
      value: selectedDept,
      decoration: InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
      ),
      items: departments.map((dept) {
        var deptData = _findDepartment(dept);
        return DropdownMenuItem(
          value: dept,
          child: Text('$dept (${deptData?['totalMembers']} members)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedDept = value;
          selectedBranch = null;
          selectedYear = null;
          selectedSemester = null;
          selectedSection = null;
          _calculateRecipients();
        });
      },
    );
  }

  Widget _buildBranchDropdown() {
    var dept = _findDepartment(selectedDept!);
    List<String> branches = ((dept?['branches'] as List?) ?? [])
        .map((b) => b['name'] as String)
        .toList();

    if (branches.isEmpty) {
      return Text('No branches available', style: TextStyle(color: Colors.grey));
    }

    return DropdownButtonFormField<String>(
      value: selectedBranch,
      decoration: InputDecoration(
        labelText: 'Branch',
        border: OutlineInputBorder(),
      ),
      items: branches.map((branch) {
        var branchData = _findBranch(selectedDept!, branch);
        return DropdownMenuItem(
          value: branch,
          child: Text('$branch (${branchData?['totalMembers']} members)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedBranch = value;
          selectedYear = null;
          selectedSemester = null;
          selectedSection = null;
          _calculateRecipients();
        });
      },
    );
  }

  Widget _buildYearDropdown() {
    var branch = _findBranch(selectedDept!, selectedBranch!);
    List<int> years = ((branch?['years'] as List?) ?? [])
        .map((y) => y['year'] as int)
        .toList();

    if (years.isEmpty) {
      return Text('No years available', style: TextStyle(color: Colors.grey));
    }

    return DropdownButtonFormField<int>(
      value: selectedYear,
      decoration: InputDecoration(
        labelText: 'Year',
        border: OutlineInputBorder(),
      ),
      items: years.map((year) {
        var yearData = _findYear(selectedDept!, selectedBranch!, year);
        return DropdownMenuItem(
          value: year,
          child: Text('Year $year (${_countInYear(yearData)} members)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedYear = value;
          selectedSemester = null;
          selectedSection = null;
          _calculateRecipients();
        });
      },
    );
  }

  Widget _buildSemesterDropdown() {
    var year = _findYear(selectedDept!, selectedBranch!, selectedYear!);
    List<int> semesters = ((year?['semesters'] as List?) ?? [])
        .map((s) => s['semester'] as int)
        .toList();

    if (semesters.isEmpty) {
      return Text('No semesters available', style: TextStyle(color: Colors.grey));
    }

    return DropdownButtonFormField<int>(
      value: selectedSemester,
      decoration: InputDecoration(
        labelText: 'Semester',
        border: OutlineInputBorder(),
      ),
      items: semesters.map((sem) {
        var semData = _findSemester(selectedDept!, selectedBranch!, selectedYear!, sem);
        return DropdownMenuItem(
          value: sem,
          child: Text('Semester $sem (${_countInSemester(semData)} members)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedSemester = value;
          selectedSection = null;
          _calculateRecipients();
        });
      },
    );
  }

  Widget _buildSectionDropdown() {
    var semester = _findSemester(selectedDept!, selectedBranch!, selectedYear!, selectedSemester!);
    List<String> sections = ((semester?['sections'] as List?) ?? [])
        .map((s) => s['section'] as String)
        .toList();

    if (sections.isEmpty) {
      return Text('No sections available', style: TextStyle(color: Colors.grey));
    }

    return DropdownButtonFormField<String>(
      value: selectedSection,
      decoration: InputDecoration(
        labelText: 'Section',
        border: OutlineInputBorder(),
      ),
      items: sections.map((section) {
        var secData = _findSection(selectedDept!, selectedBranch!, selectedYear!, selectedSemester!, section);
        return DropdownMenuItem(
          value: section,
          child: Text('Section $section (${secData?['totalMembers']} members)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedSection = value;
          _calculateRecipients();
        });
      },
    );
  }

  void _resetSelections() {
    selectedDept = null;
    selectedBranch = null;
    selectedYear = null;
    selectedSemester = null;
    selectedSection = null;
  }
}