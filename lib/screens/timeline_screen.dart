// lib/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/timeline_activity.dart';
import '../services/timeline_service.dart';
import '../home/components/post_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/relevance_indicator.dart';
import '../screens/movie_details_screen.dart';
import '../screens/compose_post_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with AutomaticKeepAliveClientMixin {
  final TimelineService _timelineService = TimelineService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = false;
  String _selectedGenre = 'All';

  // List of genres to filter by
  final List<String> _genres = [
    'All',
    'Action',
    'Comedy',
    'Drama',
    'Thriller',
    'Horror',
    'Romance',
    'Sci-Fi',
    'Fantasy',
    'Animation',
    'Adventure',
  ];

  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshTimeline() async {
    setState(() {
      _isLoading = true;
    });

    // Wait for a short time to simulate refresh
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTimelineHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Timeline',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Movie reviews and recommendations tailored to your taste',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreFilter(ColorScheme colorScheme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genres.length,
        itemBuilder: (context, index) {
          final genre = _genres[index];
          final isSelected = _selectedGenre == genre;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(genre),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedGenre = genre;
                });
              },
              showCheckmark: false,
              selectedColor: colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, TimelineItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (item.type) {
      case TimelineItemType.friendPost:
      case TimelineItemType.similarToLiked:
        if (item.post != null) {
          // Use new component with RelevanceIndicator
          return _buildEnhancedPostCard(item, context);
        }
        return const SizedBox.shrink();

      case TimelineItemType.recommendation:
      case TimelineItemType.trendingMovie:
      case TimelineItemType.newReleaseGenre:
        if (item.movie != null) {
          return _buildMovieRecommendation(item, colorScheme);
        }
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEnhancedPostCard(TimelineItem item, BuildContext context) {
    if (item.post == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.type == TimelineItemType.similarToLiked
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outlineVariant,
          width: item.type == TimelineItemType.similarToLiked ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add relevance indicator at the top
          if (item.relevanceReason != null)
            RelevanceIndicator(
              reason: item.relevanceReason!,
              relevanceScore: item.relevanceScore,
              itemType: item.type,
            ),

          // Post content
          PostCard(post: item.post!),
        ],
      ),
    );
  }

  Widget _buildMovieRecommendation(TimelineItem item, ColorScheme colorScheme) {
    if (item.movie == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.type == TimelineItemType.recommendation
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.relevanceReason != null)
            RelevanceIndicator(
              reason: item.relevanceReason!,
              relevanceScore: item.relevanceScore,
              itemType: item.type,
            ),

          // Movie content
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: item.movie!),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Movie poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.movie!.posterUrl,
                      height: 150,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Movie details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.movie!.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.movie!.year,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.movie!.overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MovieDetailsScreen(movie: item.movie!),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Timeline'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Preferences',
            onPressed: () {
              // Navigate to preferences screen
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComposePostScreen(),
            ),
          ).then((posted) {
            if (posted == true) {
              // If a post was created, refresh the timeline
              _refreshIndicatorKey.currentState?.show();
            }
          });
        },
        tooltip: 'Create Post',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshTimeline,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
            StreamBuilder<List<TimelineItem>?>(
              stream: _selectedGenre == 'All'
                  ? _timelineService.getPersonalizedTimeline()
                  : _timelineService.getGenreTimeline(_selectedGenre),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading timeline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.error.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child:
                        LoadingIndicator(message: 'Loading your timeline...'),
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
                          Text(
                            'Your timeline is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Follow more friends, rate movies, or add entries to your diary to personalize your timeline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
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

                      final timelineItem = snapshot.data![index];
                      // Add animation for each item
                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: Duration(milliseconds: 500 + (index * 100)),
                        curve: Curves.easeInOut,
                        child: _buildTimelineItem(context, timelineItem),
                      );
                    },
                    childCount:
                        snapshot.data!.length + 1, // +1 for bottom padding
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
