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

  test(
    'the shown site is where the browser goes, even with a backslash trick',
    () {
      final link = qrWebLink(r'https://evil.example.com\@good.example.com/x')!;
      // A browser reads a backslash as "/": the real site is the first name, and that is the one shown.
      expect(linkHost(link), 'evil.example.com');
    },
  );

  test('a link is flagged when it is not secure, hides its site, or imitates a name', () {
    expect(linkRisk('https://einvoice.pos.example.com/r/1'), LinkRisk.none);
    expect(linkRisk('http://einvoice.pos.example.com/r/1'), LinkRisk.notSecure);
    expect(linkRisk('https://bit.ly/abc'), LinkRisk.shortLink);
    expect(linkRisk('https://xn--hasl-5qa.example.com/r'), LinkRisk.oddName);
    expect(
      linkRisk('https://hаsil.example.com/r'),
      LinkRisk.oddName,
    ); // a Cyrillic "а"
    for (final short in [
      'https://www.bit.ly/x',
      'https://bit.ly./x',
      'https://BIT.LY/x',
      'https://go.tinyurl.com/x',
    ]) {
      expect(linkRisk(short), LinkRisk.shortLink, reason: short);
    }
    for (final odd in [
      'https://bit.ly.evil.com/x',
      'https://192.168.0.1/x',
      'http://[::1]/x',
      'https://lhdn.gov.my@evil.example.com/x',
    ]) {
      expect(linkRisk(odd), LinkRisk.oddName, reason: odd);
    }
    // Only a whole name counts.
    expect(linkRisk('https://orbit.ly.example.com/x'), LinkRisk.none);
  });
}
