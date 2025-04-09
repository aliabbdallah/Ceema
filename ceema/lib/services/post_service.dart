import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/movie.dart';
import 'notification_service.dart';
import 'follow_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FollowService _followService = FollowService();

  Future<void> createPost({
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    required Movie movie,
    double rating = 0.0,
  }) async {
    await _firestore.collection('posts').add({
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'movieId': movie.id,
      'movieTitle': movie.title,
      'moviePosterUrl': movie.posterUrl,
      'movieYear': movie.year,
      'movieOverview': movie.overview,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'commentCount': 0,
      'shares': [],
      'rating': rating,
    });
  }

  Stream<List<Post>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit to most recent 50 posts for better performance
        .snapshots()
        .map((snapshot) {
          final posts =
              snapshot.docs
                  .map((doc) => Post.fromJson(doc.data(), doc.id))
                  .toList();

          // Sort by creation time to ensure newest posts appear first
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  // Get posts for a specific user
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  // Get posts from users that the current user follows
  Stream<List<Post>> getFollowingPosts(String userId) async* {
    try {
      // Get list of users that the current user follows
      final following = await _followService.getFollowing(userId).first;
      final followingIds =
          following.map((follow) => follow.followedId).toList();

      if (followingIds.isEmpty) {
        yield [];
        return;
      }

      // Firestore has a limit of 10 values in whereIn, so we need to chunk the list
      for (var i = 0; i < followingIds.length; i += 10) {
        final chunk = followingIds.skip(i).take(10).toList();
        final querySnapshot =
            await _firestore
                .collection('posts')
                .where('userId', whereIn: chunk)
                .orderBy('createdAt', descending: true)
                .get();

        final posts =
            querySnapshot.docs
                .map((doc) => Post.fromJson(doc.data(), doc.id))
                .toList();
        yield posts;
      }
    } catch (e) {
      print('Error getting following posts: $e');
      yield [];
    }
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final post = await postRef.get();

    if (post.exists) {
      final likes = List<String>.from(post.data()?['likes'] ?? []);
      final postOwnerId = post.data()?['userId'] as String;

      // Don't notify if the user is liking their own post
      final shouldNotify = postOwnerId != userId;

      if (likes.contains(userId)) {
        // Unlike
        await postRef.update({
          'likes': FieldValue.arrayRemove([userId]),
        });
        // No notification for unlikes
      } else {
        // Like
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId]),
        });

        // Notify the post owner about the like
        if (shouldNotify) {
          try {
            final userData =
                await _firestore.collection('users').doc(userId).get();
            final userName = userData.data()?['displayName'] ?? 'A user';
            final userPhotoUrl = userData.data()?['photoURL'];

            await _notificationService.createPostLikeNotification(
              recipientUserId: postOwnerId,
              senderUserId: userId,
              senderName: userName,
              senderPhotoUrl: userPhotoUrl,
              postId: postId,
            );
          } catch (e) {
            print('Error creating like notification: $e');
          }
        }
      }
    }
  }

  // Share a post
  Future<void> sharePost(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final post = await postRef.get();

    if (post.exists) {
      await postRef.update({
        'shares': FieldValue.arrayUnion([userId]),
      });
    }
  }

  // Get comments for a post
  Stream<List<dynamic>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false) // Show oldest comments first
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Add a comment to a post
  Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
  }) async {
    final commentRef =
        _firestore.collection('posts').doc(postId).collection('comments').doc();

    // Get the post data to check the post owner
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final postOwnerId = postDoc.data()?['userId'] as String;

    // Don't notify if the user is commenting on their own post
    final shouldNotify = postOwnerId != userId;

    // Start a batch write
    final batch = _firestore.batch();

    // Add the comment
    batch.set(commentRef, {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
    });

    // Update the comment count on the post
    batch.update(_firestore.collection('posts').doc(postId), {
      'commentCount': FieldValue.increment(1),
    });

    // Execute the batch
    await batch.commit();

    // Notify the post owner about the comment
    if (shouldNotify) {
      try {
        await _notificationService.createPostCommentNotification(
          recipientUserId: postOwnerId,
          senderUserId: userId,
          senderName: userName,
          senderPhotoUrl: userAvatar,
          postId: postId,
          commentText: content,
        );
      } catch (e) {
        print('Error creating comment notification: $e');
      }
    }
  }

  // Toggle like on a comment
  Future<void> toggleCommentLike(String commentId, String userId) async {
    final commentRef = _firestore.collection('comments').doc(commentId);
    final comment = await commentRef.get();

    if (comment.exists) {
      final likes = List<String>.from(comment.data()?['likes'] ?? []);

      if (likes.contains(userId)) {
        // Unlike
        await commentRef.update({
          'likes': FieldValue.arrayRemove([userId]),
        });
      } else {
        // Like
        await commentRef.update({
          'likes': FieldValue.arrayUnion([userId]),
        });
      }
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String postId) async {
    await _firestore.collection('comments').doc(commentId).delete();

    // Update the comment count on the post
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  // Update a post's content
  Future<void> updatePostContent(String postId, String newContent) async {
    await _firestore.collection('posts').doc(postId).update({
      'content': newContent,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get posts ordered by likes
  Stream<List<Post>> getPostsOrderedByLikes({int limit = 20}) {
    return _firestore
        .collection('posts')
        .orderBy('likes', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromJson(doc.data(), doc.id))
              .toList();
        });
  }
}
