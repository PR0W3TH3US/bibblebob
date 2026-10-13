import 'dart:async';

import 'package:app_links/app_links.dart';

import '../config.dart';
import '../data/contacts_repo.dart';
import '../link/link_codec.dart';
import '../models/contact.dart';

/// Handles card links opened via App Links (tapping someone's NFC tag).
/// The card is inside the link itself, so receiving works offline.
class Receiver {
  Receiver(this._codec, this._contacts);
  final LinkCodec _codec;
  final ContactsRepo _contacts;

  StreamSubscription<Uri>? _sub;

  /// [onLink] gets every bibblebob link opened while the app runs (including the launch link).
  void listen(void Function(Uri link) onLink) {
    _sub = AppLinks().uriLinkStream.listen((uri) {
      if (uri.host == Uri.parse(Config.siteBase).host) onLink(uri);
    });
  }

  void dispose() => _sub?.cancel();

  /// Decodes the link and saves (or refreshes) the contact. Null if the link is broken.
  Future<Contact?> receive(Uri link) async {
    final card = _codec.decodeLink(link);
    if (card == null) return null;
    final now = DateTime.now();
    final existing = _contacts.byCardId(card.id);
    return _contacts.save(
      Contact(
        id: existing?.id,
        cardId: card.id,
        source: ContactSource.received,
        content: card.content,
        // Keep a photo the user attached to this contact earlier.
        photoPath: existing?.photoPath,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}
