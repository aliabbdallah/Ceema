// services/timeline_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/timeline_activity.dart';
import '../models/movie.dart';
import '../models/post.dart';
import '../models/diary_entry.dart';

class TimelineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the personalized timeline for the current user
  Stream<List<TimelineItem>> getPersonalizedTimeline() {
    final userId = _auth.currentUser!.uid;

    return _getUserPreferredGenres(userId).asyncMap((preferredGenres) async {
      final List<TimelineItem> timeline = [];

      // 1. Add friend posts (higher priority)
      final friendPosts = await _getFriendsPosts(userId);
      timeline.addAll(friendPosts);

      // 2. Add personalized recommendations based on user preferences
      final recommendations =
          await _getRecommendations(userId, preferredGenres);
      timeline.addAll(recommendations);

      // 3. Add trending items in preferred genres
      final trendingItems = await _getTrendingInGenres(preferredGenres);
      timeline.addAll(trendingItems);

      // Sort the timeline by relevance score and then by timestamp
      timeline.sort((a, b) {
        // First sort by relevance (higher scores first)
        final relevanceComparison =
            b.relevanceScore.compareTo(a.relevanceScore);
        if (relevanceComparison != 0) return relevanceComparison;

        // Then by timestamp (newer items first)
        return b.timestamp.compareTo(a.timestamp);
      });

      return timeline;
    });
  }

  // Get timeline filtered by specific genre
  Stream<List<TimelineItem>> getGenreTimeline(String genre) {
    final userId = _auth.currentUser!.uid;

    return Stream.fromFuture(_getItemsByGenre(userId, genre));
  }

  // Helper method to get user's preferred genres
  Stream<List<String>> _getUserPreferredGenres(String userId) async* {
    try {
      // Get from user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();

      List<String> genres = [];
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['favoriteGenres'] != null) {
          genres = List<String>.from(userData['favoriteGenres']);
        }
      }

      // If no specified genres, try to infer from highly rated movies
      if (genres.isEmpty) {
        final highlyRatedMovies = await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: userId)
            .where('rating', isGreaterThanOrEqualTo: 4)
            .limit(5)
            .get();

        // In a real app, you would analyze these movies to determine preferred genres
        // For now, use a default set
        genres = ['Action', 'Drama', 'Comedy'];
      }

      yield genres;
    } catch (e) {
      print('Error getting user preferred genres: $e');
      yield ['Action', 'Drama', 'Comedy']; // Default fallback
    }
  }

  // Get posts from friends
  Future<List<TimelineItem>> _getFriendsPosts(String userId) async {
    try {
      // Get friends list
      final friendsSnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .get();

      final List<String> friendIds =
          friendsSnapshot.docs.map((doc) => doc['friendId'] as String).toList();

      if (friendIds.isEmpty) {
        return [];
      }

      // Get recent posts from friends
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: friendIds)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      // Convert to TimelineItem objects
      return postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data(), doc.id);

        return TimelineItem(
          id: 'friend_post_${doc.id}',
          type: TimelineItemType.friendPost,
          timestamp: post.createdAt,
          data: {
            'friendId': post.userId,
            'friendName': post.userName,
            'postContent': post.content,
            'movieId': post.movieId,
            'movieTitle': post.movieTitle,
          },
          relevanceScore: 0.8, // Friend posts are generally high relevance
          relevanceReason: 'From ${post.userName}',
          post: post,
        );
      }).toList();
    } catch (e) {
      print('Error getting friends posts: $e');
      return [];
    }
  }

  // Get personalized movie recommendations
  Future<List<TimelineItem>> _getRecommendations(
      String userId, List<String> preferredGenres) async {
    try {
      // In a real app, this would use the user's watch history and preferences
      // to generate personalized recommendations

      // Here we're just fetching some highly rated movies as recommendations
      final recommendationsSnapshot = await _firestore
          .collection('movies')
          .where('averageRating', isGreaterThanOrEqualTo: 4)
          .limit(5)
          .get();

      // Convert to TimelineItem objects
      return recommendationsSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'recommendation_${doc.id}',
          type: TimelineItemType.recommendation,
          timestamp: DateTime.now(), // Recommendations are always "fresh"
          data: {
            'movieId': movie.id,
            'movieTitle': movie.title,
            'reason': 'Based on your preferences',
          },
          relevanceScore:
              0.9, // Personalized recommendations are high relevance
          relevanceReason: 'Based on movies you\'ve enjoyed',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  // Get trending movies in preferred genres
  Future<List<TimelineItem>> _getTrendingInGenres(List<String> genres) async {
    try {
      // In a real app, you'd query a movies collection with genre filtering
      // Here we just fetch some trending movies
      final trendingSnapshot = await _firestore
          .collection('movies')
          .orderBy('popularity', descending: true)
          .limit(5)
          .get();

      // Convert to TimelineItem objects
      return trendingSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'trending_${doc.id}',
          type: TimelineItemType.trendingMovie,
          timestamp: DateTime.now(),
          data: {
            'movieId': movie.id,
            'movieTitle': movie.title,
          },
          relevanceScore: 0.6, // Trending items are medium relevance
          relevanceReason: 'Trending now',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting trending in genres: $e');
      return [];
    }
  }

  // Get items filtered by a specific genre
  Future<List<TimelineItem>> _getItemsByGenre(
      String userId, String genre) async {
    try {
      // In a real app, this would query movies by genre and possibly
      // include posts or diary entries related to those movies

      // Here we just return some movies as a placeholder
      final genreSnapshot =
          await _firestore.collection('movies').limit(10).get();

      // Convert to TimelineItem objects
      return genreSnapshot.docs.map((doc) {
        final data = doc.data();
        final movie = Movie(
          id: doc.id,
          title: data['title'] ?? 'Unknown',
          posterUrl: data['posterUrl'] ?? '',
          year: data['year'] ?? '',
          overview: data['overview'] ?? '',
        );

        return TimelineItem(
          id: 'genre_${genre}_${doc.id}',
          type: TimelineItemType.newReleaseGenre,
          timestamp: DateTime.now(),
          data: {
            'movieId': movie.id,
            'movieTitle': movie.title,
            'genre': genre,
          },
          relevanceScore: 0.7,
          relevanceReason: 'Popular in $genre',
          movie: movie,
        );
      }).toList();
    } catch (e) {
      print('Error getting items by genre: $e');
      return [];
    }
  }

  // Create a new timeline item
  Future<void> createTimelineItem({
    required TimelineItemType type,
    required Map<String, dynamic> data,
    Post? post,
    DiaryEntry? diaryEntry,
    Movie? movie,
    double relevanceScore = 0.5,
    String? relevanceReason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in');
    }

    // Create a timeline item document
    await _firestore.collection('timeline').add({
      'type': type.toString().split('.').last,
      'timestamp': FieldValue.serverTimestamp(),
      'data': data,
      'relevanceScore': relevanceScore,
      'relevanceReason': relevanceReason,
      'userId': user.uid, // The user who this item is for
      'postId': post?.id,
      'diaryEntryId': diaryEntry?.id,
      'movieId': movie?.id,
    });
  }
}
