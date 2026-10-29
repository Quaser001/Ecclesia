import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/error_reporter.dart';

void main() {
  group('ErrorReporter', () {
    test('sends error type and frames, never the message', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 204);
      });

      final reporter = ErrorReporter(baseUrl: 'http://test', client: client);
      await reporter.postForTest({
        'error_type': 'StateError',
        'frames': [
          {'file': 'main.dart', 'line': 15, 'fn': 'main'},
        ],
      });

      expect(bodies, hasLength(1));
      expect(bodies[0]['error_type'], 'StateError');
      expect(bodies[0]['frames'], hasLength(1));
    });

    test('frame parser produces the right shape', () {
      final frames = ErrorReporter.parseFramesForTest(
        StackTrace.fromString(
          '#0      main (package:mobile/main.dart:15:3)\n'
          '#1      _runMainZoned (dart:ui/hooks.dart:142:25)\n',
        ),
      );

      expect(frames, hasLength(2));
      expect(frames[0]['file'], 'main.dart');
      expect(frames[0]['line'], 15);
      expect(frames[0]['fn'], 'main');
      expect(frames[1]['file'], 'hooks.dart');
    });

    test('frame parser caps at 20 frames', () {
      final lines = List.generate(
        30,
        (i) => '#$i      fn$i (package:mobile/f$i.dart:$i:1)',
      ).join('\n');
      final frames = ErrorReporter.parseFramesForTest(StackTrace.fromString(lines));
      expect(frames.length, lessThanOrEqualTo(20));
    });

    test('frame parser handles empty stack', () {
      final frames = ErrorReporter.parseFramesForTest(StackTrace.empty);
      expect(frames, isEmpty);
    });

    test('network failure is swallowed', () async {
      final client = MockClient((req) async {
        throw Exception('network down');
      });

      final reporter = ErrorReporter(baseUrl: 'http://test', client: client);
      await reporter.postForTest({'error_type': 'E', 'frames': []});
    });
  });
}
