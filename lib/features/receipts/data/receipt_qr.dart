import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../../core/utils/log.dart';
import '../domain/einvoice_link.dart';

const _liveScanner = MethodChannel('bukuresipi/qr');

/// Google's live QR scanner (MainActivity; it runs in Play services, so no camera permission here): the QR's raw text,
/// null = closed. Throws when this phone has no scanner.
Future<String?> scanQrLive() => _liveScanner.invokeMethod<String>('scan');

/// The receipt photo's "request your e-invoice" QR, read on the phone (the server's AI cannot decode a QR): a web
/// link, the one naming an e-invoice when the receipt has several QR codes, else the only one. null = none, or no
/// ML Kit here (iOS without the pod, a test): the receipt still uploads without it.
Future<String?> einvoiceLinkIn(String path) async {
  final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  try {
    final codes = await scanner.processImage(InputImage.fromFilePath(path));
    final links = [for (final c in codes) ?qrWebLink(c.rawValue)];
    final named = links.where(
      (l) => RegExp(r'e[-_]?invoi|myinvois', caseSensitive: false).hasMatch(l),
    );
    return named.firstOrNull ?? (links.length == 1 ? links.first : null);
  } catch (e) {
    log('receipt QR: not read ($e)');
    return null;
  } finally {
    await scanner.close().catchError((_) {});
  }
}
