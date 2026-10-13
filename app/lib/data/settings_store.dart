import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small settings kept on the phone: app theme and the intro message templates.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  static const defaultSms = 'Hi {firstName}, it’s {myName}. Great to meet you! {myLink}';
  static const defaultEmailSubject = 'Great to meet you, {firstName}';
  static const defaultEmailBody =
      'Hi {firstName},\n\nIt was great to meet you. Here are my details so we can stay in touch.\n\n{myName}\n{myLink}';

  String get themeId => _prefs.getString('themeId') ?? 'purple';
  String get smsTemplate => _prefs.getString('smsTemplate') ?? defaultSms;
  String get emailSubject => _prefs.getString('emailSubject') ?? defaultEmailSubject;
  String get emailBody => _prefs.getString('emailBody') ?? defaultEmailBody;

  Future<void> setThemeId(String v) => _set('themeId', v);
  Future<void> setSmsTemplate(String v) => _set('smsTemplate', v);
  Future<void> setEmailSubject(String v) => _set('emailSubject', v);
  Future<void> setEmailBody(String v) => _set('emailBody', v);

  Future<void> _set(String k, String v) async {
    await _prefs.setString(k, v);
    notifyListeners();
  }

  Map<String, String> toJson() => {
    'themeId': themeId,
    'smsTemplate': smsTemplate,
    'emailSubject': emailSubject,
    'emailBody': emailBody,
  };

  Future<void> restore(Map<String, dynamic> j) async {
    for (final k in ['themeId', 'smsTemplate', 'emailSubject', 'emailBody']) {
      if (j[k] is String) await _prefs.setString(k, j[k] as String);
    }
    notifyListeners();
  }
}
