import 'package:bibblebob/card/card_view.dart';
import 'package:bibblebob/card/own_link_view.dart';
import 'package:bibblebob/models/card_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final spec = loadSpec();
  final full = CardContent.empty(spec).copyWith(
    name: 'Ada Lovelace',
    title: 'Analytical Engineer',
    business: 'Babbage & Co',
    phone: '+44 20 7946 0958',
    email: 'ada@example.com',
    description: 'I write programs for machines that do not exist yet.',
    links: [
      for (final (l, i) in [
        ('Website', 'web'),
        ('LinkedIn', 'linkedin'),
        ('GitHub', 'github'),
        ('Instagram', 'instagram'),
        ('Shop', 'shop'),
        ('Book', 'calendar'),
      ])
        CardLink(label: l, url: 'https://example.com/$l', icon: i),
    ],
  );

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
    ),
  );

  CardEditor editor() => CardEditor(
    controllers: {
      for (final k in ['name', 'title', 'business', 'phone', 'email', 'description']) k: TextEditingController(),
    },
    focusColor: Colors.purple,
    onEditLink: (_) {},
    onAddLink: () {},
    onReorderLinks: (_, _) {},
  );

  for (final tpl in spec.templates) {
    group('template ${tpl.id}', () {
      testWidgets('renders a full card with a More button', (tester) async {
        await tester.pumpWidget(
          host(
            CardView(
              content: full.copyWith(templateId: tpl.id),
              spec: spec,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(find.text('Babbage & Co'), findsOneWidget);
        expect(find.text('Website'), findsOneWidget);
        expect(find.text('Shop'), findsNothing); // 5th link is behind More
        await tester.ensureVisible(find.text('More (2)'));
        await tester.tap(find.text('More (2)'));
        await tester.pump();
        expect(find.text('Shop'), findsOneWidget);
      });

      testWidgets('leaves out empty optional slots', (tester) async {
        await tester.pumpWidget(
          host(
            CardView(
              content: CardContent.empty(spec).copyWith(name: 'Bo', templateId: tpl.id),
              spec: spec,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Bo'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('edit mode shows placeholders for empty slots', (tester) async {
        await tester.pumpWidget(
          host(
            CardView(
              content: CardContent.empty(spec).copyWith(templateId: tpl.id),
              spec: spec,
              editor: editor(),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final p in ['Your name', 'Add title', 'Add business', 'Add phone', 'Add email', 'Add link']) {
          expect(find.text(p), findsOneWidget, reason: p);
        }
      });
    });
  }

  testWidgets('own-link view: one button per link, single link says Open profile', (tester) async {
    await tester.pumpWidget(
      host(
        OwnLinkView(
          name: 'Grace',
          business: '',
          spec: spec,
          links: const [
            CardLink(label: 'A', url: 'https://a.io'),
            CardLink(label: 'B', url: 'https://b.io'),
          ],
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await tester.pumpWidget(
      host(
        OwnLinkView(
          name: 'Grace',
          business: '',
          spec: spec,
          links: const [CardLink(label: 'A', url: 'https://a.io')],
        ),
      ),
    );
    expect(find.text('Open profile'), findsOneWidget);
  });
}
