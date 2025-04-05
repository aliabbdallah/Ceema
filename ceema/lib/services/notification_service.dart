import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ceema/models/notification.dart' as app_notification;

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  // Get current user id
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get all notifications for current user
  Stream<List<app_notification.Notification>> getUserNotifications() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app_notification.Notification.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    });
  }

  // Get unread notification count
  Stream<int> getUnreadNotificationCount() {
    if (_currentUserId == null) {
      return Stream.value(0);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null) return;

    await _notificationsCollection.doc(notificationId).update({
      'isRead': true,
    });
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;

    final batch = _firestore.batch();
    final unreadNotifications = await _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Create a friend request notification
  Future<void> createFriendRequestNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderName,
    String? senderPhotoUrl,
  }) async {
    await _createNotification(
      userId: recipientUserId,
      title: 'New Friend Request',
      body: '$senderName sent you a friend request',
      type: app_notification.NotificationType.friendRequest,
      senderUserId: senderUserId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      referenceId: senderUserId,
    );
  }

  // Create a friend accepted notification
  Future<void> createFriendAcceptedNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderName,
    String? senderPhotoUrl,
  }) async {
    await _createNotification(
      userId: recipientUserId,
      title: 'Friend Request Accepted',
      body: '$senderName accepted your friend request',
      type: app_notification.NotificationType.friendAccepted,
      senderUserId: senderUserId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      referenceId: senderUserId,
    );
  }

  // Create a post like notification
  Future<void> createPostLikeNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderName,
    String? senderPhotoUrl,
    required String postId,
  }) async {
    await _createNotification(
      userId: recipientUserId,
      title: 'New Like',
      body: '$senderName liked your post',
      type: app_notification.NotificationType.postLike,
      senderUserId: senderUserId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      referenceId: postId,
    );
  }

  // Create a post comment notification
  Future<void> createPostCommentNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderName,
    String? senderPhotoUrl,
    required String postId,
    required String commentText,
  }) async {
    await _createNotification(
      userId: recipientUserId,
      title: 'New Comment',
      body:
          '$senderName commented: ${commentText.length > 30 ? commentText.substring(0, 30) + '...' : commentText}',
      type: app_notification.NotificationType.postComment,
      senderUserId: senderUserId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      referenceId: postId,
    );
  }

  // Create a system notification
  Future<void> createSystemNotification({
    required String recipientUserId,
    required String title,
    required String body,
  }) async {
    await _createNotification(
      userId: recipientUserId,
      title: title,
      body: body,
      type: app_notification.NotificationType.systemNotice,
    );
  }

  // Helper method to create notifications
  Future<void> _createNotification({
    required String userId,
    required String title,
    required String body,
    required app_notification.NotificationType type,
    String? senderUserId,
    String? senderName,
    String? senderPhotoUrl,
    String? referenceId,
  }) async {
    await _notificationsCollection.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsCollection.doc(notificationId).delete();
  }

  // Delete all notifications for the current user
  Future<void> deleteAllNotifications() async {
    if (_currentUserId == null) return;

    final batch = _firestore.batch();
    final notifications = await _notificationsCollection
        .where('userId', isEqualTo: _currentUserId)
        .get();

    for (var doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
