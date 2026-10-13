import 'package:flutter/material.dart';

import '../../card/card_icon.dart';
import '../../design/design_spec.dart';
import '../../models/card_content.dart';
import '../../theme/app_theme.dart';
import '../../util/links.dart';

sealed class LinkSheetResult {}

class LinkSaved extends LinkSheetResult {
  LinkSaved(this.link);
  final CardLink link;
}

class LinkDeleted extends LinkSheetResult {}

class LinkMoved extends LinkSheetResult {
  LinkMoved(this.by);
  final int by;
}

/// Edit one link on a template card: label, URL and icon.
Future<LinkSheetResult?> editLink(
  BuildContext context, {
  required DesignSpec spec,
  CardLink? link,
  bool canMoveUp = false,
  bool canMoveDown = false,
}) => showModalBottomSheet<LinkSheetResult>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _LinkSheet(spec: spec, link: link, canMoveUp: canMoveUp, canMoveDown: canMoveDown),
);

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.spec, required this.link, required this.canMoveUp, required this.canMoveDown});
  final DesignSpec spec;
  final CardLink? link;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _label = TextEditingController(text: widget.link?.label ?? '');
  late final _url = TextEditingController(text: widget.link?.url ?? '');
  late String _icon = widget.link?.icon ?? 'link';
  late bool _iconChosen = widget.link != null && widget.link!.icon != 'link';
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final url = normaliseUrl(_url.text);
    if (url == null) {
      setState(() => _error = 'Enter a web link, like example.com');
      return;
    }
    final label = _label.text.trim().isEmpty
        ? (widget.spec.linkIcons.where((i) => i.id == _icon && i.id != 'link').firstOrNull?.label ?? hostLabel(url))
        : _label.text.trim();
    Navigator.pop(context, LinkSaved(CardLink(label: label, url: url, icon: _icon)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spec = widget.spec;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.link == null ? 'Add link' : 'Edit link',
                style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _url,
                autofocus: widget.link == null,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: 'Link', hintText: 'instagram.com/you', errorText: _error),
                onChanged: (v) => setState(() {
                  _error = null;
                  if (!_iconChosen) _icon = spec.iconForUrl(v);
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                maxLength: spec.limits.linkLabel,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'What people see on the button',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: TextStyle(color: c.secondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in spec.linkIcons)
                    Tooltip(
                      message: i.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _icon = i.id;
                          _iconChosen = true;
                        }),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _icon == i.id ? c.accent : c.raised,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CardIcon(spec.iconPaths, i.id, color: _icon == i.id ? c.onAccent : c.text, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.link != null) ...[
                    IconButton(
                      tooltip: 'Delete link',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => Navigator.pop(context, LinkDeleted()),
                    ),
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: widget.canMoveUp ? () => Navigator.pop(context, LinkMoved(-1)) : null,
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: widget.canMoveDown ? () => Navigator.pop(context, LinkMoved(1)) : null,
                    ),
                  ],
                  const Spacer(),
                  FilledButton(onPressed: _save, child: const Text('Done')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
