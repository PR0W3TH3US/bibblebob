import 'package:flutter/material.dart';

import '../../models/card_content.dart';
import '../../theme/app_theme.dart';
import '../../util/links.dart';

/// "Use my own link" mode: just the link. The tag holds it directly.
class OwnLinkForm extends StatefulWidget {
  const OwnLinkForm({super.key, required this.links, required this.onChanged});

  final List<CardLink> links;
  final ValueChanged<List<CardLink>> onChanged;

  @override
  State<OwnLinkForm> createState() => OwnLinkFormState();
}

class OwnLinkFormState extends State<OwnLinkForm> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.links.firstOrNull?.url ?? '');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _url.addListener(_emit);
    // Add https:// when the user leaves the field.
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final n = normaliseUrl(_url.text);
        if (n != null && n != _url.text) _url.text = n;
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _emit() {
    final t = _url.text.trim();
    widget.onChanged(t.isEmpty ? const [] : [CardLink(label: '', url: normaliseUrl(t) ?? t)]);
  }

  /// Validates and shows the field error. Used before writing a tag or copying the link.
  bool validate() => _form.currentState?.validate() ?? false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _url,
            focusNode: _focus,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Paste your link', hintText: 'linktr.ee/you'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Paste the link your tag should open';
              return normaliseUrl(t) == null ? 'That isn’t a valid web link' : null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Your tag opens this link directly, on any phone.',
            style: TextStyle(color: c.secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
