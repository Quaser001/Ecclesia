import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../l10n/l10n.dart';

/// Shows the privacy policy bundled with the app
/// (assets/legal/privacy_policy.md, a copy of docs/PRIVACY_POLICY.md).
/// A small renderer handles the headings, bullets and bold used there, so no
/// Markdown package is needed.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.privacyPolicy)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/privacy_policy.md'),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [for (final line in snap.data!.split('\n')) _line(context, line)],
            ),
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, String raw) {
    final t = Theme.of(context).textTheme;
    final line = raw.trimRight();
    if (line.isEmpty) return const SizedBox(height: 8);
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(line.substring(2), style: t.displaySmall),
      );
    }
    if (line.startsWith('## ') || line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(line.replaceFirst(RegExp(r'^#+ '), ''),
            style: line.startsWith('## ') ? t.headlineMedium : t.titleMedium),
      );
    }
    final bullet = line.startsWith('- ') || line.startsWith('* ');
    final body = Text.rich(_inline(bullet ? line.substring(2) : line, t.bodyMedium!),
        style: t.bodyMedium);
    if (!bullet) return Padding(padding: const EdgeInsets.only(bottom: 4), child: body);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('•  '), Expanded(child: body)],
      ),
    );
  }

  /// **bold** spans; underscores and backticks are dropped.
  TextSpan _inline(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final parts = text.replaceAll('`', '').replaceAll('_', '').split('**');
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : null,
      ));
    }
    return TextSpan(children: spans);
  }
}
