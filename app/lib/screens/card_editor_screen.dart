import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../card/card_view.dart';
import '../models/card_content.dart';
import '../models/my_card.dart';
import '../link/vcard.dart';
import '../theme/app_theme.dart';
import '../util/links.dart';
import '../widgets/common.dart';
import '../widgets/sticker_fit.dart';
import 'editor/delivery_picker.dart';
import 'editor/inline_style.dart';
import 'editor/link_sheet.dart';
import 'editor/own_link_form.dart';
import 'editor/style_sheets.dart';
import 'my_cards_screen.dart';
import 'qr_screen.dart';
import 'write_tag_sheet.dart';

/// "Your site": edit one card. The card preview is the editor. Changes are saved
/// on the phone as you type; they reach other people when you write a tag or share the link.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.localId});
  final int localId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  static const _fields = ['name', 'title', 'business', 'phone', 'email', 'description'];

  late Services _s;
  late MyCard _card;
  late final Map<String, TextEditingController> _ctrl;
  final _ownLinkForm = GlobalKey<OwnLinkFormState>();
  Timer? _saveTimer;
  bool _preview = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _s = AppScope.of(context);
    _card = _s.cards.byLocalId(widget.localId)!;
    final c = _card.content;
    final initial = {
      'name': c.name,
      'title': c.title,
      'business': c.business,
      'phone': c.phone,
      'email': c.email,
      'description': c.description,
    };
    _ctrl = {for (final f in _fields) f: TextEditingController(text: initial[f])..addListener(_onText)};
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flush();
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  CardContent get _content => _card.content;

  void _onText() {
    final t = _ctrl.map((k, v) => MapEntry(k, v.text));
    if (t['name'] == _content.name &&
        t['title'] == _content.title &&
        t['business'] == _content.business &&
        t['phone'] == _content.phone &&
        t['email'] == _content.email &&
        t['description'] == _content.description) {
      return;
    }
    _update(
      _content.copyWith(
        name: t['name'],
        title: t['title'],
        business: t['business'],
        phone: t['phone'],
        email: t['email'],
        description: t['description'],
      ),
    );
  }

  void _update(CardContent content) {
    setState(() => _card = _card.copyWith(content: content));
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flush);
  }

  /// Saves what the editor owns (content, label) onto the latest stored copy.
  Future<void> _flush() async {
    final latest = _s.cards.byLocalId(_card.localId!);
    if (latest == null) return; // deleted
    await _s.cards.save(latest.copyWith(content: _card.content, label: _card.label));
  }

  // ------------------------------------------------------------------ actions

  void _setDelivery(DeliveryChoice choice) {
    final on = choice == DeliveryChoice.ownLink;
    var content = _content.copyWith(
      useOwnLink: on,
      delivery: switch (choice) {
        DeliveryChoice.contact => CardDelivery.contact,
        DeliveryChoice.qr => CardDelivery.qr,
        DeliveryChoice.webPage => CardDelivery.webPage,
        DeliveryChoice.ownLink => null,
      },
    );
    // First time: start from the template's links. The template design is never touched.
    if (on && content.ownLinks.isEmpty && content.links.isNotEmpty) {
      content = content.copyWith(
        ownLinks: [for (final l in content.links) CardLink(label: l.label, url: l.url)],
      );
    }
    FocusScope.of(context).unfocus();
    _update(content);
  }

  Future<void> _editLink(int? index) async {
    final s = AppScope.of(context);
    final links = [..._content.links];
    if (index == null && links.length >= s.spec.limits.maxLinks) {
      showInfo(context, 'You can add up to ${s.spec.limits.maxLinks} links.');
      return;
    }
    final result = await editLink(
      context,
      spec: s.spec,
      link: index == null ? null : links[index],
      canMoveUp: index != null && index > 0,
      canMoveDown: index != null && index < links.length - 1,
    );
    switch (result) {
      case LinkSaved(:final link):
        if (index == null) {
          links.add(link);
        } else {
          links[index] = link;
        }
      case LinkDeleted():
        links.removeAt(index!);
      case LinkMoved(:final by):
        links.insert(index! + by, links.removeAt(index));
      case null:
        return;
    }
    _update(_content.copyWith(links: links));
  }

  void _reorderLinks(int from, int to) {
    final links = [..._content.links];
    links.insert(to, links.removeAt(from));
    _update(_content.copyWith(links: links));
  }

  String? _validate() {
    final c = _content;
    if (c.useOwnLink) {
      if (!(_ownLinkForm.currentState?.validate() ?? false)) return 'Paste your link first.';
      return null;
    }
    if (c.name.trim().isEmpty) return 'Add your name first.';
    if (c.email.trim().isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(c.email.trim())) {
      return 'That email address doesn’t look right.';
    }
    if (c.phone.trim().isNotEmpty && !RegExp(r'^[0-9+()\-./ ]{3,}$').hasMatch(c.phone.trim())) {
      return 'Phone numbers can only contain digits, spaces and + ( ) - . /';
    }
    for (final l in c.links) {
      if (normaliseUrl(l.url) == null) return 'The link “${l.label}” isn’t valid.';
    }
    return null;
  }

  /// Checks the card, saves it, and returns the stored copy (or null if there is a problem).
  Future<MyCard?> _readyCard() async {
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem != null) {
      showInfo(context, problem);
      return null;
    }
    _saveTimer?.cancel();
    await _flush();
    return _s.cards.byLocalId(_card.localId!);
  }

  Future<void> _writeTag() async {
    final card = await _readyCard();
    if (card != null && mounted) await WriteTagSheet.show(context, initial: card);
  }

  Future<void> _showQr() async {
    final card = await _readyCard();
    if (card == null || !mounted) return;
    final own = _s.codec.directLink(card.content);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScreen(
          title: card.label,
          data: own ?? VCard.build(card.content).text,
          hint: own != null
              ? 'Scan with any phone camera to open your link.'
              : 'Scan with any phone camera, iPhone or Android, to add ${card.content.name} to contacts. Works offline.',
        ),
      ),
    );
  }

  Future<void> _copyLink() async {
    final card = await _readyCard();
    if (card == null) return;
    await Clipboard.setData(ClipboardData(text: _s.codec.link(card.content, card.cardId)));
    if (mounted) showInfo(context, 'Link copied. It opens your card for anyone, no app needed.');
  }

  Future<void> _rename() async {
    final label = await askLabel(context, title: 'Rename card', initial: _card.label);
    if (label != null) setState(() => _card = _card.copyWith(label: label));
    await _flush();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _rename,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your site', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(_card.label, style: TextStyle(color: c.secondaryText, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          if (!_content.useOwnLink)
            IconButton(
              tooltip: _preview ? 'Edit' : 'Preview',
              icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _preview = !_preview);
              },
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              final nav = Navigator.of(context);
              if (v == 'rename') await _rename();
              if (v == 'copy') await _copyLink();
              if (v == 'qr') await _showQr();
              if (v == 'delete' && context.mounted && await deleteCard(context, _card)) {
                _saveTimer?.cancel();
                nav.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'qr', child: Text('Show QR code')),
              const PopupMenuItem(value: 'copy', child: Text('Copy link')),
              const PopupMenuItem(value: 'delete', child: Text('Delete card')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: _content.deliveryChoice == DeliveryChoice.qr
                ? FilledButton.icon(
                    onPressed: _showQr,
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Show QR'),
                  )
                : FilledButton.icon(
                    onPressed: _writeTag,
                    icon: const Icon(Icons.nfc, size: 18),
                    label: const Text('Write to tag'),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: DeliveryPicker(value: _content.deliveryChoice, onChanged: _setDelivery),
          ),
          Expanded(child: _content.useOwnLink ? _ownLinkBody(s) : _templateBody(s)),
        ],
      ),
    );
  }

  Widget _templateBody(Services s) {
    final c = context.colors;
    final logo = s.image(_content.logoPath);
    final face = s.image(_content.facePath);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _label('Template'),
        TemplateStrip(
          spec: s.spec,
          content: _content,
          onSelected: (id) => _update(_content.copyWith(templateId: id)),
        ),
        const SizedBox(height: 14),
        _label('Colours'),
        PaletteStrip(
          spec: s.spec,
          style: _content.style,
          onSelected: (p) => _update(
            _content.copyWith(
              style: _content.style.copyWith(bg: p.bg, text: p.text, accent: p.accent, paletteId: p.id),
            ),
          ),
          onCustom: () => StyleSheets.colours(
            context,
            spec: s.spec,
            current: () => _content.style,
            onChanged: (style) => _update(_content.copyWith(style: style)),
          ),
        ),
        const SizedBox(height: 10),
        _label('Font'),
        FontStrip(
          spec: s.spec,
          fontId: _content.style.fontId,
          onSelected: (id) => _update(_content.copyWith(style: _content.style.copyWith(fontId: id))),
        ),
        const SizedBox(height: 18),
        if (!_preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              'Tap anything on the card to change it.',
              style: TextStyle(color: c.secondaryText, fontSize: 13),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CardView(
                content: _content,
                spec: s.spec,
                logo: logo,
                face: face,
                onLinkTap: (_) {},
                editor: _preview
                    ? null
                    : CardEditor(
                        controllers: _ctrl,
                        focusColor: c.accent,
                        onEditLink: _editLink,
                        onAddLink: () => _editLink(null),
                        onReorderLinks: _reorderLinks,
                      ),
              ),
            ),
          ),
        ),
        if (_preview)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'This is what people see when they tap your tag.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.secondaryText, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        StickerFitNote(fit: StickerFit.of(s.codec, _content, _card.cardId)),
      ],
    );
  }

  Widget _ownLinkBody(Services s) {
    final c = context.colors;
    final links = _content.ownLinks.where((l) => normaliseUrl(l.url) != null).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        OwnLinkForm(
          key: _ownLinkForm,
          links: _content.ownLinks,
          onChanged: (links) => _update(_content.copyWith(ownLinks: links)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(Icons.open_in_new, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  links.isEmpty
                      ? 'Add your link above. Your tag will open it directly.'
                      : 'Tapping your tag opens ${links.first.url} directly, on any phone.',
                  style: TextStyle(color: c.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerFitNote(fit: StickerFit.of(s.codec, _content, _card.cardId)),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      text,
      style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}
