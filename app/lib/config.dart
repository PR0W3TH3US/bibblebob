/// Deployment settings. Override at build time, e.g.
/// flutter build apk --dart-define=SITE_BASE=https://bibblebob-1ab.pages.dev
class Config {
  /// Static site that shows cards from links (`/c#<card>`). Its host must match
  /// the App Links host in AndroidManifest.xml and `link.host` in shared/design.json.
  static const siteBase = String.fromEnvironment('SITE_BASE', defaultValue: 'https://bibblebob.pages.dev');
}
