// services/friend_request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request.dart';
import 'friend_service.dart';
import 'notification_service.dart';

class FriendRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendService _friendService = FriendService();
  final NotificationService _notificationService = NotificationService();

  // Send a friend request
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String receiverId,
    required String receiverName,
    required String receiverAvatar,
  }) async {
    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }

    // Check if users are already friends
    final isAlreadyFriend =
        await _friendService.isFollowing(senderId, receiverId);
    if (isAlreadyFriend) {
      throw Exception('Already friends with this user');
    }

    // Create the friend request
    await _firestore.collection('friend_requests').add({
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the receiver
    await _notificationService.createFriendRequestNotification(
      recipientUserId: receiverId,
      senderUserId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderAvatar,
    );
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String requestId) async {
    final requestDoc =
        await _firestore.collection('friend_requests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final request = FriendRequest.fromJson(requestDoc.data()!, requestDoc.id);

    // Start a batch write
    final batch = _firestore.batch();

    // Update request status
    batch.update(requestDoc.reference, {'status': 'accepted'});

    // Create mutual friendship
    await _friendService.followUser(request.receiverId, request.senderId);
    await _friendService.followUser(request.senderId, request.receiverId);

    // Execute the batch
    await batch.commit();

    // Create notification for the sender that their request was accepted
    await _notificationService.createFriendAcceptedNotification(
      recipientUserId: request.senderId,
      senderUserId: request.receiverId,
      senderName: request.receiverName,
      senderPhotoUrl: request.receiverAvatar,
    );
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // Cancel a sent friend request
  Future<void> cancelFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  // Get pending friend requests for a user
  Stream<List<FriendRequest>> getPendingRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Get sent friend requests
  Stream<List<FriendRequest>> getSentRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data(), doc.id))
          .toList();
    });
  }
}
