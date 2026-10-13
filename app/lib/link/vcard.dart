import 'dart:convert';

import '../models/card_content.dart';

/// Builds a vCard 3.0 contact from a card. Same fields and escaping as the
/// website's "Save contact" (site/assets/profile.js → buildVCard).
class VCard {
  static const mimeType = 'text/vcard';

  /// The contact card text. With [maxBytes], fields are added in priority order
  /// (name, phone, email, business, title, links, description) and any that
  /// don't fit are left out and listed in `omitted`.
  static ({String text, List<String> omitted}) build(CardContent c, {int? maxBytes}) {
    String esc(String s) =>
        s.replaceAll(r'\', r'\\').replaceAll('\n', r'\n').replaceAll(',', r'\,').replaceAll(';', r'\;');
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();

    final name = c.name.trim();
    final parts = name.split(RegExp(r'\s+'));
    final family = parts.length > 1 ? parts.removeLast() : '';
    final head = ['BEGIN:VCARD', 'VERSION:3.0', 'N:${esc(family)};${esc(parts.join(' '))};;;', 'FN:${esc(name)}'];
    const tail = ['END:VCARD'];

    final fields = <(String, List<String>)>[
      if (opt(c.phone) case final p?) ('phone', ['TEL;TYPE=CELL:${esc(p)}']),
      if (opt(c.email) case final e?) ('email', ['EMAIL;TYPE=INTERNET:${esc(e)}']),
      if (opt(c.business) case final b?) ('business', ['ORG:${esc(b)}']),
      if (opt(c.title) case final t?) ('title', ['TITLE:${esc(t)}']),
      for (var i = 0; i < c.links.length; i++)
        ('link ${i + 1}', ['item${i + 1}.URL:${c.links[i].url}', 'item${i + 1}.X-ABLabel:${esc(c.links[i].label)}']),
      if (opt(c.description) case final d?) ('description', ['NOTE:${esc(d)}']),
    ];

    int size(List<String> lines) => utf8.encode('${lines.join('\r\n')}\r\n').length;
    final lines = [...head];
    final omitted = <String>[];
    for (final (field, add) in fields) {
      if (maxBytes == null || size([...lines, ...add, ...tail]) <= maxBytes) {
        lines.addAll(add);
      } else {
        omitted.add(field);
      }
    }
    lines.addAll(tail);
    return (text: '${lines.join('\r\n')}\r\n', omitted: omitted);
  }
}
