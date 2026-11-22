import 'package:bukuresipi_flutter/features/receipts/domain/einvoice_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a QR is a web link only when it is http(s) with a host', () {
    expect(
      qrWebLink(' https://pos.example.com/r/1 '),
      'https://pos.example.com/r/1',
    );
    expect(
      qrWebLink('http://pos.example.com/r/1'),
      'http://pos.example.com/r/1',
    );
    for (final raw in [
      null,
      '',
      'WIFI:S:shop;P:1234;;',
      'tel:0123456789',
      'javascript:alert(1)',
      'just text',
    ]) {
      expect(qrWebLink(raw), isNull, reason: '$raw');
    }
  });

  test('a link is flagged when it is not secure, hides its site, or imitates a name', () {
    expect(linkRisk('https://einvoice.pos.example.com/r/1'), LinkRisk.none);
    expect(linkRisk('http://einvoice.pos.example.com/r/1'), LinkRisk.notSecure);
    expect(linkRisk('https://bit.ly/abc'), LinkRisk.shortLink);
    expect(linkRisk('https://xn--hasl-5qa.example.com/r'), LinkRisk.oddName);
    expect(
      linkRisk('https://hаsil.example.com/r'),
      LinkRisk.oddName,
    ); // a Cyrillic "а"
  });
}
