import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/snap.dart';
import 'package:mp3_direct_cut/core/time_format.dart';
import 'package:mp3_direct_cut/ui/editor/view_window.dart';

void main() {
  test('formatTime', () {
    expect(formatTime(65.25), '1:05.250');
    expect(formatTime(3723), '1:02:03.000');
    expect(formatTime(65.9, millis: false), '1:05');
    expect(formatTime(-3), '0:00.000');
  });

  test('niceStep', () {
    expect(niceStep(600, 1000), 60);
    expect(niceStep(2, 1000), 0.2);
    expect(niceStep(1e6, 100), 3600);
  });

  const fd = 1152 / 44100;
  final rms = Float32List(1000)..fillRange(0, 1000, 0.5);
  rms.fillRange(400, 411, 0);

  test('snapToFrame rounds to the nearest boundary', () {
    expect(snapToFrame(10.4 * fd, fd, 1000), 10);
    expect(snapToFrame(-1, fd, 1000), 0);
    expect(snapToFrame(5000 * fd, fd, 1000), 1000);
  });

  test('snapToQuiet finds the quiet boundary within 0.3 s', () {
    expect(snapToQuiet(395 * fd, rms, fd, 1000), 401);
    expect(snapToQuiet(405 * fd, rms, fd, 1000), 405);
  });

  test('snapToQuiet ignores silence further than 0.3 s', () {
    expect(snapToQuiet(380 * fd, rms, fd, 1000), 380);
  });

  test('ViewWindow.zoomAt keeps the time under the pointer', () {
    const v = ViewWindow(10, 20);
    final t = v.xToT(300, 1000);
    final z = v.zoomAt(t, 0.5, 100);
    expect(z.span, 10);
    expect(z.xToT(300, 1000), closeTo(t, 1e-9));
  });

  test('ViewWindow.clamp keeps the span and start inside the file', () {
    expect(const ViewWindow(-5, 0.001).clamp(100).span, 0.05);
    expect(const ViewWindow(-5, 10).clamp(100).start, 0);
    expect(const ViewWindow(95, 10).clamp(100).start, 90);
    expect(const ViewWindow(0, 500).clamp(100).span, 100);
    expect(const ViewWindow(3, 4).pan(-10, 100).start, 0);
  });
}
