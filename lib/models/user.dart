import 'package:cloud_firestore/cloud_firestore.dart';
import 'podium_movie.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? bio;
  final String? profileImageUrl;
  final List<String> favoriteGenres;
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;
  final int mutualFriendsCount;
  final int watchlistCount;
  final int movieCount;
  final bool emailVerified;
  final int watchedCount;
  final List<PodiumMovie> podiumMovies;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.bio,
    this.profileImageUrl,
    required this.favoriteGenres,
    required this.createdAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.mutualFriendsCount = 0,
    this.watchlistCount = 0,
    this.movieCount = 0,
    this.emailVerified = false,
    this.watchedCount = 0,
    this.podiumMovies = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String documentId) {
    return UserModel(
      id: documentId,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      bio: json['bio'],
      profileImageUrl: json['profileImageUrl'],
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      mutualFriendsCount: json['mutualFriendsCount'] ?? 0,
      watchlistCount: json['watchlistCount'] ?? 0,
      movieCount: json['movieCount'] ?? 0,
      emailVerified: json['emailVerified'] ?? false,
      watchedCount: json['watchedCount'] ?? 0,
      podiumMovies:
          (json['podiumMovies'] as List?)
              ?.map((movie) => PodiumMovie.fromJson(movie))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'favoriteGenres': favoriteGenres,
      'createdAt': Timestamp.fromDate(createdAt),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'mutualFriendsCount': mutualFriendsCount,
      'watchlistCount': watchlistCount,
      'movieCount': movieCount,
      'emailVerified': emailVerified,
      'watchedCount': watchedCount,
      'podiumMovies': podiumMovies.map((movie) => movie.toJson()).toList(),
    };
  }

  UserModel copyWith({
    String? username,
    String? email,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    List<String>? favoriteGenres,
    DateTime? createdAt,
    int? followersCount,
    int? followingCount,
    int? mutualFriendsCount,
    int? watchlistCount,
    int? movieCount,
    bool? emailVerified,
    int? watchedCount,
    List<PodiumMovie>? podiumMovies,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      createdAt: createdAt ?? this.createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      watchlistCount: watchlistCount ?? this.watchlistCount,
      movieCount: movieCount ?? this.movieCount,
      emailVerified: emailVerified ?? this.emailVerified,
      watchedCount: watchedCount ?? this.watchedCount,
      podiumMovies: podiumMovies ?? this.podiumMovies,
    );
  }
}
