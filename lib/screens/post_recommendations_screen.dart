// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../services/post_service.dart';
// import '../services/post_recommendation_service.dart';
// import '../services/feed_cache_provider.dart';
// import '../models/post.dart';
// import '../widgets/loading_indicator.dart';
// import '../home/components/post_card.dart';
// import 'dart:async';

// class PostRecommendationsScreen extends StatefulWidget {
//   const PostRecommendationsScreen({Key? key}) : super(key: key);

//   @override
//   _PostRecommendationsScreenState createState() =>
//       _PostRecommendationsScreenState();
// }

// class _PostRecommendationsScreenState extends State<PostRecommendationsScreen>
//     with SingleTickerProviderStateMixin {
//   final PostRecommendationService _recommendationService =
//       PostRecommendationService();
//   late TabController _tabController;

//   // Cache for posts
//   final Map<String, List<Post>> _postsCache = {};
//   final Map<String, bool> _isLoadingCache = {};
//   final Map<String, String?> _errorCache = {};
//   final Map<String, DocumentSnapshot?> _lastDocCache = {};
//   static const int _pageSize = 10;

//   // Debounce timer for tab changes
//   Timer? _debounceTimer;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadInitialRecommendations();
//   }

//   @override
//   void dispose() {
//     _debounceTimer?.cancel();
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadInitialRecommendations() async {
//     if (!mounted) return;
//     await _loadRecommendations('personalized');
//   }

//   Future<void> _loadRecommendations(String type) async {
//     if (_isLoadingCache[type] == true) return;
//     if (!mounted) return;

//     setState(() {
//       _isLoadingCache[type] = true;
//       _errorCache[type] = null;
//     });

//     try {
//       final cacheService =
//           Provider.of<FeedCacheProvider>(context, listen: false).cacheService;

//       // Try to get cached posts first
//       final cachedResult = await cacheService.getCachedPostsWithPagination(
//         type,
//       );
//       if (cachedResult != null) {
//         if (!mounted) return;
//         setState(() {
//           _postsCache[type] = cachedResult.posts;
//           if (cachedResult.lastDocumentId != null) {
//             _getDocumentSnapshot(cachedResult.lastDocumentId!).then((doc) {
//               if (mounted) {
//                 setState(() {
//                   _lastDocCache[type] = doc;
//                 });
//               }
//             });
//           }
//           _isLoadingCache[type] = false;
//         });
//         return;
//       }

//       // If no cache, fetch fresh posts
//       List<Post> posts;
//       DocumentSnapshot? lastDoc;

//       switch (type) {
//         case 'personalized':
//           final result = await _recommendationService.getRecommendedPosts(
//             limit: _pageSize,
//             startAfter: _lastDocCache[type],
//           );
//           posts = result.posts;
//           lastDoc = result.lastDoc;
//           break;
//         case 'trending':
//           final result = await _recommendationService.getTrendingPosts(
//             limit: _pageSize,
//             startAfter: _lastDocCache[type],
//           );
//           posts = result.posts;
//           lastDoc = result.lastDoc;
//           break;
//         case 'friends':
//           final result = await _recommendationService.getFriendsPosts(
//             limit: _pageSize,
//             startAfter: _lastDocCache[type],
//           );
//           posts = result.posts;
//           lastDoc = result.lastDoc;
//           break;
//         default:
//           posts = [];
//       }

//       if (!mounted) return;

//       // Cache the new posts
//       await cacheService.cachePostsWithPagination(
//         type,
//         posts,
//         lastDoc?.id,
//         posts.isEmpty,
//       );

//       setState(() {
//         _postsCache[type] = [...?_postsCache[type], ...posts];
//         _isLoadingCache[type] = false;
//         if (lastDoc != null) {
//           _lastDocCache[type] = lastDoc;
//         }
//       });
//     } catch (error) {
//       if (!mounted) return;
//       setState(() {
//         _errorCache[type] = error.toString();
//         _isLoadingCache[type] = false;
//       });
//     }
//   }

//   Future<DocumentSnapshot> _getDocumentSnapshot(String documentId) async {
//     return await FirebaseFirestore.instance
//         .collection('posts')
//         .doc(documentId)
//         .get();
//   }

//   void _onTabChanged() {
//     _debounceTimer?.cancel();
//     _debounceTimer = Timer(const Duration(milliseconds: 300), () {
//       if (!mounted) return;
//       final type = _getCurrentTabType();
//       if (_postsCache[type] == null || _postsCache[type]!.isEmpty) {
//         _loadRecommendations(type);
//       }
//     });
//   }

//   String _getCurrentTabType() {
//     switch (_tabController.index) {
//       case 0:
//         return 'personalized';
//       case 1:
//         return 'trending';
//       case 2:
//         return 'friends';
//       default:
//         return 'personalized';
//     }
//   }

//   Widget _buildPostList(String type) {
//     final posts = _postsCache[type] ?? [];
//     final isLoading = _isLoadingCache[type] ?? false;
//     final error = _errorCache[type];

//     if (isLoading && posts.isEmpty) {
//       return const Center(child: LoadingIndicator());
//     }

//     if (error != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, size: 48, color: Colors.red),
//             const SizedBox(height: 16),
//             Text('Error: $error'),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 _postsCache[type] = [];
//                 _lastDocCache[type] = null;
//                 _loadRecommendations(type);
//               },
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (posts.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.movie_filter_outlined,
//               size: 64,
//               color: Colors.grey[300],
//             ),
//             const SizedBox(height: 16),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Text(
//                 _getEmptyMessage(type),
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.only(top: 8),
//       itemCount: posts.length + (isLoading ? 1 : 0),
//       itemBuilder: (context, index) {
//         if (index == posts.length) {
//           _loadRecommendations(type);
//           return const Center(child: LoadingIndicator());
//         }

//         final post = posts[index];
//         return SeamlessPostCard(post: post);
//       },
//     );
//   }

//   String _getEmptyMessage(String type) {
//     switch (type) {
//       case 'personalized':
//         return 'No personalized recommendations yet. Try adding more movies to your diary or following more people!';
//       case 'trending':
//         return 'No trending posts right now. Check back later!';
//       case 'friends':
//         return 'No recent posts from friends. Try following more people!';
//       default:
//         return 'No posts available.';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Discover'),
//         bottom: TabBar(
//           controller: _tabController,
//           onTap: (_) => _onTabChanged(),
//           tabs: const [
//             Tab(text: 'For You'),
//             Tab(text: 'Trending'),
//             Tab(text: 'From Friends'),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               final type = _getCurrentTabType();
//               _postsCache[type] = [];
//               _lastDocCache[type] = null;
//               _loadRecommendations(type);
//             },
//             tooltip: 'Refresh recommendations',
//           ),
//         ],
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildPostList('personalized'),
//           _buildPostList('trending'),
//           _buildPostList('friends'),
//         ],
//       ),
//     );
//   }
// }
