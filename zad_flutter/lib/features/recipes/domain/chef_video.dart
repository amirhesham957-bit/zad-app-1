/// One recent video from a curated chef or shop YouTube channel — what
/// `zad-core-intelligence`'s `channel_videos` returns.
library;

/// A video to watch on YouTube. Never downloaded: only the link opens.
class ChefVideo {
  /// Creates a video.
  const new({
    required this.id,
    required this.title,
    required this.channel,
    required this.url,
    required this.isStore,
    this.thumbnail,
  });

  /// YouTube's video id.
  final String id;

  /// The video's title as the channel wrote it.
  final String title;

  /// The channel's display name.
  final String channel;

  /// The watch link.
  final String url;

  /// A shop channel rather than a chef.
  final bool isStore;

  /// A small picture, when YouTube sent one.
  final String? thumbnail;

  /// Reads one entry of the server's `videos`; null when it has no usable
  /// id, title or https link, so a bad row never reaches the screen.
  static ChefVideo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final url = raw['url'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;
    if (url is! String || !url.startsWith('https://www.youtube.com/watch?v=')) {
      return null;
    }
    final thumb = raw['thumbnail'];
    final channel = raw['channel'];
    return ChefVideo(
      id: id,
      title: title.trim(),
      channel: channel is String ? channel.trim() : '',
      url: url,
      isStore: raw['kind'] == 'store',
      thumbnail: thumb is String && thumb.startsWith('https://') ? thumb : null,
    );
  }
}
