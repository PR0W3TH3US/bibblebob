import 'dart:convert';
import 'dart:io';

import 'package:bibblebob/design/design_spec.dart';

/// Loads the real shared design spec from the repo (same file the website uses).
DesignSpec loadSpec() {
  final d = jsonDecode(File('assets/shared/design.json').readAsStringSync()) as Map<String, dynamic>;
  final i = jsonDecode(File('assets/shared/icons.json').readAsStringSync()) as Map<String, dynamic>;
  return DesignSpec.fromJson(d, i);
}
