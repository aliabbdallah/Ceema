import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/post.dart';
import '../models/user_preferences.dart';
import '../services/preference_service.dart';
import '../services/post_service.dart';
import '../services/diary_service.dart';
import '../services/follow_service.dart';

class PostRecommendationResult {
  final List<Post> posts;
  final DocumentSnapshot? lastDoc;

  PostRecommendationResult(this.posts, this.lastDoc);
}

class SimplifiedPostRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceService _preferenceService = PreferenceService();
  final PostService _postService = PostService();
  final DiaryService _diaryService = DiaryService();
  final FollowService _followService = FollowService();

  // Simple in-memory cache for movie details
  final Map<String, Map<String, dynamic>> _movieCache = {};

  // Get recommended posts with simplified two-stage approach
  Future<PostRecommendationResult> getRecommendedPosts({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return await _getFallbackRecommendations(limit);
      }

      // 1. Get personalized recommendations
      final personalized = await _getPersonalizedPosts(
        userId,
        limit: limit,
        startAfter: startAfter,
      );

      if (personalized.posts.length >= limit) {
        return personalized;
      }

      // 2. Fill remaining slots with trending content
      final remaining = limit - personalized.posts.length;
      final trending = await _getTrendingPosts(
        limit: remaining,
        startAfter: personalized.lastDoc,
      );

      return PostRecommendationResult([
        ...personalized.posts,
        ...trending.posts,
      ], trending.lastDoc);
    } catch (e) {
      print('[SimplifiedPostRecommendationService] Error: $e');
      return await _getFallbackRecommendations(limit);
    }
  }

  // Get personalized posts based on user preferences
  Future<PostRecommendationResult> _getPersonalizedPosts(
    String userId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // Get user data in a single query
      final userData = await _fetchUserData(userId);
      if (userData.isEmpty) {
        return PostRecommendationResult([], null);
      }

      // Get candidate posts
      final candidates = await _getCandidatePosts(
        userId,
        userData['likedPostIds'],
        limit: limit * 2, // Fetch more for filtering
        startAfter: startAfter,
      );

      if (candidates.isEmpty) {
        return PostRecommendationResult([], null);
      }

      // Score and filter posts
      final scoredPosts = await _scorePosts(
        candidates,
        userData['preferences'],
        userData['following'],
        userData['watchedMovieIds'],
      );

      // Apply diversity and return top posts
      final posts = _applyDiversityAndReturnTopPosts(scoredPosts, limit);
      return PostRecommendationResult(posts, null);
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error in personalized posts: $e',
      );
      return PostRecommendationResult([], null);
    }
  }

  // Get trending postsff
  Future<PostRecommendationResult> _getTrendingPosts({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
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
      print(
        '[SimplifiedPostRecommendationService] Error in trending posts: $e',
      );
      return PostRecommendationResult([], null);
    }
  }

  // Get fallback recommendations
  Future<PostRecommendationResult> _getFallbackRecommendations(
    int limit,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return PostRecommendationResult(
        querySnapshot.docs
            .map(
              (doc) =>
                  Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
            )
            .toList(),
        querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
    } catch (e) {
      print('[SimplifiedPostRecommendationService] Error in fallback: $e');
      return PostRecommendationResult([], null);
    }
  }

  // Fetch user data in a single query
  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};

      final data = userDoc.data() ?? {};
      return {
        'preferences': await _preferenceService.getUserPreferences(),
        'following': await _getFollowingIds(userId),
        'watchedMovieIds': await _getWatchedMovieIds(userId),
        'likedPostIds': await _getLikedPostIds(userId),
      };
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error fetching user data: $e',
      );
      return {};
    }
  }

  // Get candidate posts
  Future<List<Post>> _getCandidatePosts(
    String userId,
    List<String> likedPostIds, {
    int limit = 30,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(limit * 2);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .where(
            (post) => post.userId != userId && !likedPostIds.contains(post.id),
          )
          .toList();
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error getting candidates: $e',
      );
      return [];
    }
  }

  // Score posts with algorithm
  Future<List<_ScoredPost>> _scorePosts(
    List<Post> posts,
    UserPreferences preferences,
    List<String> following,
    List<String> watchedMovieIds,
  ) async {
    final List<_ScoredPost> scoredPosts = [];

    for (final post in posts) {
      double score = 0.0;
      String primaryReason = '';

      // 1. Content Match (40%)
      final contentScore = await _calculateContentMatch(post, preferences);
      score += contentScore * 0.4;

      // 2. Social Relevance (30%)
      final socialScore = _calculateSocialRelevance(
        post,
        following,
        watchedMovieIds,
      );
      score += socialScore * 0.3;

      // 3. Engagement (30%)
      final engagementScore = _calculateEngagement(post);
      score += engagementScore * 0.3;

      // Add exploration boost (20% of posts)
      if (Random().nextDouble() < 0.2) {
        score += 0.2;
        primaryReason = 'exploration';
      }

      if (score > 0.01) {
        scoredPosts.add(_ScoredPost(post, score, primaryReason));
      }
    }

    return scoredPosts;
  }

  // Calculate content match score
  Future<double> _calculateContentMatch(
    Post post,
    UserPreferences preferences,
  ) async {
    try {
      final movieDetails = await _getMovieDetails(post.movieId);
      if (movieDetails.isEmpty) return 0.0;

      double score = 0.0;

      // Genre matching from explicit preferences (50% weight)
      if (movieDetails.containsKey('genres')) {
        final movieGenres =
            (movieDetails['genres'] as List)
                .map((g) => g['id'].toString())
                .toList();

        // Match against explicit preferences
        for (final preferredGenre in preferences.likes.where(
          (pref) => pref.type == 'genre',
        )) {
          if (movieGenres.contains(preferredGenre.id)) {
            score += preferredGenre.weight * 0.15;
          }
        }

        // Match against watched movie genres (50% weight)
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final watchedMovies = await _getWatchedMovieIds(userId);
          final watchedGenres = <String, int>{}; // genre id -> count

          // Build genre frequency from watched movies
          for (final movieId in watchedMovies) {
            final details = await _getMovieDetails(movieId);
            if (details.containsKey('genres')) {
              for (final genre in details['genres'] as List) {
                final genreId = genre['id'].toString();
                watchedGenres[genreId] = (watchedGenres[genreId] ?? 0) + 1;
              }
            }
          }

          // Calculate score based on watched genres
          if (watchedGenres.isNotEmpty) {
            final maxCount = watchedGenres.values.reduce(max);
            for (final movieGenre in movieGenres) {
              if (watchedGenres.containsKey(movieGenre)) {
                // Normalize the genre frequency to a 0-1 scale
                final genreWeight = watchedGenres[movieGenre]! / maxCount;
                score += genreWeight * 0.15;
              }
            }
          }
        }
      }

      return min(1.0, score);
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error calculating content match: $e',
      );
      return 0.0;
    }
  }

  // Calculate social relevance score
  double _calculateSocialRelevance(
    Post post,
    List<String> following,
    List<String> watchedMovieIds,
  ) {
    double score = 0.0;

    // Boost for followed users
    if (following.contains(post.userId)) {
      score += 0.5;
    }

    // Boost for watched movies
    if (watchedMovieIds.contains(post.movieId)) {
      score += 0.5;
    }

    return min(1.0, score);
  }

  // Calculate engagement score
  double _calculateEngagement(Post post) {
    final likeScore = min(1.0, post.likes.length / 20.0);
    final commentScore = min(1.0, post.commentCount / 10.0);
    return (likeScore * 0.4) + (commentScore * 0.6);
  }

  // Get movie details with simple caching
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    if (_movieCache.containsKey(movieId)) {
      return _movieCache[movieId]!;
    }

    try {
      final doc = await _firestore.collection('movies').doc(movieId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _movieCache[movieId] = data;
        return data;
      }

      // If not in Firestore, create minimal details
      final minimalDetails = {
        'id': movieId,
        'title': 'Unknown Movie',
        'genres': [],
      };

      _movieCache[movieId] = minimalDetails;
      return minimalDetails;
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error getting movie details: $e',
      );
      return {};
    }
  }

  // Apply diversity and return top posts
  List<Post> _applyDiversityAndReturnTopPosts(
    List<_ScoredPost> scoredPosts,
    int limit,
  ) {
    // Sort by score
    scoredPosts.sort((a, b) => b.score.compareTo(a.score));

    final result = <Post>[];
    final Set<String> usedMovieIds = {};
    final Set<String> usedUserIds = {};

    for (final scoredPost in scoredPosts) {
      final post = scoredPost.post;
      final movieId = post.movieId;
      final userId = post.userId;

      // Skip if we've already used this movie or user
      if (usedMovieIds.contains(movieId) || usedUserIds.contains(userId)) {
        continue;
      }

      result.add(post);
      usedMovieIds.add(movieId);
      usedUserIds.add(userId);

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  // Helper methods for getting user data
  Future<List<String>> _getFollowingIds(String userId) async {
    try {
      final follows = await _followService.getFollowing(userId).first;
      return follows.map((follow) => follow.followedId).toList();
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error getting following: $e',
      );
      return [];
    }
  }

  Future<List<String>> _getWatchedMovieIds(String userId) async {
    try {
      final diaryEntries = await _diaryService.getDiaryEntries(userId).first;
      return diaryEntries.map((entry) => entry.movieId).toList();
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error getting watched movies: $e',
      );
      return [];
    }
  }

  Future<List<String>> _getLikedPostIds(String userId) async {
    try {
      final query =
          await _firestore
              .collection('posts')
              .where('likes', arrayContains: userId)
              .get();
      return query.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print(
        '[SimplifiedPostRecommendationService] Error getting liked posts: $e',
      );
      return [];
    }
  }
}

// Helper class to represent a scored post
class _ScoredPost {
  final Post post;
  final double score;
  final String primaryReason;

  _ScoredPost(this.post, this.score, this.primaryReason);
}
