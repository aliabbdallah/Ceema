// lib/services/preference_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../models/movie.dart';
import '../models/preference.dart';
import 'tmdb_service.dart';

class PreferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user preferences
  Future<UserPreferences> getUserPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final doc =
          await _firestore.collection('user_preferences').doc(userId).get();

      if (doc.exists) {
        return UserPreferences.fromJson(doc.data() ?? {});
      } else {
        // Create default preferences if none exist
        final defaultPrefs = UserPreferences(
          userId: userId,
          likes: [],
          dislikes: [],
          importanceFactors: {
            'story': 1.0,
            'acting': 1.0,
            'visuals': 1.0,
            'soundtrack': 1.0,
            'pacing': 1.0,
          },
        );

        await _firestore
            .collection('user_preferences')
            .doc(userId)
            .set(defaultPrefs.toJson());
        return defaultPrefs;
      }
    } catch (e) {
      print('Error getting user preferences: $e');
      throw Exception('Failed to load preferences');
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(UserPreferences preferences) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('user_preferences')
          .doc(userId)
          .set(preferences.toJson());
    } catch (e) {
      print('Error updating user preferences: $e');
      throw Exception('Failed to update preferences');
    }
  }

  // Add a preference (like)
  Future<void> addPreference({
    required String id,
    required String name,
    required String type,
    double weight = 1.0,
  }) async {
    final prefs = await getUserPreferences();

    // Check if already exists
    bool exists = prefs.likes.any((item) => item.id == id && item.type == type);

    if (!exists) {
      final newLikes = [
        ...prefs.likes,
        Preference(
          id: id,
          name: name,
          type: type,
          weight: weight,
        )
      ];

      await updateUserPreferences(prefs.copyWith(likes: newLikes));
    }
  }

  // Add a dislike preference
  Future<void> addDislikePreference({
    required String id,
    required String name,
    required String type,
    double weight = 1.0,
  }) async {
    final prefs = await getUserPreferences();

    // Check if already exists
    bool exists =
        prefs.dislikes.any((item) => item.id == id && item.type == type);

    if (!exists) {
      final newDislikes = [
        ...prefs.dislikes,
        Preference(
          id: id,
          name: name,
          type: type,
          weight: weight,
        )
      ];

      await updateUserPreferences(prefs.copyWith(dislikes: newDislikes));
    }
  }

  // Remove a preference
  Future<void> removePreference({
    required String id,
    required String type,
    required bool isLike,
  }) async {
    final prefs = await getUserPreferences();

    if (isLike) {
      final newLikes = prefs.likes
          .where((item) => !(item.id == id && item.type == type))
          .toList();

      await updateUserPreferences(prefs.copyWith(likes: newLikes));
    } else {
      final newDislikes = prefs.dislikes
          .where((item) => !(item.id == id && item.type == type))
          .toList();

      await updateUserPreferences(prefs.copyWith(dislikes: newDislikes));
    }
  }

  // Update importance factors
  Future<void> updateImportanceFactor(String factor, double value) async {
    final prefs = await getUserPreferences();

    final newFactors = Map<String, double>.from(prefs.importanceFactors);
    newFactors[factor] = value;

    await updateUserPreferences(prefs.copyWith(importanceFactors: newFactors));
  }

  // Mark a movie as "not interested"
  Future<void> markMovieAsNotInterested(String movieId) async {
    final prefs = await getUserPreferences();

    if (!prefs.dislikedMovieIds.contains(movieId)) {
      final newDislikedIds = [...prefs.dislikedMovieIds, movieId];

      await updateUserPreferences(
          prefs.copyWith(dislikedMovieIds: newDislikedIds));
    }
  }

  // Remove a movie from "not interested" list
  Future<void> removeMovieFromNotInterested(String movieId) async {
    final prefs = await getUserPreferences();

    final newDislikedIds =
        prefs.dislikedMovieIds.where((id) => id != movieId).toList();

    await updateUserPreferences(
        prefs.copyWith(dislikedMovieIds: newDislikedIds));
  }
}
