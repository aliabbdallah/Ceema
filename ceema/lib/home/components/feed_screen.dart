import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'trending_movies_section.dart';
import 'post_card.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/post_recommendation_service.dart';
import 'compose_post_section.dart';
import '../../screens/search_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/profile_image_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/compose_post_screen.dart';
import 'app_bar.dart';

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

class _SeamlessFeedScreenState extends State<SeamlessFeedScreen>
    with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true;

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
    if (isAtTop && scrollDelta > 0 && !_isLoading) {
      _refreshFeed();
    }

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
      final result = await _recommendationService.getRecommendedPosts(
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _cachedForYouPosts = result.posts;
          _isForYouLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isForYouLoading = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Only refresh For You recommendations if we're on that tab
      if (_selectedFeedFilter == 'forYou') {
        await _loadForYouRecommendations();
      }
      await Future.delayed(const Duration(milliseconds: 1000));
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

                    return ProfileImageWidget(
                      imageUrl: profileImageUrl,
                      radius: 30,
                      fallbackName: username ?? displayName ?? "User",
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
    super.build(context);
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

              // Filter tabs in SliverAppBar
              SliverAppBar(
                pinned: false,
                floating: true,
                snap: true,
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

              // Content based on selected tab
              SliverFillRemaining(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    // All tab content
                    CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_showTrendingMoviesSection)
                          const SliverToBoxAdapter(
                            child: TrendingMoviesSection(),
                          ),
                        StreamBuilder<List<Post>>(
                          stream: _postService.getPosts(),
                          builder: _buildPostStreamContent,
                        ),
                      ],
                    ),
                    // For You tab content
                    CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_showTrendingMoviesSection)
                          const SliverToBoxAdapter(
                            child: TrendingMoviesSection(),
                          ),
                        if (_isForYouLoading)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 48,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Personalizing your feed',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'We\'re finding the best content for you',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index == _cachedForYouPosts.length) {
                                return const SizedBox(height: 80);
                              }
                              return SeamlessPostCard(
                                post: _cachedForYouPosts[index],
                                relevanceReason:
                                    'Recommended based on your preferences',
                              );
                            }, childCount: _cachedForYouPosts.length + 1),
                          ),
                      ],
                    ),
                    // Following tab content
                    CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        StreamBuilder<List<Post>>(
                          stream: _postService.getFollowingPosts(
                            _auth.currentUser!.uid,
                          ),
                          builder: _buildPostStreamContent,
                        ),
                      ],
                    ),
                  ],
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

  Widget _buildPostStreamContent(
    BuildContext context,
    AsyncSnapshot<List<Post>> snapshot,
  ) {
    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(child: Text('Error: ${snapshot.error}')),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedFeedFilter == 'forYou') ...[
                Icon(
                  Icons.local_fire_department,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Personalizing your feed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'re finding the best content for you',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.movie_filter,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFeedFilter == 'following'
                    ? 'No posts from following'
                    : _selectedFeedFilter == 'forYou'
                    ? 'No recommendations yet'
                    : 'No posts yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Follow more friends or check back later to see new content.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == snapshot.data!.length) {
            // Add a bottom padding at the end of the list
            return const SizedBox(height: 80);
          }

          // Use the seamless post card
          return SeamlessPostCard(
            post: snapshot.data![index],
            // Apply relevance reason for recommended content
            relevanceReason:
                _selectedFeedFilter == 'forYou'
                    ? 'Recommended based on your preferences'
                    : null,
          );
        },
        childCount: snapshot.data!.length + 1, // +1 for bottom padding
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
