import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import 'tmdb_service.dart';
import 'friend_service.dart';

// Helper class for weighted ratings
class _WeightedRating {
  final String movieId;
  double sumRatings = 0;
  double sumWeights = 0;
  int count = 0;

  _WeightedRating(this.movieId);

  void addRating(double rating, double weight) {
    sumRatings += rating * weight;
    sumWeights += weight;
    count++;
  }

  double getWeightedRating() {
    if (sumWeights == 0) return 0;
    return sumRatings / sumWeights;
  }
}

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  // Get comprehensive personalized recommendations
  Future<List<Movie>> getPersonalizedRecommendations(String userId) async {
    try {
      // Combine multiple recommendation strategies
      final genreRecommendations = await getGenreBasedRecommendations(userId);
      final similarTasteRecommendations =
          await getSimilarTasteRecommendations(userId);
      final weekendRecommendations =
          await getWeekendWatchRecommendations(userId);

      // Merge recommendations
      final recommendations = [
        ...genreRecommendations,
        ...similarTasteRecommendations,
        ...weekendRecommendations,
      ];

      // Remove duplicates while preserving order
      final uniqueRecommendations = recommendations.toSet().toList();

      // Sort by a comprehensive relevance score
      uniqueRecommendations.sort((a, b) =>
          _calculateRelevanceScore(b).compareTo(_calculateRelevanceScore(a)));

      return uniqueRecommendations.take(10).toList();
    } catch (e) {
      print('Error in personalized recommendations: $e');
      return [];
    }
  }

  // Calculate a comprehensive relevance score for a movie
  double _calculateRelevanceScore(Movie movie) {
    double score = 0;

    // Vote average contribution (0-10 scale)
    score += (movie.voteAverage) * 0.4; // 40% weight

    // Popularity contribution (normalized to 0-10 scale)
    final normalizedPopularity = min(movie.popularity / 20, 10.0); // Cap at 10
    score += normalizedPopularity * 0.3; // 30% weight

    // Recency contribution (0-10 scale)
    try {
      final year = int.tryParse(movie.year) ?? 0;
      final currentYear = DateTime.now().year;
      final yearDiff = currentYear - year;
      final recencyScore = max(0, 10 - yearDiff);
      score += recencyScore * 0.3; // 30% weight
    } catch (e) {
      // Ignore parsing errors
    }

    return score;
  }

  // Get recommendations based on user's preferred genres
  Future<List<Movie>> getGenreBasedRecommendations(String userId) async {
    try {
      // Get user's diary entries with high ratings
      final diaryEntries = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .get();

      // Extract and analyze genre preferences
      final genreFrequency = <int, int>{};
      for (var doc in diaryEntries.docs) {
        try {
          final movieId = doc.data()['movieId'] as String;
          final movieDetails = await TMDBService.getMovieDetails(movieId);

          if (movieDetails['genres'] != null) {
            final genres = movieDetails['genres'] as List;
            for (var genre in genres) {
              final genreId = genre['id'] as int;
              genreFrequency[genreId] = (genreFrequency[genreId] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('Error processing movie details for genre: $e');
        }
      }

      // Sort genres by frequency
      final sortedGenres = genreFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top genre IDs
      final topGenreIds =
          sortedGenres.take(5).map((entry) => entry.key).toList();

      // Fetch movies by top genres
      final genreMovies = await TMDBService.getMoviesByGenres(topGenreIds);

      return genreMovies.map((movieData) => Movie.fromJson(movieData)).toList();
    } catch (e) {
      print('Error getting genre-based recommendations: $e');
      return [];
    }
  }

  // Get recommendations based on users with similar taste
  Future<List<Movie>> getSimilarTasteRecommendations(String userId) async {
    try {
      // Get the current user's ratings
      final userRatings = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      // Map of movieId -> rating for the current user
      final userRatingMap = <String, double>{};
      for (var doc in userRatings.docs) {
        final data = doc.data();
        userRatingMap[data['movieId']] = (data['rating'] as num).toDouble();
      }

      // Find similar users
      final similarUserIds = await _findSimilarUsers(userId, userRatingMap);

      // Get recommendations from similar users
      final recommendations = await _getMoviesFromSimilarUsers(
          userId, similarUserIds, userRatingMap.keys.toList());

      return recommendations;
    } catch (e) {
      print('Error getting similar-taste recommendations: $e');
      return [];
    }
  }

  // Find users with similar movie taste
  Future<List<String>> _findSimilarUsers(
      String userId, Map<String, double> userRatingMap) async {
    final similarUserIds = <String>[];

    try {
      // Get followers and following as initial candidates
      final followers = await _friendService.getFollowers(userId).first;
      final following = await _friendService.getFollowing(userId).first;

      // Combine potential similar users
      final potentialUsers = [
        ...followers.map((f) => f.userId),
        ...following.map((f) => f.friendId)
      ];

      // Calculate similarity for each potential user
      for (final potentialUserId in potentialUsers) {
        // Skip if it's the same user
        if (potentialUserId == userId) continue;

        // Get potential user's ratings
        final potentialUserRatings = await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: potentialUserId)
            .get();

        // Create rating map for potential user
        final potentialUserRatingMap = <String, double>{};
        for (var doc in potentialUserRatings.docs) {
          final data = doc.data();
          potentialUserRatingMap[data['movieId']] =
              (data['rating'] as num).toDouble();
        }

        // Calculate similarity
        final similarity =
            _calculatePearsonCorrelation(userRatingMap, potentialUserRatingMap);

        // Add to similar users if correlation is positive
        if (similarity > 0.5) {
          similarUserIds.add(potentialUserId);
        }
      }

      return similarUserIds;
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  // Calculate Pearson correlation between two users' ratings
  double _calculatePearsonCorrelation(
      Map<String, double> user1Ratings, Map<String, double> user2Ratings) {
    // Find common movies
    final commonMovies = user1Ratings.keys
        .where((movieId) => user2Ratings.containsKey(movieId))
        .toList();

    // Need at least 3 common movies for meaningful correlation
    if (commonMovies.length < 3) return 0;

    // Calculate means
    double sum1 = 0, sum2 = 0;
    for (String movieId in commonMovies) {
      sum1 += user1Ratings[movieId]!;
      sum2 += user2Ratings[movieId]!;
    }
    final mean1 = sum1 / commonMovies.length;
    final mean2 = sum2 / commonMovies.length;

    // Calculate Pearson correlation
    double numerator = 0;
    double denominator1 = 0;
    double denominator2 = 0;

    for (String movieId in commonMovies) {
      final dev1 = user1Ratings[movieId]! - mean1;
      final dev2 = user2Ratings[movieId]! - mean2;
      numerator += dev1 * dev2;
      denominator1 += dev1 * dev1;
      denominator2 += dev2 * dev2;
    }

    // Prevent division by zero
    if (denominator1 == 0 || denominator2 == 0) return 0;

    return numerator / (sqrt(denominator1) * sqrt(denominator2));
  }

  // Get weekend watch recommendations based on recent viewing
  Future<List<Movie>> getWeekendWatchRecommendations(String userId) async {
    try {
      // Get recent diary entries (last two weeks)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final recentWatches = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .where('watchedDate', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .orderBy('watchedDate', descending: true)
          .limit(5)
          .get();

      // Get similar movies for recent watches
      final recommendations = <Movie>[];
      for (var doc in recentWatches.docs) {
        final movieId = doc.data()['movieId'] as String;
        final similarMovies = await TMDBService.getSimilarMovies(movieId);

        // Add top 2 similar movies
        for (var i = 0; i < similarMovies.length && i < 2; i++) {
          recommendations.add(Movie.fromJson(similarMovies[i]));
        }

        // Limit total recommendations
        if (recommendations.length >= 10) break;
      }

      return recommendations;
    } catch (e) {
      print('Error getting weekend watch recommendations: $e');
      return [];
    }
  }

  // Helper method to get movies from similar users
  Future<List<Movie>> _getMoviesFromSimilarUsers(String userId,
      List<String> similarUserIds, List<String> watchedMovieIds) async {
    try {
      if (similarUserIds.isEmpty) return [];

      // Get movies rated by similar users
      final similarUserMovies = await _firestore
          .collection('diary_entries')
          .where('userId', whereIn: similarUserIds)
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .get();

      // Create weighted ratings for movies
      final weightedRatings = <String, _WeightedRating>{};

      for (var doc in similarUserMovies.docs) {
        final data = doc.data();
        final movieId = data['movieId'] as String;
        final rating = (data['rating'] as num).toDouble();
        final ratingUserId = data['userId'] as String;

        // Skip if already watched
        if (watchedMovieIds.contains(movieId)) continue;

        // Add to weighted ratings
        if (!weightedRatings.containsKey(movieId)) {
          weightedRatings[movieId] = _WeightedRating(movieId);
        }

        // Use a simple similarity weight (you could enhance this)
        weightedRatings[movieId]!.addRating(rating, 1.0);
      }

      // Sort by weighted rating
      final sortedMovies = weightedRatings.values.toList()
        ..sort(
            (a, b) => b.getWeightedRating().compareTo(a.getWeightedRating()));

      // Get movie details
      final recommendations = <Movie>[];
      for (var weightedRating in sortedMovies) {
        try {
          final movieDetails =
              await TMDBService.getMovieDetails(weightedRating.movieId);
          recommendations.add(Movie.fromJson(movieDetails));

          // Limit recommendations
          if (recommendations.length >= 10) break;
        } catch (e) {
          print('Error fetching movie details: $e');
        }
      }

      return recommendations;
    } catch (e) {
      print('Error getting movies from similar users: $e');
      return [];
    }
  }
}
