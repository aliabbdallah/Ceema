import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/user_preferences.dart';
import '../services/preference_service.dart';
import '../services/post_service.dart';
import '../services/friend_service.dart';
import '../services/diary_service.dart';
import 'dart:math';

class PostRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceService _preferenceService = PreferenceService();
  final PostService _postService = PostService();
  final FriendService _friendService = FriendService();
  final DiaryService _diaryService = DiaryService();

  // Cache for movie data to avoid repeated queries
  final Map<String, Map<String, dynamic>> _movieCache = {};

  // Get recommended posts for the current user
  Future<List<Post>> getRecommendedPosts({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '[PostRecommendationService] Getting recommended posts for user: $userId');

      // 1. Get user data needed for recommendations
      print('[PostRecommendationService] Fetching user preferences');
      final userPreferences = await _preferenceService.getUserPreferences();
      print(
          '[PostRecommendationService] User preferences loaded: ${userPreferences.likes.length} likes, ${userPreferences.dislikes.length} dislikes');

      print('[PostRecommendationService] Fetching following IDs');
      final following = await _getFollowingIds(userId);
      print(
          '[PostRecommendationService] User follows ${following.length} users');

      print('[PostRecommendationService] Fetching watched movie IDs');
      final watchedMovieIds = await _getWatchedMovieIds(userId);
      print(
          '[PostRecommendationService] User has watched ${watchedMovieIds.length} movies');

      print('[PostRecommendationService] Fetching liked post IDs');
      final likedPostIds = await _getLikedPostIds(userId);
      print(
          '[PostRecommendationService] User has liked ${likedPostIds.length} posts');

      // 2. Fetch a pool of candidate posts
      print('[PostRecommendationService] Getting candidate posts');
      final candidates = await _getCandidatePosts(userId, likedPostIds);
      print(
          '[PostRecommendationService] Found ${candidates.length} candidate posts');

      if (candidates.isEmpty) {
        print(
            '[PostRecommendationService] No candidate posts found, returning empty list');
        return [];
      }

      // 3. Score each post
      print('[PostRecommendationService] Scoring posts');
      final scoredPosts = await _scorePosts(
          candidates, userPreferences, following, watchedMovieIds);
      print('[PostRecommendationService] Scored ${scoredPosts.length} posts');

      // 4. Sort by score and return the top posts
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));

      final result =
          scoredPosts.take(limit).map((scoredPost) => scoredPost.post).toList();

      print(
          '[PostRecommendationService] Returning ${result.length} recommended posts');
      return result;
    } catch (e) {
      print('[PostRecommendationService] Error getting recommended posts: $e');
      return [];
    }
  }

  // Get trending posts (based on engagement metrics)
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    try {
      print('[PostRecommendationService] Getting trending posts');
      // Get recent posts (from last 14 days)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final querySnapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .orderBy('createdAt', descending: true)
          .limit(50) // Get a larger pool first for sorting
          .get();

      print(
          '[PostRecommendationService] Found ${querySnapshot.docs.length} recent posts');
      final posts = querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();

      // Calculate a trend score for each post based on recency and engagement
      final scoredPosts = posts.map((post) {
        final recency = 1.0 -
            (DateTime.now().difference(post.createdAt).inHours /
                336); // 336 hours = 14 days
        final engagement = (post.likes.length + post.commentCount * 2) /
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
          '[PostRecommendationService] Returning ${result.length} trending posts');
      return result;
    } catch (e) {
      print('[PostRecommendationService] Error getting trending posts: $e');
      return [];
    }
  }

  // Get posts from friends (people the user follows)
  Future<List<Post>> getFriendsPosts({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '[PostRecommendationService] Getting posts from friends for user: $userId');
      // Get IDs of users the current user follows
      final following = await _getFollowingIds(userId);
      print(
          '[PostRecommendationService] User follows ${following.length} users');

      if (following.isEmpty) {
        print(
            '[PostRecommendationService] User does not follow anyone, returning empty list');
        return [];
      }

      // Get recent posts from followed users
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId',
              whereIn: following
                  .take(10)
                  .toList()) // Firestore limitation: maximum 10 values in whereIn
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      print(
          '[PostRecommendationService] Found ${querySnapshot.docs.length} posts from friends');
      return querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('[PostRecommendationService] Error getting friends posts: $e');
      return [];
    }
  }

  // Get similar posts based on a movie the user liked
  Future<List<Post>> getSimilarMoviePosts(String movieId,
      {int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[PostRecommendationService] Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '[PostRecommendationService] Getting similar posts for movie: $movieId');
      // Get posts about this movie (excluding user's own posts)
      final querySnapshot = await _firestore
          .collection('posts')
          .where('movieId', isEqualTo: movieId)
          .where('userId', isNotEqualTo: userId)
          .orderBy('userId')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      print(
          '[PostRecommendationService] Found ${querySnapshot.docs.length} similar posts');
      return querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print(
          '[PostRecommendationService] Error getting similar movie posts: $e');
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
            '[PostRecommendationService] Error: viewPercentage must be between 0 and 100');
        return;
      }

      // Validate view time if provided
      if (viewTimeSeconds != null && viewTimeSeconds < 0) {
        print(
            '[PostRecommendationService] Error: viewTimeSeconds cannot be negative');
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
          '[PostRecommendationService] Logging interaction: $actionType on post $postId');

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
            .set({
          'postId': postId,
          'savedAt': FieldValue.serverTimestamp(),
        });
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
          '[PostRecommendationService] Getting following IDs for user: $userId');
      try {
        final friends = await _friendService.getFollowing(userId).first;
        final result = friends.map((friend) => friend.friendId).toList();
        print(
            '[PostRecommendationService] Found ${result.length} following IDs');
        return result;
      } catch (e) {
        print('[PostRecommendationService] Error using friend service: $e');

        // Fallback: direct Firestore query
        print(
            '[PostRecommendationService] Attempting direct query for following IDs');
        final snapshot = await _firestore
            .collection('friends')
            .where('userId', isEqualTo: userId)
            .get();

        final result = snapshot.docs
            .map((doc) => doc.data()['friendId'] as String)
            .toList();
        print(
            '[PostRecommendationService] Found ${result.length} following IDs using direct query');
        return result;
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
          '[PostRecommendationService] Getting watched movie IDs for user: $userId');
      try {
        final diaryEntries = await _diaryService.getDiaryEntries(userId).first;
        final result = diaryEntries.map((entry) => entry.movieId).toList();
        print(
            '[PostRecommendationService] Found ${result.length} watched movie IDs');
        return result;
      } catch (e) {
        print('[PostRecommendationService] Error using diary service: $e');

        // Fallback: direct Firestore query
        print(
            '[PostRecommendationService] Attempting direct query for watched movie IDs');
        final snapshot = await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: userId)
            .get();

        final result = snapshot.docs
            .map((doc) => doc.data()['movieId'] as String)
            .toList();
        print(
            '[PostRecommendationService] Found ${result.length} watched movie IDs using direct query');
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
          '[PostRecommendationService] Getting liked post IDs for user: $userId');
      final query = await _firestore
          .collection('posts')
          .where('likes', arrayContains: userId)
          .get();

      final result = query.docs.map((doc) => doc.id).toList();
      print(
          '[PostRecommendationService] Found ${result.length} liked post IDs');
      return result;
    } catch (e) {
      print('[PostRecommendationService] Error getting liked post IDs: $e');
      return [];
    }
  }

  // Helper method to get candidate posts for recommendations
  Future<List<Post>> _getCandidatePosts(
    String userId,
    List<String> likedPostIds,
  ) async {
    try {
      print('[PostRecommendationService] Getting candidate posts');
      // Check if posts collection exists and has documents
      final collectionRef = _firestore.collection('posts');
      final countQuery = await collectionRef.count().get();
      print(
          '[PostRecommendationService] Total posts in collection: ${countQuery.count}');

      if (countQuery.count == 0) {
        print(
            '[PostRecommendationService] Posts collection is empty, returning empty list');
        return [];
      }

      // Query for recent posts
      try {
        print(
            '[PostRecommendationService] Querying for candidate posts (excluding user\'s own posts)');
        final querySnapshot = await _firestore
            .collection('posts')
            .where('userId', isNotEqualTo: userId) // Exclude own posts
            .orderBy('userId')
            .orderBy('createdAt', descending: true)
            .limit(100) // Get a good pool of candidates
            .get();

        print(
            '[PostRecommendationService] Found ${querySnapshot.docs.length} initial candidate posts');
        final posts = querySnapshot.docs
            .map((doc) => Post.fromJson(doc.data(), doc.id))
            .where((post) => !likedPostIds
                .contains(post.id)) // Filter out already liked posts
            .toList();

        print(
            '[PostRecommendationService] After filtering liked posts: ${posts.length} candidate posts');
        return posts;
      } catch (e) {
        print('[PostRecommendationService] Error with initial query: $e');

        // Fallback: just get recent posts without filtering by userId
        print(
            '[PostRecommendationService] Trying fallback query without userId filter');
        final querySnapshot = await _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();

        final posts = querySnapshot.docs
            .map((doc) => Post.fromJson(doc.data(), doc.id))
            .where((post) => post.userId != userId) // Filter out own posts
            .where((post) => !likedPostIds
                .contains(post.id)) // Filter out already liked posts
            .toList();

        print(
            '[PostRecommendationService] Fallback query found ${posts.length} candidate posts');
        return posts;
      }
    } catch (e) {
      print('[PostRecommendationService] Error getting candidate posts: $e');
      return [];
    }
  }

  // Helper method to score candidate posts
  Future<List<_ScoredPost>> _scorePosts(
    List<Post> posts,
    UserPreferences userPreferences,
    List<String> following,
    List<String> watchedMovieIds,
  ) async {
    print('[PostRecommendationService] Scoring ${posts.length} posts');
    final List<_ScoredPost> scoredPosts = [];

    for (final post in posts) {
      double score = 0.0;
      String primaryReason = '';

      // 1. Content relevance score (30% weight)
      final contentScore = await _calculateContentScore(post, userPreferences);
      score += contentScore * 0.3;
      if (contentScore > 0.7) {
        primaryReason = 'content';
      }

      // 2. Actor/Director affinity score (20% weight)
      final talentScore = await _calculateTalentScore(post, userPreferences);
      score += talentScore * 0.2;
      if (talentScore > 0.8 && primaryReason.isEmpty) {
        primaryReason = 'talent';
      }

      // 3. Engagement score (30% weight)
      final engagementScore = _calculateEngagementScore(post);
      score += engagementScore * 0.3;
      if (engagementScore > 0.8 && primaryReason.isEmpty) {
        primaryReason = 'engagement';
      }

      // 4. View behavior score (20% weight)
      final viewScore = await _calculateViewScore(post);
      score += viewScore * 0.2;
      if (viewScore > 0.9 && primaryReason.isEmpty) {
        primaryReason = 'view_behavior';
      }

      print(
          '[PostRecommendationService] Post ${post.id} score: $score (content: $contentScore, talent: $talentScore, engagement: $engagementScore, view: $viewScore)');

      // Add to scored posts if score is high enough
      if (score > 0.3) {
        scoredPosts.add(_ScoredPost(post, score, primaryReason));
      }
    }

    print(
        '[PostRecommendationService] ${scoredPosts.length} posts passed the minimum score threshold');
    return scoredPosts;
  }

  // Calculate content relevance score based on TMDB genres
  Future<double> _calculateContentScore(
    Post post,
    UserPreferences userPreferences,
  ) async {
    try {
      print(
          '[PostRecommendationService] Calculating content score for post ${post.id} (movie: ${post.movieId})');

      // Get movie details from TMDB
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) {
        print(
            '[PostRecommendationService] No movie details found for ${post.movieId}');
        return 0.0;
      }

      double genreScore = 0.0;

      // Get TMDB genres
      if (movieDetails.containsKey('genres')) {
        final movieGenres = (movieDetails['genres'] as List)
            .map((g) => g['id'].toString())
            .toList();

        print(
            '[PostRecommendationService] Movie has ${movieGenres.length} genres');

        // Calculate genre match score
        for (final preferredGenre
            in userPreferences.likes.where((pref) => pref.type == 'genre')) {
          if (movieGenres.contains(preferredGenre.id)) {
            genreScore += preferredGenre.weight * 0.3; // Max 0.3 per genre
            print(
                '[PostRecommendationService] Genre match: ${preferredGenre.name}, score contribution: ${preferredGenre.weight * 0.3}');
          }
        }
      }

      // Normalize score to 0-1 range
      final normalizedScore = min(1.0, genreScore);
      print('[PostRecommendationService] Content score: $normalizedScore');
      return normalizedScore;
    } catch (e) {
      print('[PostRecommendationService] Error calculating content score: $e');
      return 0.0;
    }
  }

  // Calculate talent affinity score based on TMDB credits
  Future<double> _calculateTalentScore(
    Post post,
    UserPreferences userPreferences,
  ) async {
    try {
      print(
          '[PostRecommendationService] Calculating talent score for post ${post.id}');

      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) {
        return 0.0;
      }

      double actorScore = 0.0;
      double directorScore = 0.0;

      // Calculate actor score
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = movieDetails['credits']['cast'] as List;
        final actorIds = cast.map((actor) => actor['id'].toString()).toList();

        for (final preferredActor
            in userPreferences.likes.where((pref) => pref.type == 'actor')) {
          if (actorIds.contains(preferredActor.id)) {
            actorScore += preferredActor.weight * 0.15; // Max 0.15 per actor
          }
        }
      }

      // Calculate director score
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('crew')) {
        final crew = movieDetails['credits']['crew'] as List;
        final directors = crew
            .where((person) => person['job'] == 'Director')
            .map((director) => director['id'].toString())
            .toList();

        for (final preferredDirector
            in userPreferences.likes.where((pref) => pref.type == 'director')) {
          if (directors.contains(preferredDirector.id)) {
            directorScore +=
                preferredDirector.weight * 0.2; // Max 0.2 per director
          }
        }
      }

      // Combine scores (actors + directors)
      final totalScore = min(1.0, actorScore + directorScore);
      print(
          '[PostRecommendationService] Talent score: $totalScore (actors: $actorScore, directors: $directorScore)');
      return totalScore;
    } catch (e) {
      print('[PostRecommendationService] Error calculating talent score: $e');
      return 0.0;
    }
  }

  // Calculate engagement score based on likes and comments
  double _calculateEngagementScore(Post post) {
    // Normalize likes and comments to a 0-1 scale
    final likeScore = min(1.0, post.likes.length / 50.0); // 50+ likes = 1.0
    final commentScore =
        min(1.0, post.commentCount / 20.0); // 20+ comments = 1.0

    // Calculate weighted average (comments weighted more than likes)
    final engagementScore = (likeScore * 0.4) + (commentScore * 0.6);
    print(
        '[PostRecommendationService] Engagement score: $engagementScore (likes: ${post.likes.length}, comments: ${post.commentCount})');
    return engagementScore;
  }

  // Calculate view behavior score based on view time and completion rate
  Future<double> _calculateViewScore(Post post) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0.0;

      // Get view statistics for this post
      final viewStats = await _firestore
          .collection('userInteractions')
          .where('postId', isEqualTo: post.id)
          .where('userId', isEqualTo: userId)
          .where('actionType', isEqualTo: 'view')
          .get();

      if (viewStats.docs.isEmpty) return 0.0;

      double totalViewTime = 0;
      double totalViewPercentage = 0;
      int viewCount = 0;

      // Calculate average view time and completion rate
      for (final doc in viewStats.docs) {
        final data = doc.data();
        totalViewTime += data['viewTimeSeconds'] ?? 0;
        totalViewPercentage += data['viewPercentage'] ?? 0;
        viewCount++;
      }

      final avgViewTime = totalViewTime / viewCount;
      final avgCompletionRate = totalViewPercentage / viewCount;

      // Calculate view score components
      final viewTimeScore = min(1.0, avgViewTime / 30.0); // 30+ seconds = 1.0
      final completionScore = avgCompletionRate / 100.0; // Direct percentage

      // Combine scores (weighted average)
      final viewScore = (viewTimeScore * 0.6) + (completionScore * 0.4);
      print(
          '[PostRecommendationService] View score: $viewScore (time: $viewTimeScore, completion: $completionScore)');
      return viewScore;
    } catch (e) {
      print('[PostRecommendationService] Error calculating view score: $e');
      return 0.0;
    }
  }

  // Helper method to get movie details with caching
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    // Check cache first
    if (_movieCache.containsKey(movieId)) {
      print(
          '[PostRecommendationService] Using cached movie details for $movieId');
      return _movieCache[movieId]!;
    }

    try {
      print('[PostRecommendationService] Fetching movie details for $movieId');

      // First try getting from Firestore movies collection
      final doc = await _firestore.collection('movies').doc(movieId).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        print(
            '[PostRecommendationService] Found movie details in Firestore: ${data.keys.length} keys');
        _movieCache[movieId] = data;
        return data;
      }

      // If not in Firestore, try an alternative source
      // For example, you could call your TMDB service here
      print(
          '[PostRecommendationService] Movie not found in Firestore, creating minimal movie details');

      // Create minimal details from post data
      final postsWithMovie = await _firestore
          .collection('posts')
          .where('movieId', isEqualTo: movieId)
          .limit(1)
          .get();

      if (postsWithMovie.docs.isNotEmpty) {
        final postData = postsWithMovie.docs.first.data();
        final minimalDetails = {
          'id': movieId,
          'title': postData['movieTitle'] ?? 'Unknown Movie',
          'overview': postData['movieOverview'] ?? '',
          // Add dummy genres for testing purposes
          'genres': [
            {'id': '28', 'name': 'Action'},
            {'id': '18', 'name': 'Drama'}
          ],
        };

        print(
            '[PostRecommendationService] Created minimal movie details from post data');
        _movieCache[movieId] = minimalDetails;
        return minimalDetails;
      }

      print(
          '[PostRecommendationService] Couldn\'t find any data for movie $movieId');
      return {};
    } catch (e) {
      print('[PostRecommendationService] Error getting movie details: $e');
      return {};
    }
  }
}

// Helper class to represent a scored post
class _ScoredPost {
  final Post post;
  final double score;
  final String primaryReason; // 'social', 'content', 'recency', etc.

  _ScoredPost(this.post, this.score, this.primaryReason);
}

// Helper for math operations
class Math {
  static double min(double a, double b) => a < b ? a : b;
  static double pow(double a, double b) => pow(a, b).toDouble();
}
