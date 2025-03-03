// screens/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/watchlist_service.dart';
import '../services/diary_service.dart';
import '../widgets/star_rating.dart';
import 'diary_entry_form.dart';
// import '../widgets/loading_indicator.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({
    Key? key,
    required this.movie,
  }) : super(key: key);

  @override
  _MovieDetailsScreenState createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WatchlistService _watchlistService = WatchlistService();
  final DiaryService _diaryService = DiaryService();

  bool _isLoading = true;
  bool _isInWatchlist = false;
  double _userRating = 0.0;
  bool _hasRated = false;
  Map<String, dynamic>? _movieDetails;
  List<Map<String, dynamic>> _similarMovies = [];
  late AnimationController _ratingAnimationController;

  @override
  void initState() {
    super.initState();
    _ratingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadMovieDetails();
    _checkWatchlistStatus();
    _checkUserRating();
  }

  @override
  void dispose() {
    _ratingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRating() async {
    try {
      // Check if user has already rated this movie in their diary
      final querySnapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('movieId', isEqualTo: widget.movie.id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        if (mounted) {
          setState(() {
            _userRating = (data['rating'] ?? 0).toDouble();
            _hasRated = _userRating > 0;
          });
        }
      }
    } catch (e) {
      print('Error checking user rating: $e');
    }
  }

  Future<void> _saveRating(double rating) async {
    setState(() {
      _userRating = rating;
      _hasRated = true;
    });

    try {
      // Check if user already has a diary entry for this movie
      final querySnapshot = await _firestore
          .collection('diary_entries')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('movieId', isEqualTo: widget.movie.id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing entry
        await _diaryService.updateDiaryEntry(
          querySnapshot.docs.first.id,
          rating: rating,
        );
      } else {
        // Create a new diary entry with just the rating
        await _diaryService.addDiaryEntry(
          userId: _auth.currentUser!.uid,
          movie: widget.movie,
          rating: rating,
          review: '',
          watchedDate: DateTime.now(),
          isFavorite: false,
          isRewatch: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rating saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMovieDetails() async {
    try {
      final details = await TMDBService.getMovieDetails(widget.movie.id);
      final similar = await TMDBService.getSimilarMovies(widget.movie.id);

      if (mounted) {
        setState(() {
          _movieDetails = details;
          _similarMovies = similar;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading movie details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      final doc = await _firestore
          .collection('watchlists')
          .doc(_auth.currentUser!.uid)
          .get();

      if (mounted && doc.exists) {
        final List<dynamic> watchlist = doc.data()?['movies'] ?? [];
        setState(() {
          _isInWatchlist = watchlist.any((m) => m['id'] == widget.movie.id);
        });
      }
    } catch (e) {
      print('Error checking watchlist status: $e');
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      if (_isInWatchlist) {
        // Get the watchlist item ID first
        final querySnapshot = await _firestore
            .collection('watchlist_items')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('movie.id', isEqualTo: widget.movie.id)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await _watchlistService.removeFromWatchlist(
            querySnapshot.docs.first.id,
            _auth.currentUser!.uid,
          );
        }
      } else {
        await _watchlistService.addToWatchlist(
          userId: _auth.currentUser!.uid,
          movie: widget.movie,
        );
      }

      setState(() {
        _isInWatchlist = !_isInWatchlist;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isInWatchlist ? 'Added to watchlist' : 'Removed from watchlist',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating watchlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Rating',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_hasRated)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryEntryForm(
                          movie: widget.movie,
                        ),
                      ),
                    );
                  },
                  child: const Text('Add Review'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: StarRating(
              rating: _userRating,
              size: 36,
              allowHalfRating: true,
              spacing: 8,
              onRatingChanged: (rating) {
                _saveRating(rating);
                _ratingAnimationController.forward(from: 0.0);
              },
            ),
          ),
          if (_hasRated) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                _userRating == 5
                    ? 'Masterpiece!'
                    : _userRating >= 4
                        ? 'Loved it!'
                        : _userRating >= 3
                            ? 'Liked it'
                            : _userRating >= 2
                                ? 'It was OK'
                                : 'Not for me',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _userRating >= 4
                      ? Colors.green
                      : _userRating >= 3
                          ? Colors.blue
                          : _userRating >= 2
                              ? Colors.orange
                              : Colors.red[700],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Backdrop image
        if (_movieDetails?['backdrop_path'] != null)
          Image.network(
            'https://image.tmdb.org/t/p/w1280${_movieDetails!['backdrop_path']}',
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        // Gradient overlay
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        // Back button
        Positioned(
          top: 40,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieInfo() {
    final releaseDate = _movieDetails?['release_date'] ?? '';
    final year = releaseDate.isNotEmpty ? releaseDate.substring(0, 4) : '';
    final runtime = _movieDetails?['runtime'] ?? 0;
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              widget.movie.posterUrl,
              width: 120,
              height: 180,
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
                  widget.movie.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (year.isNotEmpty) ...[
                  Text(
                    '$year • ${hours}h ${minutes}m',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_movieDetails?['vote_average'] ?? 0).toStringAsFixed(1)}/10',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleWatchlist,
                      icon: Icon(
                        _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(
                        _isInWatchlist ? 'In Watchlist' : 'Add to Watchlist',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {
                        // TODO: Implement share functionality
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.movie.overview,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarMovies() {
    if (_similarMovies.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Similar Movies',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _similarMovies.length,
            itemBuilder: (context, index) {
              final movie = Movie.fromJson(_similarMovies[index]);
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          movie.posterUrl,
                          height: 150,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildMovieInfo(),
            _buildRatingSection(),
            _buildOverview(),
            _buildSimilarMovies(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryEntryForm(
                movie: widget.movie,
                existingEntry: _hasRated
                    ? null
                    : null, // TODO: Get existing entry if available
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
        tooltip: 'Add to diary',
      ),
    );
  }
}
