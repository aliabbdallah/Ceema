// services/friend_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Follow a user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    // Get target user's data
    final targetUser =
        await _firestore.collection('users').doc(targetUserId).get();
    final targetUserData = targetUser.data() ?? {};

    // Create following relationship
    await _firestore.collection('friends').add({
      'userId': currentUserId,
      'friendId': targetUserId,
      'friendName': targetUserData['username'] ?? '',
      'friendAvatar': targetUserData['profileImageUrl'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'isFollowing': true,
      'isMutual': false,
    });

    // Check if target user is also following current user
    final mutualCheck = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: targetUserId)
        .where('friendId', isEqualTo: currentUserId)
        .get();

    // If mutual, update both documents
    if (mutualCheck.docs.isNotEmpty) {
      final mutualDoc = mutualCheck.docs.first;
      await mutualDoc.reference.update({'isMutual': true});

      final currentRelation = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: targetUserId)
          .get();

      if (currentRelation.docs.isNotEmpty) {
        await currentRelation.docs.first.reference.update({'isMutual': true});
      }
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final querySnapshot = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: currentUserId)
        .where('friendId', isEqualTo: targetUserId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      await doc.reference.delete();

      // Update mutual status for target user's relationship
      final targetRelation = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: targetUserId)
          .where('friendId', isEqualTo: currentUserId)
          .get();

      if (targetRelation.docs.isNotEmpty) {
        await targetRelation.docs.first.reference.update({'isMutual': false});
      }
    }
  }

  // Get user's following list
  Stream<List<Friend>> getFollowing(String userId) {
    try {
      return _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== FOLLOWING QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print('Filter: userId == $userId');
          print('OrderBy: createdAt DESC');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => Friend.fromJson(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      print('Error in getFollowing: $e');
      rethrow;
    }
  }

  // Get user's followers list
  Stream<List<Friend>> getFollowers(String userId) {
    try {
      return _firestore
          .collection('friends')
          .where('friendId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== FOLLOWERS QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print('Filter: friendId == $userId');
          print('OrderBy: createdAt DESC');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => Friend.fromJson(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      print('Error in getFollowers: $e');
      rethrow;
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: targetUserId)
          .get()
          .catchError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== IS FOLLOWING QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print(
              'Filter: userId == $currentUserId AND friendId == $targetUserId');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      });

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error in isFollowing: $e');
      rethrow;
    }
  }

  // Get friendship stats
  Future<Map<String, int>> getFriendshipStats(String userId) async {
    try {
      final following = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .count()
          .get()
          .catchError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== FOLLOWING COUNT QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print('Filter: userId == $userId');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      });

      final followers = await _firestore
          .collection('friends')
          .where('friendId', isEqualTo: userId)
          .count()
          .get()
          .catchError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== FOLLOWERS COUNT QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print('Filter: friendId == $userId');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      });

      final mutualFriends = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('isMutual', isEqualTo: true)
          .count()
          .get()
          .catchError((error) {
        if (error is FirebaseException && error.code == 'failed-precondition') {
          print('====== MUTUAL FRIENDS QUERY ERROR ======');
          print('Query that needs index:');
          print('Collection: friends');
          print('Filter: userId == $userId AND isMutual == true');
          print('Error details: ${error.message}');
          print('================================');
        }
        throw error;
      });

      return {
        'following': following.count ?? 0,
        'followers': followers.count ?? 0,
        'mutualFriends': mutualFriends.count ?? 0,
      };
    } catch (e) {
      print('Error in getFriendshipStats: $e');
      rethrow;
    }
  }
}
