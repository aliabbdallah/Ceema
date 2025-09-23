import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie.dart';

class WatchlistItem {
  final String id;
  final String userId;
  final Movie movie;
  final DateTime addedAt;
  final String? notes;

  WatchlistItem({
    required this.id,
    required this.userId,
    required this.movie,
    required this.addedAt,
    this.notes,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json, String documentId) {
    final movieData = json['movie'] as Map<String, dynamic>? ?? {};
    return WatchlistItem(
      id: documentId,
      userId: json['userId'] ?? '',
      movie: Movie(
        id: movieData['id'] ?? '',
        title: movieData['title'] ?? '',
        posterUrl: movieData['posterUrl'] ?? '',
        year: movieData['year'] ?? '',
        overview: movieData['overview'] ?? '',
        director: movieData['director'] ?? '',
      ),
      addedAt: (json['addedAt'] as Timestamp).toDate(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'movie': movie.toJson(),
      'addedAt': Timestamp.fromDate(addedAt),
      'notes': notes,
    };
  }
}
