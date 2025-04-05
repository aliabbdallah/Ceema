// screens/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/watchlist_service.dart';
import '../services/diary_service.dart';
import '../widgets/star_rating.dart';
import 'diary_entry_form.dart';
import 'package:flutter/rendering.dart';
import 'actor_details_screen.dart';

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
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WatchlistService _watchlistService = WatchlistService();
  final DiaryService _diaryService = DiaryService();
  late ConfettiController _confettiController;
  late ScrollController _scrollController;
  late AnimationController _ratingAnimationController;
  late TabController _tabController;
  List<YoutubePlayerController> _videoControllers = [];
  bool _isOverviewExpanded = false;
  bool _isCrewExpanded = false;

  bool _isLoading = true;
  bool _isInWatchlist = false;
  double _userRating = 0.0;
  bool _hasRated = false;
  Map<String, dynamic>? _movieDetails;
  List<Map<String, dynamic>> _similarMovies = [];
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _crew = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _activityFeed = [];

  @override
  void initState() {
    super.initState();
    _ratingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _scrollController = ScrollController();
    _loadMovieDetails();
    _checkWatchlistStatus();
    _checkUserRating();
    _loadActivityFeed();
  }

  @override
  void dispose() {
    _ratingAnimationController.dispose();
    _tabController.dispose();
    _confettiController.dispose();
    _scrollController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFullscreenChange(bool isFullscreen) async {
    if (isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
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
      final tmdbService = TMDBService();
      final details = await TMDBService.getMovieDetailsRaw(widget.movie.id);
      final similar = await TMDBService.getSimilarMovies(widget.movie.id);
      final cast = await TMDBService.getCast(widget.movie.id);
      final crew = await TMDBService.getCrew(widget.movie.id);
      final videos = await TMDBService.getVideos(widget.movie.id);

      // Initialize video controllers
      _videoControllers = videos.map((video) {
        final controller = YoutubePlayerController(
          initialVideoId: video['key'],
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: false,
            loop: false,
            isLive: false,
            forceHD: false,
            enableCaption: true,
            hideControls: false,
            controlsVisibleAtStart: true,
            useHybridComposition: true,
          ),
        );

        // Add listener for fullscreen changes
        controller.addListener(() {
          if (controller.value.isFullScreen) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
        });

        return controller;
      }).toList();

      if (mounted) {
        setState(() {
          _movieDetails = details;
          _similarMovies = similar;
          _cast = cast;
          _crew = crew;
          _videos = videos;
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

  Future<void> _loadActivityFeed() async {
    try {
      final querySnapshot = await _firestore
          .collection('diary_entries')
          .where('movieId', isEqualTo: widget.movie.id)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> activities = [];

      for (var doc in querySnapshot.docs) {
        final userDoc = await _firestore
            .collection('users')
            .doc(doc.data()['userId'])
            .get();

        if (userDoc.exists) {
          activities.add({
            'user': userDoc.data(),
            'activity': doc.data(),
            'timestamp': doc.data()['timestamp'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _activityFeed = activities;
        });
      }
    } catch (e) {
      print('Error loading activity feed: $e');
    }
  }

  Widget _buildActivityFeed() {
    if (_activityFeed.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _activityFeed.length,
          itemBuilder: (context, index) {
            final activity = _activityFeed[index];
            final user = activity['user'];
            final activityData = activity['activity'];
            final timestamp = activity['timestamp']?.toDate();

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user['photoURL'] != null
                    ? NetworkImage(user['photoURL'])
                    : null,
                child: user['photoURL'] == null
                    ? Text(user['displayName'][0].toUpperCase())
                    : null,
              ),
              title: Text(user['displayName'] ?? 'Anonymous'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getActivityText(activityData),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (timestamp != null)
                    Text(
                      _formatTimestamp(timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              ),
              trailing: activityData['rating'] != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(activityData['rating'].toString()),
                      ],
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }

  String _getActivityText(Map<String, dynamic> activity) {
    if (activity['rating'] != null) {
      return 'rated this movie ${activity['rating']}/5';
    } else if (activity['review'] != null && activity['review'].isNotEmpty) {
      return 'reviewed this movie';
    } else {
      return 'watched this movie';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_movieDetails?['backdrop_path'] != null)
              Image.network(
                'https://image.tmdb.org/t/p/w1280${_movieDetails!['backdrop_path']}',
                fit: BoxFit.cover,
              ),
            Container(
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
          ],
        ),
      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final textSpan = TextSpan(
                text: widget.movie.overview,
                style: Theme.of(context).textTheme.bodyMedium,
              );
              final textPainter = TextPainter(
                text: textSpan,
                maxLines: 3,
                textDirection: TextDirection.ltr,
              );
              textPainter.layout(maxWidth: constraints.maxWidth);
              final isTextLong = textPainter.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.movie.overview,
                    maxLines: _isOverviewExpanded ? null : 3,
                    overflow:
                        _isOverviewExpanded ? null : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isTextLong)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isOverviewExpanded = !_isOverviewExpanded;
                        });
                      },
                      child:
                          Text(_isOverviewExpanded ? 'Show less' : 'Read more'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            child: Stack(
              children: [
                StarRating(
                  rating: _userRating,
                  size: 36,
                  allowHalfRating: true,
                  spacing: 8,
                  onRatingChanged: (rating) {
                    _saveRating(rating);
                    _ratingAnimationController.forward(from: 0.0);
                    _confettiController.play();
                  },
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: math.pi / 2,
                    maxBlastForce: 5,
                    minBlastForce: 2,
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    gravity: 0.1,
                  ),
                ),
              ],
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

  Widget _buildCastSection() {
    if (_cast.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Cast',
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
            itemCount: _cast.length,
            itemBuilder: (context, index) {
              final person = _cast[index];
              final heroTag = 'actor_${person['id']}_${person['profile_path']}';
              
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActorDetailsScreen(actor: person),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Hero(
                        tag: heroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://image.tmdb.org/t/p/w185${person['profile_path']}',
                            height: 150,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.person),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        person['character'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
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

  Widget _buildCrewSection() {
    if (_crew.isEmpty) return const SizedBox();

    final crewByDepartment = <String, List<Map<String, dynamic>>>{};
    for (var person in _crew) {
      final department = person['department'] ?? 'Other';
      crewByDepartment.putIfAbsent(department, () => []);
      crewByDepartment[department]!.add(person);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: crewByDepartment.length,
      itemBuilder: (context, index) {
        final department = crewByDepartment.keys.elementAt(index);
        final crewMembers = crewByDepartment[department]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                department,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...crewMembers.map((person) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: person['profile_path'] != null
                          ? NetworkImage(
                              'https://image.tmdb.org/t/p/w185${person['profile_path']}',
                            )
                          : null,
                      child: person['profile_path'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            person['job'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildTrailersSection() {
    if (_videos.isEmpty) return const SizedBox();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final controller = _videoControllers[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
              onReady: () {
                print('Video ${video['key']} is ready to play');
              },
              onEnded: (metaData) {
                controller.seekTo(const Duration(seconds: 0));
                controller.pause();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimilarMovies() {
    if (_similarMovies.isEmpty) return const SizedBox();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _similarMovies.length,
      itemBuilder: (context, index) {
        final movie = Movie.fromJson(_similarMovies[index]);
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsScreen(movie: movie),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    movie.posterUrl,
                    height: 120,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMovieInfo(),
                _buildRatingSection(),
                _buildOverview(),
                _buildActivityFeed(),
                _buildCastSection(),
                // TabBar
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Crew'),
                      Tab(text: 'Trailers'),
                      Tab(text: 'Similar'),
                    ],
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    labelStyle: const TextStyle(fontSize: 15),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                // TabBarView
                SizedBox(
                  height: 400, // Adjust height as needed
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCrewSection(),
                      _buildTrailersSection(),
                      _buildSimilarMovies(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryEntryForm(
                movie: widget.movie,
                existingEntry: _hasRated ? null : null,
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
