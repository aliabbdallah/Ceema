import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final DateTime createdAt;
  final bool isFollowing; // For following/followers feature
  final bool isMutual; // True if both users follow each other

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    required this.createdAt,
    required this.isFollowing,
    required this.isMutual,
  });

  factory Friend.fromJson(Map<String, dynamic> json, String documentId) {
    return Friend(
      id: documentId,
      userId: json['userId'] ?? '',
      friendId: json['friendId'] ?? '',
      friendName: json['friendName'] ?? '',
      friendAvatar: json['friendAvatar'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isFollowing: json['isFollowing'] ?? false,
      isMutual: json['isMutual'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'friendId': friendId,
      'friendName': friendName,
      'friendAvatar': friendAvatar,
      'createdAt': Timestamp.fromDate(createdAt),
      'isFollowing': isFollowing,
      'isMutual': isMutual,
    };
  }
}
