/// What came back from Google's live QR scanner.
enum EinvoiceScan { saved, closed, notALink, unavailable }

/// Why a shop's e-invoice link deserves a second look: the form behind it asks for an IC and TIN, and LHDN lets every
/// shop pick its own site (Specific Guideline 3.8.2), so there is no official list to check it against.
enum LinkRisk { none, notSecure, shortLink, oddName }

const _shortLinks = {
  'bit.ly', 'cutt.ly', 'goo.gl', 'is.gd', 'ow.ly', 'qrco.de', 'rb.gy', //
  'rebrand.ly', 's.id', 'shorturl.at', 't.co', 't.ly', 'tinyurl.com',
};

/// The web link in a QR's text; null = not one.
String? qrWebLink(String? raw) {
  final u = Uri.tryParse(raw?.trim() ?? '');
  if (u == null || u.host.isEmpty) return null;
  return u.isScheme('https') || u.isScheme('http') ? u.toString() : null;
}

String linkHost(String url) => Uri.tryParse(url)?.host ?? url;

LinkRisk linkRisk(String url) {
  final u = Uri.tryParse(url);
  final host = u?.host.toLowerCase() ?? '';
  // Punycode or non-ASCII letters: how a look-alike of a real site's name is written.
  if (host.contains('xn--') || !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
    return LinkRisk.oddName;
  }
  if (_shortLinks.contains(host)) return LinkRisk.shortLink;
  return u!.isScheme('https') ? LinkRisk.none : LinkRisk.notSecure;
}
