import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/follow.dart';
import '../models/user.dart';
import 'notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Cache for follows
  final Map<String, List<Follow>> _followsCache = {};
  final Map<String, DocumentSnapshot?> _lastFollowDocCache = {};

  // Get followers with pagination
  Stream<List<Follow>> getFollowers(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore
        .collection('follows')
        .where('followedId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      final follows =
          snapshot.docs
              .map(
                (doc) =>
                    Follow.fromJson(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

      // Update cache
      _followsCache['followers_$userId'] = follows;
      if (snapshot.docs.isNotEmpty) {
        _lastFollowDocCache['followers_$userId'] = snapshot.docs.last;
      }

      return follows;
    });
  }

  // Get following with pagination
  Stream<List<Follow>> getFollowing(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      final follows =
          snapshot.docs
              .map(
                (doc) =>
                    Follow.fromJson(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

      // Update cache
      _followsCache['following_$userId'] = follows;
      if (snapshot.docs.isNotEmpty) {
        _lastFollowDocCache['following_$userId'] = snapshot.docs.last;
      }

      return follows;
    });
  }

  // Get cached followers
  List<Follow>? getCachedFollowers(String userId) {
    return _followsCache['followers_$userId'];
  }

  // Get cached following
  List<Follow>? getCachedFollowing(String userId) {
    return _followsCache['following_$userId'];
  }

  // Get last document for pagination
  DocumentSnapshot? getLastFollowDoc(String cacheKey) {
    return _lastFollowDocCache[cacheKey];
  }

  // Follow a user
  Future<void> followUser(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Prevent users from following themselves
      if (currentUser.uid == targetId) {
        throw Exception('You cannot follow yourself');
      }

      // Check if already following
      final existingFollow =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .get();

      if (existingFollow.docs.isNotEmpty) return;

      // Fetch current user's profile from Firestore
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserData = currentUserDoc.data() ?? {};

      // Fetch target user's profile from Firestore
      final targetUserDoc =
          await _firestore.collection('users').doc(targetId).get();
      final targetUserData = targetUserDoc.data() ?? {};

      // Create follow relationship
      final follow = Follow(
        id: '',
        followerId: currentUser.uid,
        followerName:
            currentUserData['username'] ??
            currentUser.displayName ??
            'Unknown User',
        followerAvatar:
            currentUserData['profileImageUrl'] ?? currentUser.photoURL ?? '',
        followedId: targetId,
        followedName: targetUserData['username'] ?? 'User',
        followedAvatar: targetUserData['profileImageUrl'] ?? '',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('follows').add(follow.toJson());

      // Create notification for the target user (the one being followed)
      await _notificationService.createFollowNotification(
        recipientUserId: targetId,
        senderUserId: currentUser.uid,
        senderName:
            currentUserData['username'] ??
            currentUser.displayName ??
            'Unknown User',
        senderPhotoUrl:
            currentUserData['profileImageUrl'] ?? currentUser.photoURL ?? '',
      );

      // Clear cache
      _followsCache.remove('following_${currentUser.uid}');
      _followsCache.remove('followers_$targetId');
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Find and delete follow relationship
      final followQuery =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .get();

      for (var doc in followQuery.docs) {
        await doc.reference.delete();
      }

      // Clear cache
      _followsCache.remove('following_${currentUser.uid}');
      _followsCache.remove('followers_$targetId');
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  // Check if following a user
  Future<bool> isFollowing(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check cache first
      final cachedFollowing = getCachedFollowing(currentUser.uid);
      if (cachedFollowing != null) {
        return cachedFollowing.any((follow) => follow.followedId == targetId);
      }

      // If not in cache, query Firestore
      final followQuery =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .get();

      return followQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('follows')
              .where('followedId', isEqualTo: userId)
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting follower count: $e');
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting following count: $e');
      return 0;
    }
  }
}
