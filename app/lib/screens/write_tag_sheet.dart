import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/my_card.dart';
import '../services/nfc_writer.dart';
import '../theme/app_theme.dart';
import '../link/tag_plan.dart';
import '../widgets/sticker_fit.dart';

enum _Step { choose, waiting, done, failed }

/// Pick a card (default preselected), then hold the phone to a tag.
class WriteTagSheet extends StatefulWidget {
  const WriteTagSheet({super.key, this.initial});
  final MyCard? initial;

  static Future<void> show(BuildContext context, {MyCard? initial}) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => WriteTagSheet(initial: initial),
  );

  @override
  State<WriteTagSheet> createState() => _WriteTagSheetState();
}

class _WriteTagSheetState extends State<WriteTagSheet> {
  int? _selected;
  _Step _step = _Step.choose;
  String _message = '';
  List<String> _omitted = const [];
  int _capacity = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial?.localId;
  }

  late NfcWriter _nfc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nfc = AppScope.of(context).nfc;
  }

  @override
  void dispose() {
    if (_step == _Step.waiting) _nfc.cancel();
    super.dispose();
  }

  MyCard? _card(BuildContext context) {
    final cards = AppScope.of(context).cards;
    return (_selected != null ? cards.byLocalId(_selected!) : null) ?? cards.defaultCard;
  }

  Future<void> _write(MyCard card) async {
    final nfc = _nfc;
    final status = await nfc.status();
    if (!mounted) return;
    if (status != NfcStatus.ready) {
      setState(() {
        _step = _Step.failed;
        _message = status == NfcStatus.disabled
            ? 'NFC is turned off. Turn it on in your phone’s settings, then try again.'
            : 'This phone can’t write NFC tags.';
      });
      return;
    }
    setState(() => _step = _Step.waiting);
    try {
      final codec = AppScope.of(context).codec;
      var omitted = const <String>[];
      final capacity = await nfc.write((maxSize) {
        final plan = TagPlan.of(codec, card.content, card.cardId, maxSize: maxSize)!;
        omitted = plan.omitted;
        return plan.records;
      });
      if (mounted) {
        setState(() {
          _step = _Step.done;
          _omitted = omitted;
          _capacity = capacity;
        });
      }
    } on NfcWriteException catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _message = e.message;
        });
      }
    }
  }

  Future<void> _cancelWaiting() async {
    await _nfc.cancel();
    if (mounted) setState(() => _step = _Step.choose);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    final card = _card(context);
    if (card == null) return const SizedBox(height: 120);

    Widget body;
    switch (_step) {
      case _Step.choose:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Write to tag',
              style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Choose which card the tag opens.', style: TextStyle(color: c.secondaryText)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioGroup<int>(
                    groupValue: card.localId,
                    onChanged: (v) => setState(() => _selected = v),
                    child: Column(
                      children: [
                        for (final x in s.cards.cards)
                          RadioListTile<int>(
                            value: x.localId!,
                            contentPadding: EdgeInsets.zero,
                            title: Text(x.label + (x.isDefault ? '  ·  Default' : '')),
                            subtitle: Text(
                              StickerFit.of(s.codec, x.content, x.cardId).short,
                              style: TextStyle(color: c.secondaryText),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StickerFitNote(fit: StickerFit.of(s.codec, card.content, card.cardId)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _write(card),
              icon: const Icon(Icons.nfc),
              label: const Text('Write to tag'),
            ),
          ],
        );
      case _Step.waiting:
        body = _Status(
          icon: Icons.nfc,
          title: 'Hold your phone to the tag',
          text: 'Keep it still against the back of your phone until it’s done.\nWriting “${card.label}”.',
          action: TextButton(onPressed: _cancelWaiting, child: const Text('Cancel')),
          busy: true,
        );
      case _Step.done:
        body = _Status(
          icon: Icons.check_circle,
          title: _omitted.isEmpty ? 'Done!' : 'Done, with a shorter card',
          text: _omitted.isEmpty
              ? 'The tag now holds your whole card “${card.label}”.\n'
                    'Writing a different card to it later replaces it.'
              : 'This sticker is small ($_capacity bytes), so it leaves out ${describeOmitted(_omitted)}. '
                    'Use an NTAG215 or NTAG216 sticker for the whole card.',
          action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        );
      case _Step.failed:
        body = _Status(
          icon: Icons.error_outline,
          title: 'Couldn’t write the tag',
          text: _message,
          action: FilledButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('Try again')),
        );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: body,
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.title, required this.text, required this.action, this.busy = false});
  final IconData icon;
  final String title;
  final String text;
  final Widget action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (busy)
                SizedBox(width: 88, height: 88, child: CircularProgressIndicator(strokeWidth: 3, color: c.accent)),
              Icon(icon, size: 44, color: c.accent),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(color: c.secondaryText, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        action,
      ],
    );
  }
}
