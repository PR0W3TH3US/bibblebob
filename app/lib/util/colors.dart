import 'dart:math' as math;

import 'package:flutter/painting.dart';

Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

String colorToHex(Color c) {
  String two(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG contrast ratio (1–21). Matches contrastRatio() in site/assets/render.js.
double contrastRatio(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Black or white, whichever reads better on [c]. Matches onColor() in render.js.
Color onColor(Color c) {
  const white = Color(0xFFFFFFFF), black = Color(0xFF000000);
  return contrastRatio(c, white) >= contrastRatio(c, black) ? white : black;
}
