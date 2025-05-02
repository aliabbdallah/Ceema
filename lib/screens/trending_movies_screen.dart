import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';

class TrendingMoviesScreen extends StatefulWidget {
  const TrendingMoviesScreen({Key? key}) : super(key: key);

  @override
  _TrendingMoviesScreenState createState() => _TrendingMoviesScreenState();
}

class _TrendingMoviesScreenState extends State<TrendingMoviesScreen> {
  List<Movie> _trendingMovies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrendingMovies();
  }

  Future<void> _loadTrendingMovies() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final moviesData = await TMDBService.getTrendingMoviesRaw();
      if (mounted) {
        setState(() {
          _trendingMovies =
              moviesData.map((data) => Movie.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading trending movies';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToMovieDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.60,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
      ),
      itemCount: _trendingMovies.length,
      itemBuilder: (context, index) {
        final movie = _trendingMovies[index];
        return Hero(
          tag: 'movie-${movie.id}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToMovieDetails(movie),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        movie.posterUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: const Center(
                              child: Icon(
                                Icons.movie,
                                size: 40,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movie.year,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending Movies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrendingMovies,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadTrendingMovies,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadTrendingMovies,
                child: _buildMovieGrid(),
              ),
    );
  }
}
