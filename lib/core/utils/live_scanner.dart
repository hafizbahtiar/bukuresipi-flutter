import 'package:flutter/services.dart';

const _channel = MethodChannel('bukuresipi/qr');

/// Google's live code scanner (MainActivity; it runs in Play services, so no camera permission here): the code's raw
/// text, null = closed. [product] = a shop barcode (EAN / UPC) instead of a QR code. Throws [PlatformException] or
/// [MissingPluginException] when this phone has no scanner.
Future<String?> scanCodeLive({bool product = false}) =>
    _channel.invokeMethod<String>('scan', {'product': product});
