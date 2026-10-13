import 'package:flutter/material.dart';

import '../design/design_spec.dart';
import '../models/card_content.dart';
import 'card_icon.dart';

/// What an own-link card looks like to the receiver. Mirrors the .own section
/// of site/assets/site.css, which always uses the dark base and purple accent.
class OwnLinkView extends StatelessWidget {
  const OwnLinkView({
    super.key,
    required this.name,
    required this.business,
    required this.links,
    required this.spec,
    this.onLinkTap,
    this.showSiteButtons = false,
  });

  final String name;
  final String business;
  final List<CardLink> links;
  final DesignSpec spec;
  final void Function(CardLink link)? onLinkTap;

  /// Also show the page's "Save contact" / "Get the app" buttons (editor preview).
  final bool showSiteButtons;

  static const _bg = Color(0xFF0B0B0F);
  static const _text = Color(0xFFF2F2F5);
  static const _secondary = Color(0xFF9A9AA5);
  static const _accent = Color(0xFFA855F7);

  @override
  Widget build(BuildContext context) {
    Widget button(String label, {bool filled = true, VoidCallback? onTap}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: filled ? _accent : null,
            borderRadius: BorderRadius.circular(26),
            border: filled ? null : Border.all(color: _text.withValues(alpha: 0.3), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (filled && onTap != null) ...[
                CardIcon(spec.iconPaths, 'link', color: Colors.white),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: filled ? Colors.white : _text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name.trim().isEmpty ? 'Your name' : name.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: name.trim().isEmpty ? _secondary : _text,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (business.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                business.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _secondary, fontSize: 16),
              ),
            ),
          const SizedBox(height: 32),
          for (final l in links)
            button(
              links.length == 1 ? 'Open profile' : l.label,
              onTap: onLinkTap == null ? () {} : () => onLinkTap!(l),
            ),
          if (showSiteButtons) ...[button('Save contact'), button('Get the app', filled: false)],
        ],
      ),
    );
  }
}
