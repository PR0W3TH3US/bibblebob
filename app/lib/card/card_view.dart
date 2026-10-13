import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_spec.dart';
import '../models/card_content.dart';
import '../util/colors.dart';
import 'card_icon.dart';

/// Inline editing hooks. When a CardView gets one, the card itself is the editor:
/// text slots become text fields, empty slots show greyed placeholders.
class CardEditor {
  CardEditor({
    required this.controllers,
    required this.focusColor,
    required this.onEditLink,
    required this.onAddLink,
    required this.onReorderLinks,
  });

  /// Keys: name, title, business, phone, email, description.
  final Map<String, TextEditingController> controllers;

  /// The app accent; outlines the field being edited.
  final Color focusColor;
  final void Function(int index) onEditLink;
  final VoidCallback onAddLink;
  final void Function(int oldIndex, int newIndex) onReorderLinks;
}

/// Renders a template card. Metrics mirror site/assets/card.css — change both together.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.content,
    required this.spec,
    this.logo,
    this.face,
    this.editor,
    this.onLinkTap,
    this.onPhoneTap,
    this.onEmailTap,
  });

  final CardContent content;
  final DesignSpec spec;
  final ImageProvider? logo;
  final ImageProvider? face;
  final CardEditor? editor;
  final void Function(CardLink link)? onLinkTap;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onEmailTap;

  bool get editing => editor != null;

  @override
  Widget build(BuildContext context) {
    final tpl = spec.template(content.templateId);
    final s = _CardStyle.from(content.style, spec, tpl);
    final blocks = <Widget>[];
    for (final name in tpl.order) {
      final w = switch (name) {
        'header' => null, // drawn separately (banner needs full width)
        'contact' => _contact(s),
        'description' => _description(s),
        'links' => _links(context, s),
        _ => null,
      };
      if (name == 'header') {
        blocks.add(const _HeaderSlot());
      } else if (w != null) {
        blocks.add(w);
      }
    }

    final banner = tpl.header == HeaderLayout.banner;
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 20));
      children.add(blocks[i] is _HeaderSlot ? _header(s) : blocks[i]);
    }

    return DefaultTextStyle(
      style: TextStyle(fontFamily: s.font, color: s.text, fontSize: 15),
      child: Container(
        color: s.bg,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, banner && tpl.order.first == 'header' ? 0 : 28, 24, 24),
        child: Column(
          crossAxisAlignment: tpl.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ header

  Widget _header(_CardStyle s) {
    final tpl = s.tpl;
    final text = Column(
      crossAxisAlignment: tpl.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _text(
          s,
          'name',
          content.name,
          'Your name',
          TextStyle(fontSize: tpl.nameSize, fontWeight: FontWeight.w700, height: 1.15, color: s.text),
          maxLength: spec.limits.name,
        ),
        if (editing || content.title.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _text(
              s,
              'title',
              content.title,
              'Add title',
              TextStyle(fontSize: 15, height: 1.35, color: s.muted),
              maxLength: spec.limits.title,
            ),
          ),
        if (editing || content.business.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _text(
              s,
              'business',
              content.business,
              'Add business',
              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: s.text),
              maxLength: spec.limits.business,
            ),
          ),
      ],
    );

    switch (tpl.header) {
      case HeaderLayout.banner:
        final faceW = _face(s, 104, border: 4);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: faceW != null ? 172 : 112,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Full-bleed band: cancel the card's side padding.
                  Positioned(
                    left: -24,
                    right: -24,
                    top: 0,
                    height: 112,
                    child: Container(
                      color: s.accent,
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.topLeft,
                      child: _logo(s, maxHeight: 32),
                    ),
                  ),
                  if (faceW != null) Positioned(top: 60, child: faceW),
                ],
              ),
            ),
            SizedBox(height: faceW != null ? 14 : 16),
            text,
          ],
        );
      case HeaderLayout.split:
        final logo = _logo(s, maxHeight: 36);
        final faceW = _face(s, 88);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null) ...[logo, const SizedBox(height: 16)],
            Row(
              children: [
                if (faceW != null) ...[faceW, const SizedBox(width: 16)],
                Expanded(child: text),
              ],
            ),
          ],
        );
      case HeaderLayout.center:
      case HeaderLayout.left:
        final logo = _logo(s, maxHeight: 36);
        final faceW = _face(s, tpl.header == HeaderLayout.left ? 80 : 104);
        return Column(
          crossAxisAlignment: tpl.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null) ...[logo, const SizedBox(height: 16)],
            if (faceW != null) ...[faceW, const SizedBox(height: 14)],
            text,
          ],
        );
    }
  }

  Widget? _logo(_CardStyle s, {required double maxHeight}) {
    if (logo != null) {
      final img = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 160),
        child: Image(image: logo!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
      );
      return img;
    }
    return null;
  }

  Widget? _face(_CardStyle s, double size, {double border = 0}) {
    final radius = switch (s.tpl.face) {
      FaceShape.circle => size / 2,
      FaceShape.rounded => size * 0.22,
      FaceShape.square => size * 0.08,
    };
    Widget? inner;
    if (face != null) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image(
          image: face!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
        ),
      );
    }
    if (inner == null) return null;
    if (border > 0) {
      inner = Container(
        padding: EdgeInsets.all(border),
        decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(radius + border)),
        child: inner,
      );
    }
    return inner;
  }

  // ------------------------------------------------------------------ contact + description

  Widget? _contact(_CardStyle s) {
    final hasPhone = content.phone.trim().isNotEmpty, hasEmail = content.email.trim().isNotEmpty;
    if (!editing && !hasPhone && !hasEmail) return null;
    Widget row(
      String key,
      String iconId,
      String value,
      String placeholder,
      VoidCallback? onTap,
      TextInputType type,
      int max,
    ) {
      final child = Row(
        mainAxisSize: s.tpl.centered ? MainAxisSize.min : MainAxisSize.max,
        children: [
          CardIcon(spec.iconPaths, iconId, color: s.accent),
          const SizedBox(width: 12),
          Flexible(
            child: _text(
              s,
              key,
              value,
              placeholder,
              TextStyle(fontSize: 15, color: s.text),
              keyboard: type,
              maxLength: max,
              align: TextAlign.start,
            ),
          ),
        ],
      );
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: InkWell(
          onTap: editing ? null : onTap,
          child: Align(
            alignment: s.tpl.centered ? Alignment.center : Alignment.centerLeft,
            widthFactor: 1,
            child: child,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: s.tpl.centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editing || hasPhone)
          row('phone', 'ui-phone', content.phone, 'Add phone', onPhoneTap, TextInputType.phone, spec.limits.phone),
        if (editing || hasEmail)
          row(
            'email',
            'ui-email',
            content.email,
            'Add email',
            onEmailTap,
            TextInputType.emailAddress,
            spec.limits.email,
          ),
      ],
    );
  }

  Widget? _description(_CardStyle s) {
    if (!editing && content.description.trim().isEmpty) return null;
    return SizedBox(
      width: double.infinity,
      child: _text(
        s,
        'description',
        content.description,
        'Add a short description',
        TextStyle(fontSize: 15, height: 1.5, color: s.muted),
        multiline: true,
        maxLength: spec.limits.description,
      ),
    );
  }

  // ------------------------------------------------------------------ links

  Widget? _links(BuildContext context, _CardStyle s) {
    final links = content.links;
    if (!editing && links.isEmpty) return null;
    final max = spec.linkPreviewCount;

    if (editing) {
      final items = [for (var i = 0; i < links.length; i++) _link(s, links[i], i, dimmed: i >= max)];
      final addRow = _tappable(
        _Placeholder(
          width: double.infinity,
          height: 52,
          radius: 14,
          color: s.placeholder,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: s.placeholder, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add link',
                style: TextStyle(color: s.placeholder, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
        editor!.onAddLink,
        'Add link',
      );
      final note = links.length > max
          ? Text(
              'Links after the $max${_ordinal(max)} are behind a “More” button.',
              style: TextStyle(fontSize: 12, color: s.muted),
              textAlign: TextAlign.center,
            )
          : null;

      Widget list;
      if (s.tpl.links == LinkStyle.grid) {
        list = _grid(items);
      } else {
        list = ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: editor!.onReorderLinks,
          proxyDecorator: (child, _, _) => Material(type: MaterialType.transparency, child: child),
          children: [
            for (var i = 0; i < items.length; i++)
              ReorderableDelayedDragStartListener(
                key: ValueKey('link-$i-${links[i].url}'),
                index: i,
                child: Padding(
                  padding: EdgeInsets.only(bottom: s.tpl.links == LinkStyle.list ? 0 : 10),
                  child: items[i],
                ),
              ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (links.isNotEmpty) list,
          if (links.isNotEmpty && s.tpl.links == LinkStyle.grid) const SizedBox(height: 10),
          if (links.isNotEmpty && s.tpl.links == LinkStyle.list) const SizedBox(height: 10),
          addRow,
          if (note != null) ...[const SizedBox(height: 8), note],
        ],
      );
    }

    return _LinksWithMore(
      count: links.length,
      max: max,
      accent: s.accent,
      iconPaths: spec.iconPaths,
      builder: (visible) {
        final items = [for (var i = 0; i < visible; i++) _link(s, links[i], i)];
        if (s.tpl.links == LinkStyle.grid) return _grid(items);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0 && s.tpl.links != LinkStyle.list) const SizedBox(height: 10),
              items[i],
            ],
          ],
        );
      },
    );
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final i in items) SizedBox(width: w, child: i)],
        );
      },
    );
  }

  Widget _link(_CardStyle s, CardLink l, int index, {bool dimmed = false}) {
    final label = Text(l.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
    Widget w;
    switch (s.tpl.links) {
      case LinkStyle.pill:
        w = _LinkBox(
          height: 52,
          decoration: BoxDecoration(color: s.accent, borderRadius: BorderRadius.circular(26)),
          leading: CardIcon(spec.iconPaths, l.icon, color: s.onAccent),
          leadingInset: 18,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onAccent),
          child: label,
        );
      case LinkStyle.outline:
        w = _LinkBox(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: s.accent, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          leading: CardIcon(spec.iconPaths, l.icon, color: s.accent),
          leadingInset: 16,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.text),
          child: label,
        );
      case LinkStyle.list:
        w = Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: s.hair)),
          ),
          child: Row(
            children: [
              CardIcon(spec.iconPaths, l.icon, color: s.accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: s.text),
                ),
              ),
              CardIcon(spec.iconPaths, 'ui-chevron', color: s.muted),
            ],
          ),
        );
      case LinkStyle.grid:
        w = Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CardIcon(spec.iconPaths, l.icon, color: s.accent, size: 26),
              const SizedBox(height: 8),
              DefaultTextStyle.merge(
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.text),
                child: label,
              ),
            ],
          ),
        );
    }
    if (dimmed) w = Opacity(opacity: 0.55, child: w);
    if (editing) return _tappable(w, () => editor!.onEditLink(index), 'Edit link ${l.label}');
    return Semantics(
      link: true,
      label: l.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLinkTap == null ? null : () => onLinkTap!(l),
        child: w,
      ),
    );
  }

  // ------------------------------------------------------------------ text slots

  Widget _text(
    _CardStyle s,
    String key,
    String value,
    String placeholder,
    TextStyle style, {
    bool multiline = false,
    TextInputType? keyboard,
    int? maxLength,
    TextAlign? align,
  }) {
    final textAlign = align ?? (s.tpl.centered ? TextAlign.center : TextAlign.start);
    if (!editing) return Text(value.trim(), style: style, textAlign: textAlign);
    return _InlineField(
      controller: editor!.controllers[key]!,
      style: style,
      placeholder: placeholder,
      placeholderColor: s.placeholder,
      focusColor: editor!.focusColor,
      align: textAlign,
      multiline: multiline,
      keyboard: keyboard,
      maxLength: maxLength,
    );
  }

  Widget _tappable(Widget child, VoidCallback onTap, String label) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );

  static String _ordinal(int n) => switch (n % 10) {
    1 when n != 11 => 'st',
    2 when n != 12 => 'nd',
    3 when n != 13 => 'rd',
    _ => 'th',
  };
}

class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CardStyle {
  _CardStyle({required this.tpl, required this.bg, required this.text, required this.accent, required this.font})
    : onAccent = onColor(accent),
      muted = text.withValues(alpha: 0.68),
      hair = text.withValues(alpha: 0.12),
      tile = text.withValues(alpha: 0.07),
      placeholder = text.withValues(alpha: 0.35);

  factory _CardStyle.from(CardStyle style, DesignSpec spec, TemplateSpec tpl) => _CardStyle(
    tpl: tpl,
    bg: hexToColor(style.bg),
    text: hexToColor(style.text),
    accent: hexToColor(style.accent),
    font: spec.font(style.fontId).flutterFamily,
  );

  final TemplateSpec tpl;
  final Color bg, text, accent, onAccent, muted, hair, tile, placeholder;
  final String font;
}

class _LinkBox extends StatelessWidget {
  const _LinkBox({
    required this.height,
    required this.decoration,
    required this.leading,
    required this.leadingInset,
    required this.style,
    required this.child,
  });
  final double height;
  final BoxDecoration decoration;
  final Widget leading;
  final double leadingInset;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: decoration,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(left: leadingInset, child: leading),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 52),
          child: DefaultTextStyle.merge(style: style, child: child),
        ),
      ],
    ),
  );
}

class _LinksWithMore extends StatefulWidget {
  const _LinksWithMore({
    required this.count,
    required this.max,
    required this.accent,
    required this.iconPaths,
    required this.builder,
  });
  final int count;
  final int max;
  final Color accent;
  final Map<String, String> iconPaths;
  final Widget Function(int visible) builder;

  @override
  State<_LinksWithMore> createState() => _LinksWithMoreState();
}

class _LinksWithMoreState extends State<_LinksWithMore> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsed = !_expanded && widget.count > widget.max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.builder(collapsed ? widget.max : widget.count),
        if (collapsed) ...[
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () => setState(() => _expanded = true),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More (${widget.count - widget.max})',
                      style: TextStyle(color: widget.accent, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    CardIcon(widget.iconPaths, 'ui-more', color: widget.accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.child,
  });
  final double width, height, radius;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color, width: 1.5),
      color: color.withValues(alpha: 0.08),
    ),
    child: child,
  );
}

/// A text field that looks like the card's text. Outlined in the app accent while focused.
class _InlineField extends StatefulWidget {
  const _InlineField({
    required this.controller,
    required this.style,
    required this.placeholder,
    required this.placeholderColor,
    required this.focusColor,
    required this.align,
    this.multiline = false,
    this.keyboard,
    this.maxLength,
  });
  final TextEditingController controller;
  final TextStyle style;
  final String placeholder;
  final Color placeholderColor;
  final Color focusColor;
  final TextAlign align;
  final bool multiline;
  final TextInputType? keyboard;
  final int? maxLength;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: focused ? widget.focusColor : Colors.transparent, width: 1.5),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: widget.style,
        textAlign: widget.align,
        cursorColor: widget.focusColor,
        keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboard,
        textCapitalization: widget.keyboard == null ? TextCapitalization.sentences : TextCapitalization.none,
        maxLines: widget.multiline ? null : 1,
        minLines: 1,
        inputFormatters: [if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength)],
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: widget.placeholder,
          hintStyle: widget.style.copyWith(color: widget.placeholderColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
