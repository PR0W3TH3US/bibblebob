import 'package:flutter/material.dart';

import '../../models/card_content.dart';
import '../../theme/app_theme.dart';

/// The four ways a card can reach people.
enum DeliveryChoice { webPage, contact, qr, ownLink }

extension CardContentDelivery on CardContent {
  DeliveryChoice get deliveryChoice => useOwnLink
      ? DeliveryChoice.ownLink
      : switch (delivery) {
          CardDelivery.webPage => DeliveryChoice.webPage,
          CardDelivery.contact => DeliveryChoice.contact,
          CardDelivery.qr => DeliveryChoice.qr,
        };
}

/// "How people get your card": web page, contact (vCard), QR code, or own link.
class DeliveryPicker extends StatelessWidget {
  const DeliveryPicker({super.key, required this.value, required this.onChanged});
  final DeliveryChoice value;
  final ValueChanged<DeliveryChoice> onChanged;

  static const _options = [
    (DeliveryChoice.webPage, Icons.public, 'Web page'),
    (DeliveryChoice.contact, Icons.contact_page_outlined, 'Contact'),
    (DeliveryChoice.qr, Icons.qr_code_2, 'QR code'),
    (DeliveryChoice.ownLink, Icons.link, 'Own link'),
  ];

  static String describe(DeliveryChoice v) => switch (v) {
    DeliveryChoice.webPage => 'Tag opens your designed card in the browser on any phone, iPhone too. Needs internet and the bibblebob web page.',
    DeliveryChoice.contact =>
      '⚠ Android only. Tag holds a contact card: others tap “Add to contacts”, fully offline. iPhones can’t read it.',
    DeliveryChoice.qr =>
      'Show a QR code on your screen. Any camera, iPhone too, adds you as a contact, offline. No tag needed.',
    DeliveryChoice.ownLink => 'Tag opens a link you already have (Linktree, your website…), on any phone.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How people get your card',
          style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (choice, icon, label) in _options) ...[
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == choice,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(choice),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: value == choice ? c.accent : c.raised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, color: value == choice ? c.onAccent : c.text, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: value == choice ? c.onAccent : c.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (choice != DeliveryChoice.ownLink) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(describe(value), style: TextStyle(color: c.secondaryText, fontSize: 13, height: 1.35)),
      ],
    );
  }
}
