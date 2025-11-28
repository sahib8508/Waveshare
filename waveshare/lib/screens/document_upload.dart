import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'registration_success.dart';


class DocumentUpload extends StatefulWidget {
  final String orgId;
  final String orgCode;
  final String adminId;
  final String orgName;

  const DocumentUpload({
    Key? key,
    required this.orgId,
    required this.orgCode,
    required this.adminId,
    required this.orgName,
  }) : super(key: key);

  @override
  State<DocumentUpload> createState() => _DocumentUploadState();
}

class _DocumentUploadState extends State<DocumentUpload> {
  String? _selectedDocType;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  final List<String> _docTypes = [
    'Official Letterhead',
    'Registration Certificate',
    'Accreditation Document',
  ];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showError('File selection failed: $e');
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null || _selectedDocType == null) {
      _showError('Please select document type and file');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.uploadDocument(
        orgId: widget.orgId,
        documentType: _selectedDocType!,
        file: _selectedFile!,
      );

      setState(() => _isLoading = false);

      if (response['success']) {
        _navigateToSuccess();
      } else {
        _showError(response['message'] ?? 'Upload failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  Future<void> _skipUpload() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.skipDocument(
        orgId: widget.orgId,
      );

      setState(() => _isLoading = false);

      if (response['success']) {
        _navigateToSuccess();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _navigateToSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrationSuccess(
          orgCode: widget.orgCode,
          adminId: widget.adminId,
          orgId: widget.orgId,
          orgName: widget.orgName,
        ),
      ),
    );
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
        title: const Text('Upload Document'),
        backgroundColor: AppConstants.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Step 4 of 7',
                style: AppConstants.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Verification Document',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '(Optional - helps with faster verification)',
                style: AppConstants.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Document Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedDocType,
                decoration: InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusMedium,
                    ),
                  ),
                ),
                items: _docTypes
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDocType = value);
                },
              ),
              const SizedBox(height: 16),

              // File Picker
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _selectedFile == null
                      ? 'Select File (PDF, JPG, PNG)'
                      : _selectedFile!.name,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: AppConstants.primaryBlue),
                ),
              ),
              const SizedBox(height: 32),

              // Upload Button
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Upload Document',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Skip Button
              TextButton(
                onPressed: _isLoading ? null : _skipUpload,
                child: const Text('Skip for Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}