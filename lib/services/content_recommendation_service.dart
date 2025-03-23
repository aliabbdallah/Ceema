// lib/services/content_recommendation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../models/user_preferences.dart';
import '../services/tmdb_service.dart';
import '../services/preference_service.dart';

class ContentRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceService _preferenceService = PreferenceService();

  // Cache for movie details to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _movieCache = {};

  // Get content-based recommendations
  Future<List<Movie>> getContentBasedRecommendations({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      print('Getting recommendations for user: $userId');

      if (userId == null) {
        print('ERROR: User not authenticated');
        throw Exception('User not authenticated');
      }

      // Get user preferences
      final preferences = await _preferenceService.getUserPreferences();
      print(
          'User preferences loaded: ${preferences.likes.length} likes, ${preferences.dislikes.length} dislikes');

      print('DEBUG: Checking preferences state:');
      print('- Likes: ${preferences.likes.length}');
      print('- Dislikes: ${preferences.dislikes.length}');
      print('- Importance Factors: ${preferences.importanceFactors}');
      print('- Disliked Movies: ${preferences.dislikedMovieIds.length}');

      // Always get some initial candidates, even without preferences
      List<Map<String, dynamic>> candidates = [];
      final tmdbService = TMDBService();

      try {
        // Get trending movies as base candidates
        final trendingMoviesRaw = await TMDBService.getTrendingMoviesRaw();
        print('DEBUG: Got ${trendingMoviesRaw.length} trending movies');
        candidates.addAll(trendingMoviesRaw);
      } catch (e) {
        print('ERROR getting trending movies: $e');
      }

      // If we have importance factors, add top rated movies
      if (preferences.importanceFactors.isNotEmpty) {
        try {
          final topRatedMovies = await TMDBService.getTopRatedMovies();
          print('DEBUG: Got ${topRatedMovies.length} top rated movies');
          candidates.addAll(topRatedMovies);
        } catch (e) {
          print('ERROR getting top rated movies: $e');
        }
      }

      // Get movies based on preferred genres
      final genrePreferences =
          preferences.likes.where((pref) => pref.type == 'genre').toList();

      if (genrePreferences.isNotEmpty) {
        // Get genre IDs from preferences
        final genreIds = genrePreferences
            .map((pref) => int.tryParse(pref.id) ?? 0)
            .where((id) => id > 0)
            .toList();

        if (genreIds.isNotEmpty) {
          final genreMovies = await TMDBService.getMoviesByGenres(genreIds);
          candidates.addAll(genreMovies);
        }
      }

      // Get movies from preferred directors
      final directorPreferences =
          preferences.likes.where((pref) => pref.type == 'director').toList();

      for (var director in directorPreferences) {
        try {
          // Search for movies by the director
          final directorMoviesRaw =
              await TMDBService.searchMoviesRaw(director.name);
          candidates.addAll(directorMoviesRaw);
        } catch (e) {
          print('Error getting movies for director ${director.name}: $e');
        }
      }

      // Get movies from preferred actors
      final actorPreferences =
          preferences.likes.where((pref) => pref.type == 'actor').toList();

      for (var actor in actorPreferences) {
        try {
          // Search for movies with the actor
          final actorMoviesRaw = await TMDBService.searchMoviesRaw(actor.name);
          candidates.addAll(actorMoviesRaw);
        } catch (e) {
          print('Error getting movies for actor ${actor.name}: $e');
        }
      }

      // Remove duplicates by ID
      final Map<String, Map<String, dynamic>> uniqueCandidates = {};
      for (var movie in candidates) {
        final id = movie['id'].toString();
        uniqueCandidates[id] = movie;
      }

      // Filter out movies already in user's diary or watchlist
      final userDiary = await _getUserDiaryMovieIds(userId);
      final userWatchlist = await _getUserWatchlistMovieIds(userId);
      final dislikedMovies = preferences.dislikedMovieIds;

      final filteredCandidates = uniqueCandidates.values.where((movie) {
        final movieId = movie['id'].toString();
        return !userDiary.contains(movieId) &&
            !userWatchlist.contains(movieId) &&
            !dislikedMovies.contains(movieId);
      }).toList();

      // Score and rank candidates
      List<Map<String, dynamic>> scoredCandidates =
          await _scoreCandidates(filteredCandidates, preferences);

      // Sort by score (descending)
      scoredCandidates.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // Convert to Movie objects with error handling
      final recommendedMovies = <Movie>[];
      for (var data in scoredCandidates.take(limit)) {
        try {
          print(
              'DEBUG: Converting movie data: ${data['title']} (ID: ${data['id']})');
          final movie = Movie.fromJson(data);
          recommendedMovies.add(movie);
        } catch (e) {
          print('ERROR converting movie data: $e');
          print('Problematic data: $data');
        }
      }

      print('DEBUG: Returning ${recommendedMovies.length} recommended movies');

      // If no movies could be converted, try fallback
      if (recommendedMovies.isEmpty) {
        print('WARNING: No movies could be converted, trying fallback');
        return _getFallbackRecommendations(limit);
      }

      return recommendedMovies;
    } catch (e) {
      print('Error getting content-based recommendations: $e');
      return _getFallbackRecommendations(limit);
    }
  }

  // Score each candidate movie based on user preferences
  Future<List<Map<String, dynamic>>> _scoreCandidates(
      List<Map<String, dynamic>> candidates,
      UserPreferences preferences) async {
    final result = <Map<String, dynamic>>[];
    final tmdbService = TMDBService();

    for (var candidate in candidates) {
      double score = 0.0;
      final movieId = candidate['id'].toString();

      // Get detailed movie info if needed
      Map<String, dynamic> movieDetails;
      if (_movieCache.containsKey(movieId)) {
        movieDetails = _movieCache[movieId]!;
      } else {
        try {
          movieDetails = await TMDBService.getMovieDetailsRaw(movieId);
          _movieCache[movieId] = movieDetails;
        } catch (e) {
          print('Error getting details for movie $movieId: $e');
          // Use existing data if details can't be fetched
          movieDetails = candidate;
        }
      }

      // Score based on genres
      if (movieDetails.containsKey('genres')) {
        final movieGenres = (movieDetails['genres'] as List)
            .map((g) => g['id'].toString())
            .toList();

        for (var genre
            in preferences.likes.where((pref) => pref.type == 'genre')) {
          if (movieGenres.contains(genre.id)) {
            score += genre.weight;
          }
        }

        // Penalize for disliked genres
        for (var genre
            in preferences.dislikes.where((pref) => pref.type == 'genre')) {
          if (movieGenres.contains(genre.id)) {
            score -= genre.weight * 1.5; // Stronger penalty for dislikes
          }
        }
      }

      // Score based on directors
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('crew')) {
        final directors = (movieDetails['credits']['crew'] as List)
            .where((crew) => crew['job'] == 'Director')
            .map((dir) => dir['id'].toString())
            .toList();

        for (var director
            in preferences.likes.where((pref) => pref.type == 'director')) {
          if (directors.contains(director.id)) {
            score += director.weight * 1.5; // Directors are important
          }
        }

        for (var director
            in preferences.dislikes.where((pref) => pref.type == 'director')) {
          if (directors.contains(director.id)) {
            score -= director.weight * 2.0; // Strong penalty
          }
        }
      }

      // Score based on actors
      if (movieDetails.containsKey('credits') &&
          movieDetails['credits'].containsKey('cast')) {
        final cast = (movieDetails['credits']['cast'] as List)
            .map((actor) => actor['id'].toString())
            .toList();

        for (var actor
            in preferences.likes.where((pref) => pref.type == 'actor')) {
          if (cast.contains(actor.id)) {
            score += actor.weight;
          }
        }

        for (var actor
            in preferences.dislikes.where((pref) => pref.type == 'actor')) {
          if (cast.contains(actor.id)) {
            score -= actor.weight * 1.5;
          }
        }
      }

      // Apply importance factors
      if (movieDetails.containsKey('vote_average')) {
        final rating = (movieDetails['vote_average'] as num).toDouble();

        // Apply rating score weighted by user's importance factors
        if (preferences.importanceFactors.isNotEmpty) {
          // Use average of importance factors as a weight multiplier
          final avgImportance =
              preferences.importanceFactors.values.reduce((a, b) => a + b) /
                  preferences.importanceFactors.length;
          score += (rating / 10.0) * avgImportance;
        } else {
          score += rating / 10.0; // Default weight if no importance factors
        }
      }

      // Store the original movie data with the calculated score
      final scoredMovie = Map<String, dynamic>.from(candidate);
      scoredMovie['score'] = score;
      result.add(scoredMovie);
    }

    return result;
  }

  // Get IDs of movies in user's diary
  Future<List<String>> _getUserDiaryMovieIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['movieId'] as String)
          .toList();
    } catch (e) {
      print('Error getting diary movies: $e');
      return [];
    }
  }

  // Get IDs of movies in user's watchlist
  Future<List<String>> _getUserWatchlistMovieIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('watchlist_items')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['movie']['id'] as String)
          .toList();
    } catch (e) {
      print('Error getting watchlist movies: $e');
      return [];
    }
  }

  // Fallback to trending movies if recommendations can't be generated
  Future<List<Movie>> _getFallbackRecommendations(int limit) async {
    try {
      print('DEBUG: Getting fallback recommendations');
      final trendingMoviesRaw = await TMDBService.getTrendingMoviesRaw();
      print('DEBUG: Got ${trendingMoviesRaw.length} trending movies');

      final movies = <Movie>[];
      for (var data in trendingMoviesRaw.take(limit)) {
        try {
          print(
              'DEBUG: Converting fallback movie: ${data['title']} (ID: ${data['id']})');
          final movie = Movie.fromJson(data);
          movies.add(movie);
        } catch (e) {
          print('ERROR converting fallback movie: $e');
          print('Problematic data: $data');
        }
      }

      print('DEBUG: Returning ${movies.length} fallback movies');
      return movies;
    } catch (e) {
      print('Error getting fallback recommendations: $e');
      return [];
    }
  }
}
