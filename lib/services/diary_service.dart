import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import 'post_service.dart';

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

    // Create a post about the diary entry if rating is provided
    if (rating > 0) {
      final user = _auth.currentUser;
      if (user != null) {
        String content = review.isNotEmpty
            ? review
            : 'I watched ${movie.title} and rated it ${rating % 1 == 0 ? rating.toInt() : rating} stars!';

        await _postService.createPost(
          userId: user.uid,
          userName: user.displayName ?? 'User',
          userAvatar: user.photoURL ??
              'https://ui-avatars.com/api/?name=${user.displayName ?? "User"}',
          content: content,
          movie: movie,
          rating: rating,
        );
      }
    }
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
    // Get the current diary entry
    final diaryDoc =
        await _firestore.collection('diary_entries').doc(entryId).get();

    if (!diaryDoc.exists) {
      throw Exception('Diary entry not found');
    }

    final diaryData = diaryDoc.data()!;
    final userId = diaryData['userId'] as String;
    final movieId = diaryData['movieId'] as String;

    // Update diary entry
    final Map<String, dynamic> updates = {};
    if (rating != null) updates['rating'] = rating;
    if (review != null) updates['review'] = review;
    if (watchedDate != null) {
      updates['watchedDate'] = Timestamp.fromDate(watchedDate);
    }
    if (isFavorite != null) updates['isFavorite'] = isFavorite;
    if (isRewatch != null) updates['isRewatch'] = isRewatch;

    await _firestore.collection('diary_entries').doc(entryId).update(updates);

    // If rating was updated, find and update associated post
    if (rating != null) {
      // Find posts for this movie by this user
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('movieId', isEqualTo: movieId)
          .get();

      if (postsQuery.docs.isNotEmpty) {
        // Update the most recent post with the new rating
        final postId = postsQuery.docs.first.id;
        await _firestore.collection('posts').doc(postId).update({
          'rating': rating,
        });
      }
    }
  }

  // Delete a diary entry
  Future<void> deleteDiaryEntry(String entryId) async {
    await _firestore.collection('diary_entries').doc(entryId).delete();
  }

  // Get diary statistics
  Future<Map<String, dynamic>> getDiaryStats(String userId) async {
    final QuerySnapshot entries = await _firestore
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
