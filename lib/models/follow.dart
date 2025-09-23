import 'package:cloud_firestore/cloud_firestore.dart';

class Follow {
  final String id;
  final String followerId;
  final String followerName;
  final String followerAvatar;
  final String followedId;
  final String followedName;
  final String followedAvatar;
  final DateTime createdAt;

  Follow({
    required this.id,
    required this.followerId,
    required this.followerName,
    required this.followerAvatar,
    required this.followedId,
    required this.followedName,
    required this.followedAvatar,
    required this.createdAt,
  });

  factory Follow.fromJson(Map<String, dynamic> json, String documentId) {
    return Follow(
      id: documentId,
      followerId: json['followerId'] ?? '',
      followerName: json['followerName'] ?? '',
      followerAvatar: json['followerAvatar'] ?? '',
      followedId: json['followedId'] ?? '',
      followedName: json['followedName'] ?? '',
      followedAvatar: json['followedAvatar'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'followerId': followerId,
      'followerName': followerName,
      'followerAvatar': followerAvatar,
      'followedId': followedId,
      'followedName': followedName,
      'followedAvatar': followedAvatar,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Follow copyWith({
    String? id,
    String? followerId,
    String? followerName,
    String? followerAvatar,
    String? followedId,
    String? followedName,
    String? followedAvatar,
    DateTime? createdAt,
  }) {
    return Follow(
      id: id ?? this.id,
      followerId: followerId ?? this.followerId,
      followerName: followerName ?? this.followerName,
      followerAvatar: followerAvatar ?? this.followerAvatar,
      followedId: followedId ?? this.followedId,
      followedName: followedName ?? this.followedName,
      followedAvatar: followedAvatar ?? this.followedAvatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
