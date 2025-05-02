import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../services/watchlist_service.dart';
import '../services/diary_service.dart';
import 'movie_details_screen.dart';
import 'full_filmography_screen.dart';

class ActorDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> actor;

  const ActorDetailsScreen({Key? key, required this.actor}) : super(key: key);

  @override
  _ActorDetailsScreenState createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WatchlistService _watchlistService = WatchlistService();
  final DiaryService _diaryService = DiaryService();
  bool _isLoading = true;
  bool _isBiographyExpanded = false;
  Map<String, dynamic>? _actorDetails;
  List<Map<String, dynamic>> _credits = [];
  Set<String> _userWatchlist = {};
  Set<String> _userDiary = {};
  static const int _initialGridSize = 8; // 4x2 grid

  void _sortCredits() {
    setState(() {
      _credits.sort((a, b) {
        final countA = (a['vote_count'] ?? 0).toInt();
        final countB = (b['vote_count'] ?? 0).toInt();
        return countB.compareTo(countA);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadActorDetails();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final watchlistDoc =
          await _firestore.collection('watchlists').doc(userId).get();
      if (watchlistDoc.exists) {
        final watchlist = watchlistDoc.data()?['movies'] ?? [];
        _userWatchlist = Set<String>.from(
          watchlist.map((m) => m['id'].toString()),
        );
      }

      final diaryQuery =
          await _firestore
              .collection('diary_entries')
              .where('userId', isEqualTo: userId)
              .get();
      _userDiary = Set<String>.from(
        diaryQuery.docs.map((doc) => doc.data()['movieId'].toString()),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadActorDetails() async {
    try {
      final actorId = widget.actor['id'].toString();
      final details = await TMDBService.getPersonDetails(actorId);
      final credits = await TMDBService.getPersonCredits(actorId);

      if (mounted) {
        setState(() {
          _actorDetails = details;
          _credits = List<Map<String, dynamic>>.from(credits['cast'] ?? []);
          _sortCredits();
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
            content: Text('Error loading actor details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int? _calculateAge(String birthday) {
    try {
      final birthDate = DateTime.parse(birthday);
      final now = DateTime.now();
      var age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day} ${_getMonthName(parsedDate.month)} ${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildHeader() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.actor['name'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildProfileSection() {
    final heroTag =
        'actor_${widget.actor['id']}_${widget.actor['profile_path']}';
    final birthday = _actorDetails?['birthday'];
    final age = birthday != null ? _calculateAge(birthday) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image
          Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://image.tmdb.org/t/p/w500${_actorDetails?['profile_path']}',
                width: 120,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Biography
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (birthday != null) ...[
                  Text(
                    '${_formatDate(birthday)}${age != null ? ' (${age} years old)' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_actorDetails?['place_of_birth'] != null) ...[
                  Text(
                    'Born in ${_actorDetails!['place_of_birth']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_actorDetails?['biography'] != null) ...[
                  Text(
                    'Biography',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _actorDetails!['biography'],
                    maxLines: _isBiographyExpanded ? null : 4,
                    overflow:
                        _isBiographyExpanded ? null : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isBiographyExpanded = !_isBiographyExpanded;
                      });
                    },
                    child: Text(
                      _isBiographyExpanded ? 'Show less' : 'Read more',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBar() {
    final totalFilms = _credits.length;
    final watchlistCount =
        _credits
            .where((credit) => _userWatchlist.contains(credit['id'].toString()))
            .length;
    final watchlistPercentage =
        totalFilms > 0 ? (watchlistCount / totalFilms * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                'ACTOR IN',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$totalFilms FILMS',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'WATCHLIST',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$watchlistPercentage%',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilmographyGrid() {
    if (_credits.isEmpty) return const SizedBox();

    final displayedCredits = _credits.take(_initialGridSize).toList();

    return Container(
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Filmography',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.667,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayedCredits.length,
            itemBuilder: (context, index) {
              final credit = displayedCredits[index];
              final movie = Movie.fromJson(credit);
              final movieId = movie.id;
              final isInWatchlist = _userWatchlist.contains(movieId);
              final isInDiary = _userDiary.contains(movieId);

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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          movie.posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.movie,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isInWatchlist || isInDiary)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              isInDiary ? Icons.check : Icons.bookmark,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_credits.length > _initialGridSize)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              child: ListTile(
                title: Text(
                  'All films as Actor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FullFilmographyScreen(
                            credits: _credits,
                            actorName: widget.actor['name'],
                            userWatchlist: _userWatchlist,
                            userDiary: _userDiary,
                          ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.actor['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.black87,
            elevation: 4,
            pinned: true,
            expandedHeight: 0,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileSection(),
                _buildStatisticsBar(),
                _buildFilmographyGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
