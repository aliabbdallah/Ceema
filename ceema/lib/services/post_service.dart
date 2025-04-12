import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/movie.dart';
import 'notification_service.dart';
import 'follow_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FollowService _followService = FollowService();

  // User data cache
  final Map<String, Map<String, dynamic>> _userCache = {};

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
        .asyncMap((snapshot) async {
          final posts = await Future.wait(
            snapshot.docs.map((doc) async {
              final postData = doc.data();
              // Fetch the current user data (using cache)
              final userData = await _getUserData(postData['userId']);

              // Create post with updated user data
              return Post.fromJson({
                ...postData,
                'username': userData['username'] ?? postData['userName'],
                'displayName':
                    userData['displayName'] ??
                    userData['username'] ??
                    postData['userName'],
                'profileImageUrl':
                    userData['profileImageUrl'] ?? postData['userAvatar'],
              }, doc.id);
            }),
          );

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
        .asyncMap((snapshot) async {
          // Fetch the current user data (using cache)
          final userData = await _getUserData(userId);

          return snapshot.docs.map((doc) {
            final postData = doc.data();
            return Post.fromJson({
              ...postData,
              'username': userData['username'] ?? postData['userName'],
              'displayName':
                  userData['displayName'] ??
                  userData['username'] ??
                  postData['userName'],
              'profileImageUrl':
                  userData['profileImageUrl'] ?? postData['userAvatar'],
            }, doc.id);
          }).toList();
        });
  }

  /// Get posts from users that the current user follows
  /// Uses a direct querying approach for reliability
  Stream<List<Post>> getFollowingPosts(String userId) {
    // Create a StreamController to manage our combined data
    final controller = StreamController<List<Post>>.broadcast();

    // Function to load data
    Future<void> loadPosts() async {
      try {
        // Show loading state
        controller.add([]);

        // Get users that current user follows (limit to 30 for performance)
        final following = await _followService.getFollowing(userId).first;

        // If not following anyone, return empty list
        if (following.isEmpty) {
          controller.add([]);
          return;
        }

        // Get IDs of followed users (limited to 30 most recent)
        final followingIds =
            following
                .take(30) // Limit to 30 followed users for performance
                .map((follow) => follow.followedId)
                .toList();

        // Fetch posts in smaller direct batches to avoid Firestore limitations
        final allPosts = <Post>[];

        // Process in batches of 5 users at a time (for parallel fetching)
        for (var i = 0; i < followingIds.length; i += 5) {
          final end =
              (i + 5 < followingIds.length) ? i + 5 : followingIds.length;
          final batchIds = followingIds.sublist(i, end);

          // Create a list of futures for each user's posts
          final futures =
              batchIds
                  .map(
                    (followedId) =>
                        _firestore
                            .collection('posts')
                            .where('userId', isEqualTo: followedId)
                            .orderBy('createdAt', descending: true)
                            .limit(10) // Limit to 10 most recent posts per user
                            .get(),
                  )
                  .toList();

          // Wait for all futures to complete
          final results = await Future.wait(futures);

          // Process each result
          for (final querySnapshot in results) {
            final docs = querySnapshot.docs;
            if (docs.isEmpty) continue;

            // Process each document
            for (final doc in docs) {
              final postData = doc.data();
              final postUserId = postData['userId'] as String;

              // Get user data (from cache)
              final userData = await _getUserData(postUserId);

              // Create post object
              final post = Post.fromJson({
                ...postData,
                'username': userData['username'] ?? postData['userName'],
                'displayName':
                    userData['displayName'] ??
                    userData['username'] ??
                    postData['userName'],
                'profileImageUrl':
                    userData['profileImageUrl'] ?? postData['userAvatar'],
              }, doc.id);

              allPosts.add(post);
            }
          }
        }

        // Sort posts by creation date (newest first)
        allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Send sorted posts to the stream
        controller.add(allPosts);
      } catch (e) {
        controller.addError(e);
      }
    }

    // Initial load
    loadPosts();

    // Set up a timer for periodic refresh (every 30 seconds)
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!controller.isClosed) {
        loadPosts();
      }
    });

    // Clean up when the stream is closed
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };

    return controller.stream;
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
            final userData = await _getUserData(userId);
            final userName = userData['displayName'] ?? 'A user';
            final userPhotoUrl = userData['photoURL'];

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

  // Add a reply to a comment
  Future<void> addReply({
    required String postId,
    required String parentCommentId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
  }) async {
    final commentRef =
        _firestore.collection('posts').doc(postId).collection('comments').doc();

    // Get the parent comment data
    final parentCommentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(parentCommentId);
    final parentComment = await parentCommentRef.get();

    if (!parentComment.exists) {
      throw Exception('Parent comment not found');
    }

    // Start a batch write
    final batch = _firestore.batch();

    // Add the reply
    batch.set(commentRef, {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'postId': postId,
      'parentCommentId': parentCommentId,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': <String>[],
      'replyCount': 0,
    });

    // Update the parent comment's reply count
    batch.update(parentCommentRef, {'replyCount': FieldValue.increment(1)});

    // Execute the batch
    await batch.commit();

    // Notify the parent comment owner about the reply
    final parentCommentOwnerId = parentComment.data()?['userId'] as String;
    if (parentCommentOwnerId != userId) {
      try {
        await _notificationService.createCommentReplyNotification(
          recipientUserId: parentCommentOwnerId,
          senderUserId: userId,
          senderName: userName,
          senderPhotoUrl: userAvatar,
          postId: postId,
          commentId: parentCommentId,
          replyText: content,
        );
      } catch (e) {
        print('Error creating reply notification: $e');
      }
    }
  }

  // Get comments for a post with optional parent comment filter
  Stream<List<dynamic>> getComments(String postId, {String? parentCommentId}) {
    Query query = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments');

    // If parentCommentId is provided, get replies to that comment
    if (parentCommentId != null) {
      query = query.where('parentCommentId', isEqualTo: parentCommentId);
    }
    // For top-level comments, don't filter by parentCommentId at all
    // This will show all comments that don't have a parentCommentId field

    return query.orderBy('createdAt', descending: false).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Only include comments without parentCommentId when getting top-level comments
            if (parentCommentId == null && data['parentCommentId'] != null) {
              return null;
            }
            return {
              'id': doc.id,
              'postId': postId,
              ...data,
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'likes': List<String>.from(data['likes'] ?? []),
              'replyCount': data['replyCount'] ?? 0,
            };
          })
          .where((comment) => comment != null)
          .toList();
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
      'postId': postId,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': <String>[], // Initialize as empty String array
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
  Future<void> toggleCommentLike(
    String commentId,
    String postId,
    String userId,
  ) async {
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final comment = await commentRef.get();

    if (comment.exists) {
      final data = comment.data() ?? {};
      final likes = List<String>.from(data['likes'] ?? []);

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
    // Get a reference to the post and comment
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    // Delete the comment
    await commentRef.delete();

    // Get all comments to count them
    final commentsSnapshot = await postRef.collection('comments').get();
    final commentCount = commentsSnapshot.docs.length;

    // Update the post with the actual comment count
    await postRef.update({'commentCount': commentCount});
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
        .asyncMap((snapshot) async {
          final posts = await Future.wait(
            snapshot.docs.map((doc) async {
              final postData = doc.data();
              // Fetch the current user data (using cache)
              final userData = await _getUserData(postData['userId']);

              // Create post with updated user data
              return Post.fromJson({
                ...postData,
                'username': userData['username'] ?? postData['userName'],
                'displayName':
                    userData['displayName'] ??
                    userData['username'] ??
                    postData['userName'],
                'profileImageUrl':
                    userData['profileImageUrl'] ?? postData['userAvatar'],
              }, doc.id);
            }),
          );
          return posts;
        });
  }

  // Get comments count for a post
  Stream<int> getCommentsCount(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Fetch user data with caching
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    _userCache[userId] = userData;
    return userData;
  }
}
