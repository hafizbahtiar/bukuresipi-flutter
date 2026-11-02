/// Reads a post's caption on the phone, for sites whose caption the API cannot get (TikTok's oEmbed gives none).
/// Returns null when it cannot; the link is sent anyway.
abstract interface class CaptionReader {
  Future<String?> read(String url);
}
