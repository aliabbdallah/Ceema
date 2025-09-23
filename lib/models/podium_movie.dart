import 'package:cloud_firestore/cloud_firestore.dart';

class PodiumMovie {
  final String tmdbId;
  final String title;
  final String posterUrl;
  final int rank; // 1, 2, or 3
  final String? comment;

  PodiumMovie({
    required this.tmdbId,
    required this.title,
    required this.posterUrl,
    required this.rank,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'tmdbId': tmdbId,
      'title': title,
      'posterUrl': posterUrl,
      'rank': rank,
      'comment': comment,
    };
  }

  factory PodiumMovie.fromJson(Map<String, dynamic> json) {
    return PodiumMovie(
      tmdbId: json['tmdbId'] ?? '',
      title: json['title'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      rank: json['rank'] ?? 0,
      comment: json['comment'],
    );
  }

  PodiumMovie copyWith({
    String? tmdbId,
    String? title,
    String? posterUrl,
    int? rank,
    String? comment,
  }) {
    return PodiumMovie(
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      rank: rank ?? this.rank,
      comment: comment ?? this.comment,
    );
  }
}
