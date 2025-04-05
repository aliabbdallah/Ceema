// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/movie.dart';
// import '../models/user_preferences.dart';
// import '../models/post.dart';
// import '../services/tmdb_service.dart';
// import '../services/preference_service.dart';

// class ColdStartService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final PreferenceService _preferenceService = PreferenceService();

//   // Cache for initial recommendations
//   List<Post>? _cachedRecommendations;
//   DateTime? _lastFetchTime;
//   bool _isFetching = false;

//   // Get initial recommendations for new users
//   Future<List<Post>> getInitialRecommendations() async {
//     try {
//       // If already fetching, return cached data or empty list
//       if (_isFetching) {
//         print('DEBUG: Already fetching, returning cached data');
//         return _cachedRecommendations ?? [];
//       }

//       // Check if we have cached recommendations that are less than 5 minutes old
//       if (_cachedRecommendations != null &&
//           _lastFetchTime != null &&
//           DateTime.now().difference(_lastFetchTime!) <
//               const Duration(minutes: 5)) {
//         print('DEBUG: Returning cached recommendations');
//         return _cachedRecommendations!;
//       }

//       _isFetching = true;
//       print('DEBUG: Getting most liked posts');

//       // Get all posts from Firestore
//       final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
//           .collection('posts')
//           .orderBy('likes', descending: true)
//           .get();

//       List<Post> posts;
//       if (querySnapshot.docs.isEmpty) {
//         print('DEBUG: No posts found in Firestore, fetching trending movies');
//         // If no posts in Firestore, get trending movies from TMDB
//         final trendingMovies = await TMDBService.getTrendingMoviesRaw();
//         posts = trendingMovies.map((movie) {
//           return Post(
//             id: movie['id'].toString(),
//             userId: 'system',
//             userName: 'System',
//             userAvatar: '',
//             content: 'Check out this trending movie!',
//             movieId: movie['id'].toString(),
//             movieTitle: movie['title'],
//             moviePosterUrl: movie['poster_path'],
//             movieYear: movie['release_date']?.substring(0, 4) ?? '',
//             movieOverview: movie['overview'] ?? '',
//             createdAt: DateTime.now(),
//             likes: [],
//             commentCount: 0,
//             rating: (movie['vote_average'] ?? 0.0).toDouble(),
//           );
//         }).toList();

//         print(
//             'DEBUG: Created ${posts.length} sample posts from trending movies');
//       } else {
//         // Convert Firestore documents to Post objects
//         posts = querySnapshot.docs.map((doc) {
//           final data = doc.data() as Map<String, dynamic>;
//           return Post(
//             id: doc.id,
//             userId: data['userId'] ?? '',
//             userName: data['userName'] ?? '',
//             userAvatar: data['userAvatar'] ?? '',
//             content: data['content'] ?? '',
//             movieId: data['movieId'] ?? '',
//             movieTitle: data['movieTitle'] ?? '',
//             moviePosterUrl: data['moviePosterUrl'] ?? '',
//             movieYear: data['movieYear'] ?? '',
//             movieOverview: data['movieOverview'] ?? '',
//             createdAt: (data['createdAt'] as Timestamp).toDate(),
//             likes: List<String>.from(data['likes'] ?? []),
//             commentCount: data['commentCount'] ?? 0,
//             rating: (data['rating'] ?? 0.0).toDouble(),
//           );
//         }).toList();

//         print('DEBUG: Found ${posts.length} posts, sorted by likes');
//       }

//       // Cache the results
//       _cachedRecommendations = posts;
//       _lastFetchTime = DateTime.now();
//       _isFetching = false;

//       return posts;
//     } catch (e) {
//       print('DEBUG: Error in getInitialRecommendations: $e');
//       _isFetching = false;
//       return _cachedRecommendations ?? [];
//     }
//   }

//   // Clear the cache when needed (e.g., when user preferences change)
//   void clearCache() {
//     _cachedRecommendations = null;
//     _lastFetchTime = null;
//     _isFetching = false;
//   }

//   // Get popular genres from TMDB
//   Future<List<int>> _getPopularGenres() async {
//     try {
//       // Default popular genres if API fails
//       return [
//         28, // Action
//         12, // Adventure
//         16, // Animation
//         35, // Comedy
//         18, // Drama
//         10751, // Family
//         14, // Fantasy
//         27, // Horror
//         9648, // Mystery
//         10749, // Romance
//         878, // Science Fiction
//         53, // Thriller
//       ];
//     } catch (e) {
//       print('Error getting popular genres: $e');
//       return [28, 12, 16, 35, 18];
//     }
//   }

//   // Initialize user preferences with default values
//   Future<void> initializeUserPreferences() async {
//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId == null) throw Exception('User not authenticated');

//       // Create default preferences
//       final defaultPrefs = UserPreferences(
//         userId: userId,
//         likes: [],
//         dislikes: [],
//         importanceFactors: {
//           'story': 1.0,
//           'acting': 1.0,
//           'visuals': 1.0,
//           'soundtrack': 1.0,
//           'pacing': 1.0,
//         },
//       );

//       // Save to Firestore
//       await _firestore
//           .collection('user_preferences')
//           .doc(userId)
//           .set(defaultPrefs.toJson());
//     } catch (e) {
//       print('Error initializing user preferences: $e');
//     }
//   }
// }
