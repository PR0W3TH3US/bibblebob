import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../card/card_view.dart';
import '../card/own_link_view.dart';
import '../services/intro_messages.dart';
import '../theme/app_theme.dart';
import 'photo_screen.dart';

/// Shows a saved contact's full card (received cards) or the photo of their paper card.
/// Works offline: everything comes from the phone.
class ContactCardScreen extends StatelessWidget {
  const ContactCardScreen({super.key, required this.contactId, this.justReceived = false});
  final int contactId;
  final bool justReceived;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    return ListenableBuilder(
      listenable: s.contacts,
      builder: (context, _) {
        final contact = s.contacts.all.where((x) => x.id == contactId).firstOrNull;
        if (contact == null) return Scaffold(appBar: AppBar());
        final me = s.cards.defaultCard;
        final photo = s.image(contact.photoPath);
        return Scaffold(
          appBar: AppBar(title: Text(contact.name)),
          body: ListView(
            children: [
              if (justReceived)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: c.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Saved to your contacts. You can see it offline from now on.',
                          style: TextStyle(color: c.text),
                        ),
                      ),
                    ],
                  ),
                ),
              if (contact.isOwnLink)
                OwnLinkView(
                  name: contact.name,
                  business: contact.business,
                  links: contact.links,
                  spec: s.spec,
                  onLinkTap: (l) => IntroMessages.openLink(l.url),
                )
              else if (contact.hasDesign)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CardView(
                        content: contact.content,
                        spec: s.spec,
                        logo: s.image(contact.content.logoPath),
                        face: s.image(contact.content.facePath),
                        onLinkTap: (l) => IntroMessages.openLink(l.url),
                        onPhoneTap: () => s.intro.sms(contact, me),
                        onEmailTap: () => s.intro.email(contact, me),
                      ),
                    ),
                  ),
                ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoScreen(image: photo))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image(image: photo, fit: BoxFit.contain),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
