import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../services/movie_rating_service.dart';
import '../services/diary_service.dart';
import 'movie_details_screen.dart';

class WatchedMoviesScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const WatchedMoviesScreen({
    Key? key,
    required this.userId,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  _WatchedMoviesScreenState createState() => _WatchedMoviesScreenState();
}

class _WatchedMoviesScreenState extends State<WatchedMoviesScreen> {
  final MovieRatingService _movieRatingService = MovieRatingService();
  final DiaryService _diaryService = DiaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _watchedMovies = [];
  bool _isLoading = true;
  String? _selectedYear;
  String _sortBy = 'watchedAt';
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _loadWatchedMovies();
  }

  Future<void> _loadWatchedMovies() async {
    try {
      // Get movies from diary entries
      final diaryEntries =
          await _firestore
              .collection('diary_entries')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('watchedDate', descending: true)
              .get();

      // Get movies from direct ratings
      final directRatings =
          await _firestore
              .collection('movie_ratings')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('updatedAt', descending: true)
              .get();

      final Set<String> processedMovieIds = {};
      final List<Map<String, dynamic>> allMovies = [];

      // Process diary entries
      for (var doc in diaryEntries.docs) {
        final data = doc.data();
        final movieId = data['movieId'];
        if (!processedMovieIds.contains(movieId)) {
          processedMovieIds.add(movieId);
          allMovies.add({
            'movie': Movie(
              id: movieId,
              title: data['movieTitle'],
              posterUrl: data['moviePosterUrl'],
              year: data['movieYear'],
              overview: data['movieOverview'] ?? '',
            ),
            'rating': data['rating'],
            'watchedAt': data['watchedDate'],
            'source': 'diary',
          });
        }
      }

      // Process direct ratings
      for (var doc in directRatings.docs) {
        final data = doc.data();
        final movieId = data['movieId'];
        if (!processedMovieIds.contains(movieId)) {
          processedMovieIds.add(movieId);
          allMovies.add({
            'movie': Movie(
              id: movieId,
              title: data['movieTitle'],
              posterUrl: data['moviePosterUrl'],
              year: data['movieYear'],
              overview: '',
            ),
            'rating': data['rating'],
            'watchedAt': data['updatedAt'],
            'source': 'rating',
          });
        }
      }

      // Sort movies
      allMovies.sort((a, b) {
        if (_sortBy == 'title') {
          return a['movie'].title.compareTo(b['movie'].title);
        } else if (_sortBy == 'year') {
          return a['movie'].year.compareTo(b['movie'].year);
        } else if (_sortBy == 'rating') {
          final ratingA = (a['rating'] as num).toDouble();
          final ratingB = (b['rating'] as num).toDouble();
          return ratingB.compareTo(ratingA);
        } else {
          return (b['watchedAt'] as Timestamp).compareTo(
            a['watchedAt'] as Timestamp,
          );
        }
      });

      if (mounted) {
        setState(() {
          _watchedMovies = allMovies;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading watched movies: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(rating.ceil(), (index) {
        if (index < rating.floor()) {
          return Icon(
            Icons.star,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          );
        } else if (index == rating.floor() && rating % 1 >= 0.5) {
          return Icon(
            Icons.star_half,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          );
        } else {
          return Icon(
            Icons.star_outlined,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          );
        }
      }),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movieData) {
    final movie = movieData['movie'] as Movie;
    final rating = (movieData['rating'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      onLongPress: () => _showMovieOptions(movie),
      child: Column(
        children: [
          // Poster
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
            ),
          ),

          // Rating and Actions
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(children: [_buildRatingStars(rating)]),
          ),
        ],
      ),
    );
  }

  void _showMovieOptions(Movie movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'View Details',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailsScreen(movie: movie),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'Edit Rating',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement edit rating functionality
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'Remove from Watched',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement remove functionality
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            title: Text(
              'Sort by',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  title: Text(
                    'Recently Watched',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  value: 'watchedAt',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value.toString();
                      _sortDescending = true;
                    });
                    Navigator.pop(context);
                    _loadWatchedMovies();
                  },
                ),
                RadioListTile(
                  title: Text(
                    'Title',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  value: 'title',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value.toString();
                      _sortDescending = false;
                    });
                    Navigator.pop(context);
                    _loadWatchedMovies();
                  },
                ),
                RadioListTile(
                  title: Text(
                    'Year',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  value: 'year',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value.toString();
                      _sortDescending = true;
                    });
                    Navigator.pop(context);
                    _loadWatchedMovies();
                  },
                ),
                RadioListTile(
                  title: Text(
                    'Rating',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  value: 'rating',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value.toString();
                      _sortDescending = true;
                    });
                    Navigator.pop(context);
                    _loadWatchedMovies();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          widget.isCurrentUser ? 'My Watched Movies' : 'Watched Movies',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_by_alpha),
            onPressed: _showSortDialog,
            tooltip: 'Sort',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _watchedMovies.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No watched movies yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isCurrentUser
                          ? 'Start rating movies to see them here'
                          : 'This user hasn\'t watched any movies yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
              : LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 24,
                        ),
                    itemCount: _watchedMovies.length,
                    itemBuilder: (context, index) {
                      return _buildMovieCard(_watchedMovies[index]);
                    },
                  );
                },
              ),
    );
  }
}
