// services/recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import 'tmdb_service.dart';
import 'friend_service.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  // Get recommendations based on user's preferred genres
  Future<List<Movie>> getGenreBasedRecommendations(String userId) async {
    try {
      // Get user's highly rated movies
      final highlyRatedMovies = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .limit(10)
          .get();

      // Extract movie IDs and get their details to analyze genres
      final List<String> movieIds = highlyRatedMovies.docs
          .map((doc) => doc.data()['movieId'] as String)
          .toList();

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
      // Get user's recent watches (last 2 weeks)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final recentWatches = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .where('watchedAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .orderBy('watchedAt', descending: true)
          .limit(5)
          .get();

      // Extract movie IDs
      final List<String> recentMovieIds = recentWatches.docs
          .map((doc) => doc.data()['movieId'] as String)
          .toList();

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
    // In a real app, you would fetch each movie's genres and analyze the frequency
    // For simplicity, we'll return some common genre IDs
    // Action (28), Adventure (12), Comedy (35), Drama (18), Sci-Fi (878)
    return [28, 12, 35, 18, 878];
  }

  // Helper method to find users with similar taste
  Future<List<String>> _findSimilarUsers(
      String userId, Map<String, double> userRatingMap) async {
    try {
      // Get all users who rated at least one of the same movies
      final List<String> similarUserIds = [];

      // In a real app, this would use a more sophisticated algorithm
      // For now, we'll get users who follow the current user
      final followers = await _friendService.getFollowers(userId).first;

      for (var follower in followers) {
        similarUserIds.add(follower.userId);
      }

      // Add some following users too
      final following = await _friendService.getFollowing(userId).first;

      for (var friend in following) {
        if (!similarUserIds.contains(friend.friendId)) {
          similarUserIds.add(friend.friendId);
        }
      }

      return similarUserIds;
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  // Helper method to get movies from similar users
  Future<List<Movie>> _getMoviesFromSimilarUsers(String userId,
      List<String> similarUserIds, List<String> watchedMovieIds) async {
    try {
      if (similarUserIds.isEmpty) return [];

      // Get highly rated movies from similar users
      final highlyRatedMovies = await _firestore
          .collection('diary_entries')
          .where('userId', whereIn: similarUserIds)
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .limit(20)
          .get();

      // Filter out movies the user has already watched
      final List<Movie> recommendations = [];
      final Set<String> addedMovieIds = {};

      for (var doc in highlyRatedMovies.docs) {
        final data = doc.data();
        final String movieId = data['movieId'];

        // Skip if user has already watched this movie or if we already added it
        if (watchedMovieIds.contains(movieId) ||
            addedMovieIds.contains(movieId)) {
          continue;
        }

        // Get movie details
        try {
          final movieDetails = await TMDBService.getMovieDetails(movieId);
          recommendations.add(Movie.fromJson(movieDetails));
          addedMovieIds.add(movieId);

          // Limit to 10 recommendations
          if (recommendations.length >= 10) break;
        } catch (e) {
          print('Error getting movie details for $movieId: $e');
        }
      }

      return recommendations;
    } catch (e) {
      print('Error getting movies from similar users: $e');
      return [];
    }
  }
}
