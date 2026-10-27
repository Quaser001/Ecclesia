import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/skeleton.dart';
import '../../l10n/l10n.dart';
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
      setState(() => _error = context.l10n.errorImageOpen);
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
      setState(() => _error = UserMessage.of(context, e));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.newScan)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.scanHeadline, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              context.l10n.scanBody,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.colors.tint(context.colors.critical, theme.brightness),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: context.colors.critical, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.ui(14,
                            weight: FontWeight.w600, color: context.colors.critical),
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
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: Text(context.l10n.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _scanning ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: Text(context.l10n.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed:
                  (_selectedImageBytes == null || _scanning) ? null : _submitScan,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: _scanning
                  ? const ScanProgressIndicator()
                  : Text(context.l10n.checkThisProduct),
            ),
            const SizedBox(height: 18),
            _PhotoTips(),
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
        height: 300,
        decoration: BoxDecoration(
          color: _selectedImageBytes != null
              ? theme.colorScheme.surface
              : context.colors.brandSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedImageBytes != null
                ? primary.withValues(alpha: 0.6)
                : primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: _selectedImageBytes != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18.5),
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
                        // Announced to screen readers; the icon has no text.
                        onTap: _scanning
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageName = null;
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(Icons.close, color: Colors.white, size: 18,
                              semanticLabel: context.l10n.removePhoto),
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_camera_outlined, size: 28, color: primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.tapToTakePhoto,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.orPickFromGallery,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Three quick tips that make the label readable on the first try.
class _PhotoTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    final tips = [
      (Icons.flip_to_back_rounded, l.tipBackOfPack),
      (Icons.wb_sunny_outlined, l.tipLight),
      (Icons.crop_free_rounded, l.tipFillFrame),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.tipsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (icon, text) in tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.brand),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
