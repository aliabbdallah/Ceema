import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/follow_request.dart';
import '../models/user.dart';
import 'follow_service.dart';
import 'notification_service.dart';
import '../models/notification.dart' as app_notification;

class FollowRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  final NotificationService _notificationService = NotificationService();

  // Send a follow request
  Future<void> sendFollowRequest({
    required String requesterId,
    required String targetId,
  }) async {
    // Get user data
    final requester =
        await _firestore.collection('users').doc(requesterId).get();
    final target = await _firestore.collection('users').doc(targetId).get();

    final requesterData = requester.data() ?? {};
    final targetData = target.data() ?? {};

    // Check if request already exists
    final existingRequest =
        await _firestore
            .collection('follow_requests')
            .where('requesterId', isEqualTo: requesterId)
            .where('targetId', isEqualTo: targetId)
            .where('status', isEqualTo: FollowRequestStatus.pending.name)
            .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Follow request already sent');
    }

    // Check if already following
    final isFollowing = await _followService.isFollowing(targetId);
    if (isFollowing) {
      throw Exception('Already following this user');
    }

    // Create the follow request
    await _firestore.collection('follow_requests').add({
      'requesterId': requesterId,
      'requesterName': requesterData['username'] ?? '',
      'requesterAvatar': requesterData['profileImageUrl'] ?? '',
      'targetId': targetId,
      'targetName': targetData['username'] ?? '',
      'targetAvatar': targetData['profileImageUrl'] ?? '',
      'status': FollowRequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the target user
    await _notificationService.createFollowRequestNotification(
      recipientUserId: targetId,
      senderUserId: requesterId,
      senderName: requesterData['username'] ?? '',
      senderPhotoUrl: requesterData['profileImageUrl'] ?? '',
    );
  }

  // Accept a follow request
  Future<void> acceptFollowRequest(String requestId) async {
    final requestDoc =
        await _firestore.collection('follow_requests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw Exception('Follow request not found');
    }

    final request = FollowRequest.fromJson(requestDoc.data()!, requestDoc.id);

    // Start a batch write
    final batch = _firestore.batch();

    // Update request status
    batch.update(requestDoc.reference, {
      'status': FollowRequestStatus.accepted.name,
    });

    // Create follow relationship
    final followDoc = _firestore.collection('follows').doc();
    batch.set(followDoc, {
      'followerId': request.requesterId,
      'followerName': request.requesterName,
      'followerAvatar': request.requesterAvatar,
      'followedId': request.targetId,
      'followedName': request.targetName,
      'followedAvatar': request.targetAvatar,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Execute the batch
    await batch.commit();

    // Create notification for the requester that their request was accepted
    await _notificationService.createFollowRequestAcceptedNotification(
      recipientUserId: request.requesterId,
      senderUserId: request.targetId,
      senderName: request.targetName,
      senderPhotoUrl: request.targetAvatar,
    );

    // Create a separate follow back suggestion notification for the target user
    await _notificationService.createFollowBackSuggestionNotification(
      recipientUserId: request.targetId,
      senderUserId: request.requesterId,
      senderName: request.requesterName,
      senderPhotoUrl: request.requesterAvatar,
    );

    // Delete the original follow request notification
    final originalNotification =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: request.targetId)
            .where(
              'type',
              isEqualTo: app_notification.NotificationType.followRequest.name,
            )
            .where('senderUserId', isEqualTo: request.requesterId)
            .get();

    if (originalNotification.docs.isNotEmpty) {
      await _notificationService.deleteNotification(
        originalNotification.docs.first.id,
      );
    }
  }

  // Decline a follow request
  Future<void> declineFollowRequest(String requestId) async {
    await _firestore.collection('follow_requests').doc(requestId).update({
      'status': FollowRequestStatus.declined.name,
    });
  }

  // Cancel a sent follow request
  Future<void> cancelFollowRequest(String requestId) async {
    await _firestore.collection('follow_requests').doc(requestId).delete();
  }

  // Get pending follow requests for a user
  Stream<List<FollowRequest>> getPendingRequests(String userId) {
    return _firestore
        .collection('follow_requests')
        .where('targetId', isEqualTo: userId)
        .where('status', isEqualTo: FollowRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FollowRequest.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  // Get sent follow requests
  Stream<List<FollowRequest>> getSentRequests(String userId) {
    return _firestore
        .collection('follow_requests')
        .where('requesterId', isEqualTo: userId)
        .where('status', isEqualTo: FollowRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FollowRequest.fromJson(doc.data(), doc.id))
              .toList();
        });
  }
}
