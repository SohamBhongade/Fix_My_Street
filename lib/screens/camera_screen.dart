import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/surface_card.dart';
import 'ai_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedFile;
  Uint8List? _capturedBytes;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
        _capturedBytes = bytes;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load image: $e';
        _busy = false;
      });
    }
  }

  void _continueToAnalysis() {
    if (_capturedBytes == null || _capturedFile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AIPreviewScreen(
          imageBytes: _capturedBytes!,
          imagePath: _capturedFile!.path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Capture issue'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: _capturedBytes == null
                      ? _buildEmptyPreview()
                      : _buildPreview(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      onTap: _busy ? null : () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SecondaryButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: _busy ? null : () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: _busy ? 'Loading' : 'Analyze with AI',
                icon: Icons.auto_awesome_outlined,
                busy: _busy,
                onTap: (_busy || _capturedBytes == null)
                    ? null
                    : _continueToAnalysis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 28,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('No photo selected', style: AppText.heading),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Capture or pick a clear image of the issue.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.file(
        File(_capturedFile!.path),
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}
