import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../services/api_service.dart';
import '../settings/privacy_policy_screen.dart';

/// The version of the notice text below. Must match CONSENT_NOTICE_VERSION
/// on the server (src/services/consent.py). Change both when the text
/// changes, so everyone is asked again.
const consentNoticeVersion = '2026-10-29';

/// Shows the privacy notice until this person has agreed to it, then [child].
///
/// The server is the authority: it refuses to save a profile or score a scan
/// without a recorded agreement (DPDP Act s.6(10)). The phone only remembers
/// "agreed to this version" so the app opens without a network round trip;
/// any 428 from the server brings the notice back.
class ConsentGate extends StatefulWidget {
  final ApiService apiService;

  /// The family profile this is for: each person agrees for themselves.
  final String? profileId;
  final Widget child;

  const ConsentGate({super.key, required this.apiService, required this.child, this.profileId});

  static String _key(String? profileId) => 'calfit.consent.${profileId ?? 'default'}';

  /// After "Delete my data" or removing a profile.
  static Future<void> forget(String? profileId) async =>
      (await SharedPreferences.getInstance()).remove(_key(profileId));

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _Gate { checking, needed, agreed, failed }

class _ConsentGateState extends State<ConsentGate> {
  _Gate _state = _Gate.checking;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.apiService.consentNeeded.addListener(_onServerSaysNeeded);
    _check();
  }

  @override
  void dispose() {
    widget.apiService.consentNeeded.removeListener(_onServerSaysNeeded);
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _state = _Gate.checking;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(ConsentGate._key(widget.profileId)) == consentNoticeVersion) {
      if (mounted) setState(() => _state = _Gate.agreed);
      return;
    }
    try {
      final status = await widget.apiService.getConsent();
      if (!mounted) return;
      if (status.agreed && status.currentVersion == consentNoticeVersion) {
        await prefs.setString(ConsentGate._key(widget.profileId), consentNoticeVersion);
        if (mounted) setState(() => _state = _Gate.agreed);
      } else {
        setState(() => _state = _Gate.needed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _Gate.failed;
          _error = e;
        });
      }
    }
  }

  Future<void> _onServerSaysNeeded() async {
    if (!widget.apiService.consentNeeded.value) return;
    await ConsentGate.forget(widget.profileId);
    if (mounted) setState(() => _state = _Gate.needed);
  }

  Future<void> _agreed() async {
    await (await SharedPreferences.getInstance())
        .setString(ConsentGate._key(widget.profileId), consentNoticeVersion);
    if (mounted) setState(() => _state = _Gate.agreed);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _Gate.agreed => widget.child,
      _Gate.needed => ConsentScreen(apiService: widget.apiService, onAgreed: _agreed),
      _Gate.checking => const Scaffold(body: Center(child: CircularProgressIndicator())),
      _Gate.failed => Scaffold(
          body: SafeArea(
            child: StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.l10n.consentTitle,
              message: UserMessage.of(context, _error!),
              actionLabel: context.l10n.tryAgain,
              onAction: _check,
              isError: true,
            ),
          ),
        ),
    };
  }
}

/// The notice (DPDP Rules r.3): what is collected, why, who else handles it,
/// and how to withdraw, use your rights and complain. "I agree" stays off
/// until "I am 18 or older" is ticked.
class ConsentScreen extends StatefulWidget {
  final ApiService apiService;
  final Future<void> Function() onAgreed;
  const ConsentScreen({super.key, required this.apiService, required this.onAgreed});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _adult = false;
  bool _sending = false;

  Future<void> _agree() async {
    setState(() => _sending = true);
    try {
      await widget.apiService.giveConsent(consentNoticeVersion);
      HapticFeedback.mediumImpact();
      await widget.onAgreed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(UserMessage.of(context, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;

    Widget section(String title, List<String> body) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              for (final b in body)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(b, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  Text(l.consentTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(l.consentIntro, style: theme.textTheme.bodyLarge),
                  section(l.consentWhatTitle,
                      [l.consentItemProfile, l.consentItemScans, l.consentItemToken]),
                  section(l.consentSharedTitle, [l.consentShared]),
                  section(l.consentChoicesTitle, [l.consentChoices]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      child: Text(l.consentReadPolicy),
                    ),
                  ),
                ],
              ),
            ),
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _adult,
                    onChanged: _sending ? null : (v) => setState(() => _adult = v ?? false),
                    title: Text(l.consentAdult),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  FilledButton(
                    onPressed: _adult && !_sending ? _agree : null,
                    child: _sending
                        ? const SizedBox.square(
                            dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.consentAgree),
                  ),
                  const SizedBox(height: 8),
                  Text(l.consentDeclineNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
