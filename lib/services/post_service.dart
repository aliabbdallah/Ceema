import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/movie.dart';
import 'notification_service.dart';
import 'follow_service.dart';
import 'profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../utils/user_data_cache.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FollowService _followService = FollowService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  // Cache implementation with improved TTL
  final Map<String, List<Post>> _postsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Debounce timer for rapid state changes
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // Logging configuration
  static const bool _debugMode = true; // Set to false in production
  static const String _logPrefix = '[PostService]';

  void _log(String message, {String level = 'INFO'}) {
    if (_debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('$_logPrefix [$timestamp] [$level] $message');
    }
  }

  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  void _updateCache(String key, List<Post> posts) {
    _postsCache[key] = posts;
    _cacheTimestamps[key] = DateTime.now();
    _log('Cache updated for key: $key with ${posts.length} posts');
  }

  void invalidateCache() {
    _postsCache.clear();
    _cacheTimestamps.clear();
    _log('Cache invalidated');
  }

  void invalidateUserCache(String userId) {
    final keysToRemove =
        _postsCache.keys.where((key) => key.contains(userId)).toList();
    for (final key in keysToRemove) {
      _postsCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    _log('User cache invalidated for userId: $userId');
  }

  // Debounced cache invalidation
  void debouncedInvalidateCache() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      invalidateCache();
    });
  }

  // Debounced user cache invalidation
  void debouncedInvalidateUserCache(String userId) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      invalidateUserCache(userId);
    });
  }

  Future<void> createPost({
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    required Movie movie,
    double rating = 0.0,
  }) async {
    _log('Creating post for user: $userId');
    try {
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

      // Use debounced cache invalidation
      debouncedInvalidateCache();
      debouncedInvalidateUserCache(userId);
      _log('Post created successfully');
    } catch (e, stackTrace) {
      _log('Error creating post: $e\n$stackTrace', level: 'ERROR');
      rethrow;
    }
  }

  // Fetch all posts (one-time) with improved caching
  Future<List<Post>> fetchPostsOnce({
    int limit = 50,
    bool skipCache = false,
  }) async {
    const cacheKey = 'all_posts';
    if (!skipCache && _isCacheValid(cacheKey)) {
      _log('Cache hit for all posts');
      return _postsCache[cacheKey]!;
    }

    _log('Fetching posts with limit: $limit');
    try {
      final querySnapshot =
          await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      _log('Fetched ${querySnapshot.docs.length} post docs');

      final posts = await _processPostSnapshot(querySnapshot);
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!skipCache) {
        _updateCache(cacheKey, posts);
      }

      _log('Returning ${posts.length} posts');
      return posts;
    } catch (e, stackTrace) {
      _log('Error in fetchPostsOnce: $e\n$stackTrace', level: 'ERROR');
      return [];
    }
  }

  // Fetch posts for a specific user (one-time)
  Future<List<Post>> fetchUserPostsOnce(String userId) async {
    final cacheKey = 'user_posts_$userId';
    if (_isCacheValid(cacheKey)) {
      print('[PostService] fetchUserPostsOnce: Cache hit for user $userId');
      return _postsCache[cacheKey]!;
    }

    print('[PostService] fetchUserPostsOnce called for user: $userId');
    try {
      final querySnapshot =
          await _firestore
              .collection('posts')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get();
      print(
        '[PostService] fetchUserPostsOnce: Fetched ${querySnapshot.docs.length} post docs for user $userId.',
      );
      final posts = await _processPostSnapshot(querySnapshot);

      // Update cache
      _updateCache(cacheKey, posts);

      print(
        '[PostService] fetchUserPostsOnce: Returning ${posts.length} posts for user $userId.',
      );
      return posts;
    } catch (e, stackTrace) {
      print(
        '[PostService] Error in fetchUserPostsOnce for $userId: $e\n$stackTrace',
      );
      return [];
    }
  }

  // Fetch posts from followed users (one-time)
  Future<List<Post>> fetchFollowingPostsOnce(
    String userId, {
    int limit = 50,
  }) async {
    final cacheKey = 'following_posts_$userId';
    if (_isCacheValid(cacheKey)) {
      print(
        '[PostService] fetchFollowingPostsOnce: Cache hit for user $userId',
      );
      return _postsCache[cacheKey]!;
    }

    final startTime = DateTime.now();
    print('[PostService] fetchFollowingPostsOnce called for user: $userId ===');

    try {
      print(
        '[PostService] fetchFollowingPostsOnce: Fetching following users...',
      );
      // Use the new one-time fetch method from FollowService
      final followingIds = await _followService.getFollowingIdsOnce(userId);
      print(
        '[PostService] fetchFollowingPostsOnce: Found ${followingIds.length} followed users.',
      );

      if (followingIds.isEmpty) {
        print(
          '[PostService] fetchFollowingPostsOnce: No followed users found, returning empty list',
        );
        return [];
      }

      // Firestore 'whereIn' query limit is 30 for `.get()` as well.
      // Chunking is necessary if following > 30.
      List<Post> allPosts = [];
      final chunkSize = 30;
      List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];

      for (var i = 0; i < followingIds.length; i += chunkSize) {
        final chunk = followingIds.skip(i).take(chunkSize).toList();
        print(
          '[PostService] fetchFollowingPostsOnce: Querying posts chunk ${i ~/ chunkSize + 1} for ${chunk.length} users.',
        );
        futures.add(
          _firestore
              .collection('posts')
              .where('userId', whereIn: chunk)
              .orderBy('createdAt', descending: true)
              .get(),
        );
      }

      // Wait for all chunk queries to complete
      final snapshots = await Future.wait(futures);
      print('[PostService] fetchFollowingPostsOnce: All post chunks fetched.');

      // Process all snapshots
      List<QuerySnapshot<Map<String, dynamic>>> allQuerySnapshots =
          snapshots.expand((snap) => [snap]).toList();
      // Flatten documents and process them
      final combinedSnapshotDocs =
          allQuerySnapshots.expand((snap) => snap.docs).toList();
      final combinedQuerySnapshot = _docsToSnapshot(combinedSnapshotDocs);

      allPosts = await _processPostSnapshot(combinedQuerySnapshot);

      // Sort ALL fetched posts and apply the final limit
      print(
        '[PostService] fetchFollowingPostsOnce: Sorting ${allPosts.length} total posts...',
      );
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (allPosts.length > limit) {
        allPosts = allPosts.sublist(0, limit);
      }

      // Update cache
      _updateCache(cacheKey, allPosts);

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      print(
        '[PostService] fetchFollowingPostsOnce: Completed in ${totalTime}ms. Returning ${allPosts.length} posts.',
      );
      return allPosts;
    } catch (e, stackTrace) {
      print('[PostService] Error in fetchFollowingPostsOnce: $e\n$stackTrace');
      return [];
    }
  }

  // Helper to convert List<QueryDocumentSnapshot> to QuerySnapshot mock
  // (Needed because _processPostSnapshot expects QuerySnapshot)
  QuerySnapshot<Map<String, dynamic>> _docsToSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // This is a bit of a hack. We create a mock QuerySnapshot.
    // A better approach might be to refactor _processPostSnapshot to accept List<QueryDocumentSnapshot>
    return _MockQuerySnapshot(docs);
  }

  // Helper method to process a QuerySnapshot and fetch user data
  Future<List<Post>> _processPostSnapshot(
    QuerySnapshot<Map<String, dynamic>> postsSnapshot,
  ) async {
    print(
      '[PostService] _processPostSnapshot processing ${postsSnapshot.docs.length} docs.',
    );
    if (postsSnapshot.docs.isEmpty) return [];

    final userIdsInSnapshot =
        postsSnapshot.docs
            .map((doc) => doc.data()['userId'] as String?)
            .where((id) => id != null)
            .toSet();

    print(
      '[PostService] _processPostSnapshot: Fetching user data for ${userIdsInSnapshot.length} unique users.',
    );
    Map<String, Map<String, dynamic>> usersDataMap = {};
    try {
      await Future.wait(
        userIdsInSnapshot.map((id) async {
          // Try to get user data from cache first
          final cachedUser = UserDataCache.get(id!);
          if (cachedUser != null) {
            usersDataMap[id] = cachedUser.toJson();
          } else {
            // If not in cache, fetch from ProfileService and cache it
            final userData = await _getUserData(id);
            usersDataMap[id] = userData;
            if (userData.isNotEmpty) {
              UserDataCache.set(id, UserModel.fromJson(userData, id));
            }
          }
        }),
      );
      print('[PostService] _processPostSnapshot: User data fetched.');
    } catch (e) {
      print(
        '[PostService] _processPostSnapshot: Error fetching user data - $e',
      );
      // Continue without user data
    }

    final posts =
        postsSnapshot.docs.map((doc) {
          final postData = doc.data();
          final postUserId = postData['userId'] as String?;
          final userData = usersDataMap[postUserId] ?? {};

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
    print(
      '[PostService] _processPostSnapshot returning ${posts.length} processed posts.',
    );
    return posts;
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
    final postRef = _firestore.collection('posts').doc(postId);
    final post = await postRef.get();
    if (post.exists) {
      final userId = post.data()?['userId'] as String?;
      await postRef.delete();

      // Invalidate relevant caches
      invalidateCache();
      if (userId != null) {
        invalidateUserCache(userId);
      }
    }
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

    final postRef = _firestore.collection('posts').doc(postId);
    final post = await postRef.get();
    if (post.exists) {
      final userId = post.data()?['userId'] as String?;
      await postRef.update(updateData);

      // Invalidate relevant caches
      invalidateCache();
      if (userId != null) {
        invalidateUserCache(userId);
      }
    }
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

  // Fetch user data (using cache)
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final userModel = await _profileService.getUserProfile(userId);
      final userData = userModel.toJson();
      // Ensure createdAt is included for cache validation
      if (!userData.containsKey('createdAt')) {
        userData['createdAt'] = Timestamp.fromDate(DateTime.now());
      }
      return userData;
    } catch (e) {
      print('Error getting user data for $userId: $e');
      return {}; // Return empty map on error
    }
  }

  // Handle refresh for different feed types
  Future<List<Post>> refreshFeed(String feedType, {int limit = 50}) async {
    _log('Refreshing feed for type: $feedType');

    try {
      switch (feedType) {
        case 'following':
          final userId = _auth.currentUser?.uid;
          if (userId == null) throw Exception('User not authenticated');
          // Invalidate user cache and fetch fresh following posts
          invalidateUserCache(userId);
          return await fetchFollowingPostsOnce(userId, limit: limit);

        default:
          throw Exception('Invalid feed type: $feedType');
      }
    } catch (e, stackTrace) {
      _log('Error refreshing feed: $e\n$stackTrace', level: 'ERROR');
      rethrow;
    }
  }
}

// Mock class to satisfy _processPostSnapshot signature after chunking
class _MockQuerySnapshot<T extends Object?> implements QuerySnapshot<T> {
  @override
  final List<QueryDocumentSnapshot<T>> docs;

  _MockQuerySnapshot(this.docs);

  @override
  List<DocumentChange<T>> get docChanges => throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => docs.length;
}
