import 'package:flutter/material.dart';
import '../../../models/movie.dart';
import '../widgets/movie_list_item.dart';
import '../../../screens/quick_add_movies_screen.dart';

class MovieSearchTab extends StatelessWidget {
  final List<Movie> movieResults;
  final List<Map<String, dynamic>> movieSuggestions;
  final bool isLoading;
  final bool isSearchActive;
  final bool showMovieSuggestions;

  const MovieSearchTab({
    Key? key,
    required this.movieResults,
    required this.movieSuggestions,
    required this.isLoading,
    required this.isSearchActive,
    required this.showMovieSuggestions,
  }) : super(key: key);

  Widget _buildMovieSuggestions(BuildContext context) {
    if (!showMovieSuggestions || movieSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Movie Suggestions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movieSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = movieSuggestions[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // This will be handled by the parent widget
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child:
                            suggestion['poster_path'] != null
                                ? Image.network(
                                  'https://image.tmdb.org/t/p/w500${suggestion['poster_path']}',
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 40,
                                      height: 60,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceVariant,
                                      child: Icon(
                                        Icons.movie,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  width: 40,
                                  height: 60,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                  child: Icon(
                                    Icons.movie,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (suggestion['release_date'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                suggestion['release_date'].toString().split(
                                  '-',
                                )[0],
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_filter,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No movies found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Column(
      children: [
        _buildMovieSuggestions(context),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Search Movies',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Find movies by title, actors, or genre',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuickAddMoviesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Quick Add Movies'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching movies...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (isSearchActive && movieResults.isEmpty) {
      return _buildEmptyState(context);
    }

    if (movieResults.isNotEmpty) {
      return Column(
        children: [
          _buildMovieSuggestions(context),
          Expanded(
            child: ListView.builder(
              itemCount: movieResults.length,
              itemBuilder:
                  (context, index) => MovieListItem(movie: movieResults[index]),
            ),
          ),
        ],
      );
    }

    return _buildInitialState(context);
  }
}
