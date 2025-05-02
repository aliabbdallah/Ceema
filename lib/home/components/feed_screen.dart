import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'post_card.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/simplified_post_recommendation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/compose_post_screen.dart';
import 'app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'post_list.dart';
import 'dart:async'; // Add this import for StreamSubscription

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  const _SliverAppBarDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class SeamlessFeedScreen extends StatefulWidget {
  const SeamlessFeedScreen({Key? key}) : super(key: key);

  @override
  _SeamlessFeedScreenState createState() => _SeamlessFeedScreenState();
}

class _SeamlessFeedScreenState extends State<SeamlessFeedScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = false;
  double _lastScrollPosition = 0;
  bool _isAtTop = true;
  bool _isScrollingDown = false;

  // Feed filter state
  String _selectedFeedFilter = 'all'; // 'all', 'friends', 'forYou'

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostService _postService = PostService();
  final SimplifiedPostRecommendationService _recommendationService =
      SimplifiedPostRecommendationService();

  // Track visibility of various sections
  bool _showTrendingMoviesSection = true;
  final ScrollController _scrollController = ScrollController();

  // Cache for For You recommendations
  List<Post> _cachedForYouPosts = [];
  bool _isForYouLoading = false;

  // Cache for All tab posts
  List<Post>? _allPosts;
  UniqueKey _allPostsKey = UniqueKey();

  // Cache for Following tab posts
  List<Post>? _followingPosts;
  UniqueKey _followingPostsKey = UniqueKey();

  // Stream subscription for following posts
  StreamSubscription? _followingPostsSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
    _loadForYouRecommendations();
    _scrollController.addListener(_onScroll);
    _setupFollowingPostsListener();

    debugPrint('Current User: ${_auth.currentUser?.displayName}');
    debugPrint('Current User Email: ${_auth.currentUser?.email}');
    debugPrint('Current User UID: ${_auth.currentUser?.uid}');
  }

  void _onScroll() {
    final double scrollDelta =
        _scrollController.position.pixels - _lastScrollPosition;
    final bool isAtTop = _scrollController.position.pixels <= 0;

    setState(() {
      _isAtTop = isAtTop;
      _isScrollingDown = scrollDelta > 0;
    });
    _lastScrollPosition = _scrollController.position.pixels;
  }

  Future<List<String>> _getFollowedUserIds() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final followingSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .get();

      return followingSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error fetching followed user IDs: $e');
      return [];
    }
  }

  void _setupFollowingPostsListener() async {
    final currentUserId = _auth.currentUser!.uid;
    final followedUserIds = await _getFollowedUserIds();

    if (followedUserIds.isEmpty) return;

    _followingPostsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', whereIn: followedUserIds)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docChanges.isNotEmpty && mounted) {
            // Invalidate cache and refresh when new posts are detected
            setState(() {
              _followingPostsKey = UniqueKey();
            });
          }
        });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _followingPostsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkUserPreferences() async {
    setState(() {
      _showTrendingMoviesSection = true;
    });
  }

  Future<void> _loadForYouRecommendations() async {
    if (_isForYouLoading) return;

    setState(() {
      _isForYouLoading = true;
    });

    try {
      debugPrint('Loading For You recommendations...');
      final result = await _recommendationService.getRecommendedPosts(
        limit: 20,
      );

      debugPrint('Received ${result.posts.length} recommendations');

      if (mounted) {
        setState(() {
          _cachedForYouPosts = result.posts;
          _isForYouLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading recommendations: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isForYouLoading = false;
          // Keep existing recommendations if available
          if (_cachedForYouPosts.isEmpty) {
            _cachedForYouPosts = [];
          }
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Use the new PostService refresh functionality
      switch (_selectedFeedFilter) {
        case 'forYou':
          await _loadForYouRecommendations();
          break;
        case 'following':
          final posts = await _postService.refreshFeed('following');
          if (mounted) {
            setState(() {
              _followingPosts = posts;
              _followingPostsKey = UniqueKey();
            });
          }
          break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error refreshing feed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComposeSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ComposePostScreen()),
    );
  }

  void _onTabSelected(String filter) {
    setState(() {
      _selectedFeedFilter = filter;
    });
  }

  Widget _buildAllTabContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_showTrendingMoviesSection)
          const SliverToBoxAdapter(child: TrendingMoviesSection()),
        _buildFutureFeedContent(
          context,
          _postService.fetchPostsOnce(limit: 50, skipCache: true),
          key: _allPostsKey,
        ),
      ],
    );
  }

  Widget _buildForYouTabContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_showTrendingMoviesSection)
          const SliverToBoxAdapter(child: TrendingMoviesSection()),
        if (_isForYouLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          PostList(posts: _cachedForYouPosts),
      ],
    );
  }

  Widget _buildFollowingTabContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          _buildFutureFeedContent(
            context,
            _postService.fetchFollowingPostsOnce(
              _auth.currentUser!.uid,
              limit: 50,
            ),
            key: _followingPostsKey,
            isFollowingTab: true,
          ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedFeedFilter) {
      case 'all':
        return _buildAllTabContent();
      case 'forYou':
        return _buildForYouTabContent();
      case 'following':
        return _buildFollowingTabContent();
      default:
        return _buildAllTabContent();
    }
  }

  // Helper function to build Future-based content slivers
  Widget _buildFutureFeedContent(
    BuildContext context,
    Future<List<Post>> future, {
    bool isFollowingTab = false,
    Key? key,
  }) {
    return FutureBuilder<List<Post>>(
      key: key,
      future: future,
      builder: (context, snapshot) {
        final String tabName = isFollowingTab ? 'Following' : 'All';
        print(
          '[$tabName Tab] FutureBuilder rebuilding. ConnectionState: ${snapshot.connectionState}',
        );

        if (snapshot.hasError) {
          print("[$tabName Tab] Future error: ${snapshot.error}");
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Error loading posts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isFollowingTab) {
                            _followingPostsKey = UniqueKey();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[$tabName Tab] Future waiting...');
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        print('[$tabName Tab] Future completed. Post count: ${posts.length}');
        return PostList(posts: posts, showFollowingEmptyState: isFollowingTab);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshFeed,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const CeemaAppBar(),

              if (_isLoading)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    backgroundColor: colorScheme.surfaceVariant,
                    color: colorScheme.primary,
                    minHeight: 2,
                  ),
                ),

              SliverAppBar(
                pinned: true,
                toolbarHeight: 60,
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                automaticallyImplyLeading: false,
                title: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildFilterTab(
                        label: 'All',
                        isSelected: _selectedFeedFilter == 'all',
                        onTap: () => _onTabSelected('all'),
                      ),
                      _buildFilterTab(
                        label: 'For You',
                        isSelected: _selectedFeedFilter == 'forYou',
                        onTap: () => _onTabSelected('forYou'),
                      ),
                      _buildFilterTab(
                        label: 'Following',
                        isSelected: _selectedFeedFilter == 'following',
                        onTap: () => _onTabSelected('following'),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  height:
                      MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      60 -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeSheet,
        child: const Icon(Icons.add),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
