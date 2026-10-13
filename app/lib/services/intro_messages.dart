import 'package:url_launcher/url_launcher.dart';

import '../link/link_codec.dart';
import '../data/settings_store.dart';
import '../models/contact.dart';
import '../models/my_card.dart';

/// Fills the intro templates from settings and opens the SMS / email app.
/// Placeholders: {name} {firstName} {myName} {myBusiness} {myLink}
class IntroMessages {
  IntroMessages(this._settings, this._codec);
  final SettingsStore _settings;
  final LinkCodec _codec;

  static String fill(String template, {required Contact contact, MyCard? me, LinkCodec? codec}) {
    final values = {
      'name': contact.name,
      'firstName': contact.name.trim().split(RegExp(r'\s+')).first,
      'myName': me?.content.name ?? '',
      'myBusiness': me?.content.business ?? '',
      'myLink': me != null && codec != null ? codec.link(me.content, me.cardId) : '',
    };
    var out = template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m.group(1)] ?? m.group(0)!);
    // Tidy up after empty placeholders.
    out = out
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }

  Future<bool> sms(Contact contact, MyCard? me) {
    final number = contact.content.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final body = fill(_settings.smsTemplate, contact: contact, me: me, codec: _codec);
    return launchUrl(Uri.parse('sms:$number?body=${Uri.encodeComponent(body)}'));
  }

  Future<bool> email(Contact contact, MyCard? me) {
    final subject = fill(_settings.emailSubject, contact: contact, me: me, codec: _codec);
    final body = fill(_settings.emailBody, contact: contact, me: me, codec: _codec);
    return launchUrl(
      Uri.parse(
        'mailto:${Uri.encodeComponent(contact.content.email.trim()).replaceAll('%40', '@')}'
        '?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      ),
    );
  }

  static Future<bool> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
