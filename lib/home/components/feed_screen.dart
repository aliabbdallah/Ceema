import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'compose_post_section.dart';
import 'post_list.dart';
import 'app_bar.dart';
import 'post_card.dart';
import '../../models/movie.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/post_recommendation_service.dart';
import '../../screens/post_recommendations_screen.dart';
import '../../screens/comments_screen.dart';
import '../../widgets/loading_indicator.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: ComposePostSection(
          onCancel: () => Navigator.pop(context),
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
      ),
    );
  }

  Widget _buildCreatePostCard(ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _showComposeSheet,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  _auth.currentUser?.photoURL ??
                      'https://ui-avatars.com/api/?name=${_auth.currentUser?.displayName ?? "User"}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Share your thoughts about a movie...',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.movie_outlined),
                onPressed: _showComposeSheet,
                tooltip: 'Select Movie',
              ),
            ],
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const CustomAppBar(),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loading Indicator
                  if (_isLoading)
                    LinearProgressIndicator(
                      backgroundColor: colorScheme.surfaceVariant,
                      color: colorScheme.primary,
                    ),

                  // Create Post Card
                  _buildCreatePostCard(colorScheme),

                  // Trending Movies
                  if (_showTrendingMoviesSection) const TrendingMoviesSection(),

                  // Feed Section Header with filter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Feed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              FilterChip(
                                label: const Text('All Posts'),
                                selected: _selectedFeedFilter == 'all',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedFeedFilter = 'all');
                                  }
                                },
                                labelStyle: TextStyle(
                                  color: _selectedFeedFilter == 'all'
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                selectedColor: colorScheme.primary,
                                backgroundColor: colorScheme.surfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Friends Only'),
                                selected: _selectedFeedFilter == 'friends',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                        () => _selectedFeedFilter = 'friends');
                                  }
                                },
                                labelStyle: TextStyle(
                                  color: _selectedFeedFilter == 'friends'
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                selectedColor: colorScheme.primary,
                                backgroundColor: colorScheme.surfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('For You'),
                                selected: _selectedFeedFilter == 'forYou',
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(
                                        () => _selectedFeedFilter = 'forYou');
                                  }
                                },
                                labelStyle: TextStyle(
                                  color: _selectedFeedFilter == 'forYou'
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                selectedColor: colorScheme.primary,
                                backgroundColor: colorScheme.surfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Post List Section
            _selectedFeedFilter == 'forYou'
                ? StreamBuilder<List<Post>>(
                    stream: _recommendationService
                        .getRecommendedPosts(limit: 20)
                        .asStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child:
                                Center(child: Text('Error: ${snapshot.error}')),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      if (snapshot.data!.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.movie_filter,
                                  size: 64,
                                  color: colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No recommendations yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Follow more friends, rate movies, or add entries to your diary to get personalized recommendations.',
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
                              return const SizedBox(height: 80);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: PostCard(post: snapshot.data![index]),
                            );
                          },
                          childCount: snapshot.data!.length + 1,
                        ),
                      );
                    },
                  )
                : PostList(showFriendsOnly: _selectedFeedFilter == 'friends'),
          ],
        ),
      ),
    );
  }
}
