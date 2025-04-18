import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/movie.dart';
import 'notification_service.dart';
import 'follow_service.dart';
import 'profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FollowService _followService = FollowService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  // Cache for posts
  final Map<String, List<Post>> _postsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  // Use different expiration for general and following posts
  static const Duration _generalCacheExpiration = Duration(minutes: 5);
  static const Duration _followingCacheExpiration = Duration(minutes: 10);

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

  // Get all posts with user data
  Stream<List<Post>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit to most recent 50 posts for better performance
        .snapshots()
        .asyncMap((snapshot) async {
          // Directly fetch and process posts without checking cache
          final posts = await Future.wait(
            snapshot.docs.map((doc) async {
              final postData = doc.data();
              final userData = await _getUserData(postData['userId']);

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

          // Sort by creation time
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Return fresh posts directly
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
          final cacheKey = 'user_posts_$userId';
          final now = DateTime.now();

          // Check cache first
          if (_postsCache.containsKey(cacheKey) &&
              _cacheTimestamps.containsKey(cacheKey) &&
              now.difference(_cacheTimestamps[cacheKey]!) <
                  _generalCacheExpiration) {
            // Use general expiration
            return _postsCache[cacheKey]!;
          }

          final userData = await _getUserData(userId);
          final posts =
              snapshot.docs.map((doc) {
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

          // Update cache
          _postsCache[cacheKey] = posts;
          _cacheTimestamps[cacheKey] = now;

          return posts;
        });
  }

  Stream<List<Post>> getFollowingPosts(String userId) async* {
    final cacheKey = 'following_posts_$userId';
    final now = DateTime.now();

    // Check cache first
    if (_postsCache.containsKey(cacheKey) &&
        _cacheTimestamps.containsKey(cacheKey) &&
        now.difference(_cacheTimestamps[cacheKey]!) <
            _followingCacheExpiration) {
      // Use following-specific expiration
      yield _postsCache[cacheKey]!;
      return; // Return cached data and exit
    }

    try {
      // Get list of users that the current user follows
      final following = await _followService.getFollowing(userId).first;
      final followingIds =
          following.map((follow) => follow.followedId).toList();

      if (followingIds.isEmpty) {
        _postsCache[cacheKey] = []; // Cache empty list
        _cacheTimestamps[cacheKey] = now;
        yield [];
        return;
      }

      // Fetch posts in chunks due to Firestore 'whereIn' limit
      List<Post> allPosts = [];
      for (var i = 0; i < followingIds.length; i += 10) {
        final chunk = followingIds.skip(i).take(10).toList();
        final querySnapshot =
            await _firestore
                .collection('posts')
                .where('userId', whereIn: chunk)
                // No need to order here, we'll sort the combined list later
                .get();

        // Fetch user data for authors in this chunk concurrently
        final postsFromChunk = await Future.wait(
          querySnapshot.docs.map((doc) async {
            final postData = doc.data();
            final userData = await _getUserData(postData['userId']);
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
        allPosts.addAll(postsFromChunk);
      }

      // Sort the combined list by creation time
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Update cache
      _postsCache[cacheKey] = allPosts;
      _cacheTimestamps[cacheKey] = now;

      yield allPosts; // Yield the complete, sorted list
    } catch (e) {
      print('Error getting following posts: $e');
      yield []; // Yield empty list on error
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

  // Update a post's content, movie, and rating
  Future<void> updatePostDetails(
    String postId,
    String newContent,
    Movie? movie,
    double rating,
  ) async {
    final updateData = <String, dynamic>{};
    updateData['content'] = newContent;
    updateData['rating'] = rating;
    updateData['editedAt'] = FieldValue.serverTimestamp();

    if (movie != null) {
      updateData['movieId'] = movie.id;
      updateData['movieTitle'] = movie.title;
      updateData['moviePosterUrl'] = movie.posterUrl;
      updateData['movieYear'] = movie.year;
      updateData['movieOverview'] = movie.overview;
    } else {
      // If movie is null, clear movie-related fields
      updateData['movieId'] = '';
      updateData['movieTitle'] = '';
      updateData['moviePosterUrl'] = '';
      updateData['movieYear'] = '';
      updateData['movieOverview'] = '';
      updateData['rating'] = 0.0; // Also reset rating if movie is removed
    }

    await _firestore.collection('posts').doc(postId).update(updateData);
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
    try {
      final userModel = await _profileService.getUserProfile(userId);
      return userModel.toJson();
    } catch (e) {
      print('Error getting user data: $e');
      return {};
    }
  }

  // Clear cache for a specific key (used for manual refresh)
  void clearCache(String key) {
    _postsCache.remove(key);
    _cacheTimestamps.remove(key);
    // If clearing following posts, trigger a refetch
    if (key.startsWith('following_posts_')) {
      final userId = key.substring('following_posts_'.length);
      // This assumes you have a way to get the controller for this user.
      // A better approach might be needed depending on your app structure.
      // For simplicity, this example won't directly trigger refetch here.
      // The UI refresh action should call clearCache and then potentially
      // re-listen or trigger a fetch.
    }
  }

  // Clear all cache
  void clearAllCache() {
    _postsCache.clear();
    _cacheTimestamps.clear();
  }
}
