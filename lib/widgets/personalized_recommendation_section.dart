// lib/widgets/personalized_recommendation_section.dart
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/content_recommendation_service.dart';
import '../screens/movie_details_screen.dart';
import '../screens/preference_settings_screen.dart';
import 'loading_indicator.dart';

class PersonalizedRecommendationSection extends StatefulWidget {
  const PersonalizedRecommendationSection({Key? key}) : super(key: key);

  @override
  _PersonalizedRecommendationSectionState createState() =>
      _PersonalizedRecommendationSectionState();
}

class _PersonalizedRecommendationSectionState
    extends State<PersonalizedRecommendationSection> {
  final ContentRecommendationService _recommendationService =
      ContentRecommendationService();

  bool _isLoading = true;
  List<Movie> _recommendations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recommendations =
          await _recommendationService.getContentBasedRecommendations();

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading recommendations: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: LoadingIndicator(message: 'Loading your recommendations...'),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
            TextButton.icon(
              onPressed: _loadRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 48,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Personalize Your Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Set your preferences to get movie recommendations tailored just for you',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreferenceSettingsScreen(),
                    ),
                  ).then((_) => _loadRecommendations());
                },
                icon: const Icon(Icons.settings),
                label: const Text('Set Preferences'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.recommend,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'For You',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Based on your preferences',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Force Refresh',
                    onPressed: _loadRecommendations,
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Adjust Preferences',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PreferenceSettingsScreen(),
                        ),
                      ).then((_) => _loadRecommendations());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              final movie = _recommendations[index];
              return _buildMovieCard(context, movie, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(BuildContext context, Movie movie, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 150,
      margin: EdgeInsets.only(
        right: 16,
        left: index == 0 ? 0 : 0,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: movie),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie poster with rating badge
            Stack(
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    movie.posterUrl,
                    height: 200,
                    width: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: 150,
                        color: colorScheme.surfaceVariant,
                        child: const Icon(Icons.movie,
                            size: 50, color: Colors.white70),
                      );
                    },
                  ),
                ),

                // Rating badge
                if (movie.rating > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Title and year
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movie.year,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
