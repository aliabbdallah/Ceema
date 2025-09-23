import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watchlist_item.dart';
import '../models/movie.dart';
import 'tmdb_service.dart'; // Import TMDBService

class WatchlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TMDBService _tmdbService = TMDBService(); // Add TMDBService instance

  // Add a movie to watchlist by ID
  Future<void> addToWatchlist({
    required String userId,
    required String movieId, // Changed from Movie movie
    String? notes,
  }) async {
    // Check if the movie is already in the watchlist by ID
    final existingItem =
        await _firestore
            .collection('watchlist_items')
            .where('userId', isEqualTo: userId)
            .where('movie.id', isEqualTo: movieId) // Check using movie ID
            .limit(1)
            .get();

    if (existingItem.docs.isNotEmpty) {
      // Movie already in watchlist, update notes if provided
      if (notes != null) {
        await _firestore
            .collection('watchlist_items')
            .doc(existingItem.docs.first.id)
            .update({'notes': notes});
      }
      print('Movie $movieId already in watchlist for user $userId.');
      return;
    }

    try {
      // Fetch full movie details from TMDBService
      final Movie? movie = await _tmdbService.getMovieDetails(movieId);

      if (movie == null) {
        throw Exception('Failed to fetch movie details for ID: $movieId');
      }

      // Add new watchlist item with full details
      await _firestore.collection('watchlist_items').add({
        'userId': userId,
        'movie': movie.toJson(), // Use the fetched movie object
        'addedAt': FieldValue.serverTimestamp(),
        'notes': notes,
      });
      print('Added movie $movieId to watchlist for user $userId.');

      // Update user's watchlist count
      await _updateWatchlistCount(userId);
    } catch (e) {
      print('Error adding movie $movieId to watchlist: $e');
      // Re-throw or handle error as needed
      throw Exception('Failed to add movie to watchlist: $e');
    }
  }

  // Remove a movie from watchlist
  Future<void> removeFromWatchlist(String itemId, String userId) async {
    await _firestore.collection('watchlist_items').doc(itemId).delete();
    await _updateWatchlistCount(userId);
  }

  // Mark a watchlist item as watched (moves to diary)
  Future<void> markAsWatched(String itemId, String userId) async {
    // This would typically involve:
    // 1. Getting the watchlist item
    // 2. Creating a diary entry with default values
    // 3. Removing the watchlist item
    // For now, we'll just remove it from the watchlist
    await removeFromWatchlist(itemId, userId);
  }

  // Get all watchlist items for a user
  Stream<List<WatchlistItem>> getWatchlistItems(String userId) {
    return _firestore
        .collection('watchlist_items')
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => WatchlistItem.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  // Check if a movie is in the user's watchlist
  Future<bool> isInWatchlist(String userId, String movieId) async {
    final query =
        await _firestore
            .collection('watchlist_items')
            .where('userId', isEqualTo: userId)
            .where('movie.id', isEqualTo: movieId) // Check using movie ID
            .limit(1)
            .get();

    return query.docs.isNotEmpty;
  }

  // Get watchlist count for a user
  Future<int> getWatchlistCount(String userId) async {
    final query =
        await _firestore
            .collection('watchlist_items')
            .where('userId', isEqualTo: userId)
            .count()
            .get();

    return query.count ?? 0;
  }

  // Update user's watchlist count in their profile
  Future<void> _updateWatchlistCount(String userId) async {
    final count = await getWatchlistCount(userId);
    await _firestore.collection('users').doc(userId).update({
      'watchlistCount': count,
    });
  }

  // Get filtered watchlist items
  Future<List<WatchlistItem>> getFilteredWatchlist({
    required String userId,
    String? genre,
    String? year,
    String? sortBy,
    bool descending = true,
  }) async {
    Query query = _firestore
        .collection('watchlist_items')
        .where('userId', isEqualTo: userId);

    // Apply filters
    if (genre != null) {
      // This assumes movies have genres stored in them
      // You might need to adjust this based on your data structure
      query = query.where('movie.genres', arrayContains: genre);
    }

    if (year != null) {
      query = query.where('movie.year', isEqualTo: year);
    }

    // Apply sorting
    String orderField = 'addedAt';
    if (sortBy == 'title') {
      orderField = 'movie.title';
    } else if (sortBy == 'year') {
      orderField = 'movie.year';
    }

    QuerySnapshot snapshot =
        await query.orderBy(orderField, descending: descending).get();

    return snapshot.docs
        .map(
          (doc) => WatchlistItem.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // Get filtered watchlist items as a stream
  Stream<List<WatchlistItem>> getFilteredWatchlistStream({
    required String userId,
    String? genre,
    String? year,
    String? sortBy,
    bool descending = true,
  }) {
    Query query = _firestore
        .collection('watchlist_items')
        .where('userId', isEqualTo: userId);

    // Apply filters
    if (genre != null) {
      query = query.where('movie.genres', arrayContains: genre);
    }

    if (year != null) {
      query = query.where('movie.year', isEqualTo: year);
    }

    // Apply sorting
    String orderField = 'addedAt';
    if (sortBy == 'title') {
      orderField = 'movie.title';
    } else if (sortBy == 'year') {
      orderField = 'movie.year';
    }

    return query.orderBy(orderField, descending: descending).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map(
            (doc) => WatchlistItem.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }
}
