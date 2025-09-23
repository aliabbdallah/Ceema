import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'post_card.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/post_recommendation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/compose_post_screen.dart';
import 'app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'post_list.dart';

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _SliverAppBarDelegate({
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
  final PageController _pageController = PageController();
  double _lastScrollPosition = 0;
  bool _isAtTop = true;
  bool _isScrollingDown = false;

  // Feed filter state
  String _selectedFeedFilter = 'all'; // 'all', 'friends', 'forYou'

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostService _postService = PostService();
  final PostRecommendationService _recommendationService =
      PostRecommendationService();

  // Track visibility of various sections
  bool _showTrendingMoviesSection = true;
  final ScrollController _scrollController = ScrollController();

  // Cache for For You recommendations
  List<Post> _cachedForYouPosts = [];
  bool _isForYouLoading = false;

  // Key to force FutureBuilder rebuild on refresh
  UniqueKey _allPostsKey = UniqueKey();
  UniqueKey _followingPostsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
    _loadForYouRecommendations();
    _scrollController.addListener(_onScroll);

    debugPrint('Current User: ${_auth.currentUser?.displayName}');
    debugPrint('Current User Email: ${_auth.currentUser?.email}');
    debugPrint('Current User UID: ${_auth.currentUser?.uid}');
  }

  void _onScroll() {
    final double scrollDelta =
        _scrollController.position.pixels - _lastScrollPosition;
    final bool isAtTop = _scrollController.position.pixels <= 0;

    // Check if we're at top and scrolling down
    // We might want to disable refresh-on-scroll-down with FutureBuilder
    // if (isAtTop && scrollDelta > 0 && !_isLoading) {
    //   _refreshFeed();
    // }

    setState(() {
      _isAtTop = isAtTop;
      _isScrollingDown = scrollDelta > 0;
    });
    _lastScrollPosition = _scrollController.position.pixels;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
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
      // Refresh For You separately
      if (_selectedFeedFilter == 'forYou') {
        await _loadForYouRecommendations();
      } else {
        // Update keys to force FutureBuilder rebuild for All/Following
        if (_selectedFeedFilter == 'all') {
          setState(() {
            _allPostsKey = UniqueKey();
          });
        } else if (_selectedFeedFilter == 'following') {
          setState(() {
            _followingPostsKey = UniqueKey();
          });
        }
        // Simulate network delay for visual feedback if needed
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('Error refreshing feed: $e');
      // Consider showing an error message to the user
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

  void _onPageChanged(int index) {
    setState(() {
      switch (index) {
        case 0:
          _selectedFeedFilter = 'all';
          break;
        case 1:
          _selectedFeedFilter = 'forYou';
          break;
        case 2:
          _selectedFeedFilter = 'following';
          break;
      }
    });
  }

  void _onTabSelected(String filter) {
    setState(() {
      _selectedFeedFilter = filter;
      switch (filter) {
        case 'all':
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
        case 'forYou':
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
        case 'following':
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
      }
    });
  }

  Widget _buildCreatePostCard(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // User avatar
                StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_auth.currentUser?.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final profileImageUrl =
                        snapshot.data?.get('profileImageUrl') as String?;
                    final username = snapshot.data?.get('username') as String?;
                    final displayName = _auth.currentUser?.displayName;

                    return CachedNetworkImage(
                      imageUrl: profileImageUrl ?? '',
                      imageBuilder:
                          (context, imageProvider) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      placeholder:
                          (context, url) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                            ),
                            child: Center(
                              child: Text(
                                (username ?? displayName ?? "U")[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                            ),
                            child: Center(
                              child: Text(
                                (username ?? displayName ?? "U")[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_auth.currentUser?.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final username = snapshot.data?.get('username') as String?;
                    final displayName = _auth.currentUser?.displayName;

                    return Text(
                      username ?? displayName ?? "User",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceVariant.withOpacity(0.3),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: Size.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading posts',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.error,
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
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          // Use PostList for rendering, it handles the empty state
          final posts = snapshot.data ?? [];
          print('[$tabName Tab] Future completed. Post count: ${posts.length}');
          return PostList(
            posts: posts,
            showFollowingEmptyState: isFollowingTab,
          );
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshFeed,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              const CeemaAppBar(),

              // Loading indicator
              if (_isLoading)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    backgroundColor: colorScheme.surfaceVariant,
                    color: colorScheme.primary,
                  ),
                ),

              // Filter tabs
              SliverAppBar(
                pinned: true,
                toolbarHeight: 56,
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                automaticallyImplyLeading: false,
                title: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
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

              // PageView
              SliverToBoxAdapter(
                child: Container(
                  height:
                      MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      56 -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: [
                      // --- All Tab Content ---
                      CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ), // Changed physics
                        slivers: [
                          if (_showTrendingMoviesSection)
                            const SliverToBoxAdapter(
                              child: TrendingMoviesSection(),
                            ),
                          // Use FutureBuilder via helper, pass the key
                          _buildFutureFeedContent(
                            context,
                            _postService.fetchPostsOnce(limit: 50),
                            key: _allPostsKey, // Pass key to helper
                          ),
                        ],
                      ),

                      // --- For You Tab Content --- (Remains mostly unchanged, uses cached data)
                      CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          if (_showTrendingMoviesSection)
                            const SliverToBoxAdapter(
                              child: TrendingMoviesSection(),
                            ),
                          if (_isForYouLoading)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ), // Simplified loading
                              ),
                            )
                          else
                            PostList(posts: _cachedForYouPosts),
                        ],
                      ),

                      // --- Following Tab Content ---
                      CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          // Use FutureBuilder via helper, pass the key
                          _buildFutureFeedContent(
                            context,
                            _postService.fetchFollowingPostsOnce(
                              _auth.currentUser!.uid,
                              limit: 50,
                            ),
                            key: _followingPostsKey, // Pass key to helper
                            isFollowingTab: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeSheet,
        child: const Icon(Icons.add),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.transparent,
                width: 2,
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
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
