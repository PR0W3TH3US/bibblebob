import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../card/card_view.dart';
import '../card/own_link_view.dart';
import '../models/my_card.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/sticker_fit.dart';
import 'card_editor_screen.dart';
import 'write_tag_sheet.dart';

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  Future<void> _newCard(BuildContext context) async {
    final s = AppScope.of(context);
    final label = await askLabel(context, title: 'New card', initial: s.cards.cards.isEmpty ? 'Work' : '');
    if (label == null || !context.mounted) return;
    final card = await s.cards.create(label: label);
    if (context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardEditorScreen(localId: card.localId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My cards', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Write to tag',
            icon: const Icon(Icons.nfc),
            onPressed: s.cards.cards.isEmpty ? null : () => WriteTagSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newCard(context),
        icon: const Icon(Icons.add),
        label: const Text('New card', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: s.cards,
        builder: (context, _) {
          final cards = s.cards.cards;
          if (cards.isEmpty) {
            return EmptyState(
              icon: Icons.badge_outlined,
              title: 'Make your first card',
              text: 'Create a card for work, freelance or events, then write it to an NFC tag.',
              action: FilledButton.icon(
                onPressed: () => _newCard(context),
                icon: const Icon(Icons.add),
                label: const Text('New card'),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) => _CardTile(card: cards[i], colors: c),
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.colors});
  final MyCard card;
  final AppColors colors;

  Future<void> _menu(BuildContext context, String action) async {
    final s = AppScope.of(context);
    switch (action) {
      case 'tag':
        await WriteTagSheet.show(context, initial: card);
      case 'rename':
        final label = await askLabel(context, title: 'Rename card', initial: card.label);
        if (label != null) await s.cards.save(card.copyWith(label: label));
      case 'duplicate':
        await s.cards.duplicate(card);
        if (context.mounted) showInfo(context, 'Copied. People who receive it see it as a separate card.');
      case 'default':
        await s.cards.setDefault(card);
      case 'delete':
        await deleteCard(context, card);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = colors;
    final status = StickerFit.of(s.codec, card.content, card.cardId).short;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardEditorScreen(localId: card.localId!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: card.isDefault ? c.accent : c.raised, width: card.isDefault ? 2 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: s.spec.designWidth,
                      child: card.content.useOwnLink
                          ? OwnLinkView(
                              name: card.content.name,
                              business: card.content.business,
                              links: card.content.ownLinks,
                              spec: s.spec,
                            )
                          : CardView(
                              content: card.content.name.trim().isEmpty
                                  ? card.content.copyWith(name: 'Your name')
                                  : card.content,
                              spec: s.spec,
                              logo: s.image(card.content.logoPath),
                              face: s.image(card.content.facePath),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            card.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        if (card.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'Default',
                              style: TextStyle(color: c.onAccent, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(status, style: TextStyle(color: c.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Card options',
                icon: Icon(Icons.more_vert, color: c.secondaryText),
                onSelected: (a) => _menu(context, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'tag', child: Text('Write to tag')),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  if (!card.isDefault) const PopupMenuItem(value: 'default', child: Text('Make default')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> askLabel(BuildContext context, {required String title, String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Work, Freelance, Events', counterText: ''),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: submit, child: const Text('Save')),
        ],
      );
    },
  ).whenComplete(ctrl.dispose);
}

/// Deletes a card from this phone. Tags already written with it keep working:
/// the whole card is stored inside the tag's link.
Future<bool> deleteCard(BuildContext context, MyCard card) async {
  final s = AppScope.of(context);
  final ok = await confirm(
    context,
    title: 'Delete “${card.label}”?',
    message: 'This removes the card from this phone. Tags you already wrote with it keep showing it.',
    action: 'Delete',
    destructive: true,
  );
  if (!ok) return false;
  await s.cards.delete(card);
  return true;
}
