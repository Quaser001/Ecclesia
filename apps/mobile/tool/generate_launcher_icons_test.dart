// Renders CalFit's launcher icons from the same painter the app uses.
//
//   flutter test tool/generate_launcher_icons_test.dart
//
// Writes the legacy PNGs (Android 7 and older, and launchers that ignore
// adaptive icons) for every density, round variants, and the 512 px Play
// Store icon. Lives in tool/ so the normal test run doesn't regenerate them.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/brand_mark.dart';

const _background = Color(0xFF1F6B4F); // ic_launcher_background
const _ring = Color(0xFFFAF7F2);
const _tick = Color(0xFFF08A72);

const _densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};

Future<List<int>> _render(int size, {required bool round, double markScale = 0.62}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final bg = Paint()..color = _background..isAntiAlias = true;
  if (round) {
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, bg);
  } else {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.2)), bg);
  }
  final mark = s * markScale;
  canvas.save();
  canvas.translate((s - mark) / 2, (s - mark) / 2);
  const BrandMarkPainter(ring: _ring, tick: _tick).paint(canvas, Size(mark, mark));
  canvas.restore();
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets('generate launcher icons', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      for (final entry in _densities.entries) {
        final dir = Directory('$res/mipmap-${entry.key}')..createSync(recursive: true);
        File('${dir.path}/ic_launcher.png')
            .writeAsBytesSync(await _render(entry.value, round: false));
        File('${dir.path}/ic_launcher_round.png')
            .writeAsBytesSync(await _render(entry.value, round: true));
      }
      // Play Store listing icon: full square; Google Play applies the mask.
      Directory('store').createSync();
      final store = ui.PictureRecorder();
      final c = Canvas(store);
      c.drawRect(const Rect.fromLTWH(0, 0, 512, 512), Paint()..color = _background);
      c.translate(512 * 0.19, 512 * 0.19);
      const BrandMarkPainter(ring: _ring, tick: _tick).paint(c, const Size(512 * 0.62, 512 * 0.62));
      final img = await store.endRecording().toImage(512, 512);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('store/play_store_icon_512.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
