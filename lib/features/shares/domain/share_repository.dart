import 'share.dart';

/// Sending shared posts to the API. Every method throws ApiException (core/network) on failure.
abstract interface class ShareRepository {
  /// Returns the share id; the API reads the post in the background (poll [get]).
  Future<String> submitLink(String url);

  /// A screenshot or photo: JPG, PNG or WebP up to 5 MB.
  Future<String> submitImage(String path);

  Future<Share> get(String id);
}
