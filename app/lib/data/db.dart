import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database. Contacts and my cards never leave the phone,
/// except my cards inside the links I write to tags or share.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const _myCards = '''
    CREATE TABLE my_cards (
      local_id   INTEGER PRIMARY KEY AUTOINCREMENT,
      card_id    TEXT NOT NULL,
      label      TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      content    TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''';

  static Future<AppDatabase> open({String? path}) async {
    final file = path ?? p.join(await getDatabasesPath(), 'bibblebob.db');
    final db = await openDatabase(
      file,
      version: 2,
      onCreate: (db, _) async {
        await db.execute(_myCards);
        await db.execute('''
          CREATE TABLE contacts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            card_id     TEXT UNIQUE,
            source      TEXT NOT NULL,
            name        TEXT NOT NULL,
            business    TEXT NOT NULL DEFAULT '',
            content     TEXT NOT NULL,
            photo_path  TEXT,
            created_at  INTEGER NOT NULL,
            updated_at  INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX contacts_name ON contacts (name COLLATE NOCASE)');
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) {
          // v1 had server publishing (edit keys, published state). Keep the cards, drop those columns.
          await db.execute('ALTER TABLE my_cards RENAME TO my_cards_v1');
          await db.execute(_myCards);
          await db.execute('''
            INSERT INTO my_cards (local_id, card_id, label, is_default, content, sort_order)
            SELECT local_id, substr(lower(hex(randomblob(3))), 1, 6), label, is_default, content, sort_order
            FROM my_cards_v1''');
          await db.execute('DROP TABLE my_cards_v1');
        }
      },
    );
    return AppDatabase._(db);
  }
}
