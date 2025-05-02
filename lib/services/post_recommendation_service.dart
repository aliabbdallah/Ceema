// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:math';
// import 'dart:math' as math;
// import '../models/post.dart';
// import '../models/user_preferences.dart';
// import '../services/preference_service.dart';
// import '../services/post_service.dart';
// import '../services/diary_service.dart';
// import '../services/follow_service.dart';

// class PostRecommendationResult {
//   final List<Post> posts;
//   final DocumentSnapshot? lastDoc;

//   PostRecommendationResult(this.posts, this.lastDoc);
// }

// class PostRecommendationService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final PreferenceService _preferenceService = PreferenceService();
//   final PostService _postService = PostService();
//   final DiaryService _diaryService = DiaryService();
//   final FollowService _followService = FollowService();

//   // Cache for movie data with expiration and size limit
//   final Map<String, _CachedMovieDetails> _movieCache = {};
//   static const Duration _cacheExpiration = Duration(hours: 24);
//   static const int _maxCacheSize = 1000; // Maximum number of cached movies

//   // Debug flag for logging
//   static const bool _debug = false;

//   // Get recommended posts for the current user with multi-stage fallback
//   Future<PostRecommendationResult> getRecommendedPosts({
//     int limit = 10,
//     DocumentSnapshot? startAfter,
//   }) async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) {
//         _log('Error: User not authenticated');
//         return await _getFallbackRecommendations(limit);
//       }

//       _log('Getting recommended posts for user: $userId');

//       // 1. Parallel fetch of user data
//       final userData = await _fetchUserDataInParallel(userId);
//       if (userData.isEmpty) {
//         return await _getFallbackRecommendations(limit);
//       }

//       // 2. Try personalized recommendations first
//       final personalizedResult = await _tryPersonalizedRecommendations(
//         userId,
//         userData,
//         limit: limit,
//         startAfter: startAfter,
//       );

//       if (personalizedResult.posts.length >= limit) {
//         return personalizedResult;
//       }

//       // 3. Try collaborative filtering for remaining slots
//       final remainingSlots = limit - personalizedResult.posts.length;
//       if (remainingSlots > 0) {
//         final collaborativeResult = await _tryCollaborativeFiltering(
//           userId,
//           userData,
//           limit: remainingSlots,
//           startAfter: personalizedResult.lastDoc,
//         );

//         if (collaborativeResult.posts.isNotEmpty) {
//           return PostRecommendationResult([
//             ...personalizedResult.posts,
//             ...collaborativeResult.posts,
//           ], collaborativeResult.lastDoc);
//         }
//       }

//       // 4. Try trending content for remaining slots
//       final trendingResult = await getTrendingPosts(
//         limit: remainingSlots,
//         startAfter: personalizedResult.lastDoc,
//       );

//       if (trendingResult.posts.isNotEmpty) {
//         return PostRecommendationResult([
//           ...personalizedResult.posts,
//           ...trendingResult.posts,
//         ], trendingResult.lastDoc);
//       }

//       // 5. Finally, try random recent content
//       return await _getFallbackRecommendations(limit);
//     } catch (e) {
//       _log('Error getting recommended posts: $e');
//       return await _getFallbackRecommendations(limit);
//     }
//   }

//   // Fetch all user data in parallel
//   Future<Map<String, dynamic>> _fetchUserDataInParallel(String userId) async {
//     try {
//       final futures = await Future.wait([
//         _preferenceService.getUserPreferences(),
//         _getFollowingIds(userId),
//         _getWatchedMovieIds(userId),
//         _getLikedPostIds(userId),
//       ]);

//       final preferences = futures[0] as UserPreferences;
//       final following = futures[1] as List<String>;
//       final watchedMovieIds = futures[2] as List<String>;
//       final likedPostIds = futures[3] as List<String>;

//       // Check if user is new (has minimal data)
//       final isNewUser =
//           preferences.likes.isEmpty &&
//           following.isEmpty &&
//           watchedMovieIds.isEmpty;

//       return {
//         'preferences': preferences,
//         'following': following,
//         'watchedMovieIds': watchedMovieIds,
//         'likedPostIds': likedPostIds,
//         'isNewUser': isNewUser,
//       };
//     } catch (e) {
//       _log('Error fetching user data: $e');
//       return {};
//     }
//   }

//   // Get fallback recommendations when personalized ones can't be generated
//   Future<PostRecommendationResult> _getFallbackRecommendations(
//     int limit,
//   ) async {
//     try {
//       // Try trending posts first
//       final trendingResult = await getTrendingPosts(limit: limit);
//       if (trendingResult.posts.isNotEmpty) {
//         return trendingResult;
//       }

//       // If no trending posts, get recent posts
//       final querySnapshot =
//           await _firestore
//               .collection('posts')
//               .orderBy('createdAt', descending: true)
//               .limit(limit)
//               .get();

//       return PostRecommendationResult(
//         querySnapshot.docs
//             .map(
//               (doc) =>
//                   Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
//             )
//             .toList(),
//         querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
//       );
//     } catch (e) {
//       _log('Error getting fallback recommendations: $e');
//       return PostRecommendationResult([], null);
//     }
//   }

//   // Get candidate posts with pagination and dynamic filtering
//   Future<List<Post>> _getCandidatePosts(
//     String userId,
//     List<String> likedPostIds, {
//     int limit = 30,
//     DocumentSnapshot? startAfter,
//     bool isNewUser = false,
//   }) async {
//     try {
//       // Base query without user filter for broader selection
//       Query query = _firestore
//           .collection('posts')
//           .orderBy('createdAt', descending: true)
//           .limit(limit * 2); // Fetch more initially for filtering

//       if (startAfter != null) {
//         query = query.startAfterDocument(startAfter);
//       }

//       final querySnapshot = await query.get();
//       final posts =
//           querySnapshot.docs
//               .map(
//                 (doc) =>
//                     Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
//               )
//               .toList();

//       // Apply dynamic filtering based on content availability
//       final filteredPosts = _applyDynamicFiltering(
//         posts,
//         userId,
//         likedPostIds,
//         isNewUser: isNewUser,
//       );

//       return filteredPosts.take(limit).toList();
//     } catch (e) {
//       _log('Error getting candidate posts: $e');
//       return [];
//     }
//   }

//   // Apply dynamic filtering based on content availability
//   List<Post> _applyDynamicFiltering(
//     List<Post> posts,
//     String userId,
//     List<String> likedPostIds, {
//     required bool isNewUser,
//   }) {
//     final Map<String, int> movieCounts = {};
//     final Map<String, int> userCounts = {};
//     final List<Post> filteredPosts = [];

//     // Calculate content availability metrics
//     for (final post in posts) {
//       movieCounts[post.movieId] = (movieCounts[post.movieId] ?? 0) + 1;
//       userCounts[post.userId] = (userCounts[post.userId] ?? 0) + 1;
//     }

//     // Determine dynamic thresholds based on content availability
//     final totalMovies = movieCounts.length;
//     final totalUsers = userCounts.length;

//     // More lenient thresholds when content is scarce
//     final maxPostsPerMovie = totalMovies < 10 ? 3 : 2;
//     final maxPostsPerUser = totalUsers < 10 ? 4 : 3;

//     // Apply filtering with dynamic thresholds
//     for (final post in posts) {
//       if (post.userId == userId) continue; // Skip own posts
//       if (likedPostIds.contains(post.id)) continue; // Skip liked posts

//       final movieCount = movieCounts[post.movieId] ?? 0;
//       final userCount = userCounts[post.userId] ?? 0;

//       if (movieCount > maxPostsPerMovie) continue;
//       if (userCount > maxPostsPerUser) continue;

//       filteredPosts.add(post);
//     }

//     return filteredPosts;
//   }

//   // Score posts with simplified algorithm for new users
//   Future<List<_ScoredPost>> _scorePosts(
//     List<Post> posts,
//     UserPreferences preferences,
//     List<String> following,
//     List<String> watchedMovieIds, {
//     required bool isNewUser,
//   }) async {
//     final List<_ScoredPost> scoredPosts = [];

//     _log('Scoring ${posts.length} candidate posts');
//     // Log candidate IDs
//     final candidateIds = posts.map((p) => p.id).toList();
//     _log('Candidate Post IDs: $candidateIds');

//     _log('User preferences: ${preferences.likes.length} likes');
//     _log(
//       'Following: ${following.length} users: $following',
//     ); // Log following IDs
//     _log(
//       'Watched movies: ${watchedMovieIds.length} movies: $watchedMovieIds',
//     ); // Log watched movie IDs

//     // If we have very few posts, just return them all
//     if (posts.length <= 10) {
//       _log('Few posts available, returning all posts');
//       return posts.map((post) => _ScoredPost(post, 1.0, 'all_posts')).toList();
//     }

//     for (final post in posts) {
//       double score = 0.0;
//       String primaryReason = '';

//       // Base score for all posts
//       score += 0.3;

//       if (isNewUser) {
//         // Simplified scoring for new users
//         score += _calculateNewUserScore(post, following);
//         primaryReason = 'new_user';
//         _log('New user score for post ${post.id}: $score');
//       } else {
//         // Full scoring algorithm for existing users
//         score += await _calculateFullScore(
//           post,
//           preferences,
//           following,
//           watchedMovieIds,
//         );
//         primaryReason = _getScoreReason(score, post, preferences);
//         _log('Full score for post ${post.id}: $score, reason: $primaryReason');
//       }

//       // Add cross-domain boost
//       final crossDomainScore = await _calculateCrossDomainScore(
//         post,
//         preferences,
//       );
//       score += crossDomainScore * 0.2; // 20% weight for cross-domain relevance

//       // Add temporal diversity boost
//       final temporalScore = _calculateTemporalScore(post);
//       score += temporalScore * 0.1; // 10% weight for temporal diversity

//       // Add exploration boost (20-30% of posts)
//       if (Random().nextDouble() < 0.25) {
//         score += 0.2; // Boost for exploration
//         primaryReason = 'exploration';
//       }

//       // Extremely lenient threshold
//       if (score > 0.01) {
//         scoredPosts.add(_ScoredPost(post, score, primaryReason));
//         _log('Added post ${post.id} with score $score');
//       } else {
//         _log('Filtered out post ${post.id} with score $score');
//       }
//     }

//     _log('Final scored posts count: ${scoredPosts.length}');
//     return scoredPosts;
//   }

//   // Calculate full score for existing users
//   Future<double> _calculateFullScore(
//     Post post,
//     UserPreferences preferences,
//     List<String> following,
//     List<String> watchedMovieIds,
//   ) async {
//     double score = 0.0;

//     // Base score for all posts
//     score += 0.3;

//     _log(
//       '--- Scoring Post ID: ${post.id} ---',
//     ); // Log start of scoring for a post
//     _log('Initial Base Score: $score');

//     // 1. Content relevance score (15% weight)
//     final contentScore = await _calculateContentScore(post, preferences);
//     score += contentScore * 0.15;
//     _log(
//       'Content score contribution: ${contentScore * 0.15} (Raw: $contentScore)',
//     );

//     // 2. Actor/Director affinity score (10% weight)
//     final talentScore = await _calculateTalentScore(post, preferences);
//     score += talentScore * 0.1;
//     _log('Talent score contribution: ${talentScore * 0.1} (Raw: $talentScore)');

//     // 3. Engagement score (20% weight)
//     final engagementScore = _calculateEngagementScore(post);
//     score += engagementScore * 0.2;
//     _log(
//       'Engagement score contribution: ${engagementScore * 0.2} (Raw: $engagementScore)',
//     );

//     // 4. View behavior score (10% weight)
//     final viewScore = await _calculateViewScoreOptimized(post);
//     score += viewScore * 0.1;
//     _log('View score contribution: ${viewScore * 0.1} (Raw: $viewScore)');

//     // Add significant boost for posts from followed users
//     bool isFollowed = following.contains(post.userId);
//     _log(
//       'Checking Follow Boost: Post User ID: ${post.userId}, Is Followed: $isFollowed',
//     );
//     if (isFollowed) {
//       score += 0.5; // Huge boost for followed users
//       _log('Applied Follow Boost: +0.5');
//     }

//     // Add significant boost for posts about watched movies
//     bool isWatchedMovie = watchedMovieIds.contains(post.movieId);
//     _log(
//       'Checking Watched Movie Boost: Post Movie ID: ${post.movieId}, Is Watched: $isWatchedMovie',
//     );
//     if (isWatchedMovie) {
//       score += 0.5; // Huge boost for watched movies
//       _log('Applied Watched Movie Boost: +0.5');
//     }

//     // Add boost for recent posts
//     final ageInHours = DateTime.now().difference(post.createdAt).inHours;
//     if (ageInHours < 24) {
//       score += 0.3;
//     } else if (ageInHours < 72) {
//       score += 0.2;
//     } else if (ageInHours < 168) {
//       // 1 week
//       score += 0.1;
//     }

//     // Ensure minimum score
//     if (score < 0.5) {
//       score = 0.5;
//     }

//     _log('Total score for post ${post.id}: $score');
//     return score;
//   }

//   // Simplified scoring for new users with collaborative filtering
//   double _calculateNewUserScore(Post post, List<String> following) {
//     double score = 0.0;

//     // Base score for all posts
//     score += 0.3;

//     // Boost for posts from followed users
//     if (following.contains(post.userId)) {
//       score += 0.5;
//     }

//     // Boost for recent posts
//     final ageInHours = DateTime.now().difference(post.createdAt).inHours;
//     if (ageInHours < 24) {
//       score += 0.4;
//     } else if (ageInHours < 72) {
//       score += 0.3;
//     } else if (ageInHours < 168) {
//       // 1 week
//       score += 0.2;
//     }

//     // Boost for engagement
//     final engagementScore =
//         (post.likes.length + post.commentCount * 2) /
//         10.0; // More lenient denominator
//     score += min(engagementScore, 0.4);

//     // Ensure minimum score
//     if (score < 0.5) {
//       score = 0.5;
//     }

//     return score;
//   }

//   // Calculate engagement score based on likes and comments
//   double _calculateEngagementScore(Post post) {
//     // More lenient engagement scoring
//     final likeScore = min(1.0, post.likes.length / 20.0); // Lower denominator
//     final commentScore = min(
//       1.0,
//       post.commentCount / 10.0,
//     ); // Lower denominator
//     return (likeScore * 0.4) + (commentScore * 0.6);
//   }

//   // Get movie details with caching and size limit
//   Future<Map<String, dynamic>> _getMovieDetails(String movieId) async {
//     // Check cache first
//     if (_movieCache.containsKey(movieId)) {
//       final cached = _movieCache[movieId]!;
//       if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
//         _log('Using cached movie details for $movieId');
//         return cached.details;
//       }
//     }

//     // Clean cache if it's too large
//     if (_movieCache.length >= _maxCacheSize) {
//       _cleanCache();
//     }

//     try {
//       final doc = await _firestore.collection('movies').doc(movieId).get();
//       if (doc.exists) {
//         final data = doc.data() ?? {};
//         _movieCache[movieId] = _CachedMovieDetails(data, DateTime.now());
//         return data;
//       }

//       // If not in Firestore, create minimal details
//       final minimalDetails = {
//         'id': movieId,
//         'title': 'Unknown Movie',
//         'genres': [],
//       };

//       _movieCache[movieId] = _CachedMovieDetails(
//         minimalDetails,
//         DateTime.now(),
//       );
//       return minimalDetails;
//     } catch (e) {
//       _log('Error getting movie details: $e');
//       return {};
//     }
//   }

//   // Clean cache by removing oldest entries
//   void _cleanCache() {
//     final sortedEntries =
//         _movieCache.entries.toList()
//           ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

//     // Remove oldest entries until we're under the limit
//     while (_movieCache.length >= _maxCacheSize) {
//       _movieCache.remove(sortedEntries.removeAt(0).key);
//     }
//   }

//   // Helper method for conditional logging
//   void _log(String message) {
//     if (_debug) {
//       print('[PostRecommendationService] $message');
//     }
//   }

//   // Get trending posts (based on engagement metrics)
//   Future<PostRecommendationResult> getTrendingPosts({
//     int limit = 10,
//     DocumentSnapshot? startAfter,
//   }) async {
//     try {
//       print('[PostRecommendationService] Getting trending posts');
//       // Get recent posts (from last 14 days)
//       final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
//       Query query = _firestore
//           .collection('posts')
//           .where('createdAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
//           .orderBy('createdAt', descending: true)
//           .limit(limit);

//       if (startAfter != null) {
//         query = query.startAfterDocument(startAfter);
//       }

//       final querySnapshot = await query.get();
//       print(
//         '[PostRecommendationService] Found ${querySnapshot.docs.length} recent posts',
//       );

//       final posts = <Post>[];
//       for (var doc in querySnapshot.docs) {
//         final postData = doc.data() as Map<String, dynamic>;
//         final userId = postData['userId'] as String;

//         // Fetch user data directly from Firestore
//         final userDoc = await _firestore.collection('users').doc(userId).get();
//         if (userDoc.exists) {
//           final userData = userDoc.data() as Map<String, dynamic>;
//           postData['userName'] = userData['username'];
//           postData['userAvatar'] = userData['profileImageUrl'];
//         }

//         posts.add(Post.fromJson(postData, doc.id));
//       }

//       print(
//         '[PostRecommendationService] Returning ${posts.length} trending posts',
//       );
//       return PostRecommendationResult(
//         posts,
//         querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
//       );
//     } catch (e) {
//       print('[PostRecommendationService] Error getting trending posts: $e');
//       return PostRecommendationResult([], null);
//     }
//   }

//   // Get posts from friends (people the user follows)
//   Future<PostRecommendationResult> getFriendsPosts({
//     int limit = 10,
//     DocumentSnapshot? startAfter,
//   }) async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) {
//         print('[PostRecommendationService] Error: User not authenticated');
//         throw Exception('User not authenticated');
//       }

//       print(
//         '[PostRecommendationService] Getting posts from friends for user: $userId',
//       );
//       // Get IDs of users the current user follows
//       final following = await _getFollowingIds(userId);
//       print(
//         '[PostRecommendationService] User follows ${following.length} users',
//       );

//       if (following.isEmpty) {
//         print(
//           '[PostRecommendationService] User does not follow anyone, returning empty list',
//         );
//         return PostRecommendationResult([], null);
//       }

//       // Get recent posts from followed users
//       Query query = _firestore
//           .collection('posts')
//           .where(
//             'userId',
//             whereIn: following.take(10).toList(),
//           ) // Firestore limitation: maximum 10 values in whereIn
//           .orderBy('createdAt', descending: true)
//           .limit(limit);

//       if (startAfter != null) {
//         query = query.startAfterDocument(startAfter);
//       }

//       final querySnapshot = await query.get();

//       print(
//         '[PostRecommendationService] Found ${querySnapshot.docs.length} posts from friends',
//       );

//       final posts = <Post>[];
//       for (var doc in querySnapshot.docs) {
//         final postData = doc.data() as Map<String, dynamic>;
//         final userId = postData['userId'] as String;

//         // Fetch user data directly from Firestore
//         final userDoc = await _firestore.collection('users').doc(userId).get();
//         if (userDoc.exists) {
//           final userData = userDoc.data() as Map<String, dynamic>;
//           postData['userName'] = userData['username'];
//           postData['userAvatar'] = userData['profileImageUrl'];
//         }

//         posts.add(Post.fromJson(postData, doc.id));
//       }

//       return PostRecommendationResult(
//         posts,
//         querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
//       );
//     } catch (e) {
//       print('[PostRecommendationService] Error getting friends posts: $e');
//       return PostRecommendationResult([], null);
//     }
//   }

//   // Get similar posts based on a movie the user liked
//   Future<List<Post>> getSimilarMoviePosts(
//     String movieId, {
//     int limit = 10,
//   }) async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) {
//         print('[PostRecommendationService] Error: User not authenticated');
//         throw Exception('User not authenticated');
//       }

//       print(
//         '[PostRecommendationService] Getting similar posts for movie: $movieId',
//       );
//       // Get posts about this movie (excluding user's own posts)
//       final querySnapshot =
//           await _firestore
//               .collection('posts')
//               .where('movieId', isEqualTo: movieId)
//               .where('userId', isNotEqualTo: userId)
//               .orderBy('userId')
//               .orderBy('createdAt', descending: true)
//               .limit(limit)
//               .get();

//       print(
//         '[PostRecommendationService] Found ${querySnapshot.docs.length} similar posts',
//       );
//       return querySnapshot.docs
//           .map(
//             (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
//           )
//           .toList();
//     } catch (e) {
//       print(
//         '[PostRecommendationService] Error getting similar movie posts: $e',
//       );
//       return [];
//     }
//   }

//   // Record user interaction with a recommendation
//   Future<void> logInteraction({
//     required String postId,
//     required String
//     actionType, // 'view', 'like', 'comment', 'share', 'save', 'view_duration'
//     double? viewPercentage, // Track how much of a post was viewed (0-100)
//     int? viewTimeSeconds, // Track how long a user viewed a post in seconds
//     String?
//     source, // Where the interaction came from (e.g., 'timeline', 'search', 'profile')
//     Map<String, dynamic>?
//     additionalData, // Any additional context about the interaction
//   }) async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) {
//         print('[PostRecommendationService] Error: User not authenticated');
//         return;
//       }

//       // Validate input parameters
//       if (postId.isEmpty) {
//         print('[PostRecommendationService] Error: postId cannot be empty');
//         return;
//       }

//       if (actionType.isEmpty) {
//         print('[PostRecommendationService] Error: actionType cannot be empty');
//         return;
//       }

//       // Validate view percentage if provided
//       if (viewPercentage != null &&
//           (viewPercentage < 0 || viewPercentage > 100)) {
//         print(
//           '[PostRecommendationService] Error: viewPercentage must be between 0 and 100',
//         );
//         return;
//       }

//       // Validate view time if provided
//       if (viewTimeSeconds != null && viewTimeSeconds < 0) {
//         print(
//           '[PostRecommendationService] Error: viewTimeSeconds cannot be negative',
//         );
//         return;
//       }

//       // Prepare interaction data
//       final interactionData = {
//         'userId': userId,
//         'postId': postId,
//         'actionType': actionType,
//         'timestamp': FieldValue.serverTimestamp(),
//         'source': source ?? 'unknown',
//         if (viewPercentage != null) 'viewPercentage': viewPercentage,
//         if (viewTimeSeconds != null) 'viewTimeSeconds': viewTimeSeconds,
//         if (additionalData != null) 'additionalData': additionalData,
//       };

//       print(
//         '[PostRecommendationService] Logging interaction: $actionType on post $postId',
//       );

//       // Add to userInteractions collection
//       await _firestore.collection('userInteractions').add(interactionData);

//       // If this is a view interaction with duration, also update the post's view statistics
//       if (actionType == 'view' && viewTimeSeconds != null) {
//         final postRef = _firestore.collection('posts').doc(postId);
//         await postRef.update({
//           'totalViewTime': FieldValue.increment(viewTimeSeconds),
//           'viewCount': FieldValue.increment(1),
//         });
//       }

//       // If this is a save action, update the user's saved posts
//       if (actionType == 'save') {
//         await _firestore
//             .collection('users')
//             .doc(userId)
//             .collection('savedPosts')
//             .doc(postId)
//             .set({'postId': postId, 'savedAt': FieldValue.serverTimestamp()});
//       }
//     } catch (e, stackTrace) {
//       print('[PostRecommendationService] Error logging interaction: $e');
//       print('Stack trace: $stackTrace');
//     }
//   }

//   // Helper method to get IDs of users the current user follows
//   Future<List<String>> _getFollowingIds(String userId) async {
//     try {
//       print(
//         '[PostRecommendationService] Getting following IDs for user: $userId',
//       );
//       try {
//         final follows = await _followService.getFollowing(userId).first;
//         final result = follows.map((follow) => follow.followedId).toList();
//         print(
//           '[PostRecommendationService] Found ${result.length} following IDs',
//         );
//         return result;
//       } catch (e) {
//         print('[PostRecommendationService] Error using follow service: $e');
//         return [];
//       }
//     } catch (e) {
//       print('[PostRecommendationService] Error getting following IDs: $e');
//       return [];
//     }
//   }

//   // Helper method to get IDs of movies the user has watched
//   Future<List<String>> _getWatchedMovieIds(String userId) async {
//     try {
//       print(
//         '[PostRecommendationService] Getting watched movie IDs for user: $userId',
//       );
//       try {
//         final diaryEntries = await _diaryService.getDiaryEntries(userId).first;
//         final result = diaryEntries.map((entry) => entry.movieId).toList();
//         print(
//           '[PostRecommendationService] Found ${result.length} watched movie IDs',
//         );
//         return result;
//       } catch (e) {
//         print('[PostRecommendationService] Error using diary service: $e');

//         // Fallback: direct Firestore query
//         print(
//           '[PostRecommendationService] Attempting direct query for watched movie IDs',
//         );
//         final snapshot =
//             await _firestore
//                 .collection('diary_entries')
//                 .where('userId', isEqualTo: userId)
//                 .get();

//         final result =
//             snapshot.docs
//                 .map((doc) => doc.data()['movieId'] as String)
//                 .toList();
//         print(
//           '[PostRecommendationService] Found ${result.length} watched movie IDs using direct query',
//         );
//         return result;
//       }
//     } catch (e) {
//       print('[PostRecommendationService] Error getting watched movie IDs: $e');
//       return [];
//     }
//   }

//   // Helper method to get IDs of posts the user has already liked
//   Future<List<String>> _getLikedPostIds(String userId) async {
//     try {
//       print(
//         '[PostRecommendationService] Getting liked post IDs for user: $userId',
//       );
//       final query =
//           await _firestore
//               .collection('posts')
//               .where('likes', arrayContains: userId)
//               .get();

//       final result = query.docs.map((doc) => doc.id).toList();
//       print(
//         '[PostRecommendationService] Found ${result.length} liked post IDs',
//       );
//       return result;
//     } catch (e) {
//       print('[PostRecommendationService] Error getting liked post IDs: $e');
//       return [];
//     }
//   }

//   // Get the primary reason for a post's score
//   String _getScoreReason(double score, Post post, UserPreferences preferences) {
//     if (score > 0.7) {
//       return 'high_relevance';
//     } else if (score > 0.5) {
//       return 'good_match';
//     } else if (score > 0.3) {
//       return 'basic_match';
//     }
//     return 'low_relevance';
//   }

//   // Calculate content relevance score based on genres
//   Future<double> _calculateContentScore(
//     Post post,
//     UserPreferences preferences,
//   ) async {
//     try {
//       final movieDetails = await _getMovieDetails(post.movieId);
//       if (movieDetails.isEmpty) return 0.0;

//       double genreScore = 0.0;

//       if (movieDetails.containsKey('genres')) {
//         final movieGenres =
//             (movieDetails['genres'] as List)
//                 .map((g) => g['id'].toString())
//                 .toList();

//         for (final preferredGenre in preferences.likes.where(
//           (pref) => pref.type == 'genre',
//         )) {
//           if (movieGenres.contains(preferredGenre.id)) {
//             genreScore += preferredGenre.weight * 0.3;
//           }
//         }
//       }

//       return min(1.0, genreScore);
//     } catch (e) {
//       _log('Error calculating content score: $e');
//       return 0.0;
//     }
//   }

//   // Calculate talent affinity score based on credits
//   Future<double> _calculateTalentScore(
//     Post post,
//     UserPreferences preferences,
//   ) async {
//     try {
//       final movieDetails = await _getMovieDetails(post.movieId);
//       if (movieDetails.isEmpty) return 0.0;

//       double actorScore = 0.0;
//       double directorScore = 0.0;

//       if (movieDetails.containsKey('credits') &&
//           movieDetails['credits'].containsKey('cast')) {
//         final cast = movieDetails['credits']['cast'] as List;
//         final actorIds = cast.map((actor) => actor['id'].toString()).toList();

//         for (final preferredActor in preferences.likes.where(
//           (pref) => pref.type == 'actor',
//         )) {
//           if (actorIds.contains(preferredActor.id)) {
//             actorScore += preferredActor.weight * 0.15;
//           }
//         }
//       }

//       if (movieDetails.containsKey('credits') &&
//           movieDetails['credits'].containsKey('crew')) {
//         final crew = movieDetails['credits']['crew'] as List;
//         final directors =
//             crew
//                 .where((person) => person['job'] == 'Director')
//                 .map((director) => director['id'].toString())
//                 .toList();

//         for (final preferredDirector in preferences.likes.where(
//           (pref) => pref.type == 'director',
//         )) {
//           if (directors.contains(preferredDirector.id)) {
//             directorScore += preferredDirector.weight * 0.2;
//           }
//         }
//       }

//       return min(1.0, actorScore + directorScore);
//     } catch (e) {
//       _log('Error calculating talent score: $e');
//       return 0.0;
//     }
//   }

//   // Optimized view score calculation
//   Future<double> _calculateViewScoreOptimized(Post post) async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) return 0.0;

//       // Get aggregated view stats in a single query with limit
//       final viewStats =
//           await _firestore
//               .collection('userInteractions')
//               .where('postId', isEqualTo: post.id)
//               .where('userId', isEqualTo: userId)
//               .where('actionType', isEqualTo: 'view')
//               .orderBy('timestamp', descending: true)
//               .limit(10) // Only consider last 10 views
//               .get();

//       if (viewStats.docs.isEmpty) return 0.0;

//       double totalViewTime = 0;
//       double totalViewPercentage = 0;
//       int viewCount = 0;

//       for (final doc in viewStats.docs) {
//         final data = doc.data();
//         totalViewTime += data['viewTimeSeconds'] ?? 0;
//         totalViewPercentage += data['viewPercentage'] ?? 0;
//         viewCount++;
//       }

//       final avgViewTime = totalViewTime / viewCount;
//       final avgCompletionRate = totalViewPercentage / viewCount;

//       final viewTimeScore = min(1.0, avgViewTime / 30.0);
//       final completionScore = avgCompletionRate / 100.0;

//       return (viewTimeScore * 0.6) + (completionScore * 0.4);
//     } catch (e) {
//       _log('Error calculating view score: $e');
//       return 0.0;
//     }
//   }

//   // Apply diversity and return top posts
//   List<Post> _applyDiversityAndReturnTopPosts(
//     List<_ScoredPost> scoredPosts,
//     int limit,
//   ) {
//     // Sort by score first
//     scoredPosts.sort((a, b) => b.score.compareTo(a.score));
//     _log('--- Applying Diversity Filter ---');
//     _log(
//       'Sorted Scored Posts (Top 10): ${scoredPosts.take(10).map((sp) => '${sp.post.id}:${sp.score.toStringAsFixed(2)}').toList()}',
//     );

//     // Apply temporal diversity
//     final posts = scoredPosts.map((sp) => sp.post).toList();
//     final temporallyDiversePosts = _applyTemporalDiversity(posts, limit);

//     // Apply content diversity
//     final result = <Post>[];
//     final Set<String> usedMovieIds = {};
//     final Set<String> usedUserIds = {};
//     final Map<String, int> movieCounts = {};
//     final Map<String, int> userCounts = {};

//     for (final post in temporallyDiversePosts) {
//       final movieId = post.movieId;
//       final userId = post.userId;

//       // Skip if we've already used this movie or user too many times
//       final movieCount = movieCounts[movieId] ?? 0;
//       final userCount = userCounts[userId] ?? 0;

//       bool skipped = false;
//       if (movieCount >= 2) {
//         _log(
//           'Diversity Skip: Post ${post.id} (Movie ID: $movieId, Count: $movieCount >= 2)',
//         );
//         skipped = true;
//       }
//       if (userCount >= 3) {
//         _log(
//           'Diversity Skip: Post ${post.id} (User ID: $userId, Count: $userCount >= 3)',
//         );
//         skipped = true;
//       }
//       if (skipped) continue;

//       // Add to result
//       result.add(post);
//       usedMovieIds.add(movieId);
//       usedUserIds.add(userId);
//       movieCounts[movieId] = movieCount + 1;
//       userCounts[userId] = userCount + 1;
//       _log(
//         'Diversity Keep: Post ${post.id} (Movie: ${movieCounts[movieId]}, User: ${userCounts[userId]})',
//       );

//       if (result.length >= limit) {
//         _log('Reached limit ($limit), stopping diversity filter.');
//         break;
//       }
//     }

//     _log('Final Result Posts: ${result.map((p) => p.id).toList()}');
//     return result;
//   }

//   // Try personalized recommendations
//   Future<PostRecommendationResult> _tryPersonalizedRecommendations(
//     String userId,
//     Map<String, dynamic> userData, {
//     int limit = 10,
//     DocumentSnapshot? startAfter,
//   }) async {
//     try {
//       // Get candidate posts with broader selection
//       final candidates = await _getCandidatePosts(
//         userId,
//         userData['likedPostIds'],
//         limit: limit,
//         startAfter: startAfter,
//         isNewUser: userData['isNewUser'],
//       );

//       if (candidates.isEmpty) {
//         return PostRecommendationResult([], null);
//       }

//       // Score posts with improved algorithm
//       final scoredPosts = await _scorePosts(
//         candidates,
//         userData['preferences'],
//         userData['following'],
//         userData['watchedMovieIds'],
//         isNewUser: userData['isNewUser'],
//       );

//       // Apply diversity and return top posts
//       final posts = _applyDiversityAndReturnTopPosts(scoredPosts, limit);
//       return PostRecommendationResult(posts, null);
//     } catch (e) {
//       _log('Error in personalized recommendations: $e');
//       return PostRecommendationResult([], null);
//     }
//   }

//   // Try collaborative filtering
//   Future<PostRecommendationResult> _tryCollaborativeFiltering(
//     String userId,
//     Map<String, dynamic> userData, {
//     int limit = 10,
//     DocumentSnapshot? startAfter,
//   }) async {
//     try {
//       // Get posts from users with similar preferences
//       final similarUsers = await _findSimilarUsers(
//         userId,
//         userData['preferences'],
//       );
//       if (similarUsers.isEmpty) {
//         return PostRecommendationResult([], null);
//       }

//       // Get posts from similar users
//       final query = _firestore
//           .collection('posts')
//           .where('userId', whereIn: similarUsers.take(10).toList())
//           .orderBy('createdAt', descending: true)
//           .limit(limit);

//       if (startAfter != null) {
//         query.startAfterDocument(startAfter);
//       }

//       final querySnapshot = await query.get();
//       final posts =
//           querySnapshot.docs
//               .map(
//                 (doc) =>
//                     Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
//               )
//               .toList();

//       return PostRecommendationResult(
//         posts,
//         querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
//       );
//     } catch (e) {
//       _log('Error in collaborative filtering: $e');
//       return PostRecommendationResult([], null);
//     }
//   }

//   // Find users with similar preferences
//   Future<List<String>> _findSimilarUsers(
//     String userId,
//     UserPreferences preferences,
//   ) async {
//     try {
//       final similarUsers = <String, double>{};

//       // Get users who liked similar movies
//       for (final like in preferences.likes) {
//         if (like.type == 'movie') {
//           final query =
//               await _firestore
//                   .collection('posts')
//                   .where('movieId', isEqualTo: like.id)
//                   .where('likes', arrayContains: userId)
//                   .get();

//           for (final doc in query.docs) {
//             final postUserId = doc.data()['userId'] as String;
//             if (postUserId != userId) {
//               similarUsers[postUserId] = (similarUsers[postUserId] ?? 0) + 1;
//             }
//           }
//         }
//       }

//       // Sort by similarity score and return top users
//       final sortedEntries =
//           similarUsers.entries.toList()
//             ..sort((a, b) => b.value.compareTo(a.value));
//       return sortedEntries.map((e) => e.key).toList();
//     } catch (e) {
//       _log('Error finding similar users: $e');
//       return [];
//     }
//   }

//   // Get cross-domain recommendations based on shared actors/directors
//   Future<List<Post>> _getCrossDomainRecommendations(
//     String userId,
//     UserPreferences preferences,
//     int limit,
//   ) async {
//     try {
//       final Set<String> actorIds = {};
//       final Set<String> directorIds = {};

//       // Extract actor and director IDs from preferences
//       for (final like in preferences.likes) {
//         if (like.type == 'actor') {
//           actorIds.add(like.id);
//         } else if (like.type == 'director') {
//           directorIds.add(like.id);
//         }
//       }

//       if (actorIds.isEmpty && directorIds.isEmpty) {
//         return [];
//       }

//       // Get movies with shared actors/directors
//       final moviesQuery = _firestore.collection('movies');
//       final moviesWithSharedTalent = <String>{};

//       // Query for movies with shared actors
//       for (final actorId in actorIds.take(5)) {
//         final actorMovies =
//             await moviesQuery
//                 .where('credits.cast', arrayContains: {'id': actorId})
//                 .get();
//         moviesWithSharedTalent.addAll(actorMovies.docs.map((doc) => doc.id));
//       }

//       // Query for movies with shared directors
//       for (final directorId in directorIds.take(5)) {
//         final directorMovies =
//             await moviesQuery
//                 .where(
//                   'credits.crew',
//                   arrayContains: {'id': directorId, 'job': 'Director'},
//                 )
//                 .get();
//         moviesWithSharedTalent.addAll(directorMovies.docs.map((doc) => doc.id));
//       }

//       if (moviesWithSharedTalent.isEmpty) {
//         return [];
//       }

//       // Get posts about these movies
//       final postsQuery =
//           await _firestore
//               .collection('posts')
//               .where(
//                 'movieId',
//                 whereIn: moviesWithSharedTalent.take(10).toList(),
//               )
//               .where('userId', isNotEqualTo: userId)
//               .orderBy('createdAt', descending: true)
//               .limit(limit)
//               .get();

//       return postsQuery.docs
//           .map(
//             (doc) => Post.fromJson(doc.data() as Map<String, dynamic>, doc.id),
//           )
//           .toList();
//     } catch (e) {
//       _log('Error getting cross-domain recommendations: $e');
//       return [];
//     }
//   }

//   // Ensure temporal diversity in recommendations
//   List<Post> _applyTemporalDiversity(List<Post> posts, int limit) {
//     if (posts.length <= limit) {
//       return posts;
//     }

//     final now = DateTime.now();
//     final timeRanges = [
//       now.subtract(const Duration(days: 1)), // Last 24 hours
//       now.subtract(const Duration(days: 7)), // Last week
//       now.subtract(const Duration(days: 30)), // Last month
//       now.subtract(const Duration(days: 90)), // Last 3 months
//       now.subtract(const Duration(days: 365)), // Last year
//     ];

//     final result = <Post>[];
//     final postsByTimeRange = <int, List<Post>>{};

//     // Group posts by time range
//     for (final post in posts) {
//       final age = now.difference(post.createdAt);
//       int timeRangeIndex = timeRanges.indexWhere(
//         (range) => age < now.difference(range),
//       );
//       if (timeRangeIndex == -1) timeRangeIndex = timeRanges.length - 1;

//       postsByTimeRange.putIfAbsent(timeRangeIndex, () => []).add(post);
//     }

//     // Select posts from each time range
//     int remainingSlots = limit;
//     for (int i = 0; i < timeRanges.length && remainingSlots > 0; i++) {
//       final postsInRange = postsByTimeRange[i] ?? [];
//       if (postsInRange.isNotEmpty) {
//         final postsToTake = (remainingSlots / (timeRanges.length - i)).ceil();
//         result.addAll(postsInRange.take(postsToTake));
//         remainingSlots -= postsToTake;
//       }
//     }

//     return result;
//   }

//   // Calculate cross-domain score based on shared actors/directors
//   Future<double> _calculateCrossDomainScore(
//     Post post,
//     UserPreferences preferences,
//   ) async {
//     try {
//       final movieDetails = await _getMovieDetails(post.movieId);
//       if (movieDetails.isEmpty) return 0.0;

//       double score = 0.0;

//       // Check for shared actors
//       if (movieDetails.containsKey('credits') &&
//           movieDetails['credits'].containsKey('cast')) {
//         final cast = movieDetails['credits']['cast'] as List;
//         final actorIds = cast.map((actor) => actor['id'].toString()).toList();

//         for (final preferredActor in preferences.likes.where(
//           (pref) => pref.type == 'actor',
//         )) {
//           if (actorIds.contains(preferredActor.id)) {
//             score += preferredActor.weight * 0.15;
//           }
//         }
//       }

//       // Check for shared directors
//       if (movieDetails.containsKey('credits') &&
//           movieDetails['credits'].containsKey('crew')) {
//         final crew = movieDetails['credits']['crew'] as List;
//         final directors =
//             crew
//                 .where((person) => person['job'] == 'Director')
//                 .map((director) => director['id'].toString())
//                 .toList();

//         for (final preferredDirector in preferences.likes.where(
//           (pref) => pref.type == 'director',
//         )) {
//           if (directors.contains(preferredDirector.id)) {
//             score += preferredDirector.weight * 0.2;
//           }
//         }
//       }

//       return min(1.0, score);
//     } catch (e) {
//       _log('Error calculating cross-domain score: $e');
//       return 0.0;
//     }
//   }

//   // Calculate temporal score to ensure content diversity
//   double _calculateTemporalScore(Post post) {
//     final now = DateTime.now();
//     final ageInHours = now.difference(post.createdAt).inHours;

//     if (ageInHours < 24) {
//       return 0.3;
//     } else if (ageInHours < 168) {
//       // 1 week
//       return 0.2;
//     } else if (ageInHours < 720) {
//       // 1 month
//       return 0.1;
//     } else if (ageInHours < 2160) {
//       // 3 months
//       return 0.05;
//     }
//     return 0.0;
//   }
// }

// // Helper class for cached movie details
// class _CachedMovieDetails {
//   final Map<String, dynamic> details;
//   final DateTime timestamp;

//   _CachedMovieDetails(this.details, this.timestamp);
// }

// // Helper class to represent a scored post
// class _ScoredPost {
//   final Post post;
//   final double score;
//   final String primaryReason;

//   _ScoredPost(this.post, this.score, this.primaryReason);
// }

// // Helper for math operations
// class Math {
//   static double min(double a, double b) => a < b ? a : b;
//   static double pow(double a, double b) => pow(a, b).toDouble();
// }
