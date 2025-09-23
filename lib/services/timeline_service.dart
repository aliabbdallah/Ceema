// lib/services/timeline_service.dart - Updated with movie recommendation algorithm
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/timeline_activity.dart';
import '../models/movie.dart';
import '../models/post.dart';
import '../models/diary_entry.dart';
import 'tmdb_service.dart';
import 'follow_service.dart';

class TimelineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for movie details to reduce API calls
  final Map<String, Map<String, dynamic>> _movieDetailsCache = {};

  // Get the personalized timeline for the current user
  Stream<List<TimelineItem>> getPersonalizedTimeline() async* {
    final userId = _auth.currentUser!.uid;

    // Get user's movie preferences
    final preferences = await _buildUserMovieProfile(userId);

    // Get timeline items
    List<TimelineItem> timeline = [];

    // 1. Add movie-based post recommendations (highest priority)
    final recommendedPosts = await _getRecommendedPosts(userId, preferences);
    timeline.addAll(recommendedPosts);

    // 2. Add friend posts (high priority)
    final friendPosts = await _getFriendsPosts(userId);
    timeline.addAll(friendPosts);

    // 3. Add personalized recommendations based on user preferences
    final recommendations = await _getRecommendations(
      userId,
      preferences.favoriteGenres.keys.toList(),
    );
    timeline.addAll(recommendations);

    // 4. Add trending items in preferred genres
    final trendingItems = await _getTrendingInGenres(
      preferences.favoriteGenres.keys.toList(),
    );
    timeline.addAll(trendingItems);

    // Sort the timeline by relevance score and then by timestamp
    timeline.sort((a, b) {
      // First sort by relevance (higher scores first)
      final relevanceComparison = b.relevanceScore.compareTo(a.relevanceScore);
      if (relevanceComparison != 0) return relevanceComparison;

      // Then by timestamp (newer items first)
      return b.timestamp.compareTo(a.timestamp);
    });

    // Rebalance timeline to ensure variety
    timeline = _rebalanceTimeline(timeline);

    yield timeline;
  }

  // Get recommended posts based on user's movie taste
  Future<List<TimelineItem>> _getRecommendedPosts(
    String userId,
    _UserMovieProfile userProfile,
  ) async {
    final List<TimelineItem> result = [];

    try {
      // Get a pool of candidate posts (excluding user's own posts)
      final recentPosts =
          await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final candidatePosts =
          recentPosts.docs
              .map((doc) => Post.fromJson(doc.data(), doc.id))
              .where((post) => post.userId != userId)
              .toList();

      // Score and sort posts based on relevance to user's taste
      List<_ScoredPost> scoredPosts = await _scorePosts(
        candidatePosts,
        userProfile,
      );
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));

      // Take top posts and convert to TimelineItems
      for (var scoredPost in scoredPosts.take(10)) {
        result.add(
          TimelineItem(
            id: 'recommended_post_${scoredPost.post.id}',
            type: TimelineItemType.similarToLiked,
            timestamp: scoredPost.post.createdAt,
            data: {
              'userId': scoredPost.post.userId,
              'userName': scoredPost.post.userName,
              'reason': _getRecommendationReason(scoredPost),
            },
            relevanceScore: scoredPost.score,
            relevanceReason: _getRecommendationReason(scoredPost),
            post: scoredPost.post,
          ),
        );
      }
    } catch (e) {
      print('Error getting recommended posts: $e');
    }

    return result;
  }

  // Generate a recommendation reason based on the scored post
  String _getRecommendationReason(_ScoredPost scoredPost) {
    if (scoredPost.matchReason == 'genre') {
      return 'Based on your genre preferences';
    } else if (scoredPost.matchReason == 'director') {
      return 'Director you might enjoy';
    } else if (scoredPost.matchReason == 'actor') {
      return 'Because you like similar actors';
    } else if (scoredPost.matchReason == 'rating') {
      return 'Highly rated by users like you';
    } else if (scoredPost.matchReason == 'movie') {
      return 'Because you liked similar movies';
    } else {
      return 'Recommended for you';
    }
  }

  // Build a profile of the user's movie preferences
  Future<_UserMovieProfile> _buildUserMovieProfile(String userId) async {
    final profile = _UserMovieProfile();

    try {
      // 1. Get liked movies from diary entries
      final diaryEntries =
          await _firestore
              .collection('diary_entries')
              .where('userId', isEqualTo: userId)
              .where(
                'rating',
                isGreaterThanOrEqualTo: 3.5,
              ) // Consider 3.5+ as "liked"
              .get();

      // Extract movies the user likes
      for (var doc in diaryEntries.docs) {
        final movieId = doc.data()['movieId'] as String;
        final rating = (doc.data()['rating'] as num).toDouble();

        profile.likedMovieIds.add(movieId);

        // The higher the rating, the more weight we give to this movie's attributes
        final weight = (rating - 2.5) / 2.5; // Scale from 0 to 1

        // Get movie details (with caching)
        final movieDetails = await _getMovieDetails(movieId);

        // Process genres
        if (movieDetails.containsKey('genres')) {
          for (var genre in movieDetails['genres'] as List) {
            final genreId = genre['id'].toString();
            profile.addGenre(genreId, weight);
          }
        }

        // Process directors and actors
        if (movieDetails.containsKey('credits')) {
          // Directors
          if (movieDetails['credits'].containsKey('crew')) {
            final directors = (movieDetails['credits']['crew'] as List).where(
              (crew) => crew['job'] == 'Director',
            );

            for (var director in directors) {
              final directorId = director['id'].toString();
              profile.addDirector(directorId, weight);
            }
          }

          // Main cast (top 5 actors)
          if (movieDetails['credits'].containsKey('cast')) {
            final cast = (movieDetails['credits']['cast'] as List).take(5);

            for (var actor in cast) {
              final actorId = actor['id'].toString();
              profile.addActor(actorId, weight);
            }
          }
        }
      }
    } catch (e) {
      print('Error building user movie profile: $e');
    }

    return profile;
  }

  // Score posts based on relevance to user's movie preferences
  Future<List<_ScoredPost>> _scorePosts(
    List<Post> posts,
    _UserMovieProfile userProfile,
  ) async {
    final scoredPosts = <_ScoredPost>[];

    for (var post in posts) {
      // Skip posts about movies the user has explicitly disliked
      if (userProfile.dislikedMovieIds.contains(post.movieId)) {
        continue;
      }

      double score = 0.0;
      String matchReason = '';

      // 1. Base relevance score
      score += 0.1; // Every post starts with a small base score

      // 2. If the user already watched and liked this movie, boost the score
      if (userProfile.likedMovieIds.contains(post.movieId)) {
        score +=
            0.7; // Big boost for posts about movies the user explicitly liked
        matchReason = 'movie';
      }

      // 3. Get movie details to analyze genre, director, cast relevance
      final movieDetails = await _getMovieDetails(post.movieId);

      // 4. Relevance based on genres
      if (movieDetails.containsKey('genres')) {
        double genreScore = 0;
        for (var genre in movieDetails['genres'] as List) {
          final genreId = genre['id'].toString();

          // Check if this is a genre the user likes
          if (userProfile.favoriteGenres.containsKey(genreId)) {
            genreScore += 0.15 * userProfile.favoriteGenres[genreId]!;
          }
        }

        // If genre matching is the strongest factor so far
        if (genreScore > 0.15 &&
            (matchReason.isEmpty || score < genreScore + 0.1)) {
          matchReason = 'genre';
        }

        score += genreScore;
      }

      // 5. Relevance based on directors
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('crew')) {
        final directors = (movieDetails['credits']['crew'] as List).where(
          (crew) => crew['job'] == 'Director',
        );

        double directorScore = 0;
        for (var director in directors) {
          final directorId = director['id'].toString();

          // Check if this is a director the user likes
          if (userProfile.favoriteDirectors.containsKey(directorId)) {
            directorScore += 0.2 * userProfile.favoriteDirectors[directorId]!;
          }
        }

        // If director matching is the strongest factor so far
        if (directorScore > 0.2 &&
            (matchReason.isEmpty || score < directorScore + 0.1)) {
          matchReason = 'director';
        }

        score += directorScore;
      }

      // 6. Relevance based on actors
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = (movieDetails['credits']['cast'] as List).take(5);

        double actorScore = 0;
        for (var actor in cast) {
          final actorId = actor['id'].toString();

          // Check if this is an actor the user likes
          if (userProfile.favoriteActors.containsKey(actorId)) {
            actorScore += 0.15 * userProfile.favoriteActors[actorId]!;
          }
        }

        // If actor matching is the strongest factor so far
        if (actorScore > 0.15 &&
            (matchReason.isEmpty || score < actorScore + 0.1)) {
          matchReason = 'actor';
        }

        score += actorScore;
      }

      // 7. Boost for posts with good ratings
      if (post.rating > 0) {
        double ratingScore = 0;
        // Posts with ratings between 3-5 get a boost
        if (post.rating >= 3) {
          ratingScore = 0.1 * (post.rating / 5);
        }

        if (ratingScore > 0.1 &&
            (matchReason.isEmpty || score < ratingScore + 0.2)) {
          matchReason = 'rating';
        }

        score += ratingScore;
      }

      // 8. Recency boost - favor newer posts
      final ageInDays = DateTime.now().difference(post.createdAt).inDays;
      if (ageInDays < 7) {
        score +=
            0.1 *
            (1 - (ageInDays / 7)); // Up to 0.1 boost for very recent posts
      }

      // Add to scored posts if relevance is high enough
      if (score > 0.3) {
        scoredPosts.add(_ScoredPost(post, score, matchReason));
      }
    }

    return scoredPosts;
  }

  // Get movie details with caching
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    if (_movieDetailsCache.containsKey(movieId)) {
      return _movieDetailsCache[movieId]!;
    }

    try {
      // Get detailed info including credits
      final details = await TMDBService.getMovieDetailsRaw(movieId);

      // Cache the result
      _movieDetailsCache[movieId] = details;
      return details;
    } catch (e) {
      print('Error getting movie details for $movieId: $e');
      return {}; // Return empty map on error
    }
  }

  // Rebalance timeline to ensure variety
  List<TimelineItem> _rebalanceTimeline(List<TimelineItem> originalTimeline) {
    if (originalTimeline.length <= 5) return originalTimeline;

    // Categorize items
    final posts =
        originalTimeline
            .where(
              (item) =>
                  item.type == TimelineItemType.friendPost ||
                  item.type == TimelineItemType.similarToLiked,
            )
            .toList();

    final recommendations =
        originalTimeline
            .where(
              (item) =>
                  item.type == TimelineItemType.recommendation ||
                  item.type == TimelineItemType.newReleaseGenre,
            )
            .toList();

    final trending =
        originalTimeline
            .where((item) => item.type == TimelineItemType.trendingMovie)
            .toList();

    // Create a new timeline with intermixed content
    final rebalanced = <TimelineItem>[];
    int postIndex = 0;
    int recIndex = 0;
    int trendIndex = 0;

    // Add items in a 3:1:1 ratio (posts:recommendations:trending)
    while (rebalanced.length < originalTimeline.length) {
      // Add up to 3 posts
      for (int i = 0; i < 3 && postIndex < posts.length; i++) {
        rebalanced.add(posts[postIndex++]);
        if (rebalanced.length >= originalTimeline.length) break;
      }

      // Add 1 recommendation if available
      if (recIndex < recommendations.length &&
          rebalanced.length < originalTimeline.length) {
        rebalanced.add(recommendations[recIndex++]);
      }

      // Add 1 trending item if available
      if (trendIndex < trending.length &&
          rebalanced.length < originalTimeline.length) {
        rebalanced.add(trending[trendIndex++]);
      }
    }

    return rebalanced;
  }

  // Get timeline filtered by specific genre
  Stream<List<TimelineItem>> getGenreTimeline(String genre) async* {
    final userId = _auth.currentUser!.uid;
    yield await _getItemsByGenre(userId, genre);
  }

  // Helper method to get user's preferred genres
  Stream<List<String>> _getUserPreferredGenres(String userId) async* {
    try {
      // Get from user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();

      List<String> genres = [];
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['favoriteGenres'] != null) {
          genres = List<String>.from(userData['favoriteGenres']);
        }
      }

      // If no specified genres, try to infer from highly rated movies
      if (genres.isEmpty) {
        final highlyRatedMovies =
            await _firestore
                .collection('diary_entries')
                .where('userId', isEqualTo: userId)
                .where('rating', isGreaterThanOrEqualTo: 4)
                .limit(5)
                .get();

        // In a real app, you would analyze these movies to determine preferred genres
        // For now, use a default set
        genres = ['Action', 'Drama', 'Comedy'];
      }

      yield genres;
    } catch (e) {
      print('Error getting user preferred genres: $e');
      yield ['Action', 'Drama', 'Comedy']; // Default fallback
    }
  }

  // Get posts from friends
  Future<List<TimelineItem>> _getFriendsPosts(String userId) async {
    try {
      // Get friends list
      final friendsSnapshot =
          await _firestore
              .collection('friends')
              .where('userId', isEqualTo: userId)
              .get();

      final List<String> friendIds =
          friendsSnapshot.docs.map((doc) => doc['friendId'] as String).toList();

      if (friendIds.isEmpty) {
        return [];
      }

      // Get recent posts from friends
      final postsSnapshot =
          await _firestore
              .collection('posts')
              .where('userId', whereIn: friendIds)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

      // Convert to TimelineItem objects
      return postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data(), doc.id);

        return TimelineItem(
          id: 'friend_post_${doc.id}',
          type: TimelineItemType.friendPost,
          timestamp: post.createdAt,
          data: {
            'friendId': post.userId,
            'friendName': post.userName,
            'postContent': post.content,
            'movieId': post.movieId,
            'movieTitle': post.movieTitle,
          },
          relevanceScore: 0.8, // Friend posts are generally high relevance
          relevanceReason: 'From ${post.userName}',
          post: post,
        );
      }).toList();
    } catch (e) {
      print('Error getting friends posts: $e');
      return [];
    }
  }

  // Get personalized movie recommendations
  Future<List<TimelineItem>> _getRecommendations(
    String userId,
    List<String> preferredGenres,
  ) async {
    try {
      // In a real app, this would use the user's watch history and preferences
      // to generate personalized recommendations

      // Here we're just fetching some highly rated movies as recommendations
      final recommendationsSnapshot =
          await _firestore
              .collection('movies')
              .where('averageRating', isGreaterThanOrEqualTo: 4)
              .limit(5)
              .get();

      // Convert to TimelineItem objects
      return recommendationsSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'recommendation_${doc.id}',
          type: TimelineItemType.recommendation,
          timestamp: DateTime.now(), // Recommendations are always "fresh"
          data: {
            'movieId': movie.id,
            'movieTitle': movie.title,
            'reason': 'Based on your preferences',
          },
          relevanceScore:
              0.6, // Personalized recommendations are high relevance
          relevanceReason: 'Based on movies you\'ve enjoyed',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  // Get trending movies in preferred genres
  Future<List<TimelineItem>> _getTrendingInGenres(List<String> genres) async {
    try {
      // In a real app, you'd query a movies collection with genre filtering
      // Here we just fetch some trending movies
      final trendingSnapshot =
          await _firestore
              .collection('movies')
              .orderBy('popularity', descending: true)
              .limit(5)
              .get();

      // Convert to TimelineItem objects
      return trendingSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'trending_${doc.id}',
          type: TimelineItemType.trendingMovie,
          timestamp: DateTime.now(),
          data: {'movieId': movie.id, 'movieTitle': movie.title},
          relevanceScore: 0.5, // Trending items are medium relevance
          relevanceReason: 'Trending now',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting trending in genres: $e');
      return [];
    }
  }

  // Get items filtered by a specific genre
  Future<List<TimelineItem>> _getItemsByGenre(
    String userId,
    String genre,
  ) async {
    try {
      // In a real app, this would query movies by genre and possibly
      // include posts or diary entries related to those movies

      // Here we just return some movies as a placeholder
      final genreSnapshot =
          await _firestore.collection('movies').limit(10).get();

      // Convert to TimelineItem objects
      return genreSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'genre_${genre}_${doc.id}',
          type: TimelineItemType.newReleaseGenre,
          timestamp: DateTime.now(),
          data: {
            'movieId': movie.id,
            'movieTitle': movie.title,
            'genre': genre,
          },
          relevanceScore: 0.7,
          relevanceReason: 'Popular in $genre',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting items by genre: $e');
      return [];
    }
  }

  // Create a new timeline item
  Future<void> createTimelineItem({
    required TimelineItemType type,
    required Map<String, dynamic> data,
    Post? post,
    DiaryEntry? diaryEntry,
    Movie? movie,
    double relevanceScore = 0.5,
    String? relevanceReason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in');
    }

    // Create a timeline item document
    await _firestore.collection('timeline').add({
      'type': type.toString().split('.').last,
      'timestamp': FieldValue.serverTimestamp(),
      'data': data,
      'relevanceScore': relevanceScore,
      'relevanceReason': relevanceReason,
      'userId': user.uid, // The user who this item is for
      'postId': post?.id,
      'diaryEntryId': diaryEntry?.id,
      'movieId': movie?.id,
    });
  }
}

// Helper class to represent a user's movie preferences
class _UserMovieProfile {
  // Movies the user has watched and liked
  final Set<String> likedMovieIds = {};

  // Movies the user has explicitly disliked
  final Set<String> dislikedMovieIds = {};

  // Genres the user likes with weights
  final Map<String, double> favoriteGenres = {};

  // Directors the user likes with weights
  final Map<String, double> favoriteDirectors = {};

  // Actors the user likes with weights
  final Map<String, double> favoriteActors = {};

  // Add a genre with weight
  void addGenre(String genreId, double weight) {
    favoriteGenres[genreId] = (favoriteGenres[genreId] ?? 0) + weight;
  }

  // Add a director with weight
  void addDirector(String directorId, double weight) {
    favoriteDirectors[directorId] =
        (favoriteDirectors[directorId] ?? 0) + weight;
  }

  // Add an actor with weight
  void addActor(String actorId, double weight) {
    favoriteActors[actorId] = (favoriteActors[actorId] ?? 0) + weight;
  }
}

// Helper class to represent a post with its relevance score
class _ScoredPost {
  final Post post;
  final double score;
  final String matchReason;

  _ScoredPost(this.post, this.score, this.matchReason);
}
