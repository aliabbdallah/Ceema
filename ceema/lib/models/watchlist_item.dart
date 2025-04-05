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
    return WatchlistItem(
      id: documentId,
      userId: json['userId'] ?? '',
      movie: Movie(
        id: json['movie']['id'] ?? '',
        title: json['movie']['title'] ?? '',
        posterUrl: json['movie']['posterUrl'] ?? '',
        year: json['movie']['year'] ?? '',
        overview: json['movie']['overview'] ?? '',
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
