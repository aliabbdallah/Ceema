// lib/models/user_preferences.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'preference.dart';

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
  final List<Preference> likes;
  final List<Preference> dislikes;
  final Map<String, double> importanceFactors; // Story, Visuals, Acting, etc.
  final List<String>
      dislikedMovieIds; // Movies explicitly marked "not interested"

  UserPreferences({
    required this.userId,
    required this.likes,
    required this.dislikes,
    this.importanceFactors = const {},
    this.dislikedMovieIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'likes': likes.map((pref) => pref.toJson()).toList(),
        'dislikes': dislikes.map((pref) => pref.toJson()).toList(),
        'importanceFactors': importanceFactors,
        'dislikedMovieIds': dislikedMovieIds,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] as String? ?? '',
      likes: (json['likes'] as List?)
              ?.map((pref) => Preference.fromJson(pref as Map<String, dynamic>))
              .toList() ??
          [],
      dislikes: (json['dislikes'] as List?)
              ?.map((pref) => Preference.fromJson(pref as Map<String, dynamic>))
              .toList() ??
          [],
      importanceFactors:
          Map<String, double>.from(json['importanceFactors'] ?? {}),
      dislikedMovieIds: List<String>.from(json['dislikedMovieIds'] ?? []),
    );
  }

  UserPreferences copyWith({
    String? userId,
    List<Preference>? likes,
    List<Preference>? dislikes,
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
