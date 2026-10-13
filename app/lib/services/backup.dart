import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/contacts_repo.dart';
import '../data/db.dart';
import '../data/file_store.dart';
import '../data/my_cards_repo.dart';
import '../data/settings_store.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
}

/// One JSON file with all contacts, all my cards, the
/// settings, and every image file. Replaces accounts: keep it somewhere safe.
class Backup {
  Backup(this._db, this._files, this._cards, this._contacts, this._settings);
  final AppDatabase _db;
  final FileStore _files;
  final MyCardsRepo _cards;
  final ContactsRepo _contacts;
  final SettingsStore _settings;

  static const format = 'bibblebob-backup';
  static const version = 2;

  Future<Uint8List> build() async {
    final cards = await _cards.exportRows();
    final contacts = await _contacts.exportRows();
    final files = <String, String>{};
    for (final row in [...cards, ...contacts]) {
      for (final name in _referencedFiles(row)) {
        final f = _files.fileOrNull(name);
        if (f != null) files[name] = base64Encode(await f.readAsBytes());
      }
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': format,
          'version': version,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'settings': _settings.toJson(),
          'myCards': cards,
          'contacts': contacts,
          'files': files,
        }),
      ),
    );
  }

  /// Returns false if the user cancelled the save dialog.
  Future<bool> export() async {
    final bytes = await build();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final uri = await FilePicker.saveFile(
      fileName: 'bibblebob-backup-$stamp.json',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save backup',
    );
    return uri != null;
  }

  /// Lets the user pick a backup file. Returns its bytes, or null if cancelled.
  Future<Uint8List?> pick() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Choose a bibblebob backup');
    if (files.isEmpty) return null;
    return files.first.xFile.readAsBytes();
  }

  /// Checks a backup and returns a short summary, without changing anything.
  ({int cards, int contacts}) inspect(Uint8List bytes) {
    final j = _decode(bytes);
    return (cards: (j['myCards'] as List).length, contacts: (j['contacts'] as List).length);
  }

  /// Replaces everything on this phone with the backup's contents.
  Future<void> restore(Uint8List bytes) async {
    final j = _decode(bytes);
    final cards = (j['myCards'] as List).cast<Map<String, dynamic>>();
    final contacts = (j['contacts'] as List).cast<Map<String, dynamic>>();
    final files = (j['files'] as Map? ?? const {}).cast<String, String>();

    // Write image files first, then swap the database contents in one transaction.
    for (final e in files.entries) {
      await _files.file(e.key).writeAsBytes(base64Decode(e.value), flush: true);
    }
    await _db.db.transaction((tx) async {
      await _cards.replaceAll(cards, tx);
      await _contacts.replaceAll(contacts, tx);
    });
    await _files.deleteUnreferenced({
      for (final r in [...cards, ...contacts]) ..._referencedFiles(r),
    });
    if (j['settings'] is Map) await _settings.restore((j['settings'] as Map).cast<String, dynamic>());
    await _cards.load();
    await _contacts.load();
  }

  Map<String, dynamic> _decode(Uint8List bytes) {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('That file isn’t a bibblebob backup.');
    }
    if (j['format'] != format || j['myCards'] is! List || j['contacts'] is! List) {
      throw const BackupException('That file isn’t a bibblebob backup.');
    }
    if ((j['version'] as num? ?? 0) > version) {
      throw const BackupException('This backup was made by a newer version of bibblebob. Update the app first.');
    }
    return j;
  }

  static Iterable<String> _referencedFiles(Map<String, Object?> row) sync* {
    final content = row['content'];
    if (content is String) {
      final c = jsonDecode(content) as Map<String, dynamic>;
      for (final k in ['logoPath', 'facePath']) {
        if (c[k] is String) yield c[k] as String;
      }
    }
    for (final k in ['photo_path']) {
      if (row[k] is String) yield row[k] as String;
    }
  }
}
