// Modified lib/services/diary_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import 'post_service.dart';
import 'profile_service.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new diary entry
  Future<void> addDiaryEntry({
    required String userId,
    required Movie movie,
    required double rating,
    required String review,
    required DateTime watchedDate,
    required bool isFavorite,
    required bool isRewatch,
  }) async {
    // Add diary entry
    await _firestore.collection('diary_entries').add({
      'userId': userId,
      'movieId': movie.id,
      'movieTitle': movie.title,
      'moviePosterUrl': movie.posterUrl,
      'movieYear': movie.year,
      'rating': rating,
      'review': review,
      'watchedDate': Timestamp.fromDate(watchedDate),
      'isFavorite': isFavorite,
      'isRewatch': isRewatch,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update watched count
    final profileService = ProfileService();
    await profileService.updateUserFriendStats(userId);
  }

  // Get all diary entries for a user
  Stream<List<DiaryEntry>> getDiaryEntries(String userId) {
    return _firestore
        .collection('diary_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('watchedDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DiaryEntry.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  // Update a diary entry
  Future<void> updateDiaryEntry(
    String entryId, {
    double? rating,
    String? review,
    DateTime? watchedDate,
    bool? isFavorite,
    bool? isRewatch,
  }) async {
    final updateData = <String, dynamic>{};

    if (rating != null) updateData['rating'] = rating;
    if (review != null) updateData['review'] = review;
    if (watchedDate != null)
      updateData['watchedDate'] = Timestamp.fromDate(watchedDate);
    if (isFavorite != null) updateData['isFavorite'] = isFavorite;
    if (isRewatch != null) updateData['isRewatch'] = isRewatch;

    await _firestore
        .collection('diary_entries')
        .doc(entryId)
        .update(updateData);
  }

  // Delete a diary entry
  Future<void> deleteDiaryEntry(String entryId) async {
    await _firestore.collection('diary_entries').doc(entryId).delete();
  }

  // Get diary statistics
  Future<Map<String, dynamic>> getDiaryStats(String userId) async {
    final QuerySnapshot entries =
        await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: userId)
            .get();

    int totalMovies = entries.docs.length;
    double totalRating = 0;
    int totalRewatches = 0;
    int totalFavorites = 0;

    for (var doc in entries.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRating += (data['rating'] ?? 0).toDouble();
      if (data['isRewatch'] == true) totalRewatches++;
      if (data['isFavorite'] == true) totalFavorites++;
    }

    return {
      'totalMovies': totalMovies,
      'averageRating': totalMovies > 0 ? totalRating / totalMovies : 0,
      'totalRewatches': totalRewatches,
      'totalFavorites': totalFavorites,
    };
  }
}
