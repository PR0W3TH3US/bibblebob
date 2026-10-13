import 'dart:convert';

import '../design/design_spec.dart';

class CardLink {
  const CardLink({required this.label, required this.url, this.icon = 'link'});
  final String label;
  final String url;
  final String icon;

  CardLink copyWith({String? label, String? url, String? icon}) =>
      CardLink(label: label ?? this.label, url: url ?? this.url, icon: icon ?? this.icon);

  Map<String, dynamic> toJson({bool withIcon = true}) => {'label': label, 'url': url, if (withIcon) 'icon': icon};

  factory CardLink.fromJson(Map<String, dynamic> j) => CardLink(
    label: (j['label'] ?? '') as String,
    url: (j['url'] ?? '') as String,
    icon: (j['icon'] ?? 'link') as String,
  );
}

class CardStyle {
  const CardStyle({required this.bg, required this.text, required this.accent, required this.fontId, this.paletteId});
  final String bg;
  final String text;
  final String accent;
  final String fontId;

  /// The preset these colours came from, or null for custom colours. Local only.
  final String? paletteId;

  CardStyle copyWith({
    String? bg,
    String? text,
    String? accent,
    String? fontId,
    String? paletteId,
    bool custom = false,
  }) => CardStyle(
    bg: bg ?? this.bg,
    text: text ?? this.text,
    accent: accent ?? this.accent,
    fontId: fontId ?? this.fontId,
    paletteId: custom ? null : (paletteId ?? this.paletteId),
  );

  Map<String, dynamic> toPublicJson() => {'bg': bg, 'text': text, 'accent': accent, 'fontId': fontId};
  Map<String, dynamic> toJson() => {...toPublicJson(), if (paletteId != null) 'paletteId': paletteId};

  factory CardStyle.fromJson(Map<String, dynamic> j, DesignSpec spec) {
    final p = spec.defaultPalette;
    return CardStyle(
      bg: (j['bg'] ?? p.bg) as String,
      text: (j['text'] ?? p.text) as String,
      accent: (j['accent'] ?? p.accent) as String,
      fontId: (j['fontId'] ?? spec.defaultFontId) as String,
      paletteId: j['paletteId'] as String?,
    );
  }

  factory CardStyle.defaults(DesignSpec spec) {
    final p = spec.defaultPalette;
    return CardStyle(bg: p.bg, text: p.text, accent: p.accent, fontId: spec.defaultFontId, paletteId: p.id);
  }
}

enum SingleLinkMode { page, redirect }

/// How a built-in (template) card reaches people. "Use my own link" is separate (useOwnLink).
enum CardDelivery {
  /// Tag holds a web link with the card inside (after #); the static viewer draws it.
  webPage,

  /// Tag holds a contact card (vCard), plus the bibblebob design for the app. Android only.
  contact,

  /// No tag: the screen shows a QR code with the contact card.
  qr,
}

/// Everything on a card. Used for my own drafts and for cards received from others.
/// Both the template design and the own-link list are kept, so flipping the
/// "Use my own link" toggle never loses anything.
class CardContent {
  const CardContent({
    this.useOwnLink = false,
    this.delivery = CardDelivery.webPage,
    this.name = '',
    this.title = '',
    this.business = '',
    this.phone = '',
    this.email = '',
    this.description = '',
    this.links = const [],
    required this.templateId,
    required this.style,
    this.logoPath,
    this.facePath,
    this.ownLinks = const [],
    this.singleLinkMode = SingleLinkMode.page,
  });

  final bool useOwnLink;
  final CardDelivery delivery;
  final String name;
  final String title;
  final String business;
  final String phone;
  final String email;
  final String description;
  final List<CardLink> links;
  final String templateId;
  final CardStyle style;

  /// Local image files (my cards: picked images; contacts: downloaded copies).
  final String? logoPath;
  final String? facePath;

  final List<CardLink> ownLinks;
  final SingleLinkMode singleLinkMode;

  factory CardContent.empty(DesignSpec spec) =>
      CardContent(templateId: spec.defaultTemplateId, style: CardStyle.defaults(spec));

  CardContent copyWith({
    bool? useOwnLink,
    CardDelivery? delivery,
    String? name,
    String? title,
    String? business,
    String? phone,
    String? email,
    String? description,
    List<CardLink>? links,
    String? templateId,
    CardStyle? style,
    String? Function()? logoPath,
    String? Function()? facePath,
    List<CardLink>? ownLinks,
    SingleLinkMode? singleLinkMode,
  }) => CardContent(
    useOwnLink: useOwnLink ?? this.useOwnLink,
    delivery: delivery ?? this.delivery,
    name: name ?? this.name,
    title: title ?? this.title,
    business: business ?? this.business,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    description: description ?? this.description,
    links: links ?? this.links,
    templateId: templateId ?? this.templateId,
    style: style ?? this.style,
    logoPath: logoPath != null ? logoPath() : this.logoPath,
    facePath: facePath != null ? facePath() : this.facePath,
    ownLinks: ownLinks ?? this.ownLinks,
    singleLinkMode: singleLinkMode ?? this.singleLinkMode,
  );

  /// The data the receiver sees, in the API's format. Empty optional fields are left out.
  Map<String, dynamic> toPublicJson({String? logoUrl, String? faceUrl}) {
    String? opt(String s) => s.trim().isEmpty ? null : s.trim();
    if (useOwnLink) {
      return {
        'type': 'links',
        'name': name.trim(),
        if (opt(business) != null) 'business': opt(business),
        'links': [for (final l in ownLinks) l.toJson(withIcon: false)],
        'singleLinkMode': singleLinkMode.name,
      };
    }
    return {
      'type': 'template',
      'name': name.trim(),
      if (opt(title) != null) 'title': opt(title),
      if (opt(business) != null) 'business': opt(business),
      if (opt(phone) != null) 'phone': opt(phone),
      if (opt(email) != null) 'email': opt(email),
      if (opt(description) != null) 'description': opt(description),
      'logo': ?logoUrl,
      'face': ?faceUrl,
      'links': [for (final l in links) l.toJson()],
      'templateId': templateId,
      'style': style.toPublicJson(),
    };
  }

  /// Parses a card as returned by GET /cards/:id. Image URLs are not kept here;
  /// the caller downloads them and fills in logoPath / facePath.
  factory CardContent.fromPublicJson(Map<String, dynamic> j, DesignSpec spec) {
    final links = [for (final l in (j['links'] as List? ?? const [])) CardLink.fromJson(l as Map<String, dynamic>)];
    final isLinks = j['type'] == 'links';
    return CardContent(
      useOwnLink: isLinks,
      name: (j['name'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      business: (j['business'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      links: isLinks ? const [] : links,
      ownLinks: isLinks ? links : const [],
      singleLinkMode: j['singleLinkMode'] == 'redirect' ? SingleLinkMode.redirect : SingleLinkMode.page,
      templateId: spec.template(j['templateId'] as String?).id,
      style: j['style'] is Map
          ? CardStyle.fromJson(j['style'] as Map<String, dynamic>, spec)
          : CardStyle.defaults(spec),
    );
  }

  /// Local storage format (drafts and backups).
  Map<String, dynamic> toJson() => {
    'useOwnLink': useOwnLink,
    'delivery': delivery.name,
    'name': name,
    'title': title,
    'business': business,
    'phone': phone,
    'email': email,
    'description': description,
    'links': [for (final l in links) l.toJson()],
    'templateId': templateId,
    'style': style.toJson(),
    'logoPath': logoPath,
    'facePath': facePath,
    'ownLinks': [for (final l in ownLinks) l.toJson(withIcon: false)],
    'singleLinkMode': singleLinkMode.name,
  };

  factory CardContent.fromJson(Map<String, dynamic> j, DesignSpec spec) => CardContent(
    useOwnLink: (j['useOwnLink'] ?? false) as bool,
    delivery: CardDelivery.values.where((d) => d.name == j['delivery']).firstOrNull ?? CardDelivery.webPage,
    name: (j['name'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    business: (j['business'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    description: (j['description'] ?? '') as String,
    links: [for (final l in (j['links'] as List? ?? const [])) CardLink.fromJson(l as Map<String, dynamic>)],
    templateId: spec.template(j['templateId'] as String?).id,
    style: CardStyle.fromJson((j['style'] ?? const {}) as Map<String, dynamic>, spec),
    logoPath: j['logoPath'] as String?,
    facePath: j['facePath'] as String?,
    ownLinks: [for (final l in (j['ownLinks'] as List? ?? const [])) CardLink.fromJson(l as Map<String, dynamic>)],
    singleLinkMode: j['singleLinkMode'] == 'redirect' ? SingleLinkMode.redirect : SingleLinkMode.page,
  );

  String encode() => jsonEncode(toJson());
}
