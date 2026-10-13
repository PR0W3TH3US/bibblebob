import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Images (card logos and faces, received pictures, paper-card photos) live in
/// one folder. The database stores only the file name, so backups restore
/// cleanly on another phone.
class FileStore {
  FileStore._(this.dir);
  final Directory dir;

  static Future<FileStore> open({Directory? root}) async {
    final base = root ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'images'));
    await dir.create(recursive: true);
    return FileStore._(dir);
  }

  File file(String name) => File(p.join(dir.path, p.basename(name)));

  File? fileOrNull(String? name) {
    if (name == null || name.isEmpty) return null;
    final f = file(name);
    return f.existsSync() ? f : null;
  }

  Future<String> saveBytes(Uint8List bytes, {required String prefix, required String ext}) async {
    final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_rand()}.$ext';
    await file(name).writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<String> copyIn(File source, {required String prefix}) async {
    final ext = p.extension(source.path).replaceFirst('.', '').toLowerCase();
    return saveBytes(await source.readAsBytes(), prefix: prefix, ext: ext.isEmpty ? 'jpg' : ext);
  }

  /// Duplicates a stored file (used when duplicating a card).
  Future<String?> duplicate(String? name) async {
    final f = fileOrNull(name);
    if (f == null) return null;
    return copyIn(f, prefix: p.basename(name!).split('_').first);
  }

  Future<void> delete(String? name) async {
    final f = fileOrNull(name);
    if (f != null) await f.delete();
  }

  /// Removes files that nothing references any more.
  Future<void> deleteUnreferenced(Set<String> referenced) async {
    await for (final e in dir.list()) {
      if (e is File && !referenced.contains(p.basename(e.path))) await e.delete();
    }
  }

  Future<void> clear() async {
    await for (final e in dir.list()) {
      if (e is File) await e.delete();
    }
  }

  static String _rand() => Random.secure().nextInt(1 << 32).toRadixString(36);
}
