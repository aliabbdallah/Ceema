// screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../services/timeline_service.dart';
import '../home/components/post_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/mood_recommendation_button.dart';
import '../widgets/timeline_item.dart';
import '../widgets/trending_movie_row.dart';
import '../home/components/app_bar.dart';

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
            'Discover posts based on your movie preferences',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          const MoodRecommendationButton(),
        ],
      ),
    );
  }

  Widget _buildMovieCategories(ColorScheme colorScheme) {
    final categories = [
      {'icon': Icons.local_fire_department, 'name': 'Hot'},
      {'icon': Icons.favorite, 'name': 'Favorites'},
      {'icon': Icons.star, 'name': 'Top Rated'},
      {'icon': Icons.group, 'name': 'Friends'},
      {'icon': Icons.new_releases, 'name': 'New'},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 16,
                    color: index == 0
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(category['name'] as String),
                ],
              ),
              selected: index == 0,
              onSelected: (selected) {
                // Would implement category filtering here
              },
              labelStyle: TextStyle(
                color: index == 0
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceVariant,
            ),
          );
        },
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
        onRefresh: _refreshTimeline,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const CustomAppBar(),
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
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimelineHeader(colorScheme),
                  _buildMovieCategories(colorScheme),
                ],
              ),
            ),
            StreamBuilder<List<TimelineItem>?>(
              stream: _timelineService.getPersonalizedTimeline()
                  as Stream<List<TimelineItem>?>?,
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
                      // Check if the timeline item has a post
                      if (timelineItem.post != null) {
                        // Add animation for each post card
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: Duration(milliseconds: 500 + (index * 100)),
                          curve: Curves.easeInOut,
                          child: PostCard(post: timelineItem.post!),
                        );
                      } else {
                        // If no post, show a placeholder
                        return const SizedBox.shrink();
                      }
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
