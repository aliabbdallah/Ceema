import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/user.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get recommendations for the current user
  Future<List<Post>> getRecommendedPosts({int limit = 10}) async {
    // Step 1: Get user data for personalization
    final userId = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    // Get user's favorite genres
    final List<String> favoriteGenres =
        List<String>.from(userData['favoriteGenres'] ?? []);

    // Step 2: Get user's social connections
    final followingSnapshot = await _firestore
        .collection('friends')
        .doc(userId)
        .collection('following')
        .get();

    final List<String> following =
        followingSnapshot.docs.map((doc) => doc.id).toList();

    // Step 3: Get user's previously liked posts
    final likedPostsSnapshot = await _firestore
        .collection('posts')
        .where('likes', arrayContains: userId)
        .get();

    final List<String> likedPostIds =
        likedPostsSnapshot.docs.map((doc) => doc.id).toList();

    final List<String> likedMovieIds = likedPostsSnapshot.docs
        .map((doc) => doc.data()['movieId'] as String)
        .toList();

    // Step 4: Fetch a pool of recent posts
    final recentPostsSnapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(100) // Fetch more than needed to have a good pool to score
        .get();

    // Convert to Post objects
    final List<Post> posts = recentPostsSnapshot.docs
        .map((doc) => Post.fromJson(doc.data(), doc.id))
        .where((post) => post.userId != userId) // Exclude own posts
        .where((post) =>
            !likedPostIds.contains(post.id)) // Exclude already liked posts
        .toList();

    // Step 5: Score each post
    List<Map<String, dynamic>> scoredPosts = [];

    for (var post in posts) {
      double score = 0.0;

      // Social score (posts from followed users get a boost)
      if (following.contains(post.userId)) {
        score += 0.3;
      }

      // Genre match score (will require an additional query to get movie info)
      if (favoriteGenres.isNotEmpty) {
        try {
          final movieDoc =
              await _firestore.collection('movies').doc(post.movieId).get();
          if (movieDoc.exists) {
            final List<String> movieGenres =
                List<String>.from(movieDoc.data()?['genres'] ?? []);

            // Calculate genre match percentage
            int matchCount = 0;
            for (var genre in movieGenres) {
              if (favoriteGenres.contains(genre)) {
                matchCount++;
              }
            }

            if (matchCount > 0) {
              score += (matchCount / movieGenres.length) * 0.4;
            }
          }
        } catch (e) {
          // Skip genre scoring if error occurs
          print('Error fetching movie: $e');
        }
      }

      // Recency score (newer posts score higher)
      final ageInDays = DateTime.now().difference(post.createdAt).inDays;
      if (ageInDays < 1) {
        score += 0.2;
      } else if (ageInDays < 3) {
        score += 0.1;
      }

      // Popularity score (posts with more engagement score higher)
      final engagementCount = post.likes.length + post.commentCount;
      score += (engagementCount / 20)
          .clamp(0.0, 0.1); // Max 0.1 for very popular posts

      scoredPosts.add({'post': post, 'score': score});
    }

    // Sort by score (highest first)
    scoredPosts.sort((a, b) => b['score'].compareTo(a['score']));

    // Return top posts
    return scoredPosts.take(limit).map((item) => item['post'] as Post).toList();
  }

  // Get trending posts (based primarily on popularity)
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    final userId = _auth.currentUser!.uid;

    // Query posts with most likes in the past week
    final DateTime oneWeekAgo =
        DateTime.now().subtract(const Duration(days: 7));
    final querySnapshot = await _firestore
        .collection('posts')
        .where('createdAt', isGreaterThan: oneWeekAgo)
        .orderBy('createdAt', descending: true)
        .get();

    // Convert to Post objects
    final List<Post> posts = querySnapshot.docs
        .map((doc) => Post.fromJson(doc.data(), doc.id))
        .where((post) => post.userId != userId) // Exclude own posts
        .toList();

    // Sort by engagement (likes + comments)
    posts.sort((a, b) {
      final aEngagement = a.likes.length + a.commentCount;
      final bEngagement = b.likes.length + b.commentCount;
      return bEngagement.compareTo(aEngagement);
    });

    // Return top trending posts
    return posts.take(limit).toList();
  }

  // Get friend activity
  Future<List<Post>> getFriendActivityPosts({int limit = 10}) async {
    final userId = _auth.currentUser!.uid;

    // Get user's following
    final followingSnapshot = await _firestore
        .collection('friends')
        .doc(userId)
        .collection('following')
        .get();

    final List<String> following =
        followingSnapshot.docs.map((doc) => doc.id).toList();

    if (following.isEmpty) {
      return [];
    }

    // Get recent posts from followed users
    final querySnapshot = await _firestore
        .collection('posts')
        .where('userId', whereIn: following)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    // Convert to Post objects
    return querySnapshot.docs
        .map((doc) => Post.fromJson(doc.data(), doc.id))
        .toList();
  }

  // Track user interaction with recommendations for feedback
  Future<void> trackRecommendationInteraction({
    required String postId,
    required String interactionType, // 'view', 'like', 'comment', 'ignore'
  }) async {
    final userId = _auth.currentUser!.uid;

    await _firestore.collection('userRecommendationFeedback').add({
      'userId': userId,
      'postId': postId,
      'interactionType': interactionType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
