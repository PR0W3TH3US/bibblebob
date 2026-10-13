import 'dart:convert';

import 'package:flutter/services.dart';

/// The shared card design spec (shared/design.json + shared/icons.json).
/// The website reads the same files, so both render cards the same way.
class DesignSpec {
  DesignSpec._({
    required this.designWidth,
    required this.linkPreviewCount,
    required this.templates,
    required this.palettes,
    required this.fonts,
    required this.linkIcons,
    required this.iconPaths,
    required this.limits,
    required this.defaultTemplateId,
    required this.defaultPaletteId,
    required this.defaultFontId,
    required this.linkPath,
    required this.linkDictionary,
  });

  final double designWidth;
  final int linkPreviewCount;
  final List<TemplateSpec> templates;
  final List<PaletteSpec> palettes;
  final List<FontSpec> fonts;
  final List<LinkIconSpec> linkIcons;
  final Map<String, String> iconPaths;
  final Limits limits;
  final String defaultTemplateId;
  final String defaultPaletteId;
  final String defaultFontId;

  /// Card-in-link format (shared/LINK_FORMAT.md).
  final String linkPath;
  final List<String> linkDictionary;

  TemplateSpec template(String? id) => templates.firstWhere((t) => t.id == id, orElse: () => templates.first);
  FontSpec font(String? id) =>
      fonts.firstWhere((f) => f.id == id, orElse: () => fonts.firstWhere((f) => f.id == defaultFontId));
  PaletteSpec get defaultPalette => palettes.firstWhere((p) => p.id == defaultPaletteId);

  /// Picks an icon from the link's domain (instagram.com -> instagram), else "link".
  String iconForUrl(String url) {
    final host = Uri.tryParse(url.contains('://') ? url : 'https://$url')?.host.toLowerCase() ?? '';
    for (final icon in linkIcons) {
      for (final d in icon.domains) {
        if (host == d || host.endsWith('.$d')) return icon.id;
      }
    }
    return 'link';
  }

  static DesignSpec fromJson(Map<String, dynamic> d, Map<String, dynamic> icons) {
    final defaults = d['defaults'] as Map<String, dynamic>;
    final l = d['limits'] as Map<String, dynamic>;
    final link = d['link'] as Map<String, dynamic>;
    return DesignSpec._(
      designWidth: (d['designWidth'] as num).toDouble(),
      linkPreviewCount: d['linkPreviewCount'] as int,
      templates: [for (final t in d['templates'] as List) TemplateSpec.fromJson(t as Map<String, dynamic>)],
      palettes: [for (final p in d['palettes'] as List) PaletteSpec.fromJson(p as Map<String, dynamic>)],
      fonts: [for (final f in d['fonts'] as List) FontSpec.fromJson(f as Map<String, dynamic>)],
      linkIcons: [for (final i in d['linkIcons'] as List) LinkIconSpec.fromJson(i as Map<String, dynamic>)],
      iconPaths: icons.cast<String, String>(),
      limits: Limits(
        name: l['name'] as int,
        title: l['title'] as int,
        business: l['business'] as int,
        phone: l['phone'] as int,
        email: l['email'] as int,
        description: l['description'] as int,
        linkLabel: l['linkLabel'] as int,
        url: l['url'] as int,
        maxLinks: l['maxLinks'] as int,
      ),
      defaultTemplateId: defaults['templateId'] as String,
      defaultPaletteId: defaults['paletteId'] as String,
      defaultFontId: defaults['fontId'] as String,
      linkPath: link['path'] as String,
      linkDictionary: (link['dictionary'] as List).cast<String>(),
    );
  }

  static Future<DesignSpec> load() async {
    final d = jsonDecode(await rootBundle.loadString('assets/shared/design.json')) as Map<String, dynamic>;
    final i = jsonDecode(await rootBundle.loadString('assets/shared/icons.json')) as Map<String, dynamic>;
    return fromJson(d, i);
  }
}

enum HeaderLayout { center, left, split, banner }

enum FaceShape { circle, rounded, square }

enum LinkStyle { pill, outline, list, grid }

class TemplateSpec {
  const TemplateSpec({
    required this.id,
    required this.name,
    required this.header,
    required this.face,
    required this.links,
    required this.nameSize,
    required this.order,
  });

  final String id;
  final String name;
  final HeaderLayout header;
  final FaceShape face;
  final LinkStyle links;
  final double nameSize;
  final List<String> order;

  bool get centered => header == HeaderLayout.center || header == HeaderLayout.banner;

  factory TemplateSpec.fromJson(Map<String, dynamic> j) => TemplateSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    header: HeaderLayout.values.byName(j['header'] as String),
    face: FaceShape.values.byName(j['face'] as String),
    links: LinkStyle.values.byName(j['links'] as String),
    nameSize: (j['nameSize'] as num).toDouble(),
    order: (j['order'] as List).cast<String>(),
  );
}

class PaletteSpec {
  const PaletteSpec({required this.id, required this.name, required this.bg, required this.text, required this.accent});
  final String id;
  final String name;
  final String bg;
  final String text;
  final String accent;

  factory PaletteSpec.fromJson(Map<String, dynamic> j) => PaletteSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    bg: j['bg'] as String,
    text: j['text'] as String,
    accent: j['accent'] as String,
  );
}

class FontSpec {
  const FontSpec({required this.id, required this.family});
  final String id;
  final String family;

  /// Family name registered in pubspec.yaml.
  String get flutterFamily => 'card-$id';

  factory FontSpec.fromJson(Map<String, dynamic> j) => FontSpec(id: j['id'] as String, family: j['family'] as String);
}

class LinkIconSpec {
  const LinkIconSpec({required this.id, required this.label, required this.domains});
  final String id;
  final String label;
  final List<String> domains;

  factory LinkIconSpec.fromJson(Map<String, dynamic> j) =>
      LinkIconSpec(id: j['id'] as String, label: j['label'] as String, domains: (j['domains'] as List).cast<String>());
}

class Limits {
  const Limits({
    required this.name,
    required this.title,
    required this.business,
    required this.phone,
    required this.email,
    required this.description,
    required this.linkLabel,
    required this.url,
    required this.maxLinks,
  });
  final int name, title, business, phone, email, description, linkLabel, url, maxLinks;
}
