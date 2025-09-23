import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String displayName;
  final String userAvatar;
  final String content;
  final String movieId;
  final String movieTitle;
  final String moviePosterUrl;
  final String movieYear;
  final String movieOverview;
  final DateTime createdAt;
  final List<String> likes;
  final int commentCount;
  final double rating;

  int get likesCount => likes.length;

  String get formattedUsername => '@${userName.toLowerCase()}';

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.displayName,
    required this.userAvatar,
    required this.content,
    required this.movieId,
    required this.movieTitle,
    required this.moviePosterUrl,
    this.movieYear = '',
    this.movieOverview = '',
    required this.createdAt,
    required this.likes,
    required this.commentCount,
    this.rating = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': userName,
      'displayName': displayName,
      'profileImageUrl': userAvatar,
      'content': content,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterUrl': moviePosterUrl,
      'movieYear': movieYear,
      'movieOverview': movieOverview,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'commentCount': commentCount,
      'rating': rating,
    };
  }

  factory Post.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime createdAtDate;
    if (json['createdAt'] is Timestamp) {
      createdAtDate = (json['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }

    return Post(
      id: documentId,
      userId: json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      userAvatar: json['profileImageUrl'] ?? json['userAvatar'] ?? '',
      content: json['content'] ?? '',
      movieId: json['movieId'] ?? '',
      movieTitle: json['movieTitle'] ?? '',
      moviePosterUrl: json['moviePosterUrl'] ?? '',
      movieYear: json['movieYear'] ?? '',
      movieOverview: json['movieOverview'] ?? '',
      createdAt: createdAtDate,
      likes: List<String>.from(json['likes'] ?? []),
      commentCount: json['commentCount'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }
}
