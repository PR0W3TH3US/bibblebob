import 'package:flutter/material.dart';

import '../link/link_codec.dart';
import '../link/tag_plan.dart';
import '../models/card_content.dart';
import '../theme/app_theme.dart';

/// How a card fits on common NFC stickers, for its delivery choice.
class StickerFit {
  StickerFit._({required this.kind, required this.bytes, required this.smallOmitted, required this.fitsMedium});

  static const smallTag = 137; // NTAG213
  static const mediumTag = 496; // NTAG215

  final StickerKind kind;

  /// Size of the full tag content in bytes.
  final int bytes;

  /// What an NTAG213 can't hold (empty = everything fits every sticker).
  final List<String> smallOmitted;
  final bool fitsMedium;

  factory StickerFit.of(LinkCodec codec, CardContent content, String cardId) {
    final full = TagPlan.of(codec, content, cardId);
    final kind = codec.directLink(content) != null
        ? StickerKind.ownLink
        : content.useOwnLink
        ? StickerKind.ownLink
        : switch (content.delivery) {
            CardDelivery.webPage => StickerKind.webPage,
            CardDelivery.contact => StickerKind.contact,
            CardDelivery.qr => StickerKind.qr,
          };
    if (full == null) return StickerFit._(kind: kind, bytes: 0, smallOmitted: const [], fitsMedium: true);
    final small = TagPlan.of(codec, content, cardId, maxSize: smallTag)!;
    final medium = TagPlan.of(codec, content, cardId, maxSize: mediumTag)!;
    return StickerFit._(kind: kind, bytes: full.bytes, smallOmitted: small.omitted, fitsMedium: medium.omitted.isEmpty);
  }

  bool get fitsEverySticker => smallOmitted.isEmpty;

  /// Short status for lists, e.g. "Web page · fits every sticker".
  String get short {
    final how = switch (kind) {
      StickerKind.webPage => 'Web page',
      StickerKind.contact => 'Contact',
      StickerKind.qr => 'QR code',
      StickerKind.ownLink => 'Own link',
    };
    if (kind == StickerKind.qr) return how;
    return '$how · ${fitsEverySticker
        ? 'fits every sticker'
        : fitsMedium
        ? 'full card needs NTAG215+'
        : 'full card needs NTAG216'}';
  }

  /// Explains what people get and what small stickers leave out.
  String get detail {
    final what = switch (kind) {
      StickerKind.webPage => 'Tags open your designed card in the browser on any phone, iPhone too (needs internet). Phones with bibblebob open it in the app.',
      StickerKind.contact => 'Android only: phones without bibblebob get “Add to contacts”, offline. Phones with bibblebob see your designed card. iPhones can’t read contact tags.',
      StickerKind.qr => 'Show the QR code from this screen. Any phone camera, iPhone too, offers “Add to contacts”, offline. Nothing is written to a tag.',
      StickerKind.ownLink => 'Tags open your own link directly, on any phone.',
    };
    if (kind == StickerKind.qr || bytes == 0) return what;
    if (fitsEverySticker) return '$what\nFits on every sticker ($bytes bytes).';
    final size = fitsMedium ? 'NTAG215 or NTAG216' : 'NTAG216';
    return '$what\nThe full card ($bytes bytes) needs an $size sticker; '
        'an NTAG213 leaves out ${describeOmitted(smallOmitted)}.';
  }
}

enum StickerKind { webPage, contact, qr, ownLink }

/// ["link 1", "link 2", "description"] -> "2 links and your description"
String describeOmitted(List<String> omitted) {
  final links = omitted.where((o) => o.startsWith('link ')).length;
  final parts = [
    for (final o in omitted)
      if (o == 'design') 'your design (the contact still works)' else if (!o.startsWith('link ')) 'your $o',
    if (links > 0) links == 1 ? '1 link' : '$links links',
  ];
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

class StickerFitNote extends StatelessWidget {
  const StickerFitNote({super.key, required this.fit});
  final StickerFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            fit.fitsEverySticker ? Icons.check_circle_outline : Icons.info_outline,
            color: fit.fitsEverySticker ? c.accent : c.secondaryText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(fit.detail, style: TextStyle(color: c.secondaryText, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
