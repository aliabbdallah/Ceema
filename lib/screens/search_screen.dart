import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../models/movie.dart';
import '../services/follow_request_service.dart';
import '../services/follow_service.dart';
import '../services/tmdb_service.dart';
import '../screens/quick_add_movies_screen.dart';
import '../utils/fuzzy_search.dart';
import 'search/tabs/user_search_tab.dart';
import 'search/tabs/post_search_tab.dart';
import 'search/tabs/movie_search_tab.dart';
import 'search/tabs/actor_search_tab.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowRequestService _requestService = FollowRequestService();
  final FollowService _followService = FollowService();
  final TMDBService _tmdbService = TMDBService();

  late TabController _tabController;

  // Search results for different tabs
  List<UserModel> _userResults = [];
  List<Post> _postResults = [];
  List<Movie> _movieResults = [];
  List<Map<String, dynamic>> _actorResults = [];
  List<Map<String, dynamic>> _movieSuggestions = [];

  // For user tab when no search is active
  List<UserModel> _recentSearches = [];
  List<UserModel> _suggestedUsers = [];

  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingPosts = false;
  bool _isLoadingMovies = false;
  bool _isLoadingActors = false;
  bool _showMovieSuggestions = false;

  Timer? _debounceTimer;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadRecentSearches();
    _loadSuggestedUsers();
  }

  void _handleTabChange() {
    if (_currentQuery.isNotEmpty) {
      _performSearch(_currentQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final searches =
          await _firestore
              .collection('userSearches')
              .doc(currentUserId)
              .collection('recent')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();

      if (mounted) {
        setState(() {
          _recentSearches =
              searches.docs
                  .map((doc) {
                    final data = doc.data();
                    if (data.containsKey('userId')) {
                      return UserModel(
                        id: data['userId'],
                        username: data['username'] ?? '',
                        profileImageUrl: data['profileImageUrl'],
                        bio: data['bio'],
                        email: '',
                        favoriteGenres: [],
                        createdAt: DateTime.now(),
                      );
                    }
                    return null;
                  })
                  .where((user) => user != null)
                  .cast<UserModel>()
                  .toList();
        });
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _loadSuggestedUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Get a list of users the current user is following
      final followingList =
          await _followService.getFollowing(currentUserId).first;
      final followingIds = followingList.map((user) => user.id).toList();

      // Get users with most followers, excluding those the user already follows
      final suggestedUserDocs =
          await _firestore
              .collection('users')
              .orderBy('followerCount', descending: true)
              .limit(10)
              .get();

      final suggestions =
          suggestedUserDocs.docs
              .map((doc) => UserModel.fromJson(doc.data(), doc.id))
              .where(
                (user) =>
                    user.id != currentUserId && !followingIds.contains(user.id),
              )
              .take(5)
              .toList();

      if (mounted) {
        setState(() {
          _suggestedUsers = suggestions;
        });
      }
    } catch (e) {
      print('Error loading suggested users: $e');
    }
  }

  void _performSearch(String query) {
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _movieResults = [];
        _actorResults = [];
        _movieSuggestions = [];
        _showMovieSuggestions = false;
      });
      return;
    }

    setState(() {
      _showMovieSuggestions = query.isNotEmpty;
    });

    // Update suggestions immediately for movies
    if (_tabController.index == 2) {
      _updateMovieSuggestions(query);
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Determine which search to perform based on active tab
      switch (_tabController.index) {
        case 0:
          _searchUsers(query);
          break;
        case 1:
          _searchPosts(query);
          break;
        case 2:
          _searchMovies(query);
          break;
        case 3:
          _searchActors(query);
          break;
      }
    });
  }

  Future<void> _updateMovieSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _movieSuggestions = [];
      });
      return;
    }

    try {
      final suggestions = await TMDBService.getSuggestions(query);
      if (mounted && query == _currentQuery) {
        setState(() {
          _movieSuggestions = suggestions;
        });
      }
    } catch (e) {
      print('Error updating movie suggestions: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoadingUsers = true);

    try {
      // Get all users first
      final querySnapshot = await _firestore.collection('users').get();

      // Pre-process the search query
      final searchQuery = query.toLowerCase().trim();
      final searchTerms = searchQuery.split(' ');

      // Optimized filtering using a single pass
      final filteredUsers =
          querySnapshot.docs
              .where((doc) => doc.id != _auth.currentUser!.uid)
              .map((doc) => UserModel.fromJson(doc.data(), doc.id))
              .where((user) {
                final username = user.username.toLowerCase();

                // Quick exact match check
                if (username == searchQuery) return true;

                // Check if all search terms are present
                return searchTerms.every((term) => username.contains(term));
              })
              .toList();

      if (mounted) {
        setState(() {
          _userResults = filteredUsers;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching users: $e')));
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _searchPosts(String query) async {
    setState(() => _isLoadingPosts = true);

    try {
      // Get all posts first
      final querySnapshot =
          await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .get();

      // Pre-process the search query
      final searchQuery = query.toLowerCase().trim();
      final searchTerms = searchQuery.split(' ');

      // Optimized filtering using a single pass
      final posts =
          querySnapshot.docs
              .map((doc) => Post.fromJson(doc.data(), doc.id))
              .where((post) {
                final content = post.content.toLowerCase();
                final movieTitle = post.movieTitle.toLowerCase();

                // Quick exact match checks
                if (content == searchQuery || movieTitle == searchQuery)
                  return true;

                // Check if all search terms are present in either content or title
                return searchTerms.every(
                  (term) => content.contains(term) || movieTitle.contains(term),
                );
              })
              .toList();

      if (mounted) {
        setState(() {
          _postResults = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching posts: $e')));
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _searchMovies(String query) async {
    setState(() => _isLoadingMovies = true);

    try {
      // Pre-process the search query
      final searchQuery = query.toLowerCase().trim();
      final searchTerms = searchQuery.split(' ');

      // Try the original query first
      var movies = await _tmdbService.searchMovies(query);

      // Filter out movies with 0.0 ratings
      movies = movies.where((movie) => movie.voteAverage > 0.0).toList();

      // If we have less than 5 results, supplement with popular movies
      if (movies.length < 5) {
        final popularMovies = await _tmdbService.getPopularMovies();

        // Filter out movies with 0.0 ratings from popular movies
        final filteredPopularMovies =
            popularMovies.where((movie) => movie.voteAverage > 0.0).toList();

        // Optimized filtering of popular movies
        final matchingPopularMovies =
            filteredPopularMovies.where((movie) {
              final title = movie.title.toLowerCase();
              final overview = movie.overview.toLowerCase();

              // Quick exact match checks
              if (title == searchQuery) return true;

              // Check if all search terms are present in either title or overview
              return searchTerms.every(
                (term) => title.contains(term) || overview.contains(term),
              );
            }).toList();

        // Add matching popular movies that aren't already in the results
        final existingIds = movies.map((m) => m.id).toSet();
        movies.addAll(
          matchingPopularMovies.where((m) => !existingIds.contains(m.id)),
        );
      }

      // Sort by relevance and popularity
      final sortedMovies = _sortMovieResults(movies, query);

      if (mounted) {
        setState(() {
          _movieResults = sortedMovies;
          _isLoadingMovies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching movies: $e')));
        setState(() => _isLoadingMovies = false);
      }
    }
  }

  List<Movie> _sortMovieResults(List<Movie> movies, String query) {
    // Group movies by title for handling identical titles
    final Map<String, List<Movie>> moviesByTitle = {};
    for (final movie in movies) {
      moviesByTitle.putIfAbsent(movie.title.toLowerCase(), () => []).add(movie);
    }

    // Sort each group of identical titles by popularity
    for (final titleGroup in moviesByTitle.values) {
      if (titleGroup.length > 1) {
        titleGroup.sort((a, b) => b.popularity.compareTo(a.popularity));
      }
    }

    // Flatten the groups back into a single list
    final sortedMovies = moviesByTitle.values.expand((group) => group).toList();

    // Final sort: first by exact matches, then by popularity
    final searchQuery = query.toLowerCase();
    sortedMovies.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      // First tier: Exact title matches
      if (aTitle == searchQuery && bTitle != searchQuery) return -1;
      if (aTitle != searchQuery && bTitle == searchQuery) return 1;

      // Second tier: Sort by popularity
      return b.popularity.compareTo(a.popularity);
    });

    return sortedMovies;
  }

  List<String> _getSpellingVariations(String query) {
    final variations = <String>[];
    final lowerQuery = query.toLowerCase();

    // Common misspellings and variations
    if (lowerQuery.contains('lamd')) {
      variations.add(lowerQuery.replaceAll('lamd', 'land'));
    }
    if (lowerQuery.contains('lnd')) {
      variations.add(lowerQuery.replaceAll('lnd', 'land'));
    }
    if (lowerQuery.contains('lam')) {
      variations.add(lowerQuery.replaceAll('lam', 'land'));
    }

    // Common actor/movie related misspellings
    if (lowerQuery.contains('actr')) {
      variations.add(lowerQuery.replaceAll('actr', 'actor'));
    }
    if (lowerQuery.contains('act')) {
      variations.add(lowerQuery.replaceAll('act', 'actor'));
    }
    if (lowerQuery.contains('movy')) {
      variations.add(lowerQuery.replaceAll('movy', 'movie'));
    }
    if (lowerQuery.contains('mov')) {
      variations.add(lowerQuery.replaceAll('mov', 'movie'));
    }

    // Common name misspellings
    if (lowerQuery.contains('jon')) {
      variations.add(lowerQuery.replaceAll('jon', 'john'));
    }
    if (lowerQuery.contains('mike')) {
      variations.add(lowerQuery.replaceAll('mike', 'michael'));
    }

    // Try removing/adding common suffixes
    if (lowerQuery.endsWith('s')) {
      variations.add(lowerQuery.substring(0, lowerQuery.length - 1));
    } else {
      variations.add('${lowerQuery}s');
    }

    return variations;
  }

  Future<void> _searchActors(String query) async {
    setState(() => _isLoadingActors = true);

    try {
      // Pre-process the search query
      final searchQuery = query.toLowerCase().trim();
      final searchTerms = searchQuery.split(' ');

      // Get filtered actor results (already filtered for actors with photos)
      var results = await TMDBService.searchActors(query);

      // Optimized filtering using a single pass
      final filteredActors =
          results.where((actor) {
            final name = actor['name']?.toString().toLowerCase() ?? '';
            return searchTerms.every((term) => name.contains(term));
          }).toList();

      if (mounted) {
        setState(() {
          _actorResults = filteredActors;
          _isLoadingActors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching actors: $e')));
        setState(() => _isLoadingActors = false);
      }
    }
  }

  Future<void> _saveSearchHistory(UserModel user) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('userSearches')
          .doc(currentUserId)
          .collection('recent')
          .doc(user.id)
          .set({
            'userId': user.id,
            'username': user.username,
            'profileImageUrl': user.profileImageUrl,
            'bio': user.bio,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  void _removeFromSearchHistory(UserModel user) async {
    try {
      await _firestore
          .collection('userSearches')
          .doc(_auth.currentUser!.uid)
          .collection('recent')
          .doc(user.id)
          .delete();
      _loadRecentSearches();
    } catch (e) {
      print('Error removing search history: $e');
    }
  }

  void _clearAllSearchHistory() async {
    try {
      await _firestore
          .collection('userSearches')
          .doc(_auth.currentUser!.uid)
          .collection('recent')
          .get()
          .then((snapshot) {
            for (final doc in snapshot.docs) {
              doc.reference.delete();
            }
          });
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            prefixIcon: Icon(Icons.search, color: colorScheme.secondary),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.secondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _userResults = [];
                          _postResults = [];
                          _movieResults = [];
                          _actorResults = [];
                          _movieSuggestions = [];
                          _currentQuery = '';
                          _showMovieSuggestions = false;
                        });
                      },
                    )
                    : null,
          ),
          onChanged: _performSearch,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.secondary,
          labelColor: colorScheme.secondary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: [
            Tab(icon: Icon(Icons.person_outline), text: 'Users'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.movie_outlined), text: 'Movies'),
            Tab(icon: Icon(Icons.person_search), text: 'Actors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UserSearchTab(
            userResults: _userResults,
            recentSearches: _recentSearches,
            suggestedUsers: _suggestedUsers,
            isLoading: _isLoadingUsers,
            isSearchActive: _searchController.text.isNotEmpty,
            followService: _followService,
            requestService: _requestService,
            auth: _auth,
            firestore: _firestore,
            onRemoveFromHistory: _removeFromSearchHistory,
            onRefresh: () {
              setState(() {});
            },
          ),
          PostSearchTab(
            postResults: _postResults,
            isLoading: _isLoadingPosts,
            isSearchActive: _searchController.text.isNotEmpty,
            auth: _auth,
            firestore: _firestore,
          ),
          MovieSearchTab(
            movieResults: _movieResults,
            movieSuggestions: _movieSuggestions,
            isLoading: _isLoadingMovies,
            isSearchActive: _searchController.text.isNotEmpty,
            showMovieSuggestions: _showMovieSuggestions,
          ),
          ActorSearchTab(
            actorResults: _actorResults,
            isLoading: _isLoadingActors,
            isSearchActive: _searchController.text.isNotEmpty,
          ),
        ],
      ),
    );
  }
}
