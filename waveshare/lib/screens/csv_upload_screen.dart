import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

class CSVUploadScreen extends StatefulWidget {
  const CSVUploadScreen({Key? key}) : super(key: key);

  @override
  State<CSVUploadScreen> createState() => _CSVUploadScreenState();
}

class _CSVUploadScreenState extends State<CSVUploadScreen> {
  PlatformFile? _studentsFile;
  PlatformFile? _teachersFile;
  bool _isUploading = false;
  double _uploadProgress = 0;

  String? orgId;
  String? orgCode;
  String? adminId;
  String? orgName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      orgId = args['orgId'];
      orgCode = args['orgCode'];
      adminId = args['adminId'];
      orgName = args['orgName'];
    }
  }

  Future<void> _pickFile(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,  // ADD THIS LINE
      );

      if (result != null) {
        setState(() {
          if (type == 'students') {
            _studentsFile = result.files.first;
          } else {
            _teachersFile = result.files.first;
          }
        });
      }
    } catch (e) {
      _showError('File selection failed: $e');
    }
  }

  Future<void> _uploadCSV() async {
    if (_studentsFile == null && _teachersFile == null) {
      _showError('Please select at least one CSV file');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      int totalUploads = 0;
      if (_studentsFile != null) totalUploads++;
      if (_teachersFile != null) totalUploads++;

      double progressStep = 1.0 / totalUploads;
      double currentProgress = 0;

      // ✅ Upload students CSV
      if (_studentsFile != null) {
        print('📤 Uploading students CSV...');
        print('   File name: ${_studentsFile!.name}');
        print('   File size: ${_studentsFile!.size}');
        print('   Has bytes: ${_studentsFile!.bytes != null}');
        print('   Has path: ${_studentsFile!.path != null}');

        await ApiService.uploadCSV(
          orgId: orgId!,
          csvType: 'students',
          file: _studentsFile!,
        );
        currentProgress += progressStep;
        setState(() => _uploadProgress = currentProgress);
        print('✅ Students CSV uploaded');
      }

      // ✅ Upload teachers CSV
      if (_teachersFile != null) {
        print('📤 Uploading teachers CSV...');
        print('   File name: ${_teachersFile!.name}');
        print('   File size: ${_teachersFile!.size}');
        print('   Has bytes: ${_teachersFile!.bytes != null}');
        print('   Has path: ${_teachersFile!.path != null}');

        await ApiService.uploadCSV(
          orgId: orgId!,
          csvType: 'teachers',
          file: _teachersFile!,
        );
        currentProgress += progressStep;
        setState(() => _uploadProgress = currentProgress);
        print('✅ Teachers CSV uploaded');
      }

      setState(() => _uploadProgress = 1.0);

      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV files uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to dashboard
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/admin-dashboard',
          arguments: {
            'orgId': orgId,
            'orgCode': orgCode,
            'adminId': adminId,
            'orgName': orgName,
            'adminName': 'Admin',
          },
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');
      setState(() => _isUploading = false);
      _showError('Upload failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Setup Your Organization'),
        backgroundColor: AppConstants.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Step 1 of 3: Upload Member Database',
                style: AppConstants.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'Upload CSV Files',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                'Get started by uploading your member list',
                style: AppConstants.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Students CSV
              _buildFileCard(
                title: 'Students CSV',
                file: _studentsFile,
                onTap: () => _pickFile('students'),
                icon: Icons.school,
              ),
              const SizedBox(height: 16),

              // Teachers/Staff CSV
              _buildFileCard(
                title: 'Teachers/Staff CSV',
                file: _teachersFile,
                onTap: () => _pickFile('teachers'),
                icon: Icons.person,
              ),
              const SizedBox(height: 32),

              if (_isUploading)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppConstants.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toInt()}% Complete',
                      style: AppConstants.caption,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              ElevatedButton(
                onPressed: _isUploading ? null : _uploadCSV,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Upload & Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/admin-dashboard',
                    arguments: {
                      'orgId': orgId,
                      'orgCode': orgCode,
                      'adminId': adminId,
                      'orgName': orgName,
                    },
                  );
                },
                child: const Text('Skip for Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard({
    required String title,
    required PlatformFile? file,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          border: Border.all(
            color: file != null ? Colors.green : AppConstants.primaryBlue,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: file != null ? Colors.green : AppConstants.primaryBlue,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null ? file.name : 'No file selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: file != null ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              file != null ? Icons.check_circle : Icons.upload_file,
              color: file != null ? Colors.green : AppConstants.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}