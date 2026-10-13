import 'package:flutter/widgets.dart';

import 'data/contacts_repo.dart';
import 'data/file_store.dart';
import 'data/my_cards_repo.dart';
import 'data/settings_store.dart';
import 'design/design_spec.dart';
import 'link/link_codec.dart';
import 'services/backup.dart';
import 'services/card_scanner.dart';
import 'services/intro_messages.dart';
import 'services/nfc_writer.dart';
import 'services/receiver.dart';
import 'theme/app_theme.dart';

class Services {
  Services({
    required this.spec,
    required this.themes,
    required this.settings,
    required this.files,
    required this.cards,
    required this.contacts,
    required this.codec,
    required this.nfc,
    required this.receiver,
    required this.scanner,
    required this.intro,
    required this.backup,
  });

  final DesignSpec spec;
  final AppThemes themes;
  final SettingsStore settings;
  final FileStore files;
  final MyCardsRepo cards;
  final ContactsRepo contacts;
  final LinkCodec codec;
  final NfcWriter nfc;
  final Receiver receiver;
  final CardScanner scanner;
  final IntroMessages intro;
  final Backup backup;

  /// FileImage for a stored file name, or null.
  ImageProvider? image(String? name) {
    final f = files.fileOrNull(name);
    return f == null ? null : FileImage(f);
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final Services services;

  static Services of(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
