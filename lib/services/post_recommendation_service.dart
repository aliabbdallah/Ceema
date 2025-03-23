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
    required String actionType, // 'view', 'like', 'comment', 'share', 'ignore'
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      print(
          '[PostRecommendationService] Logging interaction: $actionType on post $postId');
      await _firestore.collection('recommendationFeedback').add({
        'userId': userId,
        'postId': postId,
        'actionType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print(
          '[PostRecommendationService] Error logging recommendation interaction: $e');
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

      // 1. Social relevance score (30% weight)
      final socialScore = _calculateSocialScore(post, following);
      score += socialScore * 0.3;
      if (socialScore > 0.5) {
        primaryReason = 'social';
      }

      // 2. Content relevance score (40% weight)
      final contentScore =
          await _calculateContentScore(post, userPreferences, watchedMovieIds);
      score += contentScore * 0.4;
      if (contentScore > 0.7 &&
          (primaryReason.isEmpty || contentScore > socialScore)) {
        primaryReason = 'content';
      }

      // 3. Engagement score (15% weight)
      final engagementScore = _calculateEngagementScore(post);
      score += engagementScore * 0.15;

      // 4. Recency score (15% weight)
      final recencyScore = _calculateRecencyScore(post);
      score += recencyScore * 0.15;
      if (recencyScore > 0.9 && primaryReason.isEmpty) {
        primaryReason = 'recency';
      }

      print(
          '[PostRecommendationService] Post ${post.id} score: $score (social: $socialScore, content: $contentScore, engagement: $engagementScore, recency: $recencyScore)');

      // Add to scored posts if score is high enough
      if (score > 0.3) {
        scoredPosts.add(_ScoredPost(post, score, primaryReason));
      }
    }

    print(
        '[PostRecommendationService] ${scoredPosts.length} posts passed the minimum score threshold');
    return scoredPosts;
  }

  // Calculate social relevance score
  double _calculateSocialScore(Post post, List<String> following) {
    // Higher score if the post is from someone the user follows
    if (following.contains(post.userId)) {
      return 1.0;
    }

    // Medium score if many followed users liked the post
    int followedLikes = 0;
    for (final userId in post.likes) {
      if (following.contains(userId)) {
        followedLikes++;
      }
    }

    if (followedLikes > 0) {
      return min(0.8, followedLikes * 0.2); // Cap at 0.8
    }

    return 0.0;
  }

  // Calculate content relevance score based on genre, actors, directors
  Future<double> _calculateContentScore(
    Post post,
    UserPreferences userPreferences,
    List<String> watchedMovieIds,
  ) async {
    try {
      print(
          '[PostRecommendationService] Calculating content score for post ${post.id} (movie: ${post.movieId})');
      // Get movie details (with caching)
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) {
        print(
            '[PostRecommendationService] No movie details found for ${post.movieId}');
        return 0.0;
      }

      double genreScore = 0.0;
      double actorScore = 0.0;
      double directorScore = 0.0;

      // Check for genre matches
      if (movieDetails.containsKey('genres')) {
        final movieGenres = (movieDetails['genres'] as List)
            .map((g) => g['id'].toString())
            .toList();

        print(
            '[PostRecommendationService] Movie has ${movieGenres.length} genres');

        for (final preferredGenre
            in userPreferences.likes.where((pref) => pref.type == 'genre')) {
          if (movieGenres.contains(preferredGenre.id)) {
            genreScore += preferredGenre.weight * 0.25; // Max 0.25 per genre
            print(
                '[PostRecommendationService] Genre match: ${preferredGenre.name}, score contribution: ${preferredGenre.weight * 0.25}');
          }
        }
      } else {
        print('[PostRecommendationService] No genres found in movie details');
      }

      // Check for actor matches
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = movieDetails['credits']['cast'] as List;
        final actorIds = cast.map((actor) => actor['id'].toString()).toList();

        print(
            '[PostRecommendationService] Movie has ${actorIds.length} actors');

        for (final preferredActor
            in userPreferences.likes.where((pref) => pref.type == 'actor')) {
          if (actorIds.contains(preferredActor.id)) {
            actorScore += preferredActor.weight * 0.2; // Max 0.2 per actor
            print(
                '[PostRecommendationService] Actor match: ${preferredActor.name}, score contribution: ${preferredActor.weight * 0.2}');
          }
        }
      } else {
        print('[PostRecommendationService] No cast found in movie details');
      }

      // Check for director matches
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('crew')) {
        final crew = movieDetails['credits']['crew'] as List;
        final directors = crew
            .where((person) => person['job'] == 'Director')
            .map((director) => director['id'].toString())
            .toList();

        print(
            '[PostRecommendationService] Movie has ${directors.length} directors');

        for (final preferredDirector
            in userPreferences.likes.where((pref) => pref.type == 'director')) {
          if (directors.contains(preferredDirector.id)) {
            directorScore +=
                preferredDirector.weight * 0.3; // Max 0.3 per director
            print(
                '[PostRecommendationService] Director match: ${preferredDirector.name}, score contribution: ${preferredDirector.weight * 0.3}');
          }
        }
      } else {
        print('[PostRecommendationService] No crew found in movie details');
      }

      // Bonus for movies related to ones the user has watched
      if (watchedMovieIds.contains(post.movieId)) {
        print(
            '[PostRecommendationService] User has watched this movie, giving max score');
        return 1.0; // Max score for movies they've already watched
      }

      // Calculate total content score (max 1.0)
      final totalScore = min(1.0, genreScore + actorScore + directorScore);
      print(
          '[PostRecommendationService] Total content score: $totalScore (genre: $genreScore, actor: $actorScore, director: $directorScore)');
      return totalScore;
    } catch (e) {
      print('[PostRecommendationService] Error calculating content score: $e');
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

  // Calculate recency score (newer posts score higher)
  double _calculateRecencyScore(Post post) {
    final ageInHours = DateTime.now().difference(post.createdAt).inHours;
    double recencyScore;

    if (ageInHours < 24) {
      recencyScore = 1.0; // Posts less than a day old
    } else if (ageInHours < 72) {
      recencyScore = 0.8; // Posts 1-3 days old
    } else if (ageInHours < 168) {
      recencyScore = 0.6; // Posts 3-7 days old
    } else if (ageInHours < 336) {
      recencyScore = 0.4; // Posts 1-2 weeks old
    } else {
      recencyScore = 0.2; // Older posts
    }

    print(
        '[PostRecommendationService] Recency score: $recencyScore (age: $ageInHours hours)');
    return recencyScore;
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
