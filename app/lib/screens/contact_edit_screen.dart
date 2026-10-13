import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/card_content.dart';
import '../models/contact.dart';
import '../services/card_scanner.dart';
import '../theme/app_theme.dart';
import '../util/links.dart';
import 'photo_screen.dart';

/// Review a scanned paper card, add someone by hand, or correct a contact.
class ContactEditScreen extends StatefulWidget {
  const ContactEditScreen({super.key, this.contact}) : scan = null;
  const ContactEditScreen.fromScan(ScanResult this.scan, {super.key}) : contact = null;

  final Contact? contact;
  final ScanResult? scan;

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _LinkFields {
  _LinkFields(CardLink l)
    : label = TextEditingController(text: l.label),
      url = TextEditingController(text: l.url),
      icon = l.icon;
  final TextEditingController label;
  final TextEditingController url;
  final String icon;
  void dispose() {
    label.dispose();
    url.dispose();
  }
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _f;
  late final List<_LinkFields> _links;
  String? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact?.content;
    final p = widget.scan?.parsed;
    _f = {
      'name': TextEditingController(text: c?.name ?? p?.name ?? ''),
      'title': TextEditingController(text: c?.title ?? p?.title ?? ''),
      'business': TextEditingController(text: c?.business ?? p?.business ?? ''),
      'phone': TextEditingController(text: c?.phone ?? p?.phone ?? ''),
      'email': TextEditingController(text: c?.email ?? p?.email ?? ''),
      'description': TextEditingController(text: c?.description ?? ''),
    };
    final initialLinks =
        widget.contact?.links ??
        [if (p != null && p.website.isNotEmpty) CardLink(label: 'Website', url: p.website, icon: 'web')];
    _links = initialLinks.map(_LinkFields.new).toList();
    _photo = widget.contact?.photoPath ?? widget.scan?.photoName;
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    super.dispose();
  }

  bool get _isOwnLink => widget.contact?.isOwnLink ?? false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final links = [
      for (final l in _links)
        if (l.url.text.trim().isNotEmpty)
          CardLink(
            label: l.label.text.trim().isEmpty ? hostLabel(normaliseUrl(l.url.text)!) : l.label.text.trim(),
            url: normaliseUrl(l.url.text)!,
            icon: l.icon == 'link' ? s.spec.iconForUrl(l.url.text) : l.icon,
          ),
    ];
    final base = widget.contact?.content ?? CardContent.empty(s.spec);
    final content = base.copyWith(
      name: _f['name']!.text.trim(),
      title: _f['title']!.text.trim(),
      business: _f['business']!.text.trim(),
      phone: _f['phone']!.text.trim(),
      email: _f['email']!.text.trim(),
      description: _f['description']!.text.trim(),
      links: _isOwnLink ? base.links : links,
      ownLinks: _isOwnLink ? links : base.ownLinks,
    );
    final now = DateTime.now();
    final contact =
        widget.contact?.copyWith(content: content, updatedAt: now) ??
        Contact(
          source: widget.scan != null ? ContactSource.scanned : ContactSource.manual,
          content: content,
          photoPath: _photo,
          createdAt: now,
          updatedAt: now,
        );
    await s.contacts.save(contact);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _discardScan() async {
    // A scanned photo that is never saved shouldn't linger.
    if (widget.scan != null) await AppScope.of(context).files.delete(widget.scan!.photoName);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    final l = s.spec.limits;
    final photo = s.image(_photo);

    Widget field(
      String key,
      String label, {
      TextInputType? type,
      int? max,
      int lines = 1,
      String? Function(String?)? validator,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _f[key],
        keyboardType: lines > 1 ? TextInputType.multiline : type,
        textCapitalization: type == null ? TextCapitalization.words : TextCapitalization.none,
        maxLength: max,
        maxLines: lines,
        minLines: 1,
        validator: validator,
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!_saving) await _discardScan();
        nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.contact != null ? 'Edit contact' : (widget.scan != null ? 'Check scanned card' : 'New contact'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (photo != null) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoScreen(image: photo))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image(image: photo, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
                if (widget.scan != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'We filled in what we could read. Check it before saving.',
                      style: TextStyle(color: c.secondaryText, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              field('name', 'Name', max: l.name, validator: (v) => (v ?? '').trim().isEmpty ? 'Add a name' : null),
              if (!_isOwnLink) field('title', 'Title', max: l.title),
              field('business', 'Business', max: l.business),
              if (!_isOwnLink) ...[
                field('phone', 'Phone', type: TextInputType.phone, max: l.phone),
                field(
                  'email',
                  'Email',
                  type: TextInputType.emailAddress,
                  max: l.email,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                        ? null
                        : 'That email doesn’t look right';
                  },
                ),
                field('description', 'Notes / description', max: l.description, lines: 4),
              ],
              const SizedBox(height: 4),
              Text(
                'Links',
                style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _links.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _links[i].label,
                          maxLength: l.linkLabel,
                          decoration: const InputDecoration(labelText: 'Label', counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _links[i].url,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(labelText: 'Link'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty || normaliseUrl(v!) != null ? null : 'Not a valid link',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove link',
                        icon: const Icon(Icons.close),
                        color: c.secondaryText,
                        onPressed: () => setState(() => _links.removeAt(i).dispose()),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _links.add(_LinkFields(const CardLink(label: '', url: '')))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
