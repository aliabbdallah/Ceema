import 'package:flutter/material.dart';
import '../services/post_recommendation_service.dart';
import '../models/post.dart';
import '../widgets/loading_indicator.dart';
import '../home/components/post_card.dart'; // Correct path

class PostRecommendationsScreen extends StatefulWidget {
  const PostRecommendationsScreen({Key? key}) : super(key: key);

  @override
  _PostRecommendationsScreenState createState() =>
      _PostRecommendationsScreenState();
}

class _PostRecommendationsScreenState extends State<PostRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  final PostRecommendationService _recommendationService =
      PostRecommendationService();
  late TabController _tabController;

  List<Post>? _personalizedPosts;
  List<Post>? _trendingPosts;
  List<Post>? _friendPosts;

  bool _isLoadingPersonalized = true;
  bool _isLoadingTrending = true;
  bool _isLoadingFriends = true;

  String? _personalizedError;
  String? _trendingError;
  String? _friendsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadRecommendations() {
    // Load personalized recommendations
    setState(() {
      _isLoadingPersonalized = true;
      _personalizedError = null;
    });

    _recommendationService.getRecommendedPosts().then((posts) {
      if (mounted) {
        setState(() {
          _personalizedPosts = posts;
          _isLoadingPersonalized = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _personalizedError = error.toString();
          _isLoadingPersonalized = false;
        });
      }
    });

    // Load trending posts
    setState(() {
      _isLoadingTrending = true;
      _trendingError = null;
    });

    _recommendationService.getTrendingPosts().then((posts) {
      if (mounted) {
        setState(() {
          _trendingPosts = posts;
          _isLoadingTrending = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _trendingError = error.toString();
          _isLoadingTrending = false;
        });
      }
    });

    // Load friend posts
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });

    _recommendationService.getFriendsPosts().then((posts) {
      if (mounted) {
        setState(() {
          _friendPosts = posts;
          _isLoadingFriends = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _friendsError = error.toString();
          _isLoadingFriends = false;
        });
      }
    });
  }

  Widget _buildPostList(
    List<Post>? posts,
    bool isLoading,
    String? error,
    String emptyMessage,
  ) {
    if (isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (posts == null || posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];

        // Log view interaction for personalized tab
        if (_tabController.index == 0) {
          _recommendationService.logInteraction(
            postId: post.id,
            actionType: 'view',
          );
        }

        return PostCard(post: post);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Trending'),
            Tab(text: 'From Friends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: 'Refresh recommendations',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Personalized recommendations
          _buildPostList(
            _personalizedPosts,
            _isLoadingPersonalized,
            _personalizedError,
            'No personalized recommendations yet. Try adding more movies to your diary or following more people!',
          ),

          // Trending posts
          _buildPostList(
            _trendingPosts,
            _isLoadingTrending,
            _trendingError,
            'No trending posts right now. Check back later!',
          ),

          // Friend posts
          _buildPostList(
            _friendPosts,
            _isLoadingFriends,
            _friendsError,
            'No recent posts from friends. Try following more people!',
          ),
        ],
      ),
    );
  }
}
