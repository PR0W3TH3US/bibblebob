import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

import '../config.dart';
import '../models/card_content.dart';
import '../services/nfc_writer.dart';
import 'link_codec.dart';
import 'vcard.dart';

/// What gets written to a tag for a card, fitted to the tag's NDEF capacity.
class TagPlan {
  TagPlan._(this.records, this.omitted, this.bytes);

  final List<NdefRecord> records;

  /// Fields that didn't fit (e.g. ["description", "link 2"]); "design" means the
  /// bibblebob design record was left out (the contact still works).
  final List<String> omitted;

  /// Total NDEF message size in bytes.
  final int bytes;

  /// Null for QR-code cards, which aren't written to tags.
  static TagPlan? of(LinkCodec codec, CardContent content, String cardId, {int? maxSize}) {
    // Own link: the tag opens the person's website on any phone.
    final direct = codec.directLink(content);
    if (direct != null) return _single(NfcWriter.uriRecord(direct), const []);
    if (content.useOwnLink) return null; // no valid link yet

    switch (content.delivery) {
      case CardDelivery.qr:
        return null;
      case CardDelivery.webPage:
        // The card travels inside the link (after #); the static viewer draws it.
        final enc = codec.encode(content, cardId, maxBytes: maxSize == null ? null : codec.tagCapacity(maxSize));
        return _single(NfcWriter.uriRecord('${Config.siteBase}${codec.spec.linkPath}#${enc.payload}'), enc.omitted);
      case CardDelivery.contact:
        // 1st record: a contact every Android phone can add offline.
        // 2nd record: the bibblebob design, read by the app (if it still fits).
        var vcard = VCard.build(content, maxBytes: maxSize == null ? null : maxSize - _overhead(VCard.mimeType, 0));
        if (maxSize != null && utf8.encode(vcard.text).length > 255) {
          vcard = VCard.build(content, maxBytes: maxSize - _overhead(VCard.mimeType, 256));
        }
        final contact = NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(VCard.mimeType)),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(vcard.text)),
        );
        final records = [contact];
        final omitted = [...vcard.omitted];
        final left = maxSize == null ? null : maxSize - _size(contact);
        final designBudget = left == null ? null : left - _overhead(LinkCodec.tagRecordType, left > 255 + 24 ? 256 : 0);
        if (designBudget == null || designBudget >= 8) {
          final enc = codec.encode(content, cardId, maxBytes: designBudget);
          if (enc.omitted.contains('name')) {
            omitted.add('design');
          } else {
            records.add(NfcWriter.cardRecord(enc.raw));
          }
        } else {
          omitted.add('design');
        }
        return TagPlan._(records, omitted, records.fold(0, (sum, r) => sum + _size(r)));
    }
  }

  static TagPlan _single(NdefRecord r, List<String> omitted) => TagPlan._([r], omitted, _size(r));

  /// Record header: flags + type length + payload length (1 byte, or 4 above 255) + type.
  static int _overhead(String type, int payloadLength) => (payloadLength > 255 ? 6 : 3) + type.length;
  static int _size(NdefRecord r) =>
      (r.payload.length > 255 ? 6 : 3) + r.type.length + r.identifier.length + r.payload.length;
}
