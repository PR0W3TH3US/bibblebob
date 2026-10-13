import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../design/design_spec.dart';
import '../models/card_content.dart';
import '../models/contact.dart';
import 'db.dart';
import 'file_store.dart';

class ContactsRepo extends ChangeNotifier {
  ContactsRepo(this._db, this._spec, this._files);
  final AppDatabase _db;
  final DesignSpec _spec;
  final FileStore _files;

  List<Contact> _all = [];
  List<Contact> get all => List.unmodifiable(_all);

  Future<void> load() async {
    final rows = await _db.db.query('contacts', orderBy: 'name COLLATE NOCASE');
    _all = rows.map(_fromRow).toList();
    notifyListeners();
  }

  Contact? byCardId(String cardId) => _all.where((c) => c.cardId == cardId).firstOrNull;

  /// Inserts, or updates the existing contact with the same card ID / row ID.
  Future<Contact> save(Contact contact) async {
    final existing = contact.id != null
        ? _all.where((c) => c.id == contact.id).firstOrNull
        : (contact.cardId != null ? byCardId(contact.cardId!) : null);
    int id;
    if (existing != null) {
      final row = _toRow(contact)..remove('created_at');
      await _db.db.update('contacts', row, where: 'id = ?', whereArgs: [existing.id]);
      id = existing.id!;
      // Drop image files the new version no longer uses.
      for (final old in [existing.content.logoPath, existing.content.facePath, existing.photoPath]) {
        if (old != null &&
            old != contact.content.logoPath &&
            old != contact.content.facePath &&
            old != contact.photoPath) {
          await _files.delete(old);
        }
      }
    } else {
      id = await _db.db.insert('contacts', _toRow(contact));
    }
    await load();
    return _all.firstWhere((c) => c.id == id);
  }

  Future<void> delete(Contact contact) async {
    await _db.db.delete('contacts', where: 'id = ?', whereArgs: [contact.id]);
    for (final f in [contact.content.logoPath, contact.content.facePath, contact.photoPath]) {
      await _files.delete(f);
    }
    await load();
  }

  /// Filters by name and/or business. Every word typed must match one of them.
  static List<Contact> filter(List<Contact> contacts, String query) {
    final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return contacts;
    return contacts.where((c) {
      final hay = '${_fold(c.name)} ${_fold(c.business)}';
      return words.every(hay.contains);
    }).toList();
  }

  /// Lower-case and strip common accents so "zoe" finds "Zoë".
  static String _fold(String s) {
    const from = 'àáâãäåāăąçćčďèéêëēėęěìíîïīįłñńňòóôõöøōőřśšşťùúûüūůűųýÿžźż';
    const to = 'aaaaaaaaacccdeeeeeeeeiiiiiilnnnoooooooorsssstuuuuuuuuyyzzz';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  // ---- backup support

  Future<List<Map<String, Object?>>> exportRows() => _db.db.query('contacts', orderBy: 'id');

  Future<void> replaceAll(List<Map<String, Object?>> rows, Transaction tx) async {
    await tx.delete('contacts');
    for (final r in rows) {
      await tx.insert('contacts', Map.of(r)..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---- mapping

  Map<String, Object?> _toRow(Contact c) => {
    'card_id': c.cardId,
    'source': c.source.name,
    'name': c.content.name,
    'business': c.content.business,
    'content': c.content.encode(),
    'photo_path': c.photoPath,
    'created_at': c.createdAt.millisecondsSinceEpoch,
    'updated_at': c.updatedAt.millisecondsSinceEpoch,
  };

  Contact _fromRow(Map<String, Object?> r) => Contact(
    id: r['id'] as int,
    cardId: r['card_id'] as String?,
    source: ContactSource.values.byName(r['source'] as String),
    content: CardContent.fromJson(jsonDecode(r['content'] as String) as Map<String, dynamic>, _spec),
    photoPath: r['photo_path'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
  );
}
