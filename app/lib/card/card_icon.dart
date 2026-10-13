import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Draws one of the shared SVG icons (shared/icons.json), same glyphs as the website.
class CardIcon extends StatelessWidget {
  const CardIcon(this.paths, this.id, {super.key, required this.color, this.size = 20});
  final Map<String, String> paths;
  final String id;
  final Color color;
  final double size;

  static final _cache = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final d = paths[id] ?? paths['link']!;
    final svg = _cache.putIfAbsent(
      d,
      () => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$d"/></svg>',
    );
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}
