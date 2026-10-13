/// Adds https:// when missing and accepts only http(s) links with a real host.
/// Only these links are written into cards; the website re-checks them when it decodes a card.
String? normaliseUrl(String input) {
  var v = input.trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(v)) v = 'https://$v';
  final u = Uri.tryParse(v);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  if (!u.host.contains('.') || u.host.startsWith('.') || u.host.endsWith('.')) return null;
  if (v.contains(' ')) return null;
  return u.toString();
}

/// "https://www.example.com/x" -> "example.com"
String hostLabel(String url) => (Uri.tryParse(url)?.host ?? url).replaceFirst(RegExp(r'^www\.'), '');
