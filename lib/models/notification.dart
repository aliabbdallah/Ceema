import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  follow,
  followRequest,
  followRequestAccepted,
  postLike,
  postComment,
  systemNotice,
  followRequestSent,
  followRequestSentAccepted,
  commentReply,
  followBackSuggestion,
}

class Notification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? senderUserId; // Nullable for system notifications
  final String? senderName;
  final String? senderPhotoUrl;
  final String? referenceId; // ID of the post, comment, etc.
  final DateTime createdAt;
  final bool isRead;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.senderUserId,
    this.senderName,
    this.senderPhotoUrl,
    this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'referenceId': referenceId,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      body: map['body'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.systemNotice,
      ),
      senderUserId: map['senderUserId'],
      senderName: map['senderName'],
      senderPhotoUrl: map['senderPhotoUrl'],
      referenceId: map['referenceId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? senderUserId,
    String? senderName,
    String? senderPhotoUrl,
    String? referenceId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
