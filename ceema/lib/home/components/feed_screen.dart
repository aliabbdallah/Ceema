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

  // Feed filter state
  String _selectedFeedFilter = 'all'; // 'all', 'friends', 'forYou'

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostService _postService = PostService();
  final PostRecommendationService _recommendationService =
      PostRecommendationService();

  // Track visibility of various sections
  bool _showTrendingMoviesSection = true;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
    debugPrint('Current User: ${_auth.currentUser?.displayName}');
    debugPrint('Current User Email: ${_auth.currentUser?.email}');
    debugPrint('Current User UID: ${_auth.currentUser?.uid}');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkUserPreferences() async {
    setState(() {
      _showTrendingMoviesSection = true;
    });
  }

  Future<void> _refreshFeed() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
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
                ProfileImageWidget(
                  imageUrl: _auth.currentUser?.photoURL,
                  radius: 20,
                  fallbackName:
                      _auth.currentUser?.displayName?.split(' ').first ??
                      _auth.currentUser?.email?.split('@').first ??
                      "User",
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
                    return Text(
                      username ??
                          _auth.currentUser?.displayName ??
                          _auth.currentUser?.email?.split('@').first ??
                          "User",
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

  Widget _buildFeedFilter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            onTap: () => setState(() => _selectedFeedFilter = 'all'),
          ),
          _buildFilterTab(
            label: 'For You',
            isSelected: _selectedFeedFilter == 'forYou',
            onTap: () => setState(() => _selectedFeedFilter = 'forYou'),
          ),
          _buildFilterTab(
            label: 'Following',
            isSelected: _selectedFeedFilter == 'following',
            onTap: () => setState(() => _selectedFeedFilter = 'following'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
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

            // Feed filter tabs
            SliverToBoxAdapter(child: _buildFeedFilter(colorScheme)),

            // Trending Movies - Only show in 'all' and 'forYou' tabs
            if (_showTrendingMoviesSection &&
                (_selectedFeedFilter == 'all' ||
                    _selectedFeedFilter == 'forYou'))
              const SliverToBoxAdapter(child: TrendingMoviesSection()),

            // Post Stream
            _selectedFeedFilter == 'forYou'
                ? StreamBuilder<List<Post>>(
                  stream:
                      _recommendationService
                          .getRecommendedPosts(limit: 20)
                          .asStream(),
                  builder: _buildPostStreamContent,
                )
                : _selectedFeedFilter == 'following'
                ? StreamBuilder<List<Post>>(
                  stream: _postService.getFollowingPosts(
                    _auth.currentUser!.uid,
                  ),
                  builder: _buildPostStreamContent,
                )
                : StreamBuilder<List<Post>>(
                  stream: _postService.getPosts(),
                  builder: _buildPostStreamContent,
                ),
          ],
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
}
