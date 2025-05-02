import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;
  final List<String> likes;
  final String? parentCommentId; // ID of the parent comment if this is a reply
  final int replyCount; // Number of replies to this comment

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
    required this.likes,
    this.parentCommentId,
    this.replyCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json, String documentId) {
    return Comment(
      id: documentId,
      postId: json['postId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatar: json['userAvatar'] ?? '',
      content: json['content'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      likes: List<String>.from(json['likes'] ?? []),
      parentCommentId: json['parentCommentId'],
      replyCount: json['replyCount'] ?? 0,
    );
  }
}
