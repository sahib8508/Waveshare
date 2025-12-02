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
  PlatformFile? _csvFile;
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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _csvFile = result.files.first;
        });
      }
    } catch (e) {
      _showError('File selection failed: $e');
    }
  }

  Future<void> _uploadCSV() async {
    if (_csvFile == null) {
      _showError('Please select a CSV file');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      print('📤 Uploading members CSV...');

      await ApiService.uploadMembersCSV(
        orgId: orgId!,
        file: _csvFile!,
      );

      setState(() => _uploadProgress = 1.0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Members uploaded and hierarchy created!'),
          backgroundColor: Colors.green,
        ),
      );

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
          },
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');
      setState(() => _isUploading = false);
      _showError('Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Upload Members'),
        backgroundColor: AppConstants.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Single CSV File',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'Include all members (students, faculty, staff) in one CSV',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // File Picker
              InkWell(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppConstants.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _csvFile != null ? Colors.green : AppConstants.primaryBlue,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: _csvFile != null ? Colors.green : AppConstants.primaryBlue,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Members CSV File',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _csvFile != null ? _csvFile!.name : 'No file selected',
                              style: TextStyle(
                                fontSize: 14,
                                color: _csvFile != null ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _csvFile != null ? Icons.check_circle : Icons.upload_file,
                        color: _csvFile != null ? Colors.green : AppConstants.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_isUploading) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toInt()}% Complete',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: _isUploading ? null : _uploadCSV,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Upload & Create Hierarchy',
                  style: TextStyle(color: Colors.white, fontSize: 16),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}