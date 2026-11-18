/// Reads a post's caption on the phone, for sites whose caption the API cannot get. Returns null when it cannot; the
/// link is sent anyway.
abstract interface class CaptionReader {
  Future<String?> read(String url);
}

/// The site whose captions the phone reads, by [host]; null = the API reads it itself. TikTok: its oEmbed gives no
/// caption. Facebook and Threads: they answer the API's datacenter address with an error page (a share came back
/// "unreadable" while the same link read fine from a home connection), and the phone is a real browser on the
/// user's own connection. The API uses the phone's caption only when its own read fails or is empty.
String? phoneReadSite(String host) {
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  if (on('tiktok.com')) return 'tiktok';
  if (on('facebook.com') || on('fb.watch') || on('fb.com')) return 'facebook';
  if (on('threads.net') || on('threads.com')) return 'threads';
  return null;
}
