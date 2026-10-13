import 'card_content.dart';

/// One of my own cards. It lives only on this phone; it reaches other people
/// inside the link written to a tag or shared (shared/LINK_FORMAT.md).
class MyCard {
  const MyCard({
    this.localId,
    required this.cardId,
    required this.label,
    required this.isDefault,
    required this.content,
    this.sortOrder = 0,
  });

  final int? localId;

  /// 6 hex characters, written into every link so receivers can update a
  /// saved contact instead of adding a duplicate.
  final String cardId;
  final String label;
  final bool isDefault;
  final CardContent content;
  final int sortOrder;

  MyCard copyWith({String? label, bool? isDefault, CardContent? content, int? sortOrder}) => MyCard(
    localId: localId,
    cardId: cardId,
    label: label ?? this.label,
    isDefault: isDefault ?? this.isDefault,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
