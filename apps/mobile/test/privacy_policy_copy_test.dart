import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app shows assets/legal/privacy_policy.md; docs/PRIVACY_POLICY.md is the
// one people review. They must never drift apart.
void main() {
  test('the in-app privacy policy is the same text as docs/PRIVACY_POLICY.md', () {
    final inApp = File('assets/legal/privacy_policy.md').readAsStringSync();
    final docs = File('../../docs/PRIVACY_POLICY.md').readAsStringSync();
    expect(inApp.replaceAll('\r\n', '\n'), docs.replaceAll('\r\n', '\n'));
  });
}
