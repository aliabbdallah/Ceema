// models/timeline_activity.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'movie.dart';
import 'post.dart';
import 'diary_entry.dart';

enum TimelineItemType {
  friendPost, // A friend created a post
  friendRating, // A friend rated a movie
  recommendation, // A movie recommendation for the user
  trendingMovie, // A trending movie in the user's preferred genres
  similarToLiked, // A movie similar to one the user liked
  friendWatched, // A movie a friend watched recently
  newReleaseGenre, // A new release in user's preferred genre
}

class TimelineItem {
  final String id;
  final TimelineItemType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final double relevanceScore; // Higher = more relevant to the user
  final String? relevanceReason; // Why this is being shown to the user

  // Optional content referenced by this item
  final Post? post;
  final DiaryEntry? diaryEntry;
  final Movie? movie;

  TimelineItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.data,
    this.relevanceScore = 0.0,
    this.relevanceReason,
    this.post,
    this.diaryEntry,
    this.movie,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json, String documentId) {
    TimelineItemType itemType = _parseItemType(json['type'] ?? '');

    // Parse referenced content if available
    Post? postData;
    DiaryEntry? diaryEntryData;
    Movie? movieData;

    if (json['postData'] != null) {
      postData = Post.fromJson(json['postData'], json['postId'] ?? '');
    }

    if (json['diaryEntryData'] != null) {
      diaryEntryData = DiaryEntry.fromJson(
          json['diaryEntryData'], json['diaryEntryId'] ?? '');
    }

    if (json['movieData'] != null) {
      movieData = Movie.fromJson(json['movieData']);
    }

    return TimelineItem(
      id: documentId,
      type: itemType,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      data: json['data'] ?? {},
      relevanceScore: (json['relevanceScore'] ?? 0.0).toDouble(),
      relevanceReason: json['relevanceReason'],
      post: postData,
      diaryEntry: diaryEntryData,
      movie: movieData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
      'relevanceScore': relevanceScore,
      'relevanceReason': relevanceReason,
      'postId': post?.id,
      'diaryEntryId': diaryEntry?.id,
      'movieId': movie?.id,
      // Note: The full object data wouldn't typically be stored in the timeline item
      // but referenced through IDs to their collections
    };
  }

  static TimelineItemType _parseItemType(String type) {
    try {
      return TimelineItemType.values.firstWhere(
        (e) => e.toString().split('.').last == type,
        orElse: () => TimelineItemType.friendPost,
      );
    } catch (e) {
      return TimelineItemType.friendPost;
    }
  }

  // Get an icon appropriate for this timeline item type
  IconData getIcon() {
    switch (type) {
      case TimelineItemType.friendPost:
        return Icons.chat_bubble_outline;
      case TimelineItemType.friendRating:
        return Icons.star_outline;
      case TimelineItemType.recommendation:
        return Icons.recommend;
      case TimelineItemType.trendingMovie:
        return Icons.trending_up;
      case TimelineItemType.similarToLiked:
        return Icons.thumbs_up_down;
      case TimelineItemType.friendWatched:
        return Icons.visibility;
      case TimelineItemType.newReleaseGenre:
        return Icons.new_releases;
    }
  }

  // Get a color appropriate for this timeline item type
  Color getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (type) {
      case TimelineItemType.friendPost:
        return Colors.blue;
      case TimelineItemType.friendRating:
        return Colors.amber;
      case TimelineItemType.recommendation:
        return colorScheme.primary;
      case TimelineItemType.trendingMovie:
        return Colors.purple;
      case TimelineItemType.similarToLiked:
        return Colors.green;
      case TimelineItemType.friendWatched:
        return Colors.teal;
      case TimelineItemType.newReleaseGenre:
        return Colors.orange;
    }
  }

  // Get a standard description for this timeline item type
  String getDescription() {
    switch (type) {
      case TimelineItemType.friendPost:
        return "shared thoughts on";
      case TimelineItemType.friendRating:
        return "rated";
      case TimelineItemType.recommendation:
        return "recommended for you";
      case TimelineItemType.trendingMovie:
        return "trending now";
      case TimelineItemType.similarToLiked:
        return "similar to movies you liked";
      case TimelineItemType.friendWatched:
        return "watched recently";
      case TimelineItemType.newReleaseGenre:
        return "new release you might like";
    }
  }
}
