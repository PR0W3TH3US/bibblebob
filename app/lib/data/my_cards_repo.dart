import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../design/design_spec.dart';
import '../models/card_content.dart';
import '../models/my_card.dart';
import '../util/ids.dart';
import 'db.dart';

class MyCardsRepo extends ChangeNotifier {
  MyCardsRepo(this._db, this._spec);
  final AppDatabase _db;
  final DesignSpec _spec;

  static const _columns = ['card_id', 'label', 'is_default', 'content', 'sort_order'];

  List<MyCard> _cards = [];
  List<MyCard> get cards => List.unmodifiable(_cards);

  MyCard? get defaultCard => _cards.where((c) => c.isDefault).firstOrNull ?? _cards.firstOrNull;
  MyCard? byLocalId(int id) => _cards.where((c) => c.localId == id).firstOrNull;
  bool ownsCardId(String cardId) => _cards.any((c) => c.cardId == cardId);

  Future<void> load() async {
    final rows = await _db.db.query('my_cards', orderBy: 'sort_order, local_id');
    _cards = rows.map(_fromRow).toList();
    notifyListeners();
  }

  Future<MyCard> create({required String label, CardContent? content}) async {
    final card = MyCard(
      cardId: newCardId(),
      label: label,
      isDefault: _cards.isEmpty,
      content: content ?? CardContent.empty(_spec),
      sortOrder: _cards.length,
    );
    final id = await _db.db.insert('my_cards', _toRow(card));
    await load();
    return byLocalId(id)!;
  }

  /// A copy gets its own card ID, so receivers see it as a different card.
  Future<MyCard> duplicate(MyCard source) => create(label: '${source.label} copy', content: source.content);

  Future<void> save(MyCard card) async {
    await _db.db.update('my_cards', _toRow(card), where: 'local_id = ?', whereArgs: [card.localId]);
    final i = _cards.indexWhere((c) => c.localId == card.localId);
    if (i >= 0) _cards[i] = card;
    notifyListeners();
  }

  Future<void> setDefault(MyCard card) async {
    await _db.db.transaction((tx) async {
      await tx.update('my_cards', {'is_default': 0});
      await tx.update('my_cards', {'is_default': 1}, where: 'local_id = ?', whereArgs: [card.localId]);
    });
    await load();
  }

  Future<void> delete(MyCard card) async {
    // Use the stored flag: the caller's copy may be stale.
    final wasDefault = byLocalId(card.localId!)?.isDefault ?? card.isDefault;
    await _db.db.delete('my_cards', where: 'local_id = ?', whereArgs: [card.localId]);
    _cards.removeWhere((c) => c.localId == card.localId);
    if (wasDefault && _cards.isNotEmpty) {
      await setDefault(_cards.first);
    } else {
      notifyListeners();
    }
  }

  // ---- backup support

  Future<List<Map<String, Object?>>> exportRows() => _db.db.query('my_cards', orderBy: 'sort_order, local_id');

  Future<void> replaceAll(List<Map<String, Object?>> rows, Transaction tx) async {
    await tx.delete('my_cards');
    for (final r in rows) {
      // Older backups carry extra columns (edit keys etc.); keep only what this version uses.
      final row = {for (final c in _columns) c: r[c]}..['card_id'] ??= newCardId();
      if ((row['card_id'] as String).length != 6) row['card_id'] = newCardId();
      await tx.insert('my_cards', row);
    }
  }

  // ---- mapping

  Map<String, Object?> _toRow(MyCard c) => {
    'card_id': c.cardId,
    'label': c.label,
    'is_default': c.isDefault ? 1 : 0,
    'content': c.content.encode(),
    'sort_order': c.sortOrder,
  };

  MyCard _fromRow(Map<String, Object?> r) => MyCard(
    localId: r['local_id'] as int,
    cardId: r['card_id'] as String,
    label: r['label'] as String,
    isDefault: r['is_default'] == 1,
    content: CardContent.fromJson(jsonDecode(r['content'] as String) as Map<String, dynamic>, _spec),
    sortOrder: r['sort_order'] as int,
  );
}
