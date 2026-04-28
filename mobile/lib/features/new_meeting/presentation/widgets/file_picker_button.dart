import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/upload_repository.dart';

class FilePickerButton extends StatefulWidget {
  const FilePickerButton({
    required this.onFileSelected,
    this.enabled = true,
    this.label = 'Browse file',
    super.key,
  });

  final ValueChanged<File> onFileSelected;
  final bool enabled;
  final String label;

  @override
  State<FilePickerButton> createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.enabled && !_isPicking ? _pickFile : null,
        icon: _isPicking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_outlined),
        label: Text(_isPicking ? 'Opening picker...' : widget.label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
    });

    try {
      final file = await pickMeetingFile(context);
      if (file != null) {
        widget.onFileSelected(file);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }
}

Future<File?> pickMeetingFile(BuildContext context) async {
  final hadPermanentlyDeniedPermission = await _requestAndroidPermissions();

  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedUploadExtensions.toList(),
      allowMultiple: false,
      withData: false,
    );
    final files = result?.files;
    final path = files == null || files.isEmpty ? null : files.first.path;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return File(path);
  } catch (_) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Could not open file picker. Please check app permissions or try again.',
        ),
        action: hadPermanentlyDeniedPermission
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              )
            : null,
      ),
    );
    return null;
  }
}

Future<bool> _requestAndroidPermissions() async {
  if (!Platform.isAndroid) {
    return false;
  }

  final statuses = await [
    Permission.audio,
    Permission.videos,
    Permission.storage,
  ].request();

  return statuses.values.any((status) => status.isPermanentlyDenied);
}
