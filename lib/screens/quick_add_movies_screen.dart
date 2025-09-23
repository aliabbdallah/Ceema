import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/diary_service.dart';
import '../services/movie_rating_service.dart';
import 'movie_details_screen.dart';

class QuickAddMoviesScreen extends StatefulWidget {
  const QuickAddMoviesScreen({Key? key}) : super(key: key);

  @override
  _QuickAddMoviesScreenState createState() => _QuickAddMoviesScreenState();
}

class _QuickAddMoviesScreenState extends State<QuickAddMoviesScreen> {
  final TMDBService _tmdbService = TMDBService();
  final DiaryService _diaryService = DiaryService();
  final MovieRatingService _movieRatingService = MovieRatingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Movie> _popularMovies = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _trendingMovies = [];
  List<Movie> _searchResults = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isAddingMovies = false;
  bool _showSuggestions = false;
  Map<String, double> _movieRatings = {};
  Set<String> _selectedMovieIds = {};
  Set<String> _alreadyWatchedIds = {};

  // New state variables for search optimization
  Timer? _debounce;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _loadUserWatchedMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    setState(() {
      _currentQuery = query;
      _showSuggestions = query.isNotEmpty;
    });

    // Update suggestions immediately
    _updateSuggestions(query);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _currentQuery = '';
          _showSuggestions = false;
        });
        return;
      }

      if (query.trim().length < 3) {
        setState(() {
          _searchResults = [];
          _currentQuery = query;
        });
        return;
      }

      _executeSearch(query);
    });
  }

  Future<void> _updateSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    try {
      final suggestions = await TMDBService.getSuggestions(query);
      if (mounted && query == _currentQuery) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (e) {
      print('Error updating suggestions: $e');
    }
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      final results = await _tmdbService.searchMovies(query);
      if (mounted && query == _currentQuery.trim()) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching movies: $e')));
      }
    }
  }

  Future<void> _loadMovies() async {
    try {
      final popular = await _tmdbService.getPopularMovies();
      final topRated = await TMDBService.getTopRatedMovies();
      final trending = await _tmdbService.getTrendingMovies();

      if (mounted) {
        setState(() {
          _popularMovies = popular;
          _topRatedMovies =
              topRated.map((data) => Movie.fromJson(data)).toList();
          _trendingMovies = trending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading movies: $e')));
      }
    }
  }

  Future<void> _loadUserWatchedMovies() async {
    if (_auth.currentUser == null) return;

    final userId = _auth.currentUser!.uid;

    // Get movies from diary entries
    final diaryEntries =
        await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: userId)
            .get();

    // Get movies from direct ratings
    final directRatings =
        await _firestore
            .collection('movie_ratings')
            .where('userId', isEqualTo: userId)
            .get();

    final Set<String> watchedIds = {};
    for (var doc in diaryEntries.docs) {
      watchedIds.add(doc.data()['movieId']);
    }
    for (var doc in directRatings.docs) {
      watchedIds.add(doc.data()['movieId']);
    }

    if (mounted) {
      setState(() {
        _alreadyWatchedIds = watchedIds;
      });
    }
  }

  Future<void> _addSelectedMovies() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add movies')),
      );
      return;
    }

    setState(() {
      _isAddingMovies = true;
    });

    final userId = _auth.currentUser!.uid;
    int successCount = 0;

    try {
      for (var movieId in _selectedMovieIds) {
        try {
          // Find the movie in any of our lists
          final movie = [
            ..._popularMovies,
            ..._topRatedMovies,
            ..._trendingMovies,
            ..._searchResults,
          ].firstWhere((m) => m.id == movieId);

          // Add to movie ratings instead of diary
          await _movieRatingService.addOrUpdateRating(
            userId: userId,
            movie: movie,
            rating: _movieRatings[movieId] ?? 3.0,
          );
          successCount++;
        } catch (e) {
          print('Error adding movie $movieId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isAddingMovies = false;
          _selectedMovieIds.clear();
          _movieRatings.clear();
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully added $successCount movies to your watched list!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAddingMovies = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding movies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRatingStars(String movieId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _movieRatings[movieId] = (index + 1).toDouble();
            });
          },
          child: Icon(
            index < (_movieRatings[movieId] ?? 0)
                ? Icons.star
                : Icons.star_border,
            color: Colors.amber,
            size: 20,
          ),
        );
      }),
    );
  }

  Widget _buildMovieGrid(List<Movie> movies, String title) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.6,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            final isSelected = _selectedMovieIds.contains(movie.id);
            final isAlreadyWatched = _alreadyWatchedIds.contains(movie.id);

            return GestureDetector(
              onTap: () {
                if (!isAlreadyWatched) {
                  setState(() {
                    if (isSelected) {
                      _selectedMovieIds.remove(movie.id);
                      _movieRatings.remove(movie.id);
                    } else {
                      _selectedMovieIds.add(movie.id);
                      _movieRatings[movie.id] = 3.0; // Default rating
                    }
                  });
                }
              },
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsScreen(movie: movie),
                  ),
                );
              },
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      movie.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.movie, color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (isAlreadyWatched)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(child: _buildRatingStars(movie.id)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuggestionsList() {
    if (!_showSuggestions || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading:
                suggestion['poster_path'] != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        '${TMDBService.imageBaseUrl}${suggestion['poster_path']}',
                        width: 40,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 60,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white54,
                            ),
                          );
                        },
                      ),
                    )
                    : Container(
                      width: 40,
                      height: 60,
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.white54),
                    ),
            title: Text(suggestion['title'] ?? ''),
            subtitle:
                suggestion['release_date'] != null
                    ? Text(suggestion['release_date'].toString().split('-')[0])
                    : null,
            onTap: () {
              _searchController.text = suggestion['title'];
              _onSearchChanged(suggestion['title']);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add Movies'),
        actions: [
          if (_selectedMovieIds.isNotEmpty)
            _isAddingMovies
                ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
                : TextButton(
                  onPressed: _addSelectedMovies,
                  child: Text(
                    'Add ${_selectedMovieIds.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          _buildSuggestionsList(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isSearching)
                            _buildMovieGrid(_searchResults, '')
                          else ...[
                            _buildMovieGrid(_trendingMovies, 'Trending Now'),
                            _buildMovieGrid(_popularMovies, 'Popular Movies'),
                            _buildMovieGrid(_topRatedMovies, 'Top Rated'),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
