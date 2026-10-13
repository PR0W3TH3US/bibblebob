import 'dart:convert';
import 'dart:typed_data';

import 'package:bibblebob/data/contacts_repo.dart';
import 'package:bibblebob/link/link_codec.dart';
import 'package:bibblebob/models/card_content.dart';
import 'package:bibblebob/models/contact.dart';
import 'package:bibblebob/models/my_card.dart';
import 'package:bibblebob/services/intro_messages.dart';
import 'package:bibblebob/services/nfc_writer.dart';
import 'package:bibblebob/util/colors.dart';
import 'package:bibblebob/util/ids.dart';
import 'package:bibblebob/util/links.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final spec = loadSpec();

  group('CardContent public JSON', () {
    test('leaves out empty optional fields', () {
      final c = CardContent.empty(spec).copyWith(name: ' Ada ', phone: '  ', email: 'ada@example.com');
      final j = c.toPublicJson();
      expect(j['type'], 'template');
      expect(j['name'], 'Ada');
      expect(j.containsKey('phone'), isFalse);
      expect(j.containsKey('title'), isFalse);
      expect(j.containsKey('logo'), isFalse);
      expect(j['email'], 'ada@example.com');
      expect(j['style'], containsPair('fontId', 'inter'));
    });

    test('own-link card publishes only name, business, links, mode', () {
      final c = CardContent.empty(spec).copyWith(
        useOwnLink: true,
        name: 'Grace',
        phone: '123', // template data is kept but not published
        ownLinks: const [CardLink(label: 'Linktree', url: 'https://linktr.ee/grace')],
        singleLinkMode: SingleLinkMode.redirect,
      );
      expect(c.toPublicJson(), {
        'type': 'links',
        'name': 'Grace',
        'links': [
          {'label': 'Linktree', 'url': 'https://linktr.ee/grace'},
        ],
        'singleLinkMode': 'redirect',
      });
    });

    test('switching mode keeps the template design', () {
      final c = CardContent.empty(spec).copyWith(name: 'A', title: 'CEO', templateId: 'bold');
      final back = c.copyWith(useOwnLink: true).copyWith(useOwnLink: false);
      expect(back.title, 'CEO');
      expect(back.templateId, 'bold');
    });

    test('local JSON round trip', () {
      final c = CardContent.empty(spec).copyWith(
        name: 'Ada',
        links: const [CardLink(label: 'GH', url: 'https://github.com/ada', icon: 'github')],
        logoPath: () => 'logo_1.png',
      );
      final back = CardContent.fromJson(jsonDecode(c.encode()) as Map<String, dynamic>, spec);
      expect(back.encode(), c.encode());
    });
  });

  test('card ids are 6 hex characters', () {
    for (var i = 0; i < 50; i++) {
      expect(newCardId(), matches(RegExp(r'^[0-9a-f]{6}$')));
    }
  });

  test('normaliseUrl adds https and rejects other schemes', () {
    expect(normaliseUrl('example.com'), 'https://example.com');
    expect(normaliseUrl(' https://x.io/a?b=1 '), 'https://x.io/a?b=1');
    expect(normaliseUrl('http://x.io'), 'http://x.io');
    expect(normaliseUrl('javascript:alert(1)'), isNull);
    expect(normaliseUrl('ftp://x.io'), isNull);
    expect(normaliseUrl('localhost'), isNull);
    expect(normaliseUrl(''), isNull);
    expect(hostLabel('https://www.example.com/x'), 'example.com');
  });

  test('icon from domain', () {
    expect(spec.iconForUrl('instagram.com/me'), 'instagram');
    expect(spec.iconForUrl('https://www.linkedin.com/in/me'), 'linkedin');
    expect(spec.iconForUrl('https://youtu.be/x'), 'youtube');
    expect(spec.iconForUrl('https://example.com'), 'link');
  });

  test('card tag record is an external bibblebob record holding raw bytes', () {
    final r = NfcWriter.cardRecord(Uint8List.fromList([0x20, 1, 2, 3]));
    expect(utf8.decode(r.type), 'bibblebob.app:card');
    expect(r.payload, [0x20, 1, 2, 3]);
  });

  test('NDEF URI record uses https:// prefix code', () {
    final r = NfcWriter.uriRecord('https://bibblebob.pages.dev/c#IAECAwEC');
    expect(r.type, [0x55]);
    expect(r.payload.first, 0x04);
    expect(utf8.decode(r.payload.sublist(1)), 'bibblebob.pages.dev/c#IAECAwEC');
  });

  group('intro messages', () {
    final contact = Contact(
      source: ContactSource.received,
      content: CardContent.empty(spec).copyWith(name: 'Jane Doe'),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    test('fills placeholders', () {
      final me = MyCard(
        cardId: 'abcdef',
        label: 'Work',
        isDefault: true,
        content: CardContent.empty(spec).copyWith(name: 'Ada'),
      );
      final codec = LinkCodec(spec);
      final text = IntroMessages.fill(
        'Hi {firstName}, it’s {myName}. {myLink}',
        contact: contact,
        me: me,
        codec: codec,
      );
      expect(text, startsWith('Hi Jane, it’s Ada. https://bibblebob.pages.dev/c#'));
      final link = Uri.parse(text.split(' ').last);
      expect(codec.decodeLink(link)!.content.name, 'Ada');
    });
    test('no card of my own leaves no stray spaces', () {
      expect(
        IntroMessages.fill('Hi {firstName}, it’s {myName}. Great to meet you! {myLink}', contact: contact, me: null),
        'Hi Jane, it’s . Great to meet you!',
      );
    });
  });

  test('contact search matches name and/or business, ignoring accents', () {
    Contact c(String name, String business) => Contact(
      source: ContactSource.manual,
      content: CardContent.empty(spec).copyWith(name: name, business: business),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final all = [c('Zoë Smith', 'Acme'), c('John Brown', 'Globex'), c('Ann Acme', 'Initech')];
    expect(ContactsRepo.filter(all, 'zoe').map((x) => x.name), ['Zoë Smith']);
    expect(ContactsRepo.filter(all, 'acme').length, 2);
    expect(ContactsRepo.filter(all, 'john globex').map((x) => x.name), ['John Brown']);
    expect(ContactsRepo.filter(all, 'john acme'), isEmpty);
    expect(ContactsRepo.filter(all, '  ').length, 3);
  });

  test('contrast helpers match the website', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21, 0.01));
    expect(onColor(hexToColor('#6D28D9')), const Color(0xFFFFFFFF));
    expect(onColor(hexToColor('#4FC3F7')), const Color(0xFF000000));
    expect(colorToHex(hexToColor('#C2410C')), '#C2410C');
  });
}
