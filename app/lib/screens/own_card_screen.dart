import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../card/card_view.dart';
import '../card/own_link_view.dart';
import '../models/card_content.dart';
import '../theme/app_theme.dart';

/// Shown when you scan one of your own tags: exactly what's stored on it,
/// i.e. what other people see (small stickers may hold a shortened card).
class OwnCardScreen extends StatelessWidget {
  const OwnCardScreen({super.key, required this.content, required this.label});
  final CardContent content;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.nfc, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This tag holds your card “$label”. This is what people see when they tap it.',
                    style: TextStyle(color: c.text),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: content.useOwnLink
                  ? OwnLinkView(
                      name: content.name,
                      business: content.business,
                      links: content.ownLinks,
                      spec: s.spec,
                      showSiteButtons: true,
                    )
                  : CardView(content: content, spec: s.spec),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
