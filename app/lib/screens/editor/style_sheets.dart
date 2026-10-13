import 'package:flutter/material.dart';

import '../../design/design_spec.dart';
import '../../models/card_content.dart';
import '../../theme/app_theme.dart';
import '../../util/colors.dart';
import 'color_picker.dart';

/// The custom-colours sheet (preset palettes, own colours, contrast warnings). Applies changes live via [onChanged].
class StyleSheets {
  static Future<void> colours(
    BuildContext context, {
    required DesignSpec spec,
    required CardStyle Function() current,
    required ValueChanged<CardStyle> onChanged,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        final c = context.colors;
        final style = current();
        final bg = hexToColor(style.bg), text = hexToColor(style.text), accent = hexToColor(style.accent);
        final textContrast = contrastRatio(text, bg);
        final accentContrast = contrastRatio(accent, bg);

        void apply(CardStyle s) {
          onChanged(s);
          setState(() {});
        }

        Future<void> custom(String which) async {
          final initial = switch (which) {
            'bg' => bg,
            'text' => text,
            _ => accent,
          };
          final title = switch (which) {
            'bg' => 'Background',
            'text' => 'Text',
            _ => 'Accent',
          };
          final picked = await pickColor(context, title: title, initial: initial);
          if (picked == null) return;
          final hex = colorToHex(picked);
          apply(switch (which) {
            'bg' => style.copyWith(bg: hex, custom: true),
            'text' => style.copyWith(text: hex, custom: true),
            _ => style.copyWith(accent: hex, custom: true),
          });
        }

        Widget swatchRow(String label, Color color, String which) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => custom(which),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: c.raised, width: 2),
            ),
          ),
          title: Text(label),
          subtitle: Text(colorToHex(color), style: TextStyle(color: c.secondaryText)),
          trailing: const Icon(Icons.edit_outlined),
        );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(context, 'Colours', null),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: spec.palettes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = spec.palettes[i];
                      final selected = style.paletteId == p.id;
                      return GestureDetector(
                        onTap: () => apply(style.copyWith(bg: p.bg, text: p.text, accent: p.accent, paletteId: p.id)),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: hexToColor(p.bg),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selected ? c.accent : c.raised, width: selected ? 2.5 : 1),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Aa',
                                    style: TextStyle(
                                      color: hexToColor(p.text),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: hexToColor(p.accent), shape: BoxShape.circle),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(p.name, style: TextStyle(color: selected ? c.accent : c.secondaryText, fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    'Custom',
                    style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      swatchRow('Background', bg, 'bg'),
                      swatchRow('Text', text, 'text'),
                      swatchRow('Accent (buttons, icons)', accent, 'accent'),
                    ],
                  ),
                ),
                if (textContrast < 4.5)
                  _warning(
                    context,
                    'Text may be hard to read (contrast ${textContrast.toStringAsFixed(1)}:1, aim for 4.5:1 or more).',
                  ),
                if (accentContrast < 3)
                  _warning(
                    context,
                    'Buttons and icons may be hard to see on this background (contrast ${accentContrast.toStringAsFixed(1)}:1).',
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ),
  );

  static Widget _title(BuildContext context, String title, String? subtitle) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) Text(subtitle, style: TextStyle(color: c.secondaryText)),
        ],
      ),
    );
  }

  static Widget _warning(BuildContext context, String text) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC857)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: c.text)),
          ),
        ],
      ),
    );
  }
}
