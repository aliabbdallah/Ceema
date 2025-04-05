import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/movie.dart';
import 'notification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

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
      final posts = snapshot.docs
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

  // Get posts from friends (users the current user follows)
  Stream<List<Post>> getFriendsPosts(String userId) async* {
    try {
      // Get the list of users that the current user follows
      final friendsSnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .get();

      // Extract friend IDs
      final List<String> friendIds = friendsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toList();

      // Add the current user's ID to include their posts too
      friendIds.add(userId);

      // If the user doesn't follow anyone, just return their own posts
      if (friendIds.length <= 1) {
        yield* getUserPosts(userId);
        return;
      }

      // Handle large friend lists by breaking into chunks of 10 (Firestore limit)
      final chunks = <List<String>>[];
      for (var i = 0; i < friendIds.length; i += 10) {
        chunks.add(
          friendIds.sublist(
            i,
            i + 10 > friendIds.length ? friendIds.length : i + 10,
          ),
        );
      }

      // Query each chunk and combine results
      yield* Stream.periodic(const Duration(seconds: 5), (_) async {
        final allPosts = <Post>[];

        for (final chunk in chunks) {
          final snapshot = await _firestore
              .collection('posts')
              .where('userId', whereIn: chunk)
              .orderBy('createdAt', descending: true)
              .get();

          allPosts.addAll(
            snapshot.docs.map((doc) => Post.fromJson(doc.data(), doc.id)),
          );
        }

        // Sort all posts by creation time
        allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return allPosts;
      }).asyncMap((future) => future);
    } catch (e) {
      print('Error getting friends posts: $e');
      // Return an empty list in case of error
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
          'likes': FieldValue.arrayRemove([userId])
        });
        // No notification for unlikes
      } else {
        // Like
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId])
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
        'shares': FieldValue.arrayUnion([userId])
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
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
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
          'likes': FieldValue.arrayRemove([userId])
        });
      } else {
        // Like
        await commentRef.update({
          'likes': FieldValue.arrayUnion([userId])
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
