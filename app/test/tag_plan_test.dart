import 'dart:convert';

import 'package:bibblebob/link/link_codec.dart';
import 'package:bibblebob/link/tag_plan.dart';
import 'package:bibblebob/link/vcard.dart';
import 'package:bibblebob/models/card_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';

import 'helpers.dart';

void main() {
  final spec = loadSpec();
  final codec = LinkCodec(spec);
  final card = CardContent.empty(spec).copyWith(
    name: 'Ada Lovelace',
    phone: '+44 20 7946 0958',
    email: 'ada@example.com',
    business: 'Babbage & Co',
    title: 'Engineer',
    description: 'I write programs for machines that do not exist yet.',
    links: const [CardLink(label: 'Site', url: 'https://ada.dev', icon: 'web')],
  );

  test('vCard has the fields and fits small tags by priority', () {
    final full = VCard.build(card).text;
    expect(full, contains('FN:Ada Lovelace'));
    expect(full, contains('N:Lovelace;Ada;;;'));
    expect(full, contains('TEL;TYPE=CELL:+44 20 7946 0958'));
    expect(full, contains('item1.URL:https://ada.dev'));
    expect(full, endsWith('END:VCARD\r\n'));
    final small = VCard.build(card, maxBytes: 120);
    expect(utf8.encode(small.text).length, lessThanOrEqualTo(120));
    expect(small.text, contains('FN:Ada Lovelace'));
    expect(small.omitted, contains('description'));
  });

  test('web page: one link record with the card inside', () {
    final plan = TagPlan.of(codec, card.copyWith(delivery: CardDelivery.webPage), 'abcdef', maxSize: 496)!;
    expect(plan.records.single.type, [0x55]);
    expect(utf8.decode(plan.records.single.payload.sublist(1)), startsWith('bibblebob.pages.dev/c#'));
  });

  test('contact: vCard first, bibblebob design second, within the tag size', () {
    for (final size in [137, 496]) {
      final plan = TagPlan.of(codec, card.copyWith(delivery: CardDelivery.contact), 'abcdef', maxSize: size)!;
      expect(plan.bytes, lessThanOrEqualTo(size), reason: 'size $size');
      expect(plan.records.first.typeNameFormat, TypeNameFormat.media);
      expect(utf8.decode(plan.records.first.type), 'text/vcard');
      if (plan.records.length > 1) {
        expect(utf8.decode(plan.records[1].type), LinkCodec.tagRecordType);
        expect(codec.decodeBytes(plan.records[1].payload)!.content.name, 'Ada Lovelace');
      }
    }
    final big = TagPlan.of(codec, card.copyWith(delivery: CardDelivery.contact), 'abcdef', maxSize: 868)!;
    expect(big.omitted, isEmpty);
    expect(big.records, hasLength(2));
  });

  test('QR code cards are not written to tags; own links are', () {
    expect(TagPlan.of(codec, card.copyWith(delivery: CardDelivery.qr), 'abcdef'), isNull);
    final own = card.copyWith(
      useOwnLink: true,
      ownLinks: const [CardLink(label: '', url: 'https://linktr.ee/ada')],
    );
    final plan = TagPlan.of(codec, own, 'abcdef', maxSize: 137)!;
    expect(utf8.decode(plan.records.single.payload.sublist(1)), 'linktr.ee/ada');
  });
}
