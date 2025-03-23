import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../services/preference_service.dart';
import '../services/tmdb_service.dart';

class AutomaticPreferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceService _preferenceService = PreferenceService();

  // Rating thresholds
  static const double _highRatingThreshold = 4.0; // 4 stars and above
  static const double _lowRatingThreshold = 2.0; // 2 stars and below

  // Genre mapping for reference (same as in PreferenceSettingsScreen)
  final Map<int, String> _genreMap = {
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

  // Generate preferences automatically based on user diary entries
  Future<void> generateAutomaticPreferences() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all diary entries for the user
      final diarySnapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      // Process entries with high ratings (likes)
      final highRatedEntries = diarySnapshot.docs
          .where((doc) => (doc.data()['rating'] ?? 0) >= _highRatingThreshold)
          .toList();

      // Process entries with low ratings (dislikes)
      final lowRatedEntries = diarySnapshot.docs
          .where((doc) => (doc.data()['rating'] ?? 0) <= _lowRatingThreshold)
          .toList();

      // Generate preferences from high-rated movies
      await _processHighRatedMovies(highRatedEntries);

      // Generate dislikes from low-rated movies
      await _processLowRatedMovies(lowRatedEntries);

      print('Automatic preference generation completed');
    } catch (e) {
      print('Error generating automatic preferences: $e');
      rethrow;
    }
  }

  // Process highly rated movies to extract likes
  Future<void> _processHighRatedMovies(
      List<QueryDocumentSnapshot> entries) async {
    if (entries.isEmpty) return;

    final tmdbService = TMDBService();

    for (var entry in entries) {
      try {
        final data = entry.data() as Map<String, dynamic>;
        final movieId = data['movieId'] as String;

        // Get detailed movie information including credits
        final movieDetails = await tmdbService.getMovieDetails(movieId);

        // Convert Movie to Map<String, dynamic> for compatibility
        final movieMap = {
          'id': movieDetails.id,
          'title': movieDetails.title,
          'genres': await _fetchMovieGenres(movieId),
          'credits': await TMDBService.getMovieCredits(movieId),
        };

        // Process genres
        await _processGenres(movieMap, true);

        // Process actors (cast)
        await _processActors(movieMap, true);

        // Process directors
        await _processDirectors(movieMap, true);
      } catch (e) {
        print('Error processing high-rated movie: $e');
        // Continue with next entry if one fails
        continue;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMovieGenres(String movieId) async {
    try {
      final movieDetailsRaw = await TMDBService.getMovieDetailsRaw(movieId);
      return List<Map<String, dynamic>>.from(movieDetailsRaw['genres'] ?? []);
    } catch (e) {
      print('Error fetching movie genres: $e');
      return [];
    }
  }

  // Process low-rated movies to extract dislikes
  Future<void> _processLowRatedMovies(
      List<QueryDocumentSnapshot> entries) async {
    if (entries.isEmpty) return;

    final tmdbService = TMDBService();

    for (var entry in entries) {
      try {
        final data = entry.data() as Map<String, dynamic>;
        final movieId = data['movieId'] as String;

        // First, mark the movie itself as not interested
        await _preferenceService.markMovieAsNotInterested(movieId);

        // Get detailed movie information including credits
        final movieDetails = await tmdbService.getMovieDetails(movieId);

        // Convert Movie to Map<String, dynamic> for compatibility
        final movieMap = {
          'id': movieDetails.id,
          'title': movieDetails.title,
          'genres': await _fetchMovieGenres(movieId),
          'credits': await TMDBService.getMovieCredits(movieId),
        };

        // Process genres
        await _processGenres(movieMap, false);

        // Process actors (cast)
        await _processActors(movieMap, false);

        // Process directors
        await _processDirectors(movieMap, false);
      } catch (e) {
        print('Error processing low-rated movie: $e');
        // Continue with next entry if one fails
        continue;
      }
    }
  }

  // Process genres from movie details
  Future<void> _processGenres(
      Map<String, dynamic> movieDetails, bool isLike) async {
    if (!movieDetails.containsKey('genres')) return;

    final genres = movieDetails['genres'] as List;

    for (var genre in genres) {
      final genreId = genre['id'].toString();
      final genreName = genre['name'] as String;

      try {
        if (isLike) {
          await _preferenceService.addPreference(
            id: genreId,
            name: genreName,
            type: 'genre',
          );
        } else {
          await _preferenceService.addDislikePreference(
            id: genreId,
            name: genreName,
            type: 'genre',
          );
        }
      } catch (e) {
        print('Error processing genre: $e');
      }
    }
  }

  // Process actors from movie details
  Future<void> _processActors(
      Map<String, dynamic> movieDetails, bool isLike) async {
    if (!movieDetails.containsKey('credits') ||
        !movieDetails['credits'].containsKey('cast') ||
        (movieDetails['credits']['cast'] as List).isEmpty) {
      // Try getting credits directly
      try {
        final movieId = movieDetails['id'].toString();
        final creditsData = await TMDBService.getMovieCredits(movieId);

        if (!creditsData.containsKey('cast') ||
            (creditsData['cast'] as List).isEmpty) {
          return;
        }

        final cast = creditsData['cast'] as List;
        await _processActorsList(cast, isLike);
      } catch (e) {
        print('Error getting credits: $e');
        return;
      }
    } else {
      final cast = movieDetails['credits']['cast'] as List;
      await _processActorsList(cast, isLike);
    }
  }

  // Helper method to process actors list
  Future<void> _processActorsList(List cast, bool isLike) async {
    // Take top 3 actors only to avoid too many preferences
    final topActors = cast.take(3).toList();

    for (var actor in topActors) {
      final actorId = actor['id'].toString();
      final actorName = actor['name'] as String;

      try {
        if (isLike) {
          await _preferenceService.addPreference(
            id: actorId,
            name: actorName,
            type: 'actor',
            weight: _calculateActorWeight(actor),
          );
        } else {
          await _preferenceService.addDislikePreference(
            id: actorId,
            name: actorName,
            type: 'actor',
            weight: _calculateActorWeight(actor),
          );
        }
      } catch (e) {
        print('Error processing actor: $e');
      }
    }
  }

  // Process directors from movie details
  Future<void> _processDirectors(
      Map<String, dynamic> movieDetails, bool isLike) async {
    if (!movieDetails.containsKey('credits') ||
        !movieDetails['credits'].containsKey('crew') ||
        (movieDetails['credits']['crew'] as List).isEmpty) {
      // Try getting credits directly
      try {
        final movieId = movieDetails['id'].toString();
        final creditsData = await TMDBService.getMovieCredits(movieId);

        if (!creditsData.containsKey('crew') ||
            (creditsData['crew'] as List).isEmpty) {
          return;
        }

        final crew = creditsData['crew'] as List;
        final directors =
            crew.where((person) => person['job'] == 'Director').toList();
        await _processDirectorsList(directors, isLike);
      } catch (e) {
        print('Error getting credits: $e');
        return;
      }
    } else {
      final crew = movieDetails['credits']['crew'] as List;
      final directors =
          crew.where((person) => person['job'] == 'Director').toList();
      await _processDirectorsList(directors, isLike);
    }
  }

  // Helper method to process directors list
  Future<void> _processDirectorsList(List directors, bool isLike) async {
    for (var director in directors) {
      final directorId = director['id'].toString();
      final directorName = director['name'] as String;

      try {
        if (isLike) {
          await _preferenceService.addPreference(
            id: directorId,
            name: directorName,
            type: 'director',
            weight: _calculateDirectorWeight(director),
          );
        } else {
          await _preferenceService.addDislikePreference(
            id: directorId,
            name: directorName,
            type: 'director',
            weight: _calculateDirectorWeight(director),
          );
        }
      } catch (e) {
        print('Error processing director: $e');
      }
    }
  }

  // Calculate actor weight (same as in PreferenceSettingsScreen)
  double _calculateActorWeight(Map<String, dynamic> actor) {
    final popularity = actor['popularity'] ?? 1.0;
    final order = actor['order'] ?? 0;
    return 1.0 + (10.0 / (order + 1)) * (popularity / 100.0);
  }

  // Calculate director weight (same as in PreferenceSettingsScreen)
  double _calculateDirectorWeight(Map<String, dynamic> director) {
    final popularity = director['popularity'] ?? 1.0;
    return 1.0 + (popularity / 100.0);
  }
}
