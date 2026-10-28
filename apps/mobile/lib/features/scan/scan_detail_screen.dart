import 'package:flutter/material.dart';

import '../../core/utils/user_message.dart';
import '../../core/widgets/status_view.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';
import '../../services/api_service.dart';
import 'scan_result_screen.dart';

/// Opens one past scan: loads it, then shows the same result layout a fresh
/// scan gets. Reached by tapping a scan anywhere in the app.
class ScanDetailScreen extends StatefulWidget {
  final ApiService apiService;
  final String scanId;

  const ScanDetailScreen({super.key, required this.apiService, required this.scanId});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  ScanResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.apiService.getScan(widget.scanId);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = UserMessage.of(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return ScanResultScreen(
        scanResult: result,
        title: context.l10n.scanDetailsTitle,
        isPastScan: true,
        apiService: widget.apiService,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.scanDetailsTitle)),
      body: _error == null
          ? const Center(child: CircularProgressIndicator())
          : StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.l10n.couldntOpenScan,
              message: _error!,
              actionLabel: context.l10n.tryAgain,
              onAction: _load,
              isError: true,
            ),
    );
  }
}
