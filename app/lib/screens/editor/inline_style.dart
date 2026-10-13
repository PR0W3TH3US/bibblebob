import 'package:flutter/material.dart';

import '../../card/card_view.dart';
import '../../design/design_spec.dart';
import '../../models/card_content.dart';
import '../../theme/app_theme.dart';
import '../../util/colors.dart';

/// Fills empty fields with sample text so previews of a new card still show each layout.
CardContent withSampleText(CardContent c) => c.copyWith(
  name: c.name.trim().isEmpty ? 'Your name' : null,
  title: c.title.trim().isEmpty ? 'Your title' : null,
  business: c.business.trim().isEmpty ? 'Business' : null,
  phone: c.phone.trim().isEmpty ? '+00 000 000 000' : null,
  email: c.email.trim().isEmpty ? 'you@example.com' : null,
  links: c.links.isEmpty
      ? const [
          CardLink(label: 'Website', url: 'https://example.com', icon: 'web'),
          CardLink(label: 'Instagram', url: 'https://instagram.com', icon: 'instagram'),
        ]
      : null,
);

/// All templates as live mini previews of the user's own card, always visible
/// at the top of the editor.
class TemplateStrip extends StatelessWidget {
  const TemplateStrip({super.key, required this.spec, required this.content, required this.onSelected});
  final DesignSpec spec;
  final CardContent content;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: spec.templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = spec.templates[i];
          final selected = t.id == content.templateId;
          return Semantics(
            button: true,
            selected: selected,
            label: '${t.name} template',
            child: GestureDetector(
              onTap: () => onSelected(t.id),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 122,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? c.accent : c.raised, width: selected ? 2.5 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: spec.designWidth,
                            child: CardView(
                              content: withSampleText(content).copyWith(templateId: t.id),
                              spec: spec,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.name,
                    style: TextStyle(
                      color: selected ? c.accent : c.secondaryText,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Colour palettes as one-tap swatches, plus a "Custom" button for own colours.
class PaletteStrip extends StatelessWidget {
  const PaletteStrip({
    super.key,
    required this.spec,
    required this.style,
    required this.onSelected,
    required this.onCustom,
  });
  final DesignSpec spec;
  final CardStyle style;
  final ValueChanged<PaletteSpec> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final custom = style.paletteId == null;
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          for (final p in spec.palettes) ...[
            Semantics(
              button: true,
              selected: style.paletteId == p.id,
              label: '${p.name} colours',
              child: GestureDetector(
                onTap: () => onSelected(p),
                child: Column(
                  children: [
                    _Swatch(
                      bg: hexToColor(p.bg),
                      fg: hexToColor(p.text),
                      accent: hexToColor(p.accent),
                      selected: style.paletteId == p.id,
                      ring: c.accent,
                    ),
                    const SizedBox(height: 4),
                    Text(p.name, style: TextStyle(color: c.secondaryText, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Semantics(
            button: true,
            selected: custom,
            label: 'Custom colours',
            child: GestureDetector(
              onTap: onCustom,
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: custom ? hexToColor(style.bg) : c.raised,
                      border: Border.all(color: custom ? c.accent : c.raised, width: custom ? 2.5 : 1),
                    ),
                    child: Icon(Icons.colorize, size: 20, color: custom ? hexToColor(style.accent) : c.text),
                  ),
                  const SizedBox(height: 4),
                  Text('Custom', style: TextStyle(color: c.secondaryText, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.bg, required this.fg, required this.accent, required this.selected, required this.ring});
  final Color bg, fg, accent, ring;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: selected ? ring : Colors.transparent, width: 2.5),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
    ),
  );
}

/// Fonts as "Aa" chips drawn in each font.
class FontStrip extends StatelessWidget {
  const FontStrip({super.key, required this.spec, required this.fontId, required this.onSelected});
  final DesignSpec spec;
  final String fontId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: spec.fonts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = spec.fonts[i];
          final selected = f.id == fontId;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(f.id),
            label: Text(
              f.family,
              style: TextStyle(
                fontFamily: f.flutterFamily,
                fontWeight: FontWeight.w700,
                color: selected ? c.onAccent : c.text,
              ),
            ),
          );
        },
      ),
    );
  }
}
