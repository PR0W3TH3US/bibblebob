import 'dart:convert';
import 'dart:typed_data';

import '../config.dart';
import '../design/design_spec.dart';
import '../models/card_content.dart';

/// Card-in-link codec. Spec: shared/LINK_FORMAT.md.
/// Must stay byte-for-byte compatible with site/assets/linkcodec.js
/// (checked against shared/link-vectors.json in test/link_codec_test.dart).
class LinkCodec {
  LinkCodec(this.spec);
  final DesignSpec spec;

  static const _version = 1;
  static const _tName = 1, _tTitle = 2, _tBusiness = 3, _tPhone = 4, _tEmail = 5, _tDescription = 6;
  static const _tLink = 7, _tOwnLink = 8;
  static const dictCodes = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    11,
    12,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
  ];
  static const _phone = '0123456789+ -().';

  /// The full link for sharing (no size limit).
  String link(CardContent card, String cardId) => tagLink(card, cardId).url;

  /// For an own-link card, its main (first) link. Tags and shared links hold that
  /// URL directly, so they open the person's own page; no bibblebob page is involved.
  String? directLink(CardContent card) {
    if (!card.useOwnLink) return null;
    final valid = RegExp(r'^https?://\S+\.\S+', caseSensitive: false);
    return card.ownLinks.where((l) => valid.hasMatch(l.url)).firstOrNull?.url;
  }

  /// The link to write to a tag or share: the direct link when there is one,
  /// otherwise the card packed into a bibblebob link (fitted to [maxBytes]).
  ({String url, List<String> omitted}) tagLink(CardContent card, String cardId, {int? maxBytes}) {
    final direct = directLink(card);
    if (direct != null) return (url: direct, omitted: const <String>[]);
    final enc = encode(card, cardId, maxBytes: maxBytes);
    return (url: '${Config.siteBase}${spec.linkPath}#${enc.payload}', omitted: enc.omitted);
  }

  /// Payload bytes available on an NDEF tag of [ndefMaxSize].
  /// NDEF external type for a card stored on a tag as raw bytes (no web link).
  static const tagRecordType = 'bibblebob.app:card';

  /// Card bytes that fit in one binary bibblebob record on a tag of [ndefMaxSize].
  int binaryCapacity(int ndefMaxSize) {
    final short = ndefMaxSize - 3 - tagRecordType.length; // header, type length, payload length (1 byte)
    if (short <= 255) return short < 0 ? 0 : short;
    return ndefMaxSize - 6 - tagRecordType.length; // long record: 4-byte payload length
  }

  /// Payload bytes available when the card travels inside a web link on a tag of [ndefMaxSize].
  int tagCapacity(int ndefMaxSize) {
    final prefix = Uri.parse(Config.siteBase).host.length + spec.linkPath.length + 1;
    var chars = ndefMaxSize - 4 - 1 - prefix;
    if (1 + prefix + chars > 255) chars = ndefMaxSize - 7 - 1 - prefix;
    return chars < 0 ? 0 : chars * 6 ~/ 8;
  }

  /// Encodes [card]. With [maxBytes], fields that don't fit are skipped
  /// (priority: name, phone, email, business, title, links, description).
  EncodedCard encode(CardContent card, String cardId, {int? maxBytes}) {
    final own = card.useOwnLink;
    final s = card.style;
    final palette = own
        ? -1
        : spec.palettes.indexWhere(
            (p) =>
                p.bg.toUpperCase() == s.bg.toUpperCase() &&
                p.text.toUpperCase() == s.text.toUpperCase() &&
                p.accent.toUpperCase() == s.accent.toUpperCase(),
          );
    final custom = !own && palette < 0;

    final head = <int>[
      (_version << 5) |
          (own ? 16 : 0) |
          (custom ? 8 : 0) |
          (own && card.singleLinkMode == SingleLinkMode.redirect ? 4 : 0),
      ..._hex(cardId),
    ];
    if (!own) {
      final t = spec.templates.indexWhere((x) => x.id == card.templateId);
      final f = spec.fonts.indexWhere((x) => x.id == s.fontId);
      head.add(((t < 0 ? 0 : t) << 4) | (f < 0 ? 0 : f));
      if (custom) {
        head.addAll([..._hex(s.bg), ..._hex(s.text), ..._hex(s.accent)]);
      } else {
        head.add(palette);
      }
    }

    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    final entries = <(String, List<int>)>[];
    List<int> text(int tag, String v) => [tag, ..._encodeText(v)];
    entries.add(('name', text(_tName, card.name.trim())));
    if (!own) {
      if (opt(card.phone) case final p?) entries.add(('phone', [_tPhone, ..._encodePhone(p)]));
      if (opt(card.email) case final e?) entries.add(('email', text(_tEmail, e)));
    }
    if (opt(card.business) case final b?) entries.add(('business', text(_tBusiness, b)));
    if (!own) {
      if (opt(card.title) case final t?) entries.add(('title', text(_tTitle, t)));
    }
    final links = own ? card.ownLinks : card.links;
    for (var i = 0; i < links.length; i++) {
      final l = links[i];
      final label = l.label == _defaultLabel(l.url, own ? null : l.icon) ? '' : l.label;
      final icon = spec.linkIcons.indexWhere((x) => x.id == l.icon);
      entries.add((
        'link ${i + 1}',
        own
            ? [_tOwnLink, ..._encodeText(l.url), ..._encodeText(label)]
            : [_tLink, icon < 0 ? 0 : icon, ..._encodeText(l.url), ..._encodeText(label)],
      ));
    }
    if (!own) {
      if (opt(card.description) case final d?) entries.add(('description', text(_tDescription, d)));
    }

    final bytes = <int>[...head];
    final omitted = <String>[];
    for (final (name, body) in entries) {
      if (maxBytes == null || bytes.length + body.length <= maxBytes) {
        bytes.addAll(body);
      } else {
        omitted.add(name);
      }
    }
    return EncodedCard(
      payload: base64Url.encode(bytes).replaceAll('=', ''),
      raw: Uint8List.fromList(bytes),
      bytes: bytes.length,
      omitted: omitted,
    );
  }

  /// Decodes a payload (the part after '#') into a card, or null if invalid.
  DecodedCard? decode(String payload) {
    try {
      return decodeBytes(base64Url.decode(base64Url.normalize(payload)));
    } catch (_) {
      return null;
    }
  }

  /// Decodes raw card bytes (as stored in a binary tag record), or null if invalid.
  DecodedCard? decodeBytes(Uint8List b) {
    try {
      var i = 0;
      void need(int n) {
        if (i + n > b.length) throw const FormatException('truncated');
      }

      int readVarint() {
        var n = 0, shift = 0, x = 0;
        do {
          need(1);
          x = b[i++];
          n |= (x & 127) << shift;
          shift += 7;
        } while (x & 128 != 0 && shift < 28);
        return n;
      }

      String readText() {
        final len = readVarint();
        need(len);
        final out = StringBuffer();
        final pending = <int>[];
        void flush() {
          if (pending.isNotEmpty) out.write(utf8.decode(pending, allowMalformed: true));
          pending.clear();
        }

        for (final x in b.sublist(i, i + len)) {
          final d = dictCodes.indexOf(x);
          if (d >= 0) {
            flush();
            if (d < spec.linkDictionary.length) out.write(spec.linkDictionary[d]);
          } else {
            pending.add(x);
          }
        }
        flush();
        i += len;
        return out.toString();
      }

      String readPhone() {
        final n = readVarint();
        final len = (n + 1) ~/ 2;
        need(len);
        final out = StringBuffer();
        for (var k = 0; k < n; k++) {
          final byte = b[i + (k >> 1)];
          out.write(_phone[k.isEven ? byte >> 4 : byte & 15]);
        }
        i += len;
        return out.toString();
      }

      need(4);
      final h = b[i++];
      if (h >> 5 != _version) return null;
      final own = h & 16 != 0;
      final id = b.sublist(i, i + 3).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      i += 3;

      var content = CardContent.empty(spec).copyWith(useOwnLink: own);
      if (!own) {
        need(1);
        final tf = b[i++];
        final template = (tf >> 4) < spec.templates.length ? spec.templates[tf >> 4] : spec.templates.first;
        final font = (tf & 15) < spec.fonts.length ? spec.fonts[tf & 15] : spec.fonts.first;
        CardStyle style;
        if (h & 8 != 0) {
          need(9);
          final c = b.sublist(i, i + 9);
          i += 9;
          style = CardStyle(
            bg: _toHex(c.sublist(0, 3)),
            text: _toHex(c.sublist(3, 6)),
            accent: _toHex(c.sublist(6, 9)),
            fontId: font.id,
          );
        } else {
          need(1);
          final idx = b[i++];
          final p = idx < spec.palettes.length ? spec.palettes[idx] : spec.palettes.first;
          style = CardStyle(bg: p.bg, text: p.text, accent: p.accent, fontId: font.id, paletteId: p.id);
        }
        content = content.copyWith(templateId: template.id, style: style);
      } else {
        content = content.copyWith(singleLinkMode: h & 4 != 0 ? SingleLinkMode.redirect : SingleLinkMode.page);
      }

      final l = spec.limits;
      String cap(String v, int n) => v.length > n ? v.substring(0, n) : v;
      final links = <CardLink>[];
      while (i < b.length) {
        final tag = b[i++];
        if (tag == _tName) {
          content = content.copyWith(name: cap(readText(), l.name));
        } else if (tag == _tTitle) {
          content = content.copyWith(title: cap(readText(), l.title));
        } else if (tag == _tBusiness) {
          content = content.copyWith(business: cap(readText(), l.business));
        } else if (tag == _tPhone) {
          content = content.copyWith(phone: cap(readPhone(), l.phone));
        } else if (tag == _tEmail) {
          content = content.copyWith(email: cap(readText(), l.email));
        } else if (tag == _tDescription) {
          content = content.copyWith(description: cap(readText(), l.description));
        } else if (tag == _tLink || tag == _tOwnLink) {
          var icon = 'link';
          if (tag == _tLink) {
            need(1);
            final idx = b[i++];
            icon = idx < spec.linkIcons.length ? spec.linkIcons[idx].id : 'link';
          }
          final url = readText();
          final label = readText();
          final valid = RegExp(r'^https?://\S+\.\S+', caseSensitive: false).hasMatch(url);
          if (!valid || links.length >= l.maxLinks) continue;
          final shown = label.isEmpty ? _defaultLabel(url, own ? null : icon) : label;
          links.add(CardLink(label: cap(shown, l.linkLabel), url: url, icon: icon));
        } else {
          break; // unknown tag: keep what we have
        }
      }
      content = own ? content.copyWith(ownLinks: links) : content.copyWith(links: links);
      if (content.name.isEmpty) return null;
      return DecodedCard(id: id, content: content);
    } catch (_) {
      return null;
    }
  }

  /// Extracts and decodes a card from a full link, or null if it isn't one.
  DecodedCard? decodeLink(Uri uri) {
    if (uri.host != Uri.parse(Config.siteBase).host || uri.path != spec.linkPath || uri.fragment.isEmpty) return null;
    return decode(uri.fragment);
  }

  // ---------------------------------------------------------------- helpers

  String _defaultLabel(String url, String? icon) {
    if (icon != null && icon != 'link' && icon != 'web') {
      final named = spec.linkIcons.where((x) => x.id == icon).firstOrNull;
      if (named != null) return named.label;
    }
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host.replaceFirst(RegExp(r'^www\.'), '');
  }

  List<int> _encodeText(String s) {
    final clean = s.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '');
    final dict = spec.linkDictionary;
    final order = [for (var k = 0; k < dict.length; k++) (dict[k], dictCodes[k])]
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    final bytes = <int>[];
    var i = 0;
    while (i < clean.length) {
      final hit = order.where((d) => clean.startsWith(d.$1, i)).firstOrNull;
      if (hit != null) {
        bytes.add(hit.$2);
        i += hit.$1.length;
      } else {
        final rune = clean.runes.elementAt(_runeIndex(clean, i));
        final ch = String.fromCharCode(rune);
        bytes.addAll(utf8.encode(ch));
        i += ch.length;
      }
    }
    return [..._varint(bytes.length), ...bytes];
  }

  // Index of the rune that starts at UTF-16 offset [offset].
  static int _runeIndex(String s, int offset) {
    var units = 0, idx = 0;
    for (final r in s.runes) {
      if (units >= offset) return idx;
      units += r > 0xFFFF ? 2 : 1;
      idx++;
    }
    return idx;
  }

  static List<int> _encodePhone(String s) {
    final nibbles = [
      for (final c in s.replaceAll('/', '-').split(''))
        if (_phone.contains(c)) _phone.indexOf(c),
    ];
    final bytes = <int>[];
    for (var i = 0; i < nibbles.length; i += 2) {
      bytes.add((nibbles[i] << 4) | (i + 1 < nibbles.length ? nibbles[i + 1] : 0));
    }
    return [..._varint(nibbles.length), ...bytes];
  }

  static List<int> _varint(int n) {
    final out = <int>[];
    do {
      var b = n & 127;
      n >>= 7;
      if (n != 0) b |= 128;
      out.add(b);
    } while (n != 0);
    return out;
  }

  static List<int> _hex(String s) {
    final h = s.replaceFirst('#', '');
    return [for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
  }

  static String _toHex(Uint8List b) => '#${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
}

class EncodedCard {
  const EncodedCard({required this.payload, required this.raw, required this.bytes, required this.omitted});
  final String payload;

  /// The card bytes themselves, for a binary tag record.
  final Uint8List raw;
  final int bytes;

  /// Fields left out to fit the size limit, e.g. ["description", "link 3"].
  final List<String> omitted;
}

class DecodedCard {
  const DecodedCard({required this.id, required this.content});

  /// 6-hex card ID; the same person's card keeps it across edits.
  final String id;
  final CardContent content;
}
