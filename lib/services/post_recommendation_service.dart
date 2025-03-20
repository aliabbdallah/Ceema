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
        throw Exception('User not authenticated');
      }

      print('Getting recommended posts for user: $userId');

      // 1. Get user data needed for recommendations
      final userPreferences = await _preferenceService.getUserPreferences();
      final following = await _getFollowingIds(userId);
      final watchedMovieIds = await _getWatchedMovieIds(userId);
      final likedPostIds = await _getLikedPostIds(userId);

      // 2. Fetch a pool of candidate posts
      final candidates = await _getCandidatePosts(userId, likedPostIds);

      // 3. Score each post
      final scoredPosts = await _scorePosts(
          candidates, userPreferences, following, watchedMovieIds);

      // 4. Sort by score and return the top posts
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));

      return scoredPosts
          .take(limit)
          .map((scoredPost) => scoredPost.post)
          .toList();
    } catch (e) {
      print('Error getting recommended posts: $e');
      return [];
    }
  }

  // Get trending posts (based on engagement metrics)
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    try {
      // Get recent posts (from last 14 days)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final querySnapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .orderBy('createdAt', descending: true)
          .limit(50) // Get a larger pool first for sorting
          .get();

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
        final trendScore = engagement / Math.pow(1.0 - recency, 1.5);

        return _ScoredPost(post, trendScore, 'trending');
      }).toList();

      // Sort by trend score
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));

      // Return top trending posts
      return scoredPosts
          .take(limit)
          .map((scoredPost) => scoredPost.post)
          .toList();
    } catch (e) {
      print('Error getting trending posts: $e');
      return [];
    }
  }

  // Get posts from friends (people the user follows)
  Future<List<Post>> getFriendsPosts({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get IDs of users the current user follows
      final following = await _getFollowingIds(userId);

      if (following.isEmpty) {
        return [];
      }

      // Get recent posts from followed users
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: following)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting friends posts: $e');
      return [];
    }
  }

  // Get similar posts based on a movie the user liked
  Future<List<Post>> getSimilarMoviePosts(String movieId,
      {int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get posts about this movie (excluding user's own posts)
      final querySnapshot = await _firestore
          .collection('posts')
          .where('movieId', isEqualTo: movieId)
          .where('userId', isNotEqualTo: userId)
          .orderBy('userId')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting similar movie posts: $e');
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

      await _firestore.collection('recommendationFeedback').add({
        'userId': userId,
        'postId': postId,
        'actionType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging recommendation interaction: $e');
    }
  }

  // Helper method to get IDs of users the current user follows
  Future<List<String>> _getFollowingIds(String userId) async {
    try {
      final friends = await _friendService.getFollowing(userId).first;
      return friends.map((friend) => friend.friendId).toList();
    } catch (e) {
      print('Error getting following IDs: $e');
      return [];
    }
  }

  // Helper method to get IDs of movies the user has watched
  Future<List<String>> _getWatchedMovieIds(String userId) async {
    try {
      final diaryEntries = await _diaryService.getDiaryEntries(userId).first;
      return diaryEntries.map((entry) => entry.movieId).toList();
    } catch (e) {
      print('Error getting watched movie IDs: $e');
      return [];
    }
  }

  // Helper method to get IDs of posts the user has already liked
  Future<List<String>> _getLikedPostIds(String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('likes', arrayContains: userId)
          .get();

      return query.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting liked post IDs: $e');
      return [];
    }
  }

  // Helper method to get candidate posts for recommendations
  Future<List<Post>> _getCandidatePosts(
    String userId,
    List<String> likedPostIds,
  ) async {
    try {
      // Query for recent posts
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isNotEqualTo: userId) // Exclude own posts
          .orderBy('userId')
          .orderBy('createdAt', descending: true)
          .limit(100) // Get a good pool of candidates
          .get();

      final posts = querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .where((post) =>
              !likedPostIds.contains(post.id)) // Filter out already liked posts
          .toList();

      return posts;
    } catch (e) {
      print('Error getting candidate posts: $e');
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

      // Add to scored posts if score is high enough
      if (score > 0.3) {
        scoredPosts.add(_ScoredPost(post, score, primaryReason));
      }
    }

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
      // Get movie details (with caching)
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) return 0.0;

      double genreScore = 0.0;
      double actorScore = 0.0;
      double directorScore = 0.0;

      // Check for genre matches
      if (movieDetails.containsKey('genres')) {
        final movieGenres = (movieDetails['genres'] as List)
            .map((g) => g['id'].toString())
            .toList();

        for (final preferredGenre
            in userPreferences.likes.where((pref) => pref.type == 'genre')) {
          if (movieGenres.contains(preferredGenre.id)) {
            genreScore += preferredGenre.weight * 0.25; // Max 0.25 per genre
          }
        }
      }

      // Check for actor matches
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = movieDetails['credits']['cast'] as List;
        final actorIds = cast.map((actor) => actor['id'].toString()).toList();

        for (final preferredActor
            in userPreferences.likes.where((pref) => pref.type == 'actor')) {
          if (actorIds.contains(preferredActor.id)) {
            actorScore += preferredActor.weight * 0.2; // Max 0.2 per actor
          }
        }
      }

      // Check for director matches
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
                preferredDirector.weight * 0.3; // Max 0.3 per director
          }
        }
      }

      // Bonus for movies related to ones the user has watched
      if (watchedMovieIds.contains(post.movieId)) {
        return 1.0; // Max score for movies they've already watched
      }

      // Calculate total content score (max 1.0)
      return min(1.0, genreScore + actorScore + directorScore);
    } catch (e) {
      print('Error calculating content score: $e');
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
    return (likeScore * 0.4) + (commentScore * 0.6);
  }

  // Calculate recency score (newer posts score higher)
  double _calculateRecencyScore(Post post) {
    final ageInHours = DateTime.now().difference(post.createdAt).inHours;

    if (ageInHours < 24) {
      return 1.0; // Posts less than a day old
    } else if (ageInHours < 72) {
      return 0.8; // Posts 1-3 days old
    } else if (ageInHours < 168) {
      return 0.6; // Posts 3-7 days old
    } else if (ageInHours < 336) {
      return 0.4; // Posts 1-2 weeks old
    } else {
      return 0.2; // Older posts
    }
  }

  // Helper method to get movie details with caching
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    // Check cache first
    if (_movieCache.containsKey(movieId)) {
      return _movieCache[movieId]!;
    }

    try {
      // Get from Firestore or external API
      // For this example, we'll assume there's a movies collection
      final doc = await _firestore.collection('movies').doc(movieId).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _movieCache[movieId] = data;
        return data;
      }

      // If not in Firestore, could fetch from TMDB API
      // For now, return empty map
      return {};
    } catch (e) {
      print('Error getting movie details: $e');
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
