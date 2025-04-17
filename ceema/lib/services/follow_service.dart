import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart'; // Import async package
import '../models/follow.dart';
import '../models/user.dart';
import 'notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Helper function to fetch user profile image URL
  Future<String?> _getUserProfileImageUrl(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['profileImageUrl'];
      }
    } catch (e) {
      print("Error fetching profile image for user $userId: $e");
    }
    return null;
  }

  // Helper function to fetch username
  Future<String> _getUserName(String userId, String fallbackName) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?.containsKey('username') == true) {
        return userDoc.data()!['username'] as String;
      }
    } catch (e) {
      print("Error fetching username for user $userId: $e");
    }
    // Return the name stored in the follow doc as a fallback
    return fallbackName;
  }

  // Get followers with profile images and latest names
  Stream<List<Follow>> getFollowers(String userId) {
    Query query = _firestore
        .collection('follows')
        .where('followedId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      final follows = <Follow>[];
      for (final doc in snapshot.docs) {
        final followData = doc.data() as Map<String, dynamic>;
        final followerId = followData['followerId'];

        // Fetch latest avatar and name
        final followerProfileImageUrl = await _getUserProfileImageUrl(
          followerId,
        );
        // Pass the potentially outdated name as a fallback
        final followerName = await _getUserName(
          followerId,
          followData['followerName'] ?? 'User',
        );

        // Create Follow object with updated avatar and name
        follows.add(
          Follow.fromJson(followData, doc.id).copyWith(
            followerAvatar: followerProfileImageUrl, // Update with fetched URL
            followerName: followerName, // Update with fetched name
          ),
        );
      }
      return follows;
    });
  }

  // Get following with profile images and latest names
  Stream<List<Follow>> getFollowing(String userId) {
    Query query = _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      final follows = <Follow>[];
      for (final doc in snapshot.docs) {
        final followData = doc.data() as Map<String, dynamic>;
        final followedId = followData['followedId'];

        // Fetch latest avatar and name
        final followedProfileImageUrl = await _getUserProfileImageUrl(
          followedId,
        );
        // Pass the potentially outdated name as a fallback
        final followedName = await _getUserName(
          followedId,
          followData['followedName'] ?? 'User',
        );

        // Create Follow object with updated avatar and name
        follows.add(
          Follow.fromJson(followData, doc.id).copyWith(
            followedAvatar: followedProfileImageUrl, // Update with fetched URL
            followedName: followedName, // Update with fetched name
          ),
        );
      }
      return follows;
    });
  }

  // Cache for follow relationships
  final Map<String, bool> _followRelationshipCache = {};

  // Check if following with caching
  Future<bool> isFollowing(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check cache first
      final cacheKey = '${currentUser.uid}_$targetId';
      if (_followRelationshipCache.containsKey(cacheKey)) {
        return _followRelationshipCache[cacheKey]!;
      }

      // Query Firestore if not in cache
      final followQuery =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .limit(1)
              .get();

      final isFollowing = followQuery.docs.isNotEmpty;
      // Update cache
      _followRelationshipCache[cacheKey] = isFollowing;

      return isFollowing;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Clear cache for a specific relationship
  void clearFollowCache(String targetId) {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _followRelationshipCache.remove('${currentUser.uid}_$targetId');
    }
  }

  // Clear entire cache
  void clearAllFollowCache() {
    _followRelationshipCache.clear();
  }

  // Follow a user
  Future<void> followUser(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Clear relationship cache before making changes
      clearFollowCache(targetId);

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
              .limit(1) // Optimized to limit(1)
              .get();

      if (existingFollow.docs.isNotEmpty) return;

      // Fetch current user's profile from Firestore for name/avatar
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserData = currentUserDoc.data() ?? {};
      final currentUsername =
          currentUserData['username'] ??
          currentUser.displayName ??
          'Unknown User';
      final currentUserAvatar =
          currentUserData['profileImageUrl'] ?? currentUser.photoURL;

      // Fetch target user's profile from Firestore for name/avatar
      final targetUserDoc =
          await _firestore.collection('users').doc(targetId).get();
      final targetUserData = targetUserDoc.data() ?? {};
      final targetUsername = targetUserData['username'] ?? 'User';
      final targetUserAvatar = targetUserData['profileImageUrl'];

      // Create follow relationship
      final follow = Follow(
        id: '', // Firestore will generate ID
        followerId: currentUser.uid,
        followerName: currentUsername,
        followerAvatar: currentUserAvatar, // Use fetched avatar
        followedId: targetId,
        followedName: targetUsername,
        followedAvatar: targetUserAvatar, // Use fetched avatar
        createdAt: DateTime.now(),
      );

      await _firestore.collection('follows').add(follow.toJson());

      // Create notification for the target user (the one being followed)
      await _notificationService.createFollowNotification(
        recipientUserId: targetId,
        senderUserId: currentUser.uid,
        senderName: currentUsername,
        senderPhotoUrl: currentUserAvatar ?? '', // Provide fetched avatar
      );
    } catch (e) {
      print('Error following user: $e');
      rethrow; // Rethrow to allow UI to handle error
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Clear relationship cache
      clearFollowCache(targetId);

      // Find and delete follow relationship
      final followQuery =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .get();

      // Use a batch write for potential multiple docs (though unlikely with limit(1))
      final batch = _firestore.batch();
      for (var doc in followQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow; // Rethrow for UI handling
    }
  }

  // Get follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('follows')
              .where('followedId', isEqualTo: userId)
              .count() // Use aggregate count
              .get();
      return querySnapshot.count ?? 0;
    } catch (e) {
      print("Error getting follower count: $e");
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .count() // Use aggregate count
              .get();
      return querySnapshot.count ?? 0;
    } catch (e) {
      print("Error getting following count: $e");
      return 0;
    }
  }

  // Get mutual friends count
  Future<int> getMutualFriendsCount(String userId1, String userId2) async {
    try {
      // Get users followed by userId1
      final following1Snapshot =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId1)
              .get();
      final following1Ids =
          following1Snapshot.docs
              .map((doc) => doc['followedId'] as String)
              .toSet();

      // Get users followed by userId2
      final following2Snapshot =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId2)
              .get();
      final following2Ids =
          following2Snapshot.docs
              .map((doc) => doc['followedId'] as String)
              .toSet();

      // Find intersection (mutual follows)
      final mutualIds = following1Ids.intersection(following2Ids);
      return mutualIds.length;
    } catch (e) {
      print("Error getting mutual friends count: $e");
      return 0;
    }
  }
}
