// lib/models/user_preferences.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentPreference {
  final String id;
  final String name;
  final String type; // 'genre', 'director', 'actor', etc.
  final double weight; // How much the user values this preference (0-1)

  ContentPreference({
    required this.id,
    required this.name,
    required this.type,
    this.weight = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'weight': weight,
    };
  }

  factory ContentPreference.fromJson(Map<String, dynamic> json) {
    return ContentPreference(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      weight: json['weight'] ?? 1.0,
    );
  }
}

class UserPreferences {
  final String userId;
  final List<ContentPreference> likes; // Things the user likes
  final List<ContentPreference> dislikes; // Things the user dislikes
  final Map<String, double> importanceFactors; // Story, Visuals, Acting, etc.
  final List<String>
      dislikedMovieIds; // Movies explicitly marked "not interested"

  UserPreferences({
    required this.userId,
    this.likes = const [],
    this.dislikes = const [],
    this.importanceFactors = const {},
    this.dislikedMovieIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'likes': likes.map((like) => like.toJson()).toList(),
      'dislikes': dislikes.map((dislike) => dislike.toJson()).toList(),
      'importanceFactors': importanceFactors,
      'dislikedMovieIds': dislikedMovieIds,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json, String id) {
    return UserPreferences(
      userId: id,
      likes: (json['likes'] as List?)
              ?.map((item) => ContentPreference.fromJson(item))
              .toList() ??
          [],
      dislikes: (json['dislikes'] as List?)
              ?.map((item) => ContentPreference.fromJson(item))
              .toList() ??
          [],
      importanceFactors:
          Map<String, double>.from(json['importanceFactors'] ?? {}),
      dislikedMovieIds: List<String>.from(json['dislikedMovieIds'] ?? []),
    );
  }

  // Create a copy with updated fields
  UserPreferences copyWith({
    String? userId,
    List<ContentPreference>? likes,
    List<ContentPreference>? dislikes,
    Map<String, double>? importanceFactors,
    List<String>? dislikedMovieIds,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      importanceFactors: importanceFactors ?? this.importanceFactors,
      dislikedMovieIds: dislikedMovieIds ?? this.dislikedMovieIds,
    );
  }
}
