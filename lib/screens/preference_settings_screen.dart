// lib/screens/preference_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';

import '../models/user_preferences.dart';
import '../services/preference_service.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../widgets/loading_indicator.dart';
import '../screens/movie_details_screen.dart';

class PreferenceSettingsScreen extends StatefulWidget {
  const PreferenceSettingsScreen({Key? key}) : super(key: key);

  @override
  _PreferenceSettingsScreenState createState() =>
      _PreferenceSettingsScreenState();
}

class _PreferenceSettingsScreenState extends State<PreferenceSettingsScreen>
    with SingleTickerProviderStateMixin {
  final PreferenceService _preferenceService = PreferenceService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  UserPreferences? _preferences;
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  bool _showSuggestions = false;
  ScrollController _scrollController = ScrollController();

  // Genre mapping for easier access
  final Map<int, String> _genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };

  // For not interested movies
  List<Movie> _notInterestedMovies = [];
  bool _loadingNotInterestedMovies = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPreferences();
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.index == 2 &&
        _preferences != null &&
        _notInterestedMovies.isEmpty) {
      _loadNotInterestedMovies();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await _preferenceService.getUserPreferences();

      if (mounted) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error loading preferences: $e');
      }
    }
  }

  Future<void> _loadNotInterestedMovies() async {
    if (_preferences == null || _preferences!.dislikedMovieIds.isEmpty) {
      return;
    }

    setState(() {
      _loadingNotInterestedMovies = true;
    });

    try {
      final List<Movie> movies = [];

      for (String movieId in _preferences!.dislikedMovieIds) {
        try {
          final movieDetails = await TMDBService.getMovieDetails(movieId);
          movies.add(Movie.fromJson(movieDetails));
        } catch (e) {
          print('Error loading movie $movieId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _notInterestedMovies = movies;
          _loadingNotInterestedMovies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingNotInterestedMovies = false;
        });
        print('Error loading not interested movies: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _searchContent(String query) async {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
        _showSuggestions = true;
      });

      try {
        // Search for movies
        final results = await TMDBService.searchMovies(query);

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          _showErrorSnackBar('Search failed: $e');
        }
      }
    });
  }

  void _addGenrePreference(Map<String, dynamic> item) async {
    try {
      List<dynamic> genres = item['genre_ids'] ?? [];

      if (genres.isEmpty && item.containsKey('genres')) {
        genres = (item['genres'] as List).map((g) => g['id']).toList();
      }

      if (genres.isEmpty) {
        // If we still don't have genres, fetch the movie details
        final movieId = item['id'].toString();
        final details = await TMDBService.getMovieDetails(movieId);

        if (details.containsKey('genres')) {
          genres = (details['genres'] as List).map((g) => g['id']).toList();
        }
      }

      if (genres.isNotEmpty) {
        // Get genre names from IDs
        for (var genreId in genres) {
          final genreName = _genreMap[genreId] ?? 'Genre $genreId';
          await _preferenceService.addPreference(
            id: genreId.toString(),
            name: genreName,
            type: 'genre',
          );
        }

        await _loadPreferences();

        if (mounted) {
          _showSuccessSnackBar('Genre preferences added');
        }
      } else {
        _showErrorSnackBar('No genres found for this movie');
      }
    } catch (e) {
      _showErrorSnackBar('Error adding genre preference: $e');
    }
  }

  void _addActorPreference(Map<String, dynamic> item) async {
    try {
      // Fetch movie details to get cast
      final movieId = item['id'].toString();
      final details = await TMDBService.getMovieDetails(movieId);

      if (details.containsKey('credits') &&
          details['credits'].containsKey('cast') &&
          (details['credits']['cast'] as List).isNotEmpty) {
        final cast = details['credits']['cast'] as List;

        // Take first 5 main actors
        for (var i = 0; i < min(5, cast.length); i++) {
          final actor = cast[i];
          await _preferenceService.addPreference(
            id: actor['id'].toString(),
            name: actor['name'],
            type: 'actor',
            weight: _calculateActorWeight(actor),
          );
        }

        await _loadPreferences();
        _showSuccessSnackBar('Actor preferences added');
      } else {
        // Try getting credits directly if not included in movie details
        try {
          final creditsData = await TMDBService.getMovieCredits(movieId);

          if (creditsData.containsKey('cast') &&
              (creditsData['cast'] as List).isNotEmpty) {
            final cast = creditsData['cast'] as List;

            for (var i = 0; i < min(5, cast.length); i++) {
              final actor = cast[i];
              await _preferenceService.addPreference(
                id: actor['id'].toString(),
                name: actor['name'],
                type: 'actor',
                weight: _calculateActorWeight(actor),
              );
            }

            await _loadPreferences();
            _showSuccessSnackBar('Actor preferences added');
          } else {
            _showErrorSnackBar('No cast information available for this movie');
          }
        } catch (e) {
          _showErrorSnackBar('Could not retrieve cast information: $e');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error adding actor preference: $e');
    }
  }

  void _addDirectorPreference(Map<String, dynamic> item) async {
    try {
      // Fetch movie details to get crew
      final movieId = item['id'].toString();
      final details = await TMDBService.getMovieDetails(movieId);

      if (details.containsKey('credits') &&
          details['credits'].containsKey('crew')) {
        final directors = (details['credits']['crew'] as List)
            .where((crew) => crew['job'] == 'Director')
            .toList();

        if (directors.isNotEmpty) {
          for (var director in directors) {
            await _preferenceService.addPreference(
              id: director['id'].toString(),
              name: director['name'],
              type: 'director',
              weight: _calculateDirectorWeight(director),
            );
          }

          await _loadPreferences();

          if (mounted) {
            _showSuccessSnackBar('Director preferences added');
          }
        } else {
          _showErrorSnackBar('No directors found for this movie');
        }
      } else {
        _showErrorSnackBar('Crew information not available');
      }
    } catch (e) {
      _showErrorSnackBar('Error adding director preference: $e');
    }
  }

  void _addToDislikedPreference(Map<String, dynamic> item, String type) async {
    try {
      final movieId = item['id'].toString();
      final details = await TMDBService.getMovieDetails(movieId);

      switch (type) {
        case 'actor':
          if (details.containsKey('credits') &&
              details['credits'].containsKey('cast')) {
            final cast = details['credits']['cast'] as List;
            if (cast.isNotEmpty) {
              // Take first 5 main actors
              for (var i = 0; i < min(5, cast.length); i++) {
                final actor = cast[i];
                await _preferenceService.addDislikePreference(
                  id: actor['id'].toString(),
                  name: actor['name'],
                  type: 'actor',
                  weight: _calculateActorWeight(actor),
                );
              }
              await _loadPreferences();
              _showSuccessSnackBar('Actor dislikes added');
            } else {
              _showErrorSnackBar('No actors found for this movie');
            }
          } else {
            _showErrorSnackBar('Cast information not available');
          }
          break;

        case 'director':
          if (details.containsKey('credits') &&
              details['credits'].containsKey('crew')) {
            final directors = (details['credits']['crew'] as List)
                .where((crew) => crew['job'] == 'Director')
                .toList();

            if (directors.isNotEmpty) {
              for (var director in directors) {
                await _preferenceService.addDislikePreference(
                  id: director['id'].toString(),
                  name: director['name'],
                  type: 'director',
                  weight: _calculateDirectorWeight(director),
                );
              }
              await _loadPreferences();
              _showSuccessSnackBar('Director dislikes added');
            } else {
              _showErrorSnackBar('No directors found for this movie');
            }
          } else {
            _showErrorSnackBar('Crew information not available');
          }
          break;

        case 'genre':
          List<dynamic> genres = item['genre_ids'] ?? [];

          if (genres.isEmpty && details.containsKey('genres')) {
            genres = (details['genres'] as List).map((g) => g['id']).toList();
          }

          if (genres.isNotEmpty) {
            // Get genre names from IDs
            for (var genreId in genres) {
              final genreName = _genreMap[genreId] ?? 'Genre $genreId';
              await _preferenceService.addDislikePreference(
                id: genreId.toString(),
                name: genreName,
                type: 'genre',
              );
            }

            await _loadPreferences();
            _showSuccessSnackBar('Genre dislikes added');
          } else {
            _showErrorSnackBar('No genres found for this movie');
          }
          break;

        default:
          _showErrorSnackBar('Unknown preference type: $type');
      }
    } catch (e) {
      _showErrorSnackBar('Error adding dislike preference: $e');
    }
  }

  // Helper method to calculate actor weight based on their role
  double _calculateActorWeight(Map<String, dynamic> actor) {
    // Consider actor's popularity and prominence in the movie
    final popularity = actor['popularity'] ?? 1.0;
    final order = actor['order'] ?? 0;

    // More prominent actors (lower order) get higher weight
    // Popularity also influences the weight
    return 1.0 + (10.0 / (order + 1)) * (popularity / 100.0);
  }

  // Helper method to calculate director weight
  double _calculateDirectorWeight(Map<String, dynamic> director) {
    // Consider director's reputation and popularity
    final popularity = director['popularity'] ?? 1.0;

    // Base weight with additional boost from popularity
    return 1.0 + (popularity / 100.0);
  }

  void _markAsNotInterested(Map<String, dynamic> item) async {
    try {
      final movieId = item['id'].toString();
      await _preferenceService.markMovieAsNotInterested(movieId);

      await _loadPreferences();

      if (mounted) {
        _showSuccessSnackBar('Movie marked as not interested');
      }
    } catch (e) {
      _showErrorSnackBar('Error marking movie as not interested: $e');
    }
  }

  void _removePreference(ContentPreference preference, bool isLike) async {
    try {
      await _preferenceService.removePreference(
        id: preference.id,
        type: preference.type,
        isLike: isLike,
      );

      await _loadPreferences();

      if (mounted) {
        _showSuccessSnackBar('${preference.name} removed from preferences');
      }
    } catch (e) {
      _showErrorSnackBar('Error removing preference: $e');
    }
  }

  void _updateImportanceFactor(String factor, double value) async {
    try {
      await _preferenceService.updateImportanceFactor(factor, value);
      await _loadPreferences();
    } catch (e) {
      _showErrorSnackBar('Error updating importance: $e');
    }
  }

  void _removeFromNotInterested(String movieId) async {
    try {
      await _preferenceService.removeMovieFromNotInterested(movieId);

      setState(() {
        _notInterestedMovies.removeWhere((movie) => movie.id == movieId);
        if (_preferences != null) {
          _preferences!.dislikedMovieIds.remove(movieId);
        }
      });

      await _loadPreferences();

      if (mounted) {
        _showSuccessSnackBar('Movie removed from Not Interested list');
      }
    } catch (e) {
      _showErrorSnackBar('Error removing movie: $e');
    }
  }

  // Helper function for min value
  int min(int a, int b) {
    return a < b ? a : b;
  }

  Widget _buildPreferenceTabView() {
    if (_preferences == null) {
      return const Center(child: Text('No preferences found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Likes section
        const Text(
          'I Like',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Genres I like
        _buildCategorySection(
          'Genres',
          _preferences!.likes.where((p) => p.type == 'genre').toList(),
          true,
          Icons.movie_filter,
          Colors.blue,
        ),

        // Directors I like
        _buildCategorySection(
          'Directors',
          _preferences!.likes.where((p) => p.type == 'director').toList(),
          true,
          Icons.video_camera_back,
          Colors.green,
        ),

        // Actors I like
        _buildCategorySection(
          'Actors',
          _preferences!.likes.where((p) => p.type == 'actor').toList(),
          true,
          Icons.person,
          Colors.purple,
        ),

        const Divider(height: 32),

        // Dislikes section
        const Text(
          "I Don't Like",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Genres I dislike
        _buildCategorySection(
          'Genres',
          _preferences!.dislikes.where((p) => p.type == 'genre').toList(),
          false,
          Icons.movie_filter,
          Colors.red.shade300,
        ),

        // Directors I dislike
        _buildCategorySection(
          'Directors',
          _preferences!.dislikes.where((p) => p.type == 'director').toList(),
          false,
          Icons.video_camera_back,
          Colors.red.shade300,
        ),

        // Actors I dislike
        _buildCategorySection(
          'Actors',
          _preferences!.dislikes.where((p) => p.type == 'actor').toList(),
          false,
          Icons.person,
          Colors.red.shade300,
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildCategorySection(
    String title,
    List<ContentPreference> items,
    bool isLike,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        items.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 16),
                child: Text(
                  'No $title added yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map((item) => _buildPreferenceChip(
                          item,
                          isLike,
                          color,
                        ))
                    .toList(),
              ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPreferenceChip(
    ContentPreference preference,
    bool isLike,
    Color color,
  ) {
    return Chip(
      avatar: Icon(
        preference.type == 'genre'
            ? Icons.movie_filter
            : preference.type == 'director'
                ? Icons.video_camera_back
                : Icons.person,
        color: color,
        size: 16,
      ),
      label: Text(preference.name),
      labelStyle: TextStyle(
        color: isLike ? Colors.black87 : Colors.white,
        fontWeight: FontWeight.w500,
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () => _removePreference(preference, isLike),
      backgroundColor: isLike ? color.withOpacity(0.2) : color,
    );
  }

  Widget _buildImportanceTab() {
    if (_preferences == null) {
      return const Center(child: Text('No preferences found'));
    }

    final importanceFactors = _preferences!.importanceFactors;

    // Define friendly names for factors
    final factorNames = {
      'story': 'Storyline & Plot',
      'acting': 'Acting Quality',
      'visuals': 'Visual Effects & Cinematography',
      'soundtrack': 'Music & Sound',
      'pacing': 'Pacing & Editing',
    };

    // Define descriptive texts for rating values
    String getFactorDescription(String factor, double value) {
      if (value <= 0.5) return 'Not important to me';
      if (value <= 1.0) return 'Somewhat important';
      if (value <= 1.5) return 'Very important';
      return 'Extremely important';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'What Matters Most to You',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adjust these sliders to tell us what aspects of movies matter most to you. We\'ll use this to fine-tune your recommendations.',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        ...importanceFactors.entries.map((entry) {
          final factor = entry.key;
          final value = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        factorNames[factor] ?? factor,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: value,
                    min: 0.0,
                    max: 2.0,
                    divisions: 4,
                    onChanged: (newValue) {
                      setState(() {
                        _preferences!.importanceFactors[factor] = newValue;
                      });
                    },
                    onChangeEnd: (newValue) {
                      _updateImportanceFactor(factor, newValue);
                    },
                  ),
                  Text(
                    getFactorDescription(factor, value),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              // Reset to default values
              for (var key in _preferences!.importanceFactors.keys) {
                _updateImportanceFactor(key, 1.0);
              }
            },
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Default'),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildNotInterestedTab() {
    if (_preferences == null) {
      return const Center(child: Text('No preferences found'));
    }

    if (_loadingNotInterestedMovies) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_preferences!.dislikedMovieIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.thumbs_up_down,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Movies Marked as Not Interested',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Movies you mark as "Not Interested" will not be recommended to you',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Not Interested Movies',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'These movies won\'t be recommended to you.',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        ..._notInterestedMovies
            .map((movie) => _buildNotInterestedMovieCard(movie))
            .toList(),
        if (_notInterestedMovies.isEmpty &&
            _preferences!.dislikedMovieIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.movie_filter,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Movie details couldn\'t be loaded',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildNotInterestedMovieCard(Movie movie) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            movie.posterUrl,
            width: 40,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 40,
              height: 60,
              color: Colors.grey.shade300,
              child: const Icon(Icons.movie),
            ),
          ),
        ),
        title: Text(movie.title),
        subtitle: Text(movie.year),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove from Not Interested',
          onPressed: () => _removeFromNotInterested(movie.id),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: movie),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    if (!_showSuggestions) return const SizedBox.shrink();

    return _isSearching
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        : _searchResults.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No results found. Try a different search term.'),
                ),
              )
            : Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    final title = item['title'] ?? 'Unknown';
                    final year = item['release_date'] != null
                        ? item['release_date'].toString().substring(0, 4)
                        : '';
                    final posterPath = item['poster_path'];
                    final posterUrl = posterPath != null
                        ? 'https://image.tmdb.org/t/p/w200$posterPath'
                        : 'https://via.placeholder.com/200x300.png?text=No+Poster';

                    return ListTile(
                      leading: Image.network(
                        posterUrl,
                        width: 40,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 60,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.movie),
                        ),
                      ),
                      title: Text('$title ${year.isNotEmpty ? '($year)' : ''}'),
                      subtitle: Text(
                        item['overview'] ?? 'No description available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        // Hide keyboard and search suggestions
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _showSuggestions = false;
                        });

                        // Show bottom sheet with options
                        _showMovieOptionsSheet(item);
                      },
                    );
                  },
                ),
              );
  }

  void _showMovieOptionsSheet(Map<String, dynamic> movie) {
    final title = movie['title'] ?? 'Unknown';
    final year = movie['release_date'] != null
        ? movie['release_date'].toString().substring(0, 4)
        : '';
    final posterPath = movie['poster_path'];
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w200$posterPath'
        : 'https://via.placeholder.com/200x300.png?text=No+Poster';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Movie header
                  ListTile(
                    leading: Image.network(
                      posterUrl,
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 40,
                        height: 60,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.movie),
                      ),
                    ),
                    title: Text('$title ${year.isNotEmpty ? '($year)' : ''}'),
                    subtitle: Text(
                      movie['overview'] ?? 'No description available',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const Divider(),

                  // Preferences options - Likes
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      "Add to 'I Like'",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.movie_filter, color: Colors.blue),
                    title: const Text('Genres in this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addGenrePreference(movie);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.purple),
                    title: const Text('Main actors in this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addActorPreference(movie);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.video_camera_back,
                        color: Colors.green),
                    title: const Text('Directors of this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addDirectorPreference(movie);
                    },
                  ),

                  const Divider(),

                  // Preferences options - Dislikes
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      "Add to 'I Don't Like'",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ListTile(
                    leading:
                        Icon(Icons.movie_filter, color: Colors.red.shade300),
                    title: const Text('Genres in this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addToDislikedPreference(movie, 'genre');
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.person, color: Colors.red.shade300),
                    title: const Text('Main actors in this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addToDislikedPreference(movie, 'actor');
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.video_camera_back,
                        color: Colors.red.shade300),
                    title: const Text('Directors of this movie'),
                    onTap: () {
                      Navigator.pop(context);
                      _addToDislikedPreference(movie, 'director');
                    },
                  ),

                  const Divider(),

                  // Not interested option
                  ListTile(
                    leading:
                        const Icon(Icons.not_interested, color: Colors.grey),
                    title: const Text('Not interested in this movie'),
                    subtitle: const Text("Don't recommend this to me"),
                    onTap: () {
                      Navigator.pop(context);
                      _markAsNotInterested(movie);
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss search suggestions when tapping outside
        if (_showSuggestions) {
          setState(() {
            _showSuggestions = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customize Recommendations'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Preferences',
              onPressed: _loadPreferences,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.thumb_up_alt_outlined),
                text: 'My Preferences',
              ),
              Tab(
                icon: Icon(Icons.tune),
                text: 'Importance',
              ),
              Tab(
                icon: Icon(Icons.not_interested),
                text: 'Not Interested',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingIndicator(message: 'Loading preferences...')
            : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for movies, actors, directors...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _showSuggestions = false;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: _searchContent,
                          onSubmitted: (value) {
                            // Hide keyboard on submit
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Search suggestions
                  if (_showSuggestions) _buildSearchSuggestions(),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPreferenceTabView(),
                        _buildImportanceTab(),
                        _buildNotInterestedTab(),
                      ],
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Suggest popular movies
            _searchController.text = 'popular';
            _searchContent('popular');
            setState(() {
              _showSuggestions = true;
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add More Preferences'),
        ),
      ),
    );
  }
}
