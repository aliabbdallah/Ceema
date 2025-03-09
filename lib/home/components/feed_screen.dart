import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'compose_post_section.dart';
import 'post_list.dart';
import 'app_bar.dart';
import '../../widgets/mood_recommendation_button.dart';
import '../../models/movie.dart';
import '../../widgets/personalized_recommendation_section.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoading = true;
    });

    // Wait for a short time to simulate refresh
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
                  FirebaseAuth.instance.currentUser?.photoURL ??
                      'https://ui-avatars.com/api/?name=${FirebaseAuth.instance.currentUser?.displayName ?? "User"}',
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
                  _buildCreatePostCard(colorScheme),

                  const MoodRecommendationButton(),

                  // Display personalized recommendations
                  const PersonalizedRecommendationSection(),

                  const TrendingMoviesSection(),

                  // Section title for feed with filter toggle
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
            // Post list section
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
