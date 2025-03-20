import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mood.dart';
import '../models/movie.dart';

class MoodRecommendationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save user's mood selection with intensity
  static Future<void> saveUserMoodSelection(
    String userId,
    String moodId, {
    double intensity = 0.5,
  }) async {
    try {
      final userMoodsRef =
          _firestore.collection('users').doc(userId).collection('moods');

      // Add new mood entry
      await userMoodsRef.add({
        'moodId': moodId,
        'intensity': intensity,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's mood history (keep last 10)
      final querySnapshot =
          await userMoodsRef.orderBy('timestamp', descending: true).get();

      if (querySnapshot.docs.length > 10) {
        final docsToDelete = querySnapshot.docs.sublist(10);
        for (var doc in docsToDelete) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('Error saving mood selection: $e');
      rethrow;
    }
  }

  // Get user's recent moods
  static Future<List<Map<String, dynamic>>> getRecentMoods(
      String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'moodId': data['moodId'],
          'intensity': data['intensity'] ?? 0.5,
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('Error getting recent moods: $e');
      return [];
    }
  }

  // Get movie recommendations based on mood and intensity
  static Future<List<Movie>> getMoviesByMood(
    Mood mood, {
    double intensity = 0.5,
  }) async {
    try {
      // Get base recommendations from TMDB API
      final List<Movie> baseRecommendations = await _getMoviesByGenres(
        mood.genreIds,
        limit: 20,
      );

      // Apply intensity-based filtering
      final adjustedRecommendations = _adjustRecommendationsByIntensity(
        baseRecommendations,
        intensity,
      );

      return adjustedRecommendations;
    } catch (e) {
      print('Error getting movies by mood: $e');
      rethrow;
    }
  }

  // Helper method to get movies by genre IDs
  static Future<List<Movie>> _getMoviesByGenres(
    List<int> genreIds, {
    int limit = 20,
  }) async {
    // Implementation depends on your movie data source (e.g., TMDB API)
    // This is a placeholder that should be replaced with actual API calls
    return [];
  }

  // Helper method to adjust recommendations based on intensity
  static List<Movie> _adjustRecommendationsByIntensity(
    List<Movie> movies,
    double intensity,
  ) {
    // Sort movies by how well they match the intensity
    movies.sort((a, b) {
      // Example scoring based on movie attributes that indicate intensity
      // (e.g., vote average, popularity, release date)
      final scoreA = _calculateIntensityScore(a, intensity);
      final scoreB = _calculateIntensityScore(b, intensity);
      return scoreB.compareTo(scoreA);
    });

    // Return top matches
    return movies.take(10).toList();
  }

  // Helper method to calculate how well a movie matches the desired intensity
  static double _calculateIntensityScore(Movie movie, double targetIntensity) {
    // Example scoring logic (replace with your own algorithm)
    // This could consider factors like:
    // - Movie rating (higher ratings might correlate with stronger emotional impact)
    // - Release date (newer movies might have more intense effects)
    // - Popularity (more popular movies might be more engaging)
    // - Genre-specific factors

    double score = 0.0;

    // Rating contribution (0-10 scale)
    final ratingScore = (movie.voteAverage / 10.0) * targetIntensity;
    score += ratingScore * 0.4; // 40% weight

    // Popularity contribution (normalized to 0-1)
    final popularityScore = (movie.popularity / 100.0) * targetIntensity;
    score += popularityScore * 0.3; // 30% weight

    // Recency contribution
    final yearDiff = DateTime.now().year - int.parse(movie.year);
    final recencyScore =
        (1 - (yearDiff / 50).clamp(0.0, 1.0)) * targetIntensity;
    score += recencyScore * 0.3; // 30% weight

    return score;
  }

  // Get all available genres
  static Future<Map<int, String>> getGenres() async {
    // This should be replaced with actual genre fetching from your movie data source
    return {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Science Fiction',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
    };
  }
}
