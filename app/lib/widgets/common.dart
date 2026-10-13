import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/contact.dart';
import '../theme/app_theme.dart';

/// Text with every occurrence of the search words highlighted in the accent colour.
class HighlightText extends StatelessWidget {
  const HighlightText(this.text, {super.key, required this.query, required this.style, this.maxLines = 1});
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    final lower = text.toLowerCase();
    final marks = List<bool>.filled(text.length, false);
    for (final w in words) {
      var i = lower.indexOf(w);
      while (i >= 0) {
        for (var k = i; k < i + w.length && k < marks.length; k++) {
          marks[k] = true;
        }
        i = lower.indexOf(w, i + w.length);
      }
    }
    final accent = context.colors.accent;
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || marks[i] != marks[start]) {
        spans.add(
          TextSpan(
            text: text.substring(start, i),
            style: marks[start] ? TextStyle(color: accent, fontWeight: FontWeight.w700) : null,
          ),
        );
        start = i;
      }
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.size = 44});
  final Contact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    final img = s.image(contact.content.facePath) ?? s.image(contact.content.logoPath);
    final initials = contact.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: img != null
          ? Image(
              image: img,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: size * 0.36),
            ),
    );
  }
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.black)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Simple centred message with an icon, used for empty lists and errors.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.secondaryText),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(color: c.secondaryText, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
