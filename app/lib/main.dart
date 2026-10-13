import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/contacts_repo.dart';
import 'data/db.dart';
import 'data/file_store.dart';
import 'data/my_cards_repo.dart';
import 'data/settings_store.dart';
import 'design/design_spec.dart';
import 'link/link_codec.dart';
import 'screens/home_screen.dart';
import 'screens/own_card_screen.dart';
import 'screens/receive_screen.dart';
import 'services/backup.dart';
import 'services/card_scanner.dart';
import 'services/intro_messages.dart';
import 'services/nfc_writer.dart';
import 'services/receiver.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final spec = await DesignSpec.load();
  final themes = await AppThemes.load();
  final settings = SettingsStore(await SharedPreferences.getInstance());
  final db = await AppDatabase.open();
  final files = await FileStore.open();
  final cards = MyCardsRepo(db, spec);
  final contacts = ContactsRepo(db, spec, files);
  await Future.wait([cards.load(), contacts.load()]);
  final codec = LinkCodec(spec);

  final services = Services(
    spec: spec,
    themes: themes,
    settings: settings,
    files: files,
    cards: cards,
    contacts: contacts,
    codec: codec,
    nfc: NfcWriter(),
    receiver: Receiver(codec, contacts),
    scanner: CardScanner(files),
    intro: IntroMessages(settings, codec),
    backup: Backup(db, files, cards, contacts, settings),
  );

  runApp(BibblebobApp(services: services));
}

class BibblebobApp extends StatefulWidget {
  const BibblebobApp({super.key, required this.services});
  final Services services;

  @override
  State<BibblebobApp> createState() => _BibblebobAppState();
}

class _BibblebobAppState extends State<BibblebobApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  Services get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.settings.addListener(_rebuild);
    s.receiver.listen(_openLink);
  }

  @override
  void dispose() {
    s.settings.removeListener(_rebuild);
    s.receiver.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Someone's tag (or a shared card link) opened the app.
  void _openLink(Uri link) {
    final card = s.codec.decodeLink(link);
    final mine = card == null ? null : s.cards.cards.where((c) => c.cardId == card.id).firstOrNull;
    if (card != null && mine != null) {
      final wrote = s.nfc.lastWrite;
      if (wrote != null && DateTime.now().difference(wrote) < const Duration(seconds: 5)) return;
      _navigator.currentState?.push(
        MaterialPageRoute(
          builder: (_) => OwnCardScreen(content: card.content, label: mine.label),
        ),
      );
      return;
    }
    _navigator.currentState?.push(MaterialPageRoute(builder: (_) => ReceiveScreen(link: link)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = s.themes.byId(s.settings.themeId);
    return AppScope(
      services: s,
      child: MaterialApp(
        title: 'bibblebob',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        theme: buildTheme(theme.colors),
        home: const HomeScreen(),
      ),
    );
  }
}
