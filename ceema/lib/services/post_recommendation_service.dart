import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/user_preferences.dart';
import '../services/preference_service.dart';
import '../services/post_service.dart';
import '../services/diary_service.dart';
import '../services/follow_service.dart';
import 'dart:math';

class PostRecommendationResult {
  final List<Post> posts;
  final DocumentSnapshot? lastDoc;

  PostRecommendationResult(this.posts, this.lastDoc);
}

class PostRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceService _preferenceService = PreferenceService();
  final PostService _postService = PostService();
  final DiaryService _diaryService = DiaryService();
  final FollowService _followService = FollowService();

  // Cache for movie data with expiration and size limit
  final Map<String, _CachedMovieDetails> _movieCache = {};
  static const Duration _cacheExpiration = Duration(hours: 24);
  static const int _maxCacheSize = 1000; // Maximum number of cached movies

  // Debug flag for logging
  static const bool _debug = false;

  // Get recommended posts for the current user
  Future<PostRecommendationResult> getRecommendedPosts({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('Error: User not authenticated');
        final fallbackPosts = await _getFallbackRecommendations(limit);
        return PostRecommendationResult(fallbackPosts, null);
      }

      _log('Getting recommended posts for user: $userId');

      // 1. Parallel fetch of user data
      final userData = await _fetchUserDataInParallel(userId);
      if (userData.isEmpty) {
        final fallbackPosts = await _getFallbackRecommendations(limit);
        return PostRecommendationResult(fallbackPosts, null);
      }

      // 2. Get candidate posts with pagination
      final candidates = await _getCandidatePosts(
        userId,
        userData['likedPostIds'],
        limit: limit,
        startAfter: startAfter,
      );
      if (candidates.isEmpty) {
        final fallbackPosts = await _getFallbackRecommendations(limit);
        return PostRecommendationResult(fallbackPosts, null);
      }

      // 3. Score posts with collaborative filtering for new users
      final scoredPosts = await _scorePosts(
        candidates,
        userData['preferences'],
        userData['following'],
        userData['watchedMovieIds'],
        isNewUser: userData['isNewUser'],
      );

      // 4. Apply diversity and return top posts
      final posts = _applyDiversityAndReturnTopPosts(scoredPosts, limit);
      return PostRecommendationResult(
        posts,
        null,
      ); // TODO: Return actual lastDoc
    } catch (e) {
      _log('Error getting recommended posts: $e');
      final fallbackPosts = await _getFallbackRecommendations(limit);
      return PostRecommendationResult(fallbackPosts, null);
    }
  }

  // Fetch all user data in parallel
  Future<Map<String, dynamic>> _fetchUserDataInParallel(String userId) async {
    try {
      final futures = await Future.wait([
        _preferenceService.getUserPreferences(),
        _getFollowingIds(userId),
        _getWatchedMovieIds(userId),
        _getLikedPostIds(userId),
      ]);

      final preferences = futures[0] as UserPreferences;
      final following = futures[1] as List<String>;
      final watchedMovieIds = futures[2] as List<String>;
      final likedPostIds = futures[3] as List<String>;

      // Check if user is new (has minimal data)
      final isNewUser =
          preferences.likes.isEmpty &&
          following.isEmpty &&
          watchedMovieIds.isEmpty;

      return {
        'preferences': preferences,
        'following': following,
        'watchedMovieIds': watchedMovieIds,
        'likedPostIds': likedPostIds,
        'isNewUser': isNewUser,
      };
    } catch (e) {
      _log('Error fetching user data: $e');
      return {};
    }
  }

  // Get fallback recommendations when personalized ones can't be generated
  Future<List<Post>> _getFallbackRecommendations(int limit) async {
    try {
      // Try trending posts first
      final trendingResult = await getTrendingPosts(limit: limit);
      if (trendingResult.posts.isNotEmpty) {
        return trendingResult.posts;
      }

      // If no trending posts, get recent posts
      final querySnapshot =
          await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map(
            (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      _log('Error getting fallback recommendations: $e');
      return [];
    }
  }

  // Get candidate posts with pagination
  Future<List<Post>> _getCandidatePosts(
    String userId,
    List<String> likedPostIds, {
    int limit = 30,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('userId', isNotEqualTo: userId)
          .orderBy('userId')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map(
            (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .where((post) => !likedPostIds.contains(post.id))
          .toList();
    } catch (e) {
      _log('Error getting candidate posts: $e');
      return [];
    }
  }

  // Score posts with simplified algorithm for new users
  Future<List<_ScoredPost>> _scorePosts(
    List<Post> posts,
    UserPreferences preferences,
    List<String> following,
    List<String> watchedMovieIds, {
    required bool isNewUser,
  }) async {
    final List<_ScoredPost> scoredPosts = [];

    for (final post in posts) {
      double score = 0.0;
      String primaryReason = '';

      if (isNewUser) {
        // Simplified scoring for new users
        score = _calculateNewUserScore(post, following);
        primaryReason = 'new_user';
      } else {
        // Full scoring algorithm for existing users
        score = await _calculateFullScore(
          post,
          preferences,
          following,
          watchedMovieIds,
        );
        primaryReason = _getScoreReason(score, post, preferences);
      }

      if (score > 0.3) {
        scoredPosts.add(_ScoredPost(post, score, primaryReason));
      }
    }

    return scoredPosts;
  }

  // Simplified scoring for new users with collaborative filtering
  double _calculateNewUserScore(Post post, List<String> following) {
    double score = 0.0;

    // Boost for posts from followed users
    if (following.contains(post.userId)) {
      score += 0.4;
    }

    // Boost for recent posts
    final ageInHours = DateTime.now().difference(post.createdAt).inHours;
    if (ageInHours < 24) {
      score += 0.3;
    } else if (ageInHours < 72) {
      score += 0.2;
    }

    // Boost for engagement with collaborative filtering
    final engagementScore = (post.likes.length + post.commentCount) / 20.0;
    score += min(engagementScore, 0.3);

    // Add collaborative filtering boost based on similar users
    final similarUserBoost = _calculateSimilarUserBoost(post);
    score += similarUserBoost * 0.2;

    return score;
  }

  // Calculate boost based on similar users' interactions
  double _calculateSimilarUserBoost(Post post) {
    // This is a simplified version - in production, you'd want to:
    // 1. Find users with similar preferences
    // 2. Check their interactions with this post
    // 3. Weight their interactions based on similarity
    return 0.0; // Placeholder for now
  }

  // Get movie details with caching and size limit
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    // Check cache first
    if (_movieCache.containsKey(movieId)) {
      final cached = _movieCache[movieId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
        _log('Using cached movie details for $movieId');
        return cached.details;
      }
    }

    // Clean cache if it's too large
    if (_movieCache.length >= _maxCacheSize) {
      _cleanCache();
    }

    try {
      final doc = await _firestore.collection('movies').doc(movieId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _movieCache[movieId] = _CachedMovieDetails(data, DateTime.now());
        return data;
      }

      // If not in Firestore, create minimal details
      final minimalDetails = {
        'id': movieId,
        'title': 'Unknown Movie',
        'genres': [],
      };

      _movieCache[movieId] = _CachedMovieDetails(
        minimalDetails,
        DateTime.now(),
      );
      return minimalDetails;
    } catch (e) {
      _log('Error getting movie details: $e');
      return {};
    }
  }

  // Clean cache by removing oldest entries
  void _cleanCache() {
    final sortedEntries =
        _movieCache.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    // Remove oldest entries until we're under the limit
    while (_movieCache.length >= _maxCacheSize) {
      _movieCache.remove(sortedEntries.removeAt(0).key);
    }
  }

  // Helper method for conditional logging
  void _log(String message) {
    if (_debug) {
      print('[PostRecommendationService] $message');
    }
  }

  // Get trending posts (based on engagement metrics)
  Future<PostRecommendationResult> getTrendingPosts({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      print('[PostRecommendationService] Getting trending posts');
      // Get recent posts (from last 14 days)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      Query query = _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      print(
        '[PostRecommendationService] Found ${querySnapshot.docs.length} recent posts',
      );
      final posts =
          querySnapshot.docs
              .map(
                (doc) =>
                    Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

      // Calculate a trend score for each post based on recency and engagement
      final scoredPosts =
          posts.map((post) {
            final recency =
                1.0 -
                (DateTime.now().difference(post.createdAt).inHours /
                    336); // 336 hours = 14 days
            final engagement =
                (post.likes.length + post.commentCount * 2) /
                10.0; // Weigh comments more

            // Trend score formula: Engagement / Time^1.5 (to prioritize recent engagement)
            final trendScore = engagement / pow(1.0 - recency, 1.5);

            return _ScoredPost(post, trendScore, 'trending');
          }).toList();

      // Sort by trend score
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));

      // Return top trending posts
      final result =
          scoredPosts.take(limit).map((scoredPost) => scoredPost.post).toList();

      print(
        '[PostRecommendationService] Returning ${result.length} trending posts',
      );
      return PostRecommendationResult(
        result,
        querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
    } catch (e) {
      print('[PostRecommendationService] Error getting trending posts: $e');
      return PostRecommendationResult([], null);
    }
  }

  // Get posts from friends (people the user follows)
  Future<PostRecommendationResult> getFriendsPosts({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
        '[PostRecommendationService] Getting posts from friends for user: $userId',
      );
      // Get IDs of users the current user follows
      final following = await _getFollowingIds(userId);
      print(
        '[PostRecommendationService] User follows ${following.length} users',
      );

      if (following.isEmpty) {
        print(
          '[PostRecommendationService] User does not follow anyone, returning empty list',
        );
        return PostRecommendationResult([], null);
      }

      // Get recent posts from followed users
      Query query = _firestore
          .collection('posts')
          .where(
            'userId',
            whereIn: following.take(10).toList(),
          ) // Firestore limitation: maximum 10 values in whereIn
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      print(
        '[PostRecommendationService] Found ${querySnapshot.docs.length} posts from friends',
      );
      final posts =
          querySnapshot.docs
              .map(
                (doc) =>
                    Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

      return PostRecommendationResult(
        posts,
        querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
    } catch (e) {
      print('[PostRecommendationService] Error getting friends posts: $e');
      return PostRecommendationResult([], null);
    }
  }

  // Get similar posts based on a movie the user liked
  Future<List<Post>> getSimilarMoviePosts(
    String movieId, {
    int limit = 10,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
        '[PostRecommendationService] Getting similar posts for movie: $movieId',
      );
      // Get posts about this movie (excluding user's own posts)
      final querySnapshot =
          await _firestore
              .collection('posts')
              .where('movieId', isEqualTo: movieId)
              .where('userId', isNotEqualTo: userId)
              .orderBy('userId')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      print(
        '[PostRecommendationService] Found ${querySnapshot.docs.length} similar posts',
      );
      return querySnapshot.docs
          .map(
            (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print(
        '[PostRecommendationService] Error getting similar movie posts: $e',
      );
      return [];
    }
  }

  // Record user interaction with a recommendation
  Future<void> logInteraction({
    required String postId,
    required String
    actionType, // 'view', 'like', 'comment', 'share', 'save', 'view_duration'
    double? viewPercentage, // Track how much of a post was viewed (0-100)
    int? viewTimeSeconds, // Track how long a user viewed a post in seconds
    String?
    source, // Where the interaction came from (e.g., 'timeline', 'search', 'profile')
    Map<String, dynamic>?
    additionalData, // Any additional context about the interaction
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        return;
      }

      // Validate input parameters
      if (postId.isEmpty) {
        print('[PostRecommendationService] Error: postId cannot be empty');
        return;
      }

      if (actionType.isEmpty) {
        print('[PostRecommendationService] Error: actionType cannot be empty');
        return;
      }

      // Validate view percentage if provided
      if (viewPercentage != null &&
          (viewPercentage < 0 || viewPercentage > 100)) {
        print(
          '[PostRecommendationService] Error: viewPercentage must be between 0 and 100',
        );
        return;
      }

      // Validate view time if provided
      if (viewTimeSeconds != null && viewTimeSeconds < 0) {
        print(
          '[PostRecommendationService] Error: viewTimeSeconds cannot be negative',
        );
        return;
      }

      // Prepare interaction data
      final interactionData = {
        'userId': userId,
        'postId': postId,
        'actionType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
        'source': source ?? 'unknown',
        if (viewPercentage != null) 'viewPercentage': viewPercentage,
        if (viewTimeSeconds != null) 'viewTimeSeconds': viewTimeSeconds,
        if (additionalData != null) 'additionalData': additionalData,
      };

      print(
        '[PostRecommendationService] Logging interaction: $actionType on post $postId',
      );

      // Add to userInteractions collection
      await _firestore.collection('userInteractions').add(interactionData);

      // If this is a view interaction with duration, also update the post's view statistics
      if (actionType == 'view' && viewTimeSeconds != null) {
        final postRef = _firestore.collection('posts').doc(postId);
        await postRef.update({
          'totalViewTime': FieldValue.increment(viewTimeSeconds),
          'viewCount': FieldValue.increment(1),
        });
      }

      // If this is a save action, update the user's saved posts
      if (actionType == 'save') {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('savedPosts')
            .doc(postId)
            .set({'postId': postId, 'savedAt': FieldValue.serverTimestamp()});
      }
    } catch (e, stackTrace) {
      print('[PostRecommendationService] Error logging interaction: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Helper method to get IDs of users the current user follows
  Future<List<String>> _getFollowingIds(String userId) async {
    try {
      print(
        '[PostRecommendationService] Getting following IDs for user: $userId',
      );
      try {
        final follows = await _followService.getFollowing(userId).first;
        final result = follows.map((follow) => follow.followedId).toList();
        print(
          '[PostRecommendationService] Found ${result.length} following IDs',
        );
        return result;
      } catch (e) {
        print('[PostRecommendationService] Error using follow service: $e');
        return [];
      }
    } catch (e) {
      print('[PostRecommendationService] Error getting following IDs: $e');
      return [];
    }
  }

  // Helper method to get IDs of movies the user has watched
  Future<List<String>> _getWatchedMovieIds(String userId) async {
    try {
      print(
        '[PostRecommendationService] Getting watched movie IDs for user: $userId',
      );
      try {
        final diaryEntries = await _diaryService.getDiaryEntries(userId).first;
        final result = diaryEntries.map((entry) => entry.movieId).toList();
        print(
          '[PostRecommendationService] Found ${result.length} watched movie IDs',
        );
        return result;
      } catch (e) {
        print('[PostRecommendationService] Error using diary service: $e');

        // Fallback: direct Firestore query
        print(
          '[PostRecommendationService] Attempting direct query for watched movie IDs',
        );
        final snapshot =
            await _firestore
                .collection('diary_entries')
                .where('userId', isEqualTo: userId)
                .get();

        final result =
            snapshot.docs
                .map((doc) => doc.data()['movieId'] as String)
                .toList();
        print(
          '[PostRecommendationService] Found ${result.length} watched movie IDs using direct query',
        );
        return result;
      }
    } catch (e) {
      print('[PostRecommendationService] Error getting watched movie IDs: $e');
      return [];
    }
  }

  // Helper method to get IDs of posts the user has already liked
  Future<List<String>> _getLikedPostIds(String userId) async {
    try {
      print(
        '[PostRecommendationService] Getting liked post IDs for user: $userId',
      );
      final query =
          await _firestore
              .collection('posts')
              .where('likes', arrayContains: userId)
              .get();

      final result = query.docs.map((doc) => doc.id).toList();
      print(
        '[PostRecommendationService] Found ${result.length} liked post IDs',
      );
      return result;
    } catch (e) {
      print('[PostRecommendationService] Error getting liked post IDs: $e');
      return [];
    }
  }

  // Calculate full score for existing users
  Future<double> _calculateFullScore(
    Post post,
    UserPreferences preferences,
    List<String> following,
    List<String> watchedMovieIds,
  ) async {
    double score = 0.0;

    // 1. Content relevance score (30% weight)
    final contentScore = await _calculateContentScore(post, preferences);
    score += contentScore * 0.3;

    // 2. Actor/Director affinity score (20% weight)
    final talentScore = await _calculateTalentScore(post, preferences);
    score += talentScore * 0.2;

    // 3. Engagement score (30% weight)
    final engagementScore = _calculateEngagementScore(post);
    score += engagementScore * 0.3;

    // 4. View behavior score (20% weight)
    final viewScore = await _calculateViewScoreOptimized(post);
    score += viewScore * 0.2;

    return score;
  }

  // Get the primary reason for a post's score
  String _getScoreReason(double score, Post post, UserPreferences preferences) {
    if (score > 0.7) {
      return 'high_relevance';
    } else if (score > 0.5) {
      return 'good_match';
    } else if (score > 0.3) {
      return 'basic_match';
    }
    return 'low_relevance';
  }

  // Calculate content relevance score based on genres
  Future<double> _calculateContentScore(
    Post post,
    UserPreferences preferences,
  ) async {
    try {
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) return 0.0;

      double genreScore = 0.0;

      if (movieDetails.containsKey('genres')) {
        final movieGenres =
            (movieDetails['genres'] as List)
                .map((g) => g['id'].toString())
                .toList();

        for (final preferredGenre in preferences.likes.where(
          (pref) => pref.type == 'genre',
        )) {
          if (movieGenres.contains(preferredGenre.id)) {
            genreScore += preferredGenre.weight * 0.3;
          }
        }
      }

      return min(1.0, genreScore);
    } catch (e) {
      _log('Error calculating content score: $e');
      return 0.0;
    }
  }

  // Calculate talent affinity score based on credits
  Future<double> _calculateTalentScore(
    Post post,
    UserPreferences preferences,
  ) async {
    try {
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) return 0.0;

      double actorScore = 0.0;
      double directorScore = 0.0;

      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = movieDetails['credits']['cast'] as List;
        final actorIds = cast.map((actor) => actor['id'].toString()).toList();

        for (final preferredActor in preferences.likes.where(
          (pref) => pref.type == 'actor',
        )) {
          if (actorIds.contains(preferredActor.id)) {
            actorScore += preferredActor.weight * 0.15;
          }
        }
      }

      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('crew')) {
        final crew = movieDetails['credits']['crew'] as List;
        final directors =
            crew
                .where((person) => person['job'] == 'Director')
                .map((director) => director['id'].toString())
                .toList();

        for (final preferredDirector in preferences.likes.where(
          (pref) => pref.type == 'director',
        )) {
          if (directors.contains(preferredDirector.id)) {
            directorScore += preferredDirector.weight * 0.2;
          }
        }
      }

      return min(1.0, actorScore + directorScore);
    } catch (e) {
      _log('Error calculating talent score: $e');
      return 0.0;
    }
  }

  // Calculate engagement score based on likes and comments
  double _calculateEngagementScore(Post post) {
    final likeScore = min(1.0, post.likes.length / 50.0);
    final commentScore = min(1.0, post.commentCount / 20.0);
    return (likeScore * 0.4) + (commentScore * 0.6);
  }

  // Optimized view score calculation
  Future<double> _calculateViewScoreOptimized(Post post) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0.0;

      // Get aggregated view stats in a single query with limit
      final viewStats =
          await _firestore
              .collection('userInteractions')
              .where('postId', isEqualTo: post.id)
              .where('userId', isEqualTo: userId)
              .where('actionType', isEqualTo: 'view')
              .orderBy('timestamp', descending: true)
              .limit(10) // Only consider last 10 views
              .get();

      if (viewStats.docs.isEmpty) return 0.0;

      double totalViewTime = 0;
      double totalViewPercentage = 0;
      int viewCount = 0;

      for (final doc in viewStats.docs) {
        final data = doc.data();
        totalViewTime += data['viewTimeSeconds'] ?? 0;
        totalViewPercentage += data['viewPercentage'] ?? 0;
        viewCount++;
      }

      final avgViewTime = totalViewTime / viewCount;
      final avgCompletionRate = totalViewPercentage / viewCount;

      final viewTimeScore = min(1.0, avgViewTime / 30.0);
      final completionScore = avgCompletionRate / 100.0;

      return (viewTimeScore * 0.6) + (completionScore * 0.4);
    } catch (e) {
      _log('Error calculating view score: $e');
      return 0.0;
    }
  }

  // Apply diversity and return top posts
  List<Post> _applyDiversityAndReturnTopPosts(
    List<_ScoredPost> scoredPosts,
    int limit,
  ) {
    final List<Post> result = [];
    final Set<String> usedMovieIds = {};
    final Set<String> usedUserIds = {};
    final Map<String, int> movieCounts = {};
    final Map<String, int> userCounts = {};

    // Sort by score first
    scoredPosts.sort((a, b) => b.score.compareTo(a.score));

    for (final scoredPost in scoredPosts) {
      final post = scoredPost.post;
      final movieId = post.movieId;
      final userId = post.userId;

      // Skip if we've already used this movie or user too many times
      final movieCount = movieCounts[movieId] ?? 0;
      final userCount = userCounts[userId] ?? 0;

      if (movieCount >= 2) continue; // Max 2 posts per movie
      if (userCount >= 3) continue; // Max 3 posts per user

      // Add to result
      result.add(post);
      usedMovieIds.add(movieId);
      usedUserIds.add(userId);
      movieCounts[movieId] = movieCount + 1;
      userCounts[userId] = userCount + 1;

      if (result.length >= limit) break;
    }

    return result;
  }
}

// Helper class for cached movie details
class _CachedMovieDetails {
  final Map<String, dynamic> details;
  final DateTime timestamp;

  _CachedMovieDetails(this.details, this.timestamp);
}

// Helper class to represent a scored post
class _ScoredPost {
  final Post post;
  final double score;
  final String primaryReason;

  _ScoredPost(this.post, this.score, this.primaryReason);
}

// Helper for math operations
class Math {
  static double min(double a, double b) => a < b ? a : b;
  static double pow(double a, double b) => pow(a, b).toDouble();
}
