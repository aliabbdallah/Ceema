import 'package:cloud_firestore/cloud_firestore.dart';

enum FollowRequestStatus { pending, accepted, declined, cancelled }

class FollowRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterAvatar;
  final String targetId;
  final String targetName;
  final String targetAvatar;
  final FollowRequestStatus status;
  final DateTime createdAt;

  FollowRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterAvatar,
    required this.targetId,
    required this.targetName,
    required this.targetAvatar,
    required this.status,
    required this.createdAt,
  });

  factory FollowRequest.fromJson(Map<String, dynamic> json, String documentId) {
    return FollowRequest(
      id: documentId,
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      requesterAvatar: json['requesterAvatar'] ?? '',
      targetId: json['targetId'] ?? '',
      targetName: json['targetName'] ?? '',
      targetAvatar: json['targetAvatar'] ?? '',
      status: FollowRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FollowRequestStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterAvatar': requesterAvatar,
      'targetId': targetId,
      'targetName': targetName,
      'targetAvatar': targetAvatar,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
