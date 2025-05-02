import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../models/preference.dart';
import 'dart:async';
import 'dart:math';

class TasteProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for movie data to avoid repeated queries
  final Map<String, Map<String, dynamic>> _movieCache = {};

  // Timer for periodic updates
  Timer? _updateTimer;

  // Constructor
  TasteProfileService() {
    // Start periodic updates (every 6 hours)
    _updateTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _updateTasteProfiles();
    });
  }

  // Dispose method to clean up resources
  void dispose() {
    _updateTimer?.cancel();
  }

  // Main method to update taste profiles for all users
  Future<void> _updateTasteProfiles() async {
    try {
      print('[TasteProfileService] Starting taste profile update');

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        await _updateUserTasteProfile(userId);
      }

      print('[TasteProfileService] Completed taste profile updates');
    } catch (e) {
      print('[TasteProfileService] Error updating taste profiles: $e');
    }
  }

  // Update taste profile for a specific user
  Future<void> _updateUserTasteProfile(String userId) async {
    try {
      print('[TasteProfileService] Updating taste profile for user: $userId');

      // Get user interactions
      final interactions = await _getUserInteractions(userId);

      // Get movie details for interacted movies
      final movieDetails = await _getInteractedMovieDetails(interactions);

      // Analyze interactions and build taste profile
      final tasteProfile = await _buildTasteProfile(interactions, movieDetails);

      // Update user preferences
      await _updateUserPreferences(userId, tasteProfile);

      print(
          '[TasteProfileService] Successfully updated taste profile for user: $userId');
    } catch (e) {
      print(
          '[TasteProfileService] Error updating taste profile for user $userId: $e');
    }
  }

  // Get user interactions from the last 30 days
  Future<List<Map<String, dynamic>>> _getUserInteractions(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final interactionsSnapshot = await _firestore
        .collection('userInteractions')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    return interactionsSnapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get movie details for interacted movies
  Future<Map<String, Map<String, dynamic>>> _getInteractedMovieDetails(
      List<Map<String, dynamic>> interactions) async {
    final movieIds = interactions
        .map((interaction) => interaction['movieId'] as String?)
        .where((id) => id != null)
        .toSet();

    final movieDetails = <String, Map<String, dynamic>>{};

    for (final movieId in movieIds) {
      if (movieId != null) {
        movieDetails[movieId] = await _getMovieDetails(movieId);
      }
    }

    return movieDetails;
  }

  // Build taste profile from interactions and movie details
  Future<Map<String, List<Preference>>> _buildTasteProfile(
      List<Map<String, dynamic>> interactions,
      Map<String, Map<String, dynamic>> movieDetails) async {
    final genrePreferences = <String, double>{};
    final actorPreferences = <String, double>{};
    final directorPreferences = <String, double>{};

    // Process each interaction
    for (final interaction in interactions) {
      final movieId = interaction['movieId'] as String?;
      if (movieId == null || !movieDetails.containsKey(movieId)) continue;

      final movie = movieDetails[movieId]!;
      final interactionWeight = _calculateInteractionWeight(interaction);

      // Process genres
      if (movie.containsKey('genres')) {
        for (final genre in movie['genres'] as List) {
          final genreId = genre['id'].toString();
          genrePreferences[genreId] =
              (genrePreferences[genreId] ?? 0) + interactionWeight;
        }
      }

      // Process actors
      if (movie.containsKey('credits') &&
          movie['credits'].containsKey('cast')) {
        final cast = movie['credits']['cast'] as List;
        for (final actor in cast.take(5)) {
          // Consider top 5 actors
          final actorId = actor['id'].toString();
          actorPreferences[actorId] =
              (actorPreferences[actorId] ?? 0) + interactionWeight;
        }
      }

      // Process directors
      if (movie.containsKey('credits') &&
          movie['credits'].containsKey('crew')) {
        final crew = movie['credits']['crew'] as List;
        final directors = crew.where((person) => person['job'] == 'Director');
        for (final director in directors) {
          final directorId = director['id'].toString();
          directorPreferences[directorId] =
              (directorPreferences[directorId] ?? 0) + interactionWeight;
        }
      }
    }

    // Normalize and convert to Preference objects
    final normalizedGenres = _normalizePreferences(genrePreferences, 'genre');
    final normalizedActors = _normalizePreferences(actorPreferences, 'actor');
    final normalizedDirectors =
        _normalizePreferences(directorPreferences, 'director');

    return {
      'genres': normalizedGenres,
      'actors': normalizedActors,
      'directors': normalizedDirectors,
    };
  }

  // Calculate weight for an interaction based on type and duration
  double _calculateInteractionWeight(Map<String, dynamic> interaction) {
    final type = interaction['actionType'] as String?;
    final viewTime = interaction['viewTimeSeconds'] as int? ?? 0;
    final viewPercentage = interaction['viewPercentage'] as double? ?? 0;

    double baseWeight = 1.0;

    switch (type) {
      case 'like':
        baseWeight = 2.0;
        break;
      case 'comment':
        baseWeight = 3.0;
        break;
      case 'save':
        baseWeight = 2.5;
        break;
      case 'view':
        // Weight based on view time and completion
        baseWeight = 1.0 + (viewTime / 30.0) + (viewPercentage / 100.0);
        break;
      default:
        baseWeight = 1.0;
    }

    return baseWeight;
  }

  // Normalize preferences and convert to Preference objects
  List<Preference> _normalizePreferences(
      Map<String, double> preferences, String type) {
    if (preferences.isEmpty) return [];

    // Find max value for normalization
    final maxValue = preferences.values.reduce(max);

    // Convert to Preference objects with normalized weights
    return preferences.entries
        .map((entry) => Preference(
              id: entry.key,
              type: type,
              name: entry
                  .key, // This should be replaced with actual names from TMDB
              weight: entry.value / maxValue,
            ))
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
  }

  // Update user preferences in Firestore
  Future<void> _updateUserPreferences(
      String userId, Map<String, List<Preference>> tasteProfile) async {
    final preferences = UserPreferences(
      userId: userId,
      likes: [
        ...tasteProfile['genres'] ?? [],
        ...tasteProfile['actors'] ?? [],
        ...tasteProfile['directors'] ?? [],
      ],
      dislikes: [], // Dislikes would be handled separately
    );

    await _firestore
        .collection('userPreferences')
        .doc(userId)
        .set(preferences.toJson());
  }

  // Get movie details with caching
  Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
    if (_movieCache.containsKey(movieId)) {
      return _movieCache[movieId]!;
    }

    try {
      // First try getting from Firestore movies collection
      final doc = await _firestore.collection('movies').doc(movieId).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _movieCache[movieId] = data;
        return data;
      }

      // If not in Firestore, try TMDB API
      // TODO: Implement TMDB API call here

      return {};
    } catch (e) {
      print('[TasteProfileService] Error getting movie details: $e');
      return {};
    }
  }
}
