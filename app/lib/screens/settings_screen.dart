import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/settings_store.dart';
import '../services/backup.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: c.secondaryText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            section('App theme'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in s.themes.all)
                    _ThemeChip(
                      name: t.name,
                      accent: t.colors.accent,
                      selected: s.settings.themeId == t.id,
                      onTap: () => s.settings.setThemeId(t.id),
                    ),
                ],
              ),
            ),
            section('Intro messages'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Used when you tap a contact’s phone number or email. '
                'You can use {firstName}, {name}, {myName}, {myBusiness} and {myLink} (your default card).',
                style: TextStyle(color: c.secondaryText, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            _TemplateField(
              label: 'Text message',
              value: s.settings.smsTemplate,
              fallback: SettingsStore.defaultSms,
              lines: 3,
              onSave: s.settings.setSmsTemplate,
            ),
            _TemplateField(
              label: 'Email subject',
              value: s.settings.emailSubject,
              fallback: SettingsStore.defaultEmailSubject,
              onSave: s.settings.setEmailSubject,
            ),
            _TemplateField(
              label: 'Email message',
              value: s.settings.emailBody,
              fallback: SettingsStore.defaultEmailBody,
              lines: 6,
              onSave: s.settings.setEmailBody,
            ),
            section('Backup'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'There are no accounts. A backup is one file with all your contacts, your cards and your settings. '
                'Keep it somewhere safe: it contains your contacts’ details.',
                style: TextStyle(color: c.secondaryText, height: 1.4),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.upload_file),
              title: const Text('Export backup'),
              onTap: () => _export(context),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Import backup'),
              subtitle: Text('Replaces everything on this phone', style: TextStyle(color: c.secondaryText)),
              onTap: () => _import(context),
            ),
            section('About'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.lock_outline),
              title: const Text('Works fully offline'),
              subtitle: Text(
                'bibblebob has no internet access. Your cards and contacts stay on this phone; '
                'cards reach others only inside the tags you write and the links you share.',
                style: TextStyle(color: c.secondaryText),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licences'),
              onTap: () => showLicensePage(context: context, applicationName: 'bibblebob'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final saved = await AppScope.of(context).backup.export();
      if (saved && context.mounted) showInfo(context, 'Backup saved.');
    } catch (_) {
      if (context.mounted) showInfo(context, 'Couldn’t save the backup.');
    }
  }

  Future<void> _import(BuildContext context) async {
    final backup = AppScope.of(context).backup;
    try {
      final bytes = await backup.pick();
      if (bytes == null || !context.mounted) return;
      final info = backup.inspect(bytes);
      final ok = await confirm(
        context,
        title: 'Restore this backup?',
        message:
            'It has ${info.cards} card${info.cards == 1 ? '' : 's'} and ${info.contacts} '
            'contact${info.contacts == 1 ? '' : 's'}. Everything currently on this phone will be replaced.',
        action: 'Restore',
        destructive: true,
      );
      if (!ok) return;
      await backup.restore(bytes);
      if (context.mounted) showInfo(context, 'Backup restored.');
    } on BackupException catch (e) {
      if (context.mounted) showInfo(context, e.message);
    } catch (_) {
      if (context.mounted) showInfo(context, 'Couldn’t read that file.');
    }
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.name, required this.accent, required this.selected, required this.onTap});
  final String name;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : c.raised, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateField extends StatefulWidget {
  const _TemplateField({
    required this.label,
    required this.value,
    required this.fallback,
    required this.onSave,
    this.lines = 1,
  });
  final String label;
  final String value;
  final String fallback;
  final int lines;
  final Future<void> Function(String) onSave;

  @override
  State<_TemplateField> createState() => _TemplateFieldState();
}

class _TemplateFieldState extends State<_TemplateField> {
  late final _ctrl = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(covariant _TemplateField old) {
    super.didUpdateWidget(old);
    // e.g. after restoring a backup
    if (!_focus.hasFocus && widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  void _save() {
    if (_ctrl.text != widget.value) widget.onSave(_ctrl.text);
  }

  @override
  void dispose() {
    _save();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: TextField(
      controller: _ctrl,
      focusNode: _focus,
      minLines: widget.lines,
      maxLines: widget.lines + 4,
      decoration: InputDecoration(
        labelText: widget.label,
        alignLabelWithHint: true,
        suffixIcon: _ctrl.text == widget.fallback
            ? null
            : IconButton(
                tooltip: 'Reset to default',
                icon: const Icon(Icons.restart_alt),
                onPressed: () {
                  _ctrl.text = widget.fallback;
                  widget.onSave(widget.fallback);
                },
              ),
      ),
    ),
  );
}
