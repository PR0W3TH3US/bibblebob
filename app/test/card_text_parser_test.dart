import 'package:bibblebob/services/card_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<OcrLine> lines(List<(String, double)> l) => [for (final (t, h) in l) OcrLine(t, height: h)];

void main() {
  test('typical card', () {
    final p = CardTextParser.parse(
      lines([
        ('ACME Widgets Ltd', 18),
        ('JANE DOE', 30),
        ('Head of Marketing', 14),
        ('M: +44 7700 900123', 12),
        ('T: +44 20 7946 0000', 12),
        ('jane.doe@acmewidgets.co.uk', 12),
        ('www.acmewidgets.co.uk', 12),
      ]),
    );
    expect(p.name, 'Jane Doe');
    expect(p.business, 'ACME Widgets Ltd');
    expect(p.title, 'Head of Marketing');
    expect(p.phone, '+44 7700 900123'); // mobile preferred
    expect(p.email, 'jane.doe@acmewidgets.co.uk');
    expect(p.website, 'www.acmewidgets.co.uk');
  });

  test('business falls back to email domain, ignores free mail', () {
    final p = CardTextParser.parse(
      lines([('Tomáš Novák', 24), ('Designer', 12), ('tomas@studiolumen.cz', 10), ('+420 601 234 567', 10)]),
    );
    expect(p.name, 'Tomáš Novák');
    expect(p.business, 'Studiolumen');
    expect(p.phone, '+420 601 234 567');

    final q = CardTextParser.parse(lines([('Ana Silva', 24), ('ana.silva@gmail.com', 10)]));
    expect(q.business, '');
  });

  test('fax numbers are skipped and empty input is fine', () {
    final p = CardTextParser.parse(lines([('Fax: +1 555 123 4567', 10), ('Tel: (555) 987-6543', 10)]));
    expect(p.phone, '(555) 987-6543');
    expect(CardTextParser.parse(const []).name, '');
  });

  test('picks the biggest name-like line', () {
    final p = CardTextParser.parse(lines([('Small Print Here', 8), ('Maria Garcia', 26), ('Lead Engineer', 12)]));
    expect(p.name, 'Maria Garcia');
    expect(p.title, 'Lead Engineer');
  });
}
