import '../../core/app_config.dart';

enum VideoZone { normal, dark }

class VideoModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final String title;
  final String? description;
  final String videoUrl;
  final String? hlsUrl; // version multi-qualités (adaptative à la connexion)
  final String? thumbnailUrl;
  final VideoZone zone;
  final int likes;
  final int comments;
  final int views;
  final bool isLiked;
  final bool isBoosted;
  final double price; // 0 = gratuit
  final bool isLocked; // vidéo payante non encore achetée par le spectateur
  final DateTime createdAt;

  const VideoModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.title,
    this.description,
    required this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.zone = VideoZone.normal,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.isLiked = false,
    this.isBoosted = false,
    this.price = 0,
    this.isLocked = false,
    required this.createdAt,
  });

  bool get isFree => price == 0;
  bool get isDark => zone == VideoZone.dark;

  /// URL de lecture : la version adaptative (HLS, s'ajuste à la connexion)
  /// quand elle existe, sinon le MP4 d'origine — servie via le CDN (Lagos)
  /// si configuré, pour un chargement rapide au Bénin.
  String get playbackUrl {
    final u = (hlsUrl != null && hlsUrl!.isNotEmpty) ? hlsUrl! : videoUrl;
    return AppConfig.cdn(u);
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
    id: json['id'] ?? '',
    creatorId: json['creator_id'] ?? '',
    creatorName: json['creator_name'] ?? json['creator_id'] ?? 'Créateur',
    creatorAvatar: json['creator_avatar'],
    title: json['title'] ?? '',
    description: json['description'],
    videoUrl: json['video_url'] ?? '',
    hlsUrl: json['hls_url'],
    thumbnailUrl: json['thumbnail_url'],
    zone: VideoZone.values.where((z) => z.name == (json['zone'] ?? 'normal')).firstOrNull ?? VideoZone.normal,
    likes: json['likes_count'] ?? json['likes'] ?? 0,
    comments: json['comments_count'] ?? json['comments'] ?? 0,
    views: json['views'] ?? 0,
    isLiked: json['is_liked'] ?? false,
    isBoosted: json['is_boosted'] ?? false,
    price: (json['price'] ?? 0).toDouble(),
    isLocked: json['is_locked'] == true,
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
  );

  // Données fictives pour les tests
  static List<VideoModel> get mockNormal => List.generate(
    10,
        (i) => VideoModel(
      id: 'video_$i',
      creatorId: 'creator_$i',
      creatorName: ['Akossi TV', 'Cotonou Vibes', 'BeninDance', 'AfroBeninPlay', 'GoroTV'][i % 5],
      creatorAvatar: null,
      title: ['Dance Agbadja 🔥', 'Cuisine béninoise', 'Humour Bénin', 'Musique Coupé-Décalé', 'Lifestyle Cotonou'][i % 5],
      description: 'Contenu créé au Bénin 🇧🇯',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      zone: VideoZone.normal,
      likes: (i + 1) * 1250,
      comments: (i + 1) * 43,
      views: (i + 1) * 8900,
      createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
    ),
  );

  static List<VideoModel> get mockDark => List.generate(
    5,
        (i) => VideoModel(
      id: 'dark_video_$i',
      creatorId: 'creator_dark_$i',
      creatorName: ['Creator ${i + 1}'][0],
      title: 'Contenu Exclusif ${i + 1}',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      zone: VideoZone.dark,
      likes: (i + 1) * 500,
      comments: (i + 1) * 20,
      views: (i + 1) * 2000,
      price: 500,
      createdAt: DateTime.now().subtract(Duration(hours: i)),
    ),
  );
}
