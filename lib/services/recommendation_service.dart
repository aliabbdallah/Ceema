// services/recommendation_service.dart
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

  // Get recommendations based on user's preferred genres
  Future<List<Movie>> getGenreBasedRecommendations(String userId) async {
    try {
      // Get user's diary entries - modified to avoid requiring a composite index
      final diaryEntries = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter and sort in memory instead of using Firestore query
      final highlyRatedEntries = diaryEntries.docs.where((doc) {
        final rating = doc.data()['rating'];
        return rating != null && rating >= 4.0;
      }).toList()
        ..sort((a, b) {
          final ratingA = a.data()['rating'] as num;
          final ratingB = b.data()['rating'] as num;
          return ratingB.compareTo(ratingA); // Descending order
        });

      // Take only the top 10 entries
      final topEntries = highlyRatedEntries.length > 10
          ? highlyRatedEntries.sublist(0, 10)
          : highlyRatedEntries;

      // Extract movie IDs and get their details to analyze genres
      final List<String> movieIds =
          topEntries.map((doc) => doc.data()['movieId'] as String).toList();

      // Get genre preferences (in a real app, you would analyze the movies to extract genres)
      // For now, we'll use a simplified approach
      final List<int> preferredGenreIds =
          await _extractPreferredGenres(movieIds);

      // Get movies by preferred genres
      final List<Map<String, dynamic>> genreMovies =
          await TMDBService.getMoviesByGenres(preferredGenreIds);

      // Convert to Movie objects
      return genreMovies.map((movieData) => Movie.fromJson(movieData)).toList();
    } catch (e) {
      print('Error getting genre-based recommendations: $e');
      return [];
    }
  }

  // Get recommendations based on users with similar taste
  Future<List<Movie>> getSimilarTasteRecommendations(String userId) async {
    try {
      // Get the current user's highly rated movies
      final userRatings = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      // Map of movieId -> rating for the current user
      final Map<String, double> userRatingMap = {};
      for (var doc in userRatings.docs) {
        final data = doc.data();
        userRatingMap[data['movieId']] = (data['rating'] as num).toDouble();
      }

      // Find users with similar ratings
      // In a real app, this would use a more sophisticated algorithm
      // For now, we'll find users who rated the same movies highly
      final List<String> similarUserIds =
          await _findSimilarUsers(userId, userRatingMap);

      // Get movies highly rated by similar users but not watched by current user
      final List<Movie> recommendations = await _getMoviesFromSimilarUsers(
          userId, similarUserIds, userRatingMap.keys.toList());

      return recommendations;
    } catch (e) {
      print('Error getting similar-taste recommendations: $e');
      return [];
    }
  }

  // Get weekend watch recommendations based on recent viewing
  Future<List<Movie>> getWeekendWatchRecommendations(String userId) async {
    try {
      // Get user's diary entries - modified to avoid requiring a composite index
      final diaryEntries = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter and sort in memory
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final recentWatches = diaryEntries.docs.where((doc) {
        final watchedAt = doc.data()['watchedAt'] as Timestamp?;
        return watchedAt != null && watchedAt.toDate().isAfter(twoWeeksAgo);
      }).toList()
        ..sort((a, b) {
          final dateA = (a.data()['watchedAt'] as Timestamp).toDate();
          final dateB = (b.data()['watchedAt'] as Timestamp).toDate();
          return dateB.compareTo(dateA); // Descending order
        });

      // Take only the top 5 entries
      final topEntries = recentWatches.length > 5
          ? recentWatches.sublist(0, 5)
          : recentWatches;

      // Extract movie IDs
      final List<String> recentMovieIds =
          topEntries.map((doc) => doc.data()['movieId'] as String).toList();

      // Get similar movies for each recent watch
      final List<Movie> recommendations = [];

      for (String movieId in recentMovieIds) {
        final similarMovies = await TMDBService.getSimilarMovies(movieId);

        // Add top 2 similar movies for each recent watch
        for (var i = 0; i < similarMovies.length && i < 2; i++) {
          recommendations.add(Movie.fromJson(similarMovies[i]));
        }

        // Limit to 10 total recommendations
        if (recommendations.length >= 10) break;
      }

      // Remove duplicates
      final Map<String, Movie> uniqueMovies = {};
      for (var movie in recommendations) {
        uniqueMovies[movie.id] = movie;
      }

      return uniqueMovies.values.toList();
    } catch (e) {
      print('Error getting weekend watch recommendations: $e');
      return [];
    }
  }

  // Helper method to extract preferred genres from highly rated movies
  Future<List<int>> _extractPreferredGenres(List<String> movieIds) async {
    // Create a map to count genre frequencies
    Map<int, int> genreFrequency = {};

    // Fetch details for each movie and analyze genres
    for (String movieId in movieIds) {
      try {
        final movieDetails = await TMDBService.getMovieDetails(movieId);

        // Extract genre IDs from the movie details
        if (movieDetails.containsKey('genres')) {
          final genres = movieDetails['genres'] as List<dynamic>;
          for (var genre in genres) {
            final genreId = genre['id'] as int;
            genreFrequency[genreId] = (genreFrequency[genreId] ?? 0) + 1;
          }
        }
      } catch (e) {
        print('Error fetching movie details for genre extraction: $e');
      }
    }

    // Sort genres by frequency (most frequent first)
    final sortedGenres = genreFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return the top 5 genres or fewer if there aren't 5
    return sortedGenres.take(5).map((entry) => entry.key).toList();
  }

  // Helper method to find users with similar taste
  Future<List<String>> _findSimilarUsers(
      String userId, Map<String, double> userRatingMap) async {
    try {
      // Get all users who rated at least one of the same movies
      final List<String> potentialSimilarUserIds = [];
      final Map<String, double> similarityScores = {};

      // First, get followers and following as potential candidates
      final followers = await _friendService.getFollowers(userId).first;
      final following = await _friendService.getFollowing(userId).first;

      for (var follower in followers) {
        potentialSimilarUserIds.add(follower.userId);
      }

      for (var friend in following) {
        if (!potentialSimilarUserIds.contains(friend.friendId)) {
          potentialSimilarUserIds.add(friend.friendId);
        }
      }

      // For each potential similar user, calculate similarity score
      for (String potentialUserId in potentialSimilarUserIds) {
        // Get their ratings
        final userRatings = await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: potentialUserId)
            .get();

        // Map of movieId -> rating for the potential similar user
        final Map<String, double> potentialUserRatingMap = {};
        for (var doc in userRatings.docs) {
          final data = doc.data();
          if (data.containsKey('rating') && data.containsKey('movieId')) {
            potentialUserRatingMap[data['movieId']] =
                (data['rating'] as num).toDouble();
          }
        }

        // Calculate similarity score using Pearson correlation
        double similarityScore =
            _calculatePearsonCorrelation(userRatingMap, potentialUserRatingMap);

        // Only consider users with positive correlation
        if (similarityScore > 0) {
          similarityScores[potentialUserId] = similarityScore;
        }
      }

      // Sort users by similarity score (highest first)
      final sortedUsers = similarityScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Return the top 10 most similar users or fewer if there aren't 10
      return sortedUsers.take(10).map((entry) => entry.key).toList();
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  // Calculate Pearson correlation coefficient between two users' ratings
  double _calculatePearsonCorrelation(
      Map<String, double> user1Ratings, Map<String, double> user2Ratings) {
    // Find movies rated by both users
    final List<String> commonMovies = user1Ratings.keys
        .where((movieId) => user2Ratings.containsKey(movieId))
        .toList();

    // If there are fewer than 3 common movies, return 0
    if (commonMovies.length < 3) {
      return 0;
    }

    // Calculate means
    double sum1 = 0, sum2 = 0;
    for (String movieId in commonMovies) {
      sum1 += user1Ratings[movieId]!;
      sum2 += user2Ratings[movieId]!;
    }
    double mean1 = sum1 / commonMovies.length;
    double mean2 = sum2 / commonMovies.length;

    // Calculate Pearson correlation
    double numerator = 0;
    double denominator1 = 0;
    double denominator2 = 0;

    for (String movieId in commonMovies) {
      double dev1 = user1Ratings[movieId]! - mean1;
      double dev2 = user2Ratings[movieId]! - mean2;
      numerator += dev1 * dev2;
      denominator1 += dev1 * dev1;
      denominator2 += dev2 * dev2;
    }

    if (denominator1 == 0 || denominator2 == 0) {
      return 0;
    }

    return numerator / (sqrt(denominator1) * sqrt(denominator2));
  }

  // Helper method to get movies from similar users
  Future<List<Movie>> _getMoviesFromSimilarUsers(String userId,
      List<String> similarUserIds, List<String> watchedMovieIds) async {
    try {
      if (similarUserIds.isEmpty) return [];

      // Get movies from similar users - modified to avoid requiring a composite index
      final similarUserMovies = await _firestore
          .collection('diary_entries')
          .where('userId', whereIn: similarUserIds)
          .get();

      // Create a weighted rating map for movies
      Map<String, _WeightedRating> weightedRatings = {};

      // Process each diary entry
      for (var doc in similarUserMovies.docs) {
        final data = doc.data();
        final String movieId = data['movieId'];
        final double rating = (data['rating'] as num).toDouble();
        final String ratingUserId = data['userId'];

        // Skip if user has already watched this movie
        if (watchedMovieIds.contains(movieId)) {
          continue;
        }

        // Get the similarity score for this user
        double similarityScore = await _getUserSimilarityScore(ratingUserId);

        // Add to weighted ratings
        if (!weightedRatings.containsKey(movieId)) {
          weightedRatings[movieId] = _WeightedRating(movieId);
        }
        weightedRatings[movieId]!.addRating(rating, similarityScore);
      }

      // Sort movies by weighted rating
      final sortedMovies = weightedRatings.values.toList()
        ..sort(
            (a, b) => b.getWeightedRating().compareTo(a.getWeightedRating()));

      // Take top 20 movies
      final topMovies = sortedMovies.take(20).toList();

      // Get movie details and create Movie objects
      final List<Movie> recommendations = [];
      for (var weightedRating in topMovies) {
        try {
          final movieDetails =
              await TMDBService.getMovieDetails(weightedRating.movieId);
          recommendations.add(Movie.fromJson(movieDetails));

          // Limit to 10 recommendations
          if (recommendations.length >= 10) break;
        } catch (e) {
          print(
              'Error getting movie details for ${weightedRating.movieId}: $e');
        }
      }

      return recommendations;
    } catch (e) {
      print('Error getting movies from similar users: $e');
      return [];
    }
  }

  // Helper method to get user similarity score
  Future<double> _getUserSimilarityScore(String userId) async {
    // In a real implementation, you would store and retrieve these scores
    // For now, we'll return a default value
    return 0.8;
  }
}
