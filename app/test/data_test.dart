import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bibblebob/data/contacts_repo.dart';
import 'package:bibblebob/data/db.dart';
import 'package:bibblebob/data/file_store.dart';
import 'package:bibblebob/data/my_cards_repo.dart';
import 'package:bibblebob/data/settings_store.dart';
import 'package:bibblebob/models/card_content.dart';
import 'package:bibblebob/models/contact.dart';
import 'package:bibblebob/services/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  final spec = loadSpec();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late AppDatabase db;
  late FileStore files;
  late MyCardsRepo cards;
  late ContactsRepo contacts;
  late SettingsStore settings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bibblebob_test');
    db = await AppDatabase.open(path: '${tmp.path}/t.db');
    files = await FileStore.open(root: tmp);
    cards = MyCardsRepo(db, spec);
    contacts = ContactsRepo(db, spec, files);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore(await SharedPreferences.getInstance());
  });

  tearDown(() async {
    await db.db.close();
    await tmp.delete(recursive: true);
  });

  test('cards: first is default, duplicate gets a new card id, default moves on delete', () async {
    final a = await cards.create(
      label: 'Work',
      content: CardContent.empty(spec).copyWith(name: 'A'),
    );
    expect(a.isDefault, isTrue);
    final b = await cards.duplicate(a);
    expect(b.isDefault, isFalse);
    expect(b.cardId, isNot(a.cardId));
    expect(b.content.name, 'A');
    expect(b.label, 'Work copy');

    await cards.setDefault(b);
    expect(cards.defaultCard!.localId, b.localId);
    await cards.delete(b);
    expect(cards.defaultCard!.localId, a.localId);
    expect(cards.defaultCard!.isDefault, isTrue);
  });

  test('receiving the same card twice updates instead of duplicating', () async {
    final now = DateTime.now();
    Contact c(String name) => Contact(
      cardId: 'abcdefghij',
      source: ContactSource.received,
      content: CardContent.empty(spec).copyWith(name: name),
      createdAt: now,
      updatedAt: now,
    );
    await contacts.save(c('First'));
    await contacts.save(c('Second'));
    expect(contacts.all.map((x) => x.name), ['Second']);
  });

  test('backup round trip restores cards, contacts, photos, settings', () async {
    final card = await cards.create(
      label: 'Work',
      content: CardContent.empty(spec).copyWith(name: 'Me'),
    );
    final photo = await files.saveBytes(Uint8List.fromList([9, 9]), prefix: 'scan', ext: 'jpg');
    await contacts.save(
      Contact(
        source: ContactSource.scanned,
        content: CardContent.empty(spec).copyWith(name: 'Paper Person', phone: '123'),
        photoPath: photo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await settings.setSmsTemplate('Yo {firstName}');

    final backup = Backup(db, files, cards, contacts, settings);
    final bytes = await backup.build();
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect((json['myCards'] as List).first['card_id'], card.cardId);

    // Wipe the phone, then restore.
    await cards.delete(cards.cards.first);
    await contacts.delete(contacts.all.first);
    await settings.setSmsTemplate('changed');
    await files.clear();
    expect(backup.inspect(bytes), (cards: 1, contacts: 1));
    await backup.restore(bytes);

    expect(cards.cards.single.cardId, card.cardId);
    expect(cards.cards.single.cardId, card.cardId);
    expect(contacts.all.single.name, 'Paper Person');
    expect(files.fileOrNull(contacts.all.single.photoPath)!.readAsBytesSync(), [9, 9]);
    expect(settings.smsTemplate, 'Yo {firstName}');
  });

  test('backup rejects other files', () {
    final backup = Backup(db, files, cards, contacts, settings);
    expect(() => backup.inspect(Uint8List.fromList(utf8.encode('{"hello":1}'))), throwsA(isA<BackupException>()));
    expect(() => backup.inspect(Uint8List.fromList([0, 1, 2])), throwsA(isA<BackupException>()));
  });

  test('restores v1 backups that still contain edit keys and publish columns', () async {
    final backup = Backup(db, files, cards, contacts, settings);
    final old = {
      'format': 'bibblebob-backup',
      'version': 1,
      'myCards': [
        {
          'local_id': 7,
          'card_id': 'abcdefghij',
          'edit_key': 'x' * 43,
          'label': 'Old',
          'is_default': 1,
          'content': CardContent.empty(spec).copyWith(name: 'Old me').encode(),
          'created_on_server': 1,
          'published_sig': 'sig',
          'sort_order': 0,
        },
      ],
      'contacts': [],
      'files': {},
    };
    await backup.restore(Uint8List.fromList(utf8.encode(jsonEncode(old))));
    expect(cards.cards.single.label, 'Old');
    expect(cards.cards.single.content.name, 'Old me');
    expect(cards.cards.single.cardId, matches(RegExp(r'^[0-9a-f]{6}$')));
  });
}
