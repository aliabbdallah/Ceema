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
    print('[FollowService] getFollowing called for userId: $userId');
    Query query = _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    // Use a single asyncMap for better efficiency and error handling
    return query
        .snapshots()
        .asyncMap((snapshot) async {
          print(
            '[FollowService] Received snapshot with ${snapshot.docs.length} follow docs for userId: $userId',
          );

          if (snapshot.docs.isEmpty) {
            print(
              '[FollowService] Snapshot is empty, emitting empty list for userId: $userId',
            );
            return <Follow>[];
          }

          print(
            '[FollowService] Processing ${snapshot.docs.length} follow docs for userId: $userId',
          );
          try {
            // Process documents concurrently using Future.wait
            final follows = await Future.wait(
              snapshot.docs.map((doc) async {
                final followData = doc.data() as Map<String, dynamic>;
                final followedId = followData['followedId'] as String?;

                if (followedId == null) {
                  print(
                    '[FollowService] Warning: Follow doc ${doc.id} missing followedId.',
                  );
                  // Decide how to handle this - skip or return a placeholder?
                  // Returning null here to filter out later, or throw an error
                  return null;
                }

                // Fetch latest avatar and name
                final followedProfileImageUrl = await _getUserProfileImageUrl(
                  followedId,
                );
                final followedName = await _getUserName(
                  followedId,
                  followData['followedName'] as String? ??
                      'User', // Handle potential null
                );

                // Create Follow object with updated avatar and name
                return Follow.fromJson(followData, doc.id).copyWith(
                  followedAvatar: followedProfileImageUrl,
                  followedName: followedName,
                );
              }).toList(),
            );

            // Filter out any nulls resulting from processing errors (like missing followedId)
            final validFollows = follows.whereType<Follow>().toList();

            print(
              '[FollowService] Emitting ${validFollows.length} valid Follow objects for userId: $userId',
            );
            return validFollows;
          } catch (e, stackTrace) {
            print(
              '[FollowService] Error processing snapshot for userId: $userId - $e\n$stackTrace',
            );
            // Rethrow or return empty list depending on desired behavior on error
            return <Follow>[]; // Return empty list on processing error
          }
        })
        .handleError((error) {
          // Handle errors specifically from the snapshots() stream itself
          print(
            '[FollowService] Error in snapshots() stream for userId: $userId - $error',
          );
          return <Follow>[]; // Return empty list on stream error
        });
  }

  // Check if following WITHOUT caching
  Future<bool> isFollowing(String targetId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Query Firestore directly
      final followQuery =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: currentUser.uid)
              .where('followedId', isEqualTo: targetId)
              .limit(1)
              .get();

      final isFollowing = followQuery.docs.isNotEmpty;

      return isFollowing;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get a list of IDs the user is following (one-time fetch)
  Future<List<String>> getFollowingIdsOnce(String userId) async {
    print('[FollowService] getFollowingIdsOnce called for userId: $userId');
    try {
      final querySnapshot =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .get();
      // Explicitly map to String? and then filter non-nulls
      final ids =
          querySnapshot.docs
              .map((doc) => doc.data()['followedId'] as String?)
              .whereType<String>() // Filter out nulls and ensure type is String
              .toList();
      print(
        '[FollowService] getFollowingIdsOnce found ${ids.length} IDs for userId: $userId',
      );
      return ids;
    } catch (e) {
      print(
        '[FollowService] Error in getFollowingIdsOnce for userId: $userId - $e',
      );
      return []; // Return empty list on error
    }
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
