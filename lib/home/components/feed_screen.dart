// lib/home/components/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'compose_post_section.dart';
import 'post_list.dart';
import 'app_bar.dart';
import '../../widgets/mood_recommendation_button.dart';
import '../../models/movie.dart';
import '../../models/post.dart';
import '../../models/timeline_activity.dart' as model;
import '../../widgets/personalized_recommendation_section.dart';
import '../../widgets/timeline_item.dart';
import '../../services/timeline_service.dart';
import '../../screens/timeline_screen.dart';
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
  bool _showFriendsOnly = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TimelineService _timelineService = TimelineService();
  final PostRecommendationService _recommendationService =
      PostRecommendationService();

  // Track visibility of various sections
  bool _showRecommendedPostsSection = true;
  bool _showPersonalizedMoviesSection = true;
  bool _showTrendingMoviesSection = true;
  bool _showReviewsSection = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkUserPreferences();
  }

  // Check user preferences for section visibility
  Future<void> _checkUserPreferences() async {
    // In a real app, you would fetch these from user preferences
    // For now, we'll just use default values
    setState(() {
      _showRecommendedPostsSection = true;
      _showPersonalizedMoviesSection = true;
      _showTrendingMoviesSection = true;
      _showReviewsSection = true;
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh all data sources
      await Future.wait([
        Future.delayed(
            const Duration(milliseconds: 1000)), // Minimum delay for UX
      ]);
    } catch (e) {
      debugPrint('Error refreshing feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ComposePostSection(
                onCancel: () => Navigator.pop(context),
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
            ),
          ],
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

  // NEW: Recommended Posts Section
  Widget _buildRecommendedPostsSection() {
    if (!_showRecommendedPostsSection) return const SizedBox.shrink();

    return FutureBuilder<List<Post>>(
      future: _recommendationService.getRecommendedPosts(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox
              .shrink(); // Don't show section if there are no recommendations
        }

        final recommendations = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.recommend,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Recommended For You',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PostRecommendationsScreen(),
                        ),
                      );
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final post = recommendations[index];

                  // Log viewing recommendation
                  _recommendationService.logInteraction(
                    postId: post.id,
                    actionType: 'view',
                  );

                  return GestureDetector(
                    onTap: () {
                      // Navigate to post detail or comment screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsScreen(post: post),
                        ),
                      );

                      // Log interaction
                      _recommendationService.logInteraction(
                        postId: post.id,
                        actionType: 'click',
                      );
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Movie poster
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                            child: Image.network(
                              post.moviePosterUrl,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.movieTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage:
                                          NetworkImage(post.userAvatar),
                                      radius: 8,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        post.userName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonalizedReviewsPreview(ColorScheme colorScheme) {
    if (!_showReviewsSection) return const SizedBox.shrink();

    return StreamBuilder<List<model.TimelineItem>>(
      stream: _timelineService.getPersonalizedTimeline(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.all(16),
            height: 200,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        // Filter to recommended posts only
        final recommendedPosts = snapshot.data!
            .where((item) =>
                item.type == model.TimelineItemType.similarToLiked &&
                item.post != null)
            .toList();

        if (recommendedPosts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Just show the first 2 recommended posts as a preview
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Reviews For You',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TimelineScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.more_horiz, size: 16),
                    label: const Text('See all'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Movie reviews tailored to your taste based on your ratings and preferences.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Show the first 2 recommendations
            for (var i = 0; i < min(2, recommendedPosts.length); i++)
              TimelineItem(
                post: recommendedPosts[i].post!,
                relevanceReason: recommendedPosts[i].relevanceReason,
                isHighlighted: true,
              ),

            // See more button
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TimelineScreen(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See more reviews for you',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper function for min value
  int min(int a, int b) {
    return a < b ? a : b;
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
            // App Bar
            const CustomAppBar(),

            // Loading Indicator
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isLoading
                    ? LinearProgressIndicator(
                        backgroundColor: colorScheme.surfaceVariant,
                        color: colorScheme.primary,
                      )
                    : const SizedBox(height: 1),
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Post Card
                  _buildCreatePostCard(colorScheme),

                  // Mood Recommendations
                  const MoodRecommendationButton(),

                  // NEW: Post Recommendations Section
                  _buildRecommendedPostsSection(),

                  // Movie Recommendations
                  if (_showPersonalizedMoviesSection)
                    const PersonalizedRecommendationSection(),

                  // Trending Movies
                  if (_showTrendingMoviesSection) const TrendingMoviesSection(),

                  // Reviews Preview
                  _buildPersonalizedReviewsPreview(colorScheme),

                  // Feed Section Header with filter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Feed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onBackground,
                          ),
                        ),
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('All Posts'),
                              selected: !_showFriendsOnly,
                              onSelected: (selected) {
                                setState(() => _showFriendsOnly = false);
                              },
                              labelStyle: TextStyle(
                                color: !_showFriendsOnly
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
                              selected: _showFriendsOnly,
                              onSelected: (selected) {
                                setState(() => _showFriendsOnly = true);
                              },
                              labelStyle: TextStyle(
                                color: _showFriendsOnly
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              selectedColor: colorScheme.primary,
                              backgroundColor: colorScheme.surfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Post List Section
            PostList(showFriendsOnly: _showFriendsOnly),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeSheet,
        child: const Icon(Icons.add),
        tooltip: 'Create Post',
      ),
    );
  }
}
