import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/skeleton.dart';
import '../../services/api_service.dart';
import 'scan_result_screen.dart';

/// Scan screen.
///
/// We removed the three "Medical Rules / Visual OCR / Better Alternatives"
/// badges — selling the user on a feature they're already using. The copy
/// is honest and declarative: tell the user exactly what to do and what
/// happens.
class ScanScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const ScanScreen({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _scanning = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    setState(() => _error = null);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "We couldn't open that image. Please try another.");
    }
  }

  Future<void> _submitScan() async {
    if (_selectedImageBytes == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final result = await widget.apiService.submitScan(
        photoBytes: _selectedImageBytes!,
        filename: _selectedImageName ?? 'product_photo.jpg',
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(scanResult: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = UserMessage.fromError(e));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New scan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Point the camera at a food label.',
              style: AppTheme.display(26,
                  weight: FontWeight.w500,
                  color: theme.textTheme.displayMedium?.color,
                  height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll tell you if it fits your profile — your conditions, allergies, and goals.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.critical.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.critical, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.ui(13,
                            weight: FontWeight.w500, color: AppColors.critical),
                      ),
                    ),
                  ],
                ),
              ),
            _buildImageWell(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: theme.textTheme.titleLarge?.color,
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _scanning ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: theme.textTheme.titleLarge?.color,
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  (_selectedImageBytes == null || _scanning) ? null : _submitScan,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.textTheme.bodyMedium?.color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _scanning
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: ScanProgressIndicator(),
                    )
                  : Text('Scan this product',
                      style: AppTheme.ui(16, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWell(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onTap: _scanning
          ? null
          : () => _pickImage(_selectedImageBytes == null
              ? ImageSource.camera
              : ImageSource.gallery),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _selectedImageBytes != null
                ? primary.withValues(alpha: 0.6)
                : theme.dividerColor,
            width: _selectedImageBytes != null ? 1.5 : 1,
          ),
        ),
        child: _selectedImageBytes != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _scanning
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageName = null;
                                });
                              },
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_camera_outlined, size: 26, color: primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tap to take a photo',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Or pick one from your gallery',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
      ),
    );
  }
}
