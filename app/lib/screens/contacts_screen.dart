import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../card/card_icon.dart';
import '../data/contacts_repo.dart';
import '../models/contact.dart';
import '../services/intro_messages.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'contact_card_screen.dart';
import 'contact_edit_screen.dart';

/// Looks like the phone's call app: search on top, a scrolling list of names.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  int? _expandedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final s = AppScope.of(context);
    try {
      final result = await s.scanner.scan();
      if (result == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactEditScreen.fromScan(result)));
    } catch (e) {
      if (mounted) showInfo(context, 'Couldn’t open the camera.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan card', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s.contacts,
          builder: (context, _) {
            final query = _search.text;
            final list = ContactsRepo.filter(s.contacts.all, query);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contacts',
                            style: TextStyle(color: c.text, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add contact by hand',
                          icon: const Icon(Icons.person_add_alt),
                          color: c.text,
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactEditScreen())),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search name or business',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(_search.clear),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: c.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                if (s.contacts.all.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.contacts_outlined,
                      title: 'No contacts yet',
                      text: 'Hold your phone to someone’s bibblebob tag, or scan a paper business card.',
                    ),
                  )
                else if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: Icons.search_off, title: 'No matches', text: 'Nobody matches “$query”.'),
                  )
                else
                  SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final contact = list[i];
                      final letter = _letter(contact);
                      final showHeader = query.isEmpty && (i == 0 || _letter(list[i - 1]) != letter);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                              child: Text(
                                letter,
                                style: TextStyle(color: c.secondaryText, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ContactTile(
                            contact: contact,
                            query: query,
                            expanded: _expandedId == contact.id,
                            onTap: () => setState(() => _expandedId = _expandedId == contact.id ? null : contact.id),
                          ),
                        ],
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _letter(Contact c) {
    final t = c.name.trim();
    if (t.isEmpty) return '#';
    final ch = t.characters.first.toUpperCase();
    return RegExp(r'\p{L}', unicode: true).hasMatch(ch) ? ch : '#';
  }
}

class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    required this.query,
    required this.expanded,
    required this.onTap,
  });
  final Contact contact;
  final String query;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = contact.content;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: expanded ? c.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ContactAvatar(contact: contact),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightText(
                          content.name.isEmpty ? 'No name' : content.name,
                          query: query,
                          style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (content.business.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: HighlightText(
                              content.business,
                              query: query,
                              style: TextStyle(color: c.secondaryText, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: expanded ? _ContactDetails(contact: contact) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    final content = contact.content;
    final me = s.cards.defaultCard;

    Widget action(IconData icon, String text, String hint, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: c.accent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(color: c.text, fontSize: 15)),
                  Text(hint, style: TextStyle(color: c.secondaryText, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final links = contact.links;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!contact.isOwnLink) ...[
            if (content.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(content.title, style: TextStyle(color: c.secondaryText)),
              ),
            if (content.phone.isNotEmpty)
              action(Icons.sms_outlined, content.phone, 'Send intro text', () => s.intro.sms(contact, me)),
            if (content.email.isNotEmpty)
              action(Icons.mail_outline, content.email, 'Send intro email', () => s.intro.email(contact, me)),
            if (content.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Text(content.description, style: TextStyle(color: c.secondaryText, height: 1.45)),
              ),
          ],
          if (links.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final l in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => IntroMessages.openLink(l.url),
                  icon: CardIcon(s.spec.iconPaths, contact.isOwnLink ? 'link' : l.icon, color: c.accent),
                  label: Text(l.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              if (contact.hasDesign || contact.photoPath != null)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => ContactCardScreen(contactId: contact.id!))),
                  icon: Icon(contact.hasDesign ? Icons.badge_outlined : Icons.photo_outlined),
                  label: Text(contact.hasDesign ? 'View card' : 'Card photo'),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit',
                color: c.secondaryText,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactEditScreen(contact: contact))),
              ),
              IconButton(
                tooltip: 'Delete',
                color: c.secondaryText,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Delete ${content.name.isEmpty ? 'contact' : content.name}?',
                    message: 'This removes the contact from this phone.',
                    action: 'Delete',
                    destructive: true,
                  );
                  if (ok) await s.contacts.delete(contact);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
