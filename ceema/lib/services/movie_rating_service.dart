import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie.dart';
import '../services/profile_service.dart';

class MovieRatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add or update a movie rating
  Future<void> addOrUpdateRating({
    required String userId,
    required Movie movie,
    required double rating,
  }) async {
    // Check if rating exists
    final existingRating =
        await _firestore
            .collection('movie_ratings')
            .where('userId', isEqualTo: userId)
            .where('movieId', isEqualTo: movie.id)
            .limit(1)
            .get();

    if (existingRating.docs.isNotEmpty) {
      // Update existing rating
      await _firestore
          .collection('movie_ratings')
          .doc(existingRating.docs.first.id)
          .update({
            'rating': rating,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } else {
      // Add new rating
      await _firestore.collection('movie_ratings').add({
        'userId': userId,
        'movieId': movie.id,
        'movieTitle': movie.title,
        'moviePosterUrl': movie.posterUrl,
        'movieYear': movie.year,
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update watched count
    final profileService = ProfileService();
    await profileService.updateUserFriendStats(userId);
  }

  // Get a user's rating for a movie
  Future<double?> getRating(String userId, String movieId) async {
    final querySnapshot =
        await _firestore
            .collection('movie_ratings')
            .where('userId', isEqualTo: userId)
            .where('movieId', isEqualTo: movieId)
            .limit(1)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      return (querySnapshot.docs.first.data()['rating'] as num).toDouble();
    }
    return null;
  }

  // Get all ratings for a user
  Stream<List<Map<String, dynamic>>> getUserRatings(String userId) {
    return _firestore
        .collection('movie_ratings')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // Delete a rating
  Future<void> deleteRating(String userId, String movieId) async {
    final querySnapshot =
        await _firestore
            .collection('movie_ratings')
            .where('userId', isEqualTo: userId)
            .where('movieId', isEqualTo: movieId)
            .limit(1)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      await _firestore
          .collection('movie_ratings')
          .doc(querySnapshot.docs.first.id)
          .delete();
    }
  }
}
