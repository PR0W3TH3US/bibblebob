import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../util/colors.dart';

/// Small HSV colour picker with a hex field. Returns the chosen colour or null.
Future<Color?> pickColor(BuildContext context, {required String title, required Color initial}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ColorPickerSheet(title: title, initial: initial),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: colorToHex(widget.initial));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor v) {
    setState(() => _hsv = v);
    _hex.text = colorToHex(v.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _hsv.toColor();

    Widget slider(String label, double value, double max, List<Color> gradient, ValueChanged<double> onChanged) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: c.secondaryText, fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: LayoutBuilder(
                  builder: (context, box) {
                    void update(Offset p) => onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0) * max);
                    return GestureDetector(
                      onTapDown: (d) => update(d.localPosition),
                      onHorizontalDragUpdate: (d) => update(d.localPosition),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(colors: gradient),
                            ),
                          ),
                          Positioned(
                            left: (value / max) * box.maxWidth - 14,
                            top: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.raised),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            slider('Hue', _hsv.hue, 360, [
              for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
            ], (v) => _set(_hsv.withHue(v.clamp(0, 359.9)))),
            slider('Saturation', _hsv.saturation, 1, [
              _hsv.withSaturation(0).toColor(),
              _hsv.withSaturation(1).toColor(),
            ], (v) => _set(_hsv.withSaturation(v))),
            slider('Brightness', _hsv.value, 1, [
              Colors.black,
              _hsv.withValue(1).toColor(),
            ], (v) => _set(_hsv.withValue(v))),
            TextField(
              controller: _hex,
              decoration: const InputDecoration(labelText: 'Hex colour', prefixIcon: Icon(Icons.tag)),
              onChanged: (v) {
                final t = v.trim().replaceFirst('#', '');
                if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(t)) setState(() => _hsv = HSVColor.fromColor(hexToColor(t)));
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, _hsv.toColor()), child: const Text('Use this colour')),
          ],
        ),
      ),
    );
  }
}
