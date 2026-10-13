import 'dart:math';

final _rng = Random.secure();

/// 3 random bytes as 6 hex characters. Goes into the card's link (shared/LINK_FORMAT.md).
String newCardId() => List.generate(3, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
