import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/podium_movie.dart';
import '../models/movie.dart';
import '../services/podium_service.dart';
import '../services/tmdb_service.dart';
import '../widgets/podium_widget.dart';
import '../services/diary_service.dart';

class PodiumEditScreen extends StatefulWidget {
  const PodiumEditScreen({Key? key}) : super(key: key);

  @override
  _PodiumEditScreenState createState() => _PodiumEditScreenState();
}

class _PodiumEditScreenState extends State<PodiumEditScreen> {
  final _podiumService = PodiumService();
  final _tmdbService = TMDBService();
  final _diaryService = DiaryService();
  final _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();
  List<Movie> _searchResults = [];
  List<Movie> _recentMovies = [];
  bool _isSearching = false;
  bool _isLoadingRecent = false;
  int? _selectedRank;
  int? _draggedRank;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _loadRecentMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentMovies() async {
    setState(() {
      _isLoadingRecent = true;
    });

    try {
      final entries =
          await _diaryService.getDiaryEntries(_auth.currentUser!.uid).first;
      final sortedEntries =
          entries..sort((a, b) => b.watchedDate.compareTo(a.watchedDate));

      final recentMovies =
          sortedEntries
              .take(10)
              .map(
                (entry) => Movie(
                  id: entry.movieId,
                  title: entry.movieTitle,
                  posterUrl: entry.moviePosterUrl,
                  year: entry.movieYear,
                  overview:
                      '', // Required by Movie model but not needed for podium
                ),
              )
              .toList();

      setState(() {
        _recentMovies = recentMovies;
        _isLoadingRecent = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRecent = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recent movies: $e')),
        );
      }
    }
  }

  Future<void> _searchMovies(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _tmdbService.searchMovies(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching movies: $e')));
      }
    }
  }

  Future<void> _addMovieToPodium(Movie movie, int rank) async {
    try {
      final podiumMovie = PodiumMovie(
        tmdbId: movie.id,
        title: movie.title,
        posterUrl: movie.posterUrl,
        rank: rank,
      );

      // Check if there's already a movie in this rank
      final existingMovies =
          await _podiumService.getPodiumMovies(_auth.currentUser!.uid).first;
      final existingMovie = existingMovies.firstWhere(
        (m) => m.rank == rank,
        orElse: () => podiumMovie,
      );

      // If there's an existing movie, show confirmation dialog
      if (existingMovie.rank == rank && existingMovie.tmdbId != movie.id) {
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Replace Movie?'),
                content: Text(
                  'Do you want to replace "${existingMovie.title}" with "${movie.title}" in position $rank?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Replace'),
                  ),
                ],
              ),
        );

        if (shouldReplace != true) {
          return;
        }
      }

      await _podiumService.updatePodiumMovie(podiumMovie);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingMovie.rank == rank
                  ? 'Movie replaced!'
                  : 'Movie added to podium!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedRank = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding movie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCommentDialog(PodiumMovie movie) async {
    final commentController = TextEditingController(text: movie.comment);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add a comment for ${movie.title}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    hintText: 'Why is this movie special to you?',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${commentController.text.length}/150',
                  style: TextStyle(
                    color:
                        commentController.text.length > 150
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _podiumService.updatePodiumMovie(
                      movie.copyWith(comment: commentController.text.trim()),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comment added!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating comment: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _handleDragStart(int rank) {
    setState(() {
      _draggedRank = rank;
    });
  }

  void _handleDragEnd() {
    setState(() {
      _draggedRank = null;
    });
  }

  void _handleDragAccept(int targetRank) async {
    if (_draggedRank == null) return;

    try {
      await _podiumService.swapPodiumRanks(_draggedRank!, targetRank);
      setState(() {
        _draggedRank = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error swapping ranks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRankSelector(List<PodiumMovie> podiumMovies) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text(
            'Select a Position',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRankButton(
                context,
                'Gold',
                1,
                Colors.amber,
                podiumMovies.any((m) => m.rank == 1),
              ),
              _buildRankButton(
                context,
                'Silver',
                2,
                Colors.grey[400]!,
                podiumMovies.any((m) => m.rank == 2),
              ),
              _buildRankButton(
                context,
                'Bronze',
                3,
                Colors.brown[300]!,
                podiumMovies.any((m) => m.rank == 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankButton(
    BuildContext context,
    String label,
    int rank,
    Color color,
    bool isOccupied,
  ) {
    final isSelected = _selectedRank == rank;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRank = rank;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isOccupied)
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            movie.posterUrl,
            width: 50,
            height: 75,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 50,
                height: 75,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 50,
                height: 75,
                color: Colors.grey[200],
                child: const Icon(Icons.movie),
              );
            },
          ),
        ),
        title: Text(movie.title),
        subtitle: Text(movie.year),
        trailing:
            _selectedRank != null
                ? IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addMovieToPodium(movie, _selectedRank!),
                )
                : null,
        onTap:
            _selectedRank != null
                ? () => _addMovieToPodium(movie, _selectedRank!)
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final podiumMovies = await _podiumService.getPodiumMovies(userId).first;
        final hasAllMovies = podiumMovies.length == 3;

        if (!hasAllMovies) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Incomplete Podium'),
                  content: const Text(
                    'You haven\'t selected all three movies yet. Are you sure you want to exit?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Exit'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay'),
                    ),
                  ],
                ),
          );
          return shouldExit ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Podium'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _selectedRank = null;
                });
              },
            ),
          ],
        ),
        body: StreamBuilder<List<PodiumMovie>>(
          stream: _podiumService.getPodiumMovies(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final podiumMovies = snapshot.data!;
            final hasAllMovies = podiumMovies.length == 3;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Current podium
                  PodiumWidget(
                    movies: podiumMovies,
                    isEditable: true,
                    onRankTap: (rank) {
                      setState(() {
                        _selectedRank = rank;
                      });
                    },
                    onMovieTap: (movie) => _showCommentDialog(movie),
                    onRankSwap: (fromRank, toRank) => _handleDragAccept(toRank),
                  ),
                  const Divider(),
                  // Rank selector
                  _buildRankSelector(podiumMovies),
                  const Divider(),
                  // Search section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRank != null
                              ? 'Select a movie for rank $_selectedRank'
                              : 'Select a rank first',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a movie...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchMovies('');
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: _searchMovies,
                        ),
                      ],
                    ),
                  ),
                  // Content section
                  SizedBox(
                    height: 400, // Fixed height for the list
                    child:
                        _isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : _searchController.text.isEmpty
                            ? _isLoadingRecent
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _recentMovies.isEmpty
                                ? const Center(
                                  child: Text('No recent movies found'),
                                )
                                : ListView.builder(
                                  itemCount: _recentMovies.length,
                                  itemBuilder:
                                      (context, index) =>
                                          _buildMovieCard(_recentMovies[index]),
                                )
                            : _searchResults.isEmpty
                            ? const Center(child: Text('No movies found'))
                            : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder:
                                  (context, index) =>
                                      _buildMovieCard(_searchResults[index]),
                            ),
                  ),
                  // Save button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed:
                          hasAllMovies
                              ? () {
                                Navigator.pop(context);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor:
                            hasAllMovies ? Colors.green : Colors.grey,
                      ),
                      child: Text(
                        hasAllMovies
                            ? 'Save Podium'
                            : 'Select all 3 movies to save',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
