enum UserZone { normal, dark }
enum KycStatus { none, pending, approved, rejected }
enum UserRole { viewer, creator }

class UserModel {
  final String id;
  final String phone;
  final String? username;
  final String? avatarUrl;
  final UserZone zone;
  final KycStatus kycStatus;
  final UserRole role;
  final double walletBalance;
  final double totalEarnings;
  final bool isSubscribedDark;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.phone,
    this.username,
    this.avatarUrl,
    this.zone = UserZone.normal,
    this.kycStatus = KycStatus.none,
    this.role = UserRole.viewer,
    this.walletBalance = 0,
    this.totalEarnings = 0,
    this.isSubscribedDark = false,
    required this.createdAt,
  });

  bool get canAccessDark =>
      kycStatus == KycStatus.approved && isSubscribedDark;

  bool get isCreator => role == UserRole.creator;

  UserModel copyWith({
    String? username,
    String? avatarUrl,
    UserZone? zone,
    KycStatus? kycStatus,
    UserRole? role,
    double? walletBalance,
    double? totalEarnings,
    bool? isSubscribedDark,
  }) {
    return UserModel(
      id: id,
      phone: phone,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      zone: zone ?? this.zone,
      kycStatus: kycStatus ?? this.kycStatus,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      isSubscribedDark: isSubscribedDark ?? this.isSubscribedDark,
      createdAt: createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phone: json['phone'],
        username: json['username'],
        avatarUrl: json['avatar_url'],
        zone: UserZone.values.byName(json['zone'] ?? 'normal'),
        kycStatus: KycStatus.values.byName(json['kyc_status'] ?? 'none'),
        role: UserRole.values.byName(json['role'] ?? 'viewer'),
        walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
        totalEarnings: (json['total_earnings'] ?? 0).toDouble(),
        isSubscribedDark: json['is_subscribed_dark'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'username': username,
        'avatar_url': avatarUrl,
        'zone': zone.name,
        'kyc_status': kycStatus.name,
        'role': role.name,
        'wallet_balance': walletBalance,
        'total_earnings': totalEarnings,
        'is_subscribed_dark': isSubscribedDark,
        'created_at': createdAt.toIso8601String(),
      };
}
