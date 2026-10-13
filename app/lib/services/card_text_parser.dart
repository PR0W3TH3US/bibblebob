/// Turns the text recognised on a paper business card into contact fields.
/// Pure Dart so it can be unit tested; heuristics, not magic — the user
/// always reviews the result before saving.
class OcrLine {
  const OcrLine(this.text, {this.height = 0});
  final String text;

  /// Height of the line's bounding box. Names are usually the largest text.
  final double height;
}

class ParsedCard {
  const ParsedCard({
    this.name = '',
    this.title = '',
    this.business = '',
    this.phone = '',
    this.email = '',
    this.website = '',
  });
  final String name, title, business, phone, email, website;
}

class CardTextParser {
  static final _email = RegExp(r'[A-Za-z0-9._%+\-]+\s?@\s?[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final _url = RegExp(
    r'\b((?:https?://)?(?:www\.)?[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}(?:/[^\s]*)?)',
    caseSensitive: false,
  );
  static final _phoneChars = RegExp(r'(\+?\(?\d[\d\s().\-/]{6,}\d)');
  static final _phoneLabel = RegExp(
    r'^(tel|telephone|phone|ph|mob|mobile|cell|m|t|p|gsm|direct|office|o)\b\.?\s*[:.]?\s*',
    caseSensitive: false,
  );
  static final _faxLabel = RegExp(r'^\s*(fax|f)\b', caseSensitive: false);

  static const _companyWords = [
    'ltd',
    'limited',
    'llc',
    'inc',
    'gmbh',
    'ag',
    's.r.o',
    'sro',
    'a.s',
    'ab',
    'as',
    'oy',
    'bv',
    'b.v',
    'sa',
    's.a',
    'sp. z o.o',
    'spa',
    'srl',
    'plc',
    'corp',
    'corporation',
    'company',
    'co.',
    'group',
    'studio',
    'agency',
    'solutions',
    'consulting',
    'technologies',
    'labs',
    'partners',
    'associates',
    'holding',
    'international',
  ];
  static const _titleWords = [
    'ceo',
    'cto',
    'cfo',
    'coo',
    'cmo',
    'founder',
    'co-founder',
    'owner',
    'director',
    'manager',
    'head',
    'lead',
    'engineer',
    'developer',
    'designer',
    'consultant',
    'officer',
    'specialist',
    'partner',
    'president',
    'vp',
    'architect',
    'analyst',
    'assistant',
    'advisor',
    'adviser',
    'sales',
    'marketing',
    'account',
    'executive',
    'coordinator',
    'producer',
    'photographer',
    'artist',
    'lawyer',
    'attorney',
    'accountant',
    'agent',
    'broker',
  ];
  static const _freeMail = [
    'gmail',
    'outlook',
    'hotmail',
    'yahoo',
    'icloud',
    'proton',
    'protonmail',
    'live',
    'aol',
    'gmx',
    'seznam',
    'email',
    'mail',
  ];

  static ParsedCard parse(List<OcrLine> input) {
    final lines = input.map((l) => OcrLine(l.text.trim(), height: l.height)).where((l) => l.text.isNotEmpty).toList();
    final used = <int>{};

    var email = '';
    for (var i = 0; i < lines.length && email.isEmpty; i++) {
      final m = _email.firstMatch(lines[i].text);
      if (m != null) {
        email = m.group(0)!.replaceAll(' ', '');
        if (lines[i].text.replaceAll(m.group(0)!, '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 8) used.add(i);
      }
    }

    var phone = '';
    for (var pass = 0; pass < 2 && phone.isEmpty; pass++) {
      for (var i = 0; i < lines.length; i++) {
        final t = lines[i].text;
        if (_faxLabel.hasMatch(t) || t.contains('@')) continue;
        // First pass prefers mobile numbers.
        if (pass == 0 && !RegExp(r'^(mob|mobile|cell|m|gsm)\b', caseSensitive: false).hasMatch(t)) continue;
        final m = _phoneChars.firstMatch(t.replaceFirst(_phoneLabel, ''));
        if (m == null) continue;
        final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 7 || digits.length > 15) continue;
        phone = m.group(0)!.trim();
        used.add(i);
        break;
      }
    }

    var website = '';
    for (var i = 0; i < lines.length && website.isEmpty; i++) {
      if (used.contains(i) || lines[i].text.contains('@')) continue;
      final m = _url.firstMatch(lines[i].text);
      if (m != null &&
          (m.group(0)!.contains('www') ||
              m.group(0)!.contains('://') ||
              m.group(0)!.contains('/') ||
              lines[i].text.trim() == m.group(0))) {
        if (RegExp(r'\d{4,}').hasMatch(m.group(0)!)) continue;
        website = m.group(0)!;
        used.add(i);
      }
    }

    bool isCompany(String t) {
      final l = ' ${t.toLowerCase()} ';
      return _companyWords.any((w) => RegExp('(^|[\\s,])${RegExp.escape(w)}(\$|[\\s,.])').hasMatch(l.trim()));
    }

    bool isTitle(String t) {
      final l = t.toLowerCase();
      return _titleWords.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(l));
    }

    bool looksLikeName(String t) {
      final words = t.split(RegExp(r'\s+'));
      if (words.length < 2 || words.length > 4) return false;
      if (RegExp(r'[\d@/:]').hasMatch(t)) return false;
      return words.every((w) => RegExp(r"^[\p{Lu}][\p{L}'’\-.]*$", unicode: true).hasMatch(w));
    }

    var title = '';
    for (var i = 0; i < lines.length && title.isEmpty; i++) {
      if (!used.contains(i) && isTitle(lines[i].text) && !isCompany(lines[i].text) && lines[i].text.length <= 60) {
        title = lines[i].text;
        used.add(i);
      }
    }

    var business = '';
    for (var i = 0; i < lines.length && business.isEmpty; i++) {
      if (!used.contains(i) && isCompany(lines[i].text)) {
        business = lines[i].text;
        used.add(i);
      }
    }

    // Name: the largest remaining line that looks like a person's name.
    var name = '';
    final candidates = [
      for (var i = 0; i < lines.length; i++)
        if (!used.contains(i) && looksLikeName(lines[i].text)) i,
    ]..sort((a, b) => lines[b].height.compareTo(lines[a].height));
    if (candidates.isNotEmpty) {
      name = _tidyCase(lines[candidates.first].text);
      used.add(candidates.first);
    }

    // Business fallback: the email's domain, unless it's a free mail provider.
    if (business.isEmpty && email.contains('@')) {
      final domain = email.split('@').last.split('.').first.toLowerCase();
      if (!_freeMail.contains(domain) && domain.length > 1) {
        business = domain[0].toUpperCase() + domain.substring(1);
      }
    }

    return ParsedCard(name: name, title: title, business: business, phone: phone, email: email, website: website);
  }

  /// "JANE DOE" -> "Jane Doe"; mixed case is kept.
  static String _tidyCase(String s) {
    if (s != s.toUpperCase()) return s;
    return s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
