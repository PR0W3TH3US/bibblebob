import 'card_content.dart';

enum ContactSource { received, scanned, manual }

/// Someone else's card, stored only on this phone.
class Contact {
  const Contact({
    this.id,
    this.cardId,
    required this.source,
    required this.content,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;

  /// Set for cards received from a tag / link; used to update instead of duplicate.
  final String? cardId;
  final ContactSource source;

  /// Name, business, links etc. For received template cards this also holds the
  /// design, so the full card can be shown offline.
  final CardContent content;

  /// Photo of a scanned paper card.
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => content.name;
  String get business => content.business;
  bool get isOwnLink => content.useOwnLink;
  List<CardLink> get links => isOwnLink ? content.ownLinks : content.links;

  /// Received template cards can be shown as the full designed card.
  bool get hasDesign => source == ContactSource.received && !isOwnLink;

  Contact copyWith({int? id, CardContent? content, String? Function()? photoPath, DateTime? updatedAt}) => Contact(
    id: id ?? this.id,
    cardId: cardId,
    source: source,
    content: content ?? this.content,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
