import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String userId;
  final String movieId;
  final String movieTitle;
  final String moviePosterUrl;
  final String movieYear;
  final double rating;
  final String review;
  final DateTime watchedDate;
  final bool isFavorite;
  final bool isRewatch;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.moviePosterUrl,
    required this.movieYear,
    required this.rating,
    required this.review,
    required this.watchedDate,
    required this.isFavorite,
    required this.isRewatch,
    required this.createdAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json, String documentId) {
    return DiaryEntry(
      id: documentId,
      userId: json['userId'] ?? '',
      movieId: json['movieId'] ?? '',
      movieTitle: json['movieTitle'] ?? '',
      moviePosterUrl: json['moviePosterUrl'] ?? '',
      movieYear: json['movieYear'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      review: json['review'] ?? '',
      watchedDate: (json['watchedDate'] as Timestamp).toDate(),
      isFavorite: json['isFavorite'] ?? false,
      isRewatch: json['isRewatch'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterUrl': moviePosterUrl,
      'movieYear': movieYear,
      'rating': rating,
      'review': review,
      'watchedDate': Timestamp.fromDate(watchedDate),
      'isFavorite': isFavorite,
      'isRewatch': isRewatch,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
