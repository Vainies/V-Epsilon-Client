class AppUser {
  final int id;
  final String handle;
  final String name;
  final String bio;
  final String avatarUrl;
  final String bannerUrl;
  final String profileBgUrl;
  final String status;
  final List<String> badges;
  final int streak;
  final int followers;
  final int following;
  // Viewer-relative
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isMuted;
  final bool isBlocked;
  // Role flags
  final bool isAdmin;
  final bool isMod;
  final bool isBanned;
  // Privacy flags (also visible to others so UI can paint lock icons)
  final bool privacyProfile;
  final bool privacyPosts;
  final bool privacyLikes;
  final bool privacyComments;
  final bool privacyReposts;
  final bool privacyFollowers;
  /// True when the server stripped private profile data because the viewer
  /// isn't allowed to see it. The client should render a "locked profile"
  /// placeholder when this is set.
  final bool locked;
  final bool hideReposts;
  final Map<String, String> profileTheme;

   AppUser({
    required this.id,
    required this.handle,
    required this.name,
    this.bio = '',
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.profileBgUrl = '',
    this.status = '',
    this.badges = const [],
    this.streak = 0,
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isMuted = false,
    this.isBlocked = false,
    this.isAdmin = false,
    this.isMod = false,
    this.isBanned = false,
    this.privacyProfile = false,
    this.privacyPosts = false,
    this.privacyLikes = false,
    this.privacyComments = false,
    this.privacyReposts = false,
    this.privacyFollowers = false,
    this.locked = false,
    this.hideReposts = false,
    this.profileTheme = const {},
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        handle: (j['handle'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        bio: (j['bio'] ?? '') as String,
        avatarUrl: (j['avatar_url'] ?? '') as String,
        bannerUrl: (j['banner_url'] ?? '') as String,
        profileBgUrl: (j['profile_bg_url'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        badges: (j['badges'] as List?)?.map((e) => e.toString()).toList() ??  [],
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        isFollowing: (j['is_following'] ?? false) as bool,
        isFollowedBy: (j['is_followed_by'] ?? false) as bool,
        isMuted: (j['is_muted'] ?? false) as bool,
        isBlocked: (j['is_blocked'] ?? false) as bool,
        isAdmin: (j['is_admin'] ?? false) as bool,
        isMod: (j['is_mod'] ?? false) as bool,
        isBanned: (j['is_banned'] ?? false) as bool,
        privacyProfile: (j['privacy_profile'] ?? false) as bool,
        privacyPosts: (j['privacy_posts'] ?? false) as bool,
        privacyLikes: (j['privacy_likes'] ?? false) as bool,
        privacyComments: (j['privacy_comments'] ?? false) as bool,
        privacyReposts: (j['privacy_reposts'] ?? false) as bool,
        privacyFollowers: (j['privacy_followers'] ?? false) as bool,
        hideReposts: (j['hide_reposts'] ?? false) as bool,
        profileTheme: (j['profile_theme'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
        locked: (j['locked'] ?? false) as bool,
      );

  AppUser copyWith({
    bool? isFollowing,
    int? followers,
    int? following,
    bool? isMuted,
    bool? isBlocked,
    bool? privacyProfile,
    bool? privacyPosts,
    bool? privacyLikes,
    bool? privacyComments,
    bool? privacyReposts,
    bool? privacyFollowers,
    String? avatarUrl,
    String? bannerUrl,
    String? name,
    String? bio,
    String? status,
  }) =>
      AppUser(
        id: id,
        handle: handle,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        status: status ?? this.status,
        badges: badges,
        streak: streak,
        followers: followers ?? this.followers,
        following: following ?? this.following,
        isFollowing: isFollowing ?? this.isFollowing,
        isFollowedBy: isFollowedBy,
        isMuted: isMuted ?? this.isMuted,
        isBlocked: isBlocked ?? this.isBlocked,
        isAdmin: isAdmin,
        isMod: isMod,
        isBanned: isBanned,
        privacyProfile: privacyProfile ?? this.privacyProfile,
        privacyPosts: privacyPosts ?? this.privacyPosts,
        privacyLikes: privacyLikes ?? this.privacyLikes,
        privacyComments: privacyComments ?? this.privacyComments,
        privacyReposts: privacyReposts ?? this.privacyReposts,
        privacyFollowers: privacyFollowers ?? this.privacyFollowers,
        locked: locked,
      );
}

class Post {
  final int id;
  final AppUser author;
  final String kind; // post|blog|code|video|polls|coop|ad
  final String title;
  final String body;
  final String code;
  final String mediaUrl;
  final String thumbUrl;
  final String duration;
  final int views;
  int likes;
  final int comments;
  int reposts;
  bool liked;
  bool reposted;
  final AppUser? repostedBy;
  final DateTime? repostedAt;
  final List<Attachment> attachments;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool spoiler;
  final String spoilerLabel;

  Post({
    required this.id,
    required this.author,
    required this.kind,
    this.title = '',
    this.body = '',
    this.code = '',
    this.mediaUrl = '',
    this.thumbUrl = '',
    this.duration = '',
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.liked = false,
    this.reposted = false,
    this.repostedBy,
    this.repostedAt,
    this.attachments = const [],
    this.metadata = const {},
    DateTime? createdAt,
    this.spoiler = false,
    this.spoilerLabel = '',
  }) : createdAt = createdAt ?? DateTime.now();

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: (j['id'] as num).toInt(),
        author: AppUser.fromJson((j['author'] ?? {}) as Map<String, dynamic>),
        kind: (j['kind'] ?? 'post') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        mediaUrl: (j['media_url'] ?? '') as String,
        thumbUrl: (j['thumb_url'] ?? '') as String,
        duration: (j['duration'] ?? '') as String,
        views: (j['views'] as num?)?.toInt() ?? 0,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        reposts: (j['reposts'] as num?)?.toInt() ?? 0,
        liked: (j['liked'] ?? false) as bool,
        reposted: (j['reposted'] ?? false) as bool,
        repostedBy: j['reposted_by'] == null
            ? null
            : AppUser.fromJson(j['reposted_by'] as Map<String, dynamic>),
        repostedAt: DateTime.tryParse((j['reposted_at'] ?? '') as String),
        attachments: ((j['attachments'] as List?) ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        metadata: (j['metadata'] as Map?)?.cast<String, dynamic>() ??  {},
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
        spoiler: (j['spoiler'] ?? false) as bool,
        spoilerLabel: (j['spoiler_label'] ?? '') as String,
      );
}

/// Embedded content in a post: image, video, URL preview, voice note, etc.
class Attachment {
  final String type; // 'image' | 'video' | 'voice' | 'link' | 'youtube' | 'github'
  final String url;
  final String? title;
  final String? description;
  final String? thumbnail;

   Attachment({required this.type, required this.url, this.title, this.description, this.thumbnail});

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        type: (j['type'] ?? 'link') as String,
        url: (j['url'] ?? '') as String,
        title: j['title'] as String?,
        description: j['description'] as String?,
        thumbnail: j['thumbnail'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (thumbnail != null) 'thumbnail': thumbnail,
      };

  /// Auto-detect attachment type from a URL.
  static Attachment fromUrl(String url) {
    final u = url.trim();
    final lower = u.toLowerCase();
    if (RegExp(r'\.(jpg|jpeg|png|webp|gif)$').hasMatch(lower)) {
      return Attachment(type: 'image', url: u);
    }
    if (RegExp(r'\.(mp4|webm|mov)$').hasMatch(lower)) {
      return Attachment(type: 'video', url: u);
    }
    if (RegExp(r'\.(m4a|aac|mp3|ogg|wav)$').hasMatch(lower)) {
      return Attachment(type: 'voice', url: u);
    }
    if (lower.contains('youtube.com/watch') || lower.contains('youtu.be/')) {
      return Attachment(type: 'youtube', url: u);
    }
    if (lower.contains('github.com/')) {
      return Attachment(type: 'github', url: u);
    }
    return Attachment(type: 'link', url: u);
  }
}

class Comment {
  final int id;
  final AppUser author;
  final String body;
  final int likes;
  final DateTime createdAt;
  final String kind;     // 'text' | 'voice'
  final String mediaUrl; // audio URL when kind=voice
  final String duration; // mm:ss label

  Comment({
    required this.id,
    required this.author,
    required this.body,
    this.likes = 0,
    DateTime? createdAt,
    this.kind = 'text',
    this.mediaUrl = '',
    this.duration = '',
  }) : createdAt = createdAt ?? DateTime.now();

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: (j['id'] as num).toInt(),
        author: AppUser.fromJson((j['author'] ?? {}) as Map<String, dynamic>),
        body: (j['body'] ?? '') as String,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
        kind: (j['kind'] ?? 'text') as String,
        mediaUrl: (j['media_url'] ?? '') as String,
        duration: (j['duration'] ?? '') as String,
      );
}

class AppNotification {
  final int id;
  final String kind; // like|follow|coop|comment
  final String body;
  final bool read;
  final DateTime createdAt;
  final AppUser actor;

  AppNotification({required this.id, required this.kind, this.body = '', this.read = false, DateTime? createdAt, required this.actor})
      : createdAt = createdAt ?? DateTime.now();

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        kind: (j['kind'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        read: (j['read'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
        actor: AppUser.fromJson((j['actor'] ?? {}) as Map<String, dynamic>),
      );
}

class Thread {
  final AppUser user;
  final String lastMessage;
  final String kind; // text|voice
  final String duration;
  final bool read;
  final DateTime time;

  Thread({required this.user, this.lastMessage = '', this.kind = 'text', this.duration = '', this.read = true, DateTime? time})
      : time = time ?? DateTime.now();

  factory Thread.fromJson(Map<String, dynamic> j) => Thread(
        user: AppUser.fromJson((j['user'] ?? {}) as Map<String, dynamic>),
        lastMessage: (j['last_message'] ?? '') as String,
        kind: (j['kind'] ?? 'text') as String,
        duration: (j['duration'] ?? '') as String,
        read: (j['read'] ?? true) as bool,
        time: DateTime.tryParse((j['time'] ?? '') as String) ?? DateTime.now(),
      );
}

/// Relative time like '2h', '5m'
String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${d.inDays ~/ 7}w';
  return '${d.inDays ~/ 30}mo';
}

/// Compact number formatter (e.g. 1523 -> 1.5k)
String compactNum(num n) {
  if (n < 1000) return n.toString();
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
