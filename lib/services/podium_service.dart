import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/podium_movie.dart';

class PodiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get podium movies for a user
  Stream<List<PodiumMovie>> getPodiumMovies(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return [];
      final data = snapshot.data()!;
      final podiumMovies = data['podiumMovies'] as List? ?? [];
      return podiumMovies.map((movie) => PodiumMovie.fromJson(movie)).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
    });
  }

  // Add or update a podium movie
  Future<void> updatePodiumMovie(PodiumMovie movie) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get current podium movies
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final currentPodiumMovies =
        (userDoc.data()?['podiumMovies'] as List? ?? [])
            .map((m) => PodiumMovie.fromJson(m))
            .toList();

    // Validate rank (must be 1, 2, or 3)
    if (movie.rank < 1 || movie.rank > 3) {
      throw Exception('Invalid rank. Must be between 1 and 3.');
    }

    // Remove any existing movie with the same rank and add the new one
    final updatedPodiumMovies =
        currentPodiumMovies.where((m) => m.rank != movie.rank).toList()
          ..add(movie);

    // Ensure we don't exceed 3 movies
    if (updatedPodiumMovies.length > 3) {
      throw Exception('Cannot have more than 3 podium movies.');
    }

    // Update Firestore
    await _firestore.collection('users').doc(userId).update({
      'podiumMovies': updatedPodiumMovies.map((m) => m.toJson()).toList(),
    });
  }

  // Remove a podium movie
  Future<void> removePodiumMovie(int rank) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get current podium movies
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final currentPodiumMovies =
        (userDoc.data()?['podiumMovies'] as List? ?? [])
            .map((m) => PodiumMovie.fromJson(m))
            .toList();

    // Remove the movie with the specified rank
    final updatedPodiumMovies =
        currentPodiumMovies.where((m) => m.rank != rank).toList();

    // Update Firestore
    await _firestore.collection('users').doc(userId).update({
      'podiumMovies': updatedPodiumMovies.map((m) => m.toJson()).toList(),
    });
  }

  // Swap ranks of two podium movies
  Future<void> swapPodiumRanks(int rank1, int rank2) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get current podium movies
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final currentPodiumMovies =
        (userDoc.data()?['podiumMovies'] as List? ?? [])
            .map((m) => PodiumMovie.fromJson(m))
            .toList();

    // Find the movies to swap
    final movie1 = currentPodiumMovies.firstWhere(
      (m) => m.rank == rank1,
      orElse: () => throw Exception('No movie found with rank $rank1'),
    );
    final movie2 = currentPodiumMovies.firstWhere(
      (m) => m.rank == rank2,
      orElse: () => throw Exception('No movie found with rank $rank2'),
    );

    // Swap ranks
    final updatedPodiumMovies =
        currentPodiumMovies
            .map(
              (m) =>
                  m.rank == rank1
                      ? m.copyWith(rank: rank2)
                      : m.rank == rank2
                      ? m.copyWith(rank: rank1)
                      : m,
            )
            .toList();

    // Update Firestore
    await _firestore.collection('users').doc(userId).update({
      'podiumMovies': updatedPodiumMovies.map((m) => m.toJson()).toList(),
    });
  }
}
