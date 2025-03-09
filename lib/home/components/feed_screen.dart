import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'compose_post_section.dart';
import 'post_list.dart';
import 'app_bar.dart';
import '../../widgets/mood_recommendation_button.dart';
import '../../services/recommendation_service.dart';
import '../../models/movie.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = false;
  bool _showFriendsOnly = false;
  final RecommendationService _recommendationService = RecommendationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lists to store recommendations
  List<Movie> _genreRecommendations = [];
  List<Movie> _similarTasteRecommendations = [];
  List<Movie> _weekendWatchRecommendations = [];
  bool _loadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecommendations = true;
    });

    try {
      final userId = _auth.currentUser!.uid;

      // Load recommendations in parallel
      final genreFuture =
          _recommendationService.getGenreBasedRecommendations(userId);
      final similarTasteFuture =
          _recommendationService.getSimilarTasteRecommendations(userId);
      final weekendWatchFuture =
          _recommendationService.getWeekendWatchRecommendations(userId);

      // Wait for all recommendations to load
      final results = await Future.wait([
        genreFuture,
        similarTasteFuture,
        weekendWatchFuture,
      ]);

      if (mounted) {
        setState(() {
          _genreRecommendations = results[0];
          _similarTasteRecommendations = results[1];
          _weekendWatchRecommendations = results[2];
          _loadingRecommendations = false;
        });
      }
    } catch (e) {
      print('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _loadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoading = true;
    });

    // Reload recommendations
    _loadRecommendations();

    // Wait for a short time to simulate refresh
    await Future.delayed(const Duration(milliseconds: 1500));

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

  Widget _buildRecommendationSection(ColorScheme colorScheme) {
    if (_loadingRecommendations) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading recommendations...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genre-based recommendations
        if (_genreRecommendations.isNotEmpty) ...[
          _buildRecommendationList(
            title: 'Based on your preferred genres',
            movies: _genreRecommendations,
            colorScheme: colorScheme,
          ),
        ],

        // Similar taste recommendations
        if (_similarTasteRecommendations.isNotEmpty) ...[
          _buildRecommendationList(
            title: 'Based on similar tastes',
            movies: _similarTasteRecommendations,
            colorScheme: colorScheme,
          ),
        ],

        // Weekend watch recommendations
        if (_weekendWatchRecommendations.isNotEmpty) ...[
          _buildRecommendationList(
            title: 'Weekend watch suggestions',
            movies: _weekendWatchRecommendations,
            colorScheme: colorScheme,
          ),
        ],

        // If no recommendations are available
        if (_genreRecommendations.isEmpty &&
            _similarTasteRecommendations.isEmpty &&
            _weekendWatchRecommendations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.movie_filter,
                    size: 48,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recommendations available yet',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rate more movies to get personalized recommendations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendationList({
    required String title,
    required List<Movie> movies,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onBackground,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        // Navigate to movie details screen
        Navigator.pushNamed(
          context,
          '/movie_details',
          arguments: movie,
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                movie.posterUrl,
                height: 150,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  width: 120,
                  color: colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.movie,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Movie title
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
              ),
            ),
            // Movie year
            Text(
              movie.year,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
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
              Hero(
                tag: 'user-avatar',
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    FirebaseAuth.instance.currentUser?.photoURL ??
                        'https://ui-avatars.com/api/?name=${FirebaseAuth.instance.currentUser?.displayName ?? "User"}',
                  ),
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

                  // Section title for recommendations
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Recommendations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onBackground,
                      ),
                    ),
                  ),

                  const MoodRecommendationButton(),

                  // Display personalized recommendations
                  _buildRecommendationSection(colorScheme),

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
