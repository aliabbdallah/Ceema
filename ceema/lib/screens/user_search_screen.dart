import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/post.dart';
import '../models/movie.dart';
import '../models/follow_request.dart';
import '../services/follow_request_service.dart';
import '../services/follow_service.dart';
import '../services/post_service.dart';
import '../services/tmdb_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/movie_details_screen.dart';
import '../screens/actor_details_screen.dart';
import '../widgets/profile_image_widget.dart';
import '../utils/fuzzy_search.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowRequestService _requestService = FollowRequestService();
  final FollowService _followService = FollowService();
  final PostService _postService = PostService();
  final TMDBService _tmdbService = TMDBService();

  late TabController _tabController;

  List<UserModel> _userResults = [];
  List<Post> _postResults = [];
  List<Movie> _movieResults = [];
  List<Map<String, dynamic>> _actorResults = [];

  List<UserModel> _recentSearches = [];
  List<UserModel> _suggestedUsers = [];

  bool _isLoadingUsers = false;
  bool _isLoadingPosts = false;
  bool _isLoadingMovies = false;
  bool _isLoadingActors = false;

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
      });
      return;
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

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoadingUsers = true);

    try {
      // Get all users first
      final querySnapshot = await _firestore.collection('users').get();

      // Filter users using fuzzy search
      final users =
          querySnapshot.docs
              .where((doc) => doc.id != _auth.currentUser!.uid)
              .map((doc) => UserModel.fromJson(doc.data(), doc.id))
              .toList();

      // Apply multi-step search filtering
      final filteredUsers =
          users.where((user) {
            final username = user.username.toLowerCase();
            final searchQuery = query.toLowerCase();

            // First try exact match
            if (username.contains(searchQuery)) {
              return true;
            }

            // Try removing spaces
            final noSpacesQuery = searchQuery.replaceAll(' ', '');
            if (noSpacesQuery != searchQuery &&
                username.contains(noSpacesQuery)) {
              return true;
            }

            // Try common spelling variations
            final variations = _getSpellingVariations(searchQuery);
            for (final variation in variations) {
              if (username.contains(variation)) {
                return true;
              }
            }

            // Finally try fuzzy match
            return FuzzySearch.isSimilar(searchQuery, username, threshold: 0.6);
          }).toList();

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

      // Apply multi-step search filtering
      final posts =
          querySnapshot.docs
              .map((doc) => Post.fromJson(doc.data(), doc.id))
              .where((post) {
                final content = post.content.toLowerCase();
                final movieTitle = post.movieTitle.toLowerCase();
                final searchQuery = query.toLowerCase();

                // First try exact matches
                if (content.contains(searchQuery) ||
                    movieTitle.contains(searchQuery)) {
                  return true;
                }

                // Try removing spaces
                final noSpacesQuery = searchQuery.replaceAll(' ', '');
                if (noSpacesQuery != searchQuery) {
                  if (content.contains(noSpacesQuery) ||
                      movieTitle.contains(noSpacesQuery)) {
                    return true;
                  }
                }

                // Try common spelling variations
                final variations = _getSpellingVariations(searchQuery);
                for (final variation in variations) {
                  if (content.contains(variation) ||
                      movieTitle.contains(variation)) {
                    return true;
                  }
                }

                // Finally try fuzzy matches
                return FuzzySearch.isSimilar(
                      searchQuery,
                      content,
                      threshold: 0.6,
                    ) ||
                    FuzzySearch.isSimilar(
                      searchQuery,
                      movieTitle,
                      threshold: 0.6,
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
      // Try the original query first
      var movies = await _tmdbService.searchMovies(query);

      // If no results, try some common spelling variations
      if (movies.isEmpty) {
        // Try removing spaces
        final noSpacesQuery = query.replaceAll(' ', '');
        if (noSpacesQuery != query) {
          movies = await _tmdbService.searchMovies(noSpacesQuery);
        }

        // If still no results, try common misspellings
        if (movies.isEmpty) {
          final variations = _getSpellingVariations(query);
          for (final variation in variations) {
            if (movies.isNotEmpty) break;
            movies = await _tmdbService.searchMovies(variation);
          }
        }
      }

      // Apply fuzzy search filtering to the results
      final filteredMovies =
          movies.where((movie) {
            final title = movie.title.toLowerCase();
            final overview = movie.overview.toLowerCase();
            final searchQuery = query.toLowerCase();

            // First try exact matches
            if (title.contains(searchQuery) || overview.contains(searchQuery)) {
              return true;
            }

            // Then try fuzzy matches
            return FuzzySearch.isSimilar(searchQuery, title, threshold: 0.6) ||
                FuzzySearch.isSimilar(searchQuery, overview, threshold: 0.6);
          }).toList();

      if (mounted) {
        setState(() {
          _movieResults = filteredMovies;
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
    if (lowerQuery.contains('mich')) {
      variations.add(lowerQuery.replaceAll('mich', 'michael'));
    }
    if (lowerQuery.contains('sara')) {
      variations.add(lowerQuery.replaceAll('sara', 'sarah'));
    }

    // Try removing common suffixes
    if (lowerQuery.endsWith('s')) {
      variations.add(lowerQuery.substring(0, lowerQuery.length - 1));
    }
    if (lowerQuery.endsWith('es')) {
      variations.add(lowerQuery.substring(0, lowerQuery.length - 2));
    }

    // Try adding common suffixes
    if (!lowerQuery.endsWith('s')) {
      variations.add('${lowerQuery}s');
    }
    if (!lowerQuery.endsWith('es')) {
      variations.add('${lowerQuery}es');
    }

    return variations;
  }

  Future<void> _searchActors(String query) async {
    setState(() => _isLoadingActors = true);

    try {
      // Try the original query first
      var results = await TMDBService.searchActors(query);

      // If no results, try some common spelling variations
      if (results.isEmpty) {
        // Try removing spaces
        final noSpacesQuery = query.replaceAll(' ', '');
        if (noSpacesQuery != query) {
          results = await TMDBService.searchActors(noSpacesQuery);
        }

        // If still no results, try common misspellings
        if (results.isEmpty) {
          final variations = _getSpellingVariations(query);
          for (final variation in variations) {
            if (results.isNotEmpty) break;
            results = await TMDBService.searchActors(variation);
          }
        }
      }

      // Apply multi-step search filtering
      final filteredActors =
          results.where((actor) {
            final name = actor['name']?.toString().toLowerCase() ?? '';
            final department =
                actor['known_for_department']?.toString().toLowerCase() ?? '';
            final searchQuery = query.toLowerCase();

            // First try exact matches
            if (name.contains(searchQuery) ||
                department.contains(searchQuery)) {
              return true;
            }

            // Try removing spaces
            final noSpacesQuery = searchQuery.replaceAll(' ', '');
            if (noSpacesQuery != searchQuery) {
              if (name.contains(noSpacesQuery) ||
                  department.contains(noSpacesQuery)) {
                return true;
              }
            }

            // Try common spelling variations
            final variations = _getSpellingVariations(searchQuery);
            for (final variation in variations) {
              if (name.contains(variation) || department.contains(variation)) {
                return true;
              }
            }

            // Finally try fuzzy matches
            return FuzzySearch.isSimilar(searchQuery, name, threshold: 0.6) ||
                FuzzySearch.isSimilar(searchQuery, department, threshold: 0.6);
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

  void _navigateToUserProfile(UserModel user) {
    _saveSearchHistory(user);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                UserProfileScreen(userId: user.id, username: user.username),
      ),
    );
  }

  Widget _buildUserItem(
    UserModel user, {
    bool isRecent = false,
    bool isSuggested = false,
  }) {
    return FutureBuilder<bool>(
      future: _followService.isFollowing(user.id),
      builder: (context, isFollowingSnapshot) {
        return FutureBuilder<List<FollowRequest>>(
          future: _requestService.getPendingRequests(user.id).first,
          builder: (context, requestsSnapshot) {
            final isFollowing = isFollowingSnapshot.data ?? false;
            final hasPendingRequest =
                requestsSnapshot.data?.any(
                  (request) => request.requesterId == _auth.currentUser!.uid,
                ) ??
                false;

            return ListTile(
              leading: GestureDetector(
                onTap: () => _navigateToUserProfile(user),
                child: ProfileImageWidget(
                  imageUrl: user.profileImageUrl,
                  radius: 24,
                  fallbackName: user.username,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToUserProfile(user),
                      child: Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (isRecent)
                    IconButton(
                      icon: const Icon(Icons.history, size: 16),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Remove from search history?'),
                            action: SnackBarAction(
                              label: 'REMOVE',
                              onPressed: () async {
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
                              },
                            ),
                          ),
                        );
                      },
                      color: Colors.grey,
                      tooltip: 'Recent search',
                    ),
                ],
              ),
              subtitle:
                  user.bio != null && user.bio!.isNotEmpty
                      ? Text(
                        user.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                      : null,
              trailing:
                  isFollowing
                      ? ElevatedButton(
                        onPressed: () async {
                          try {
                            await _followService.unfollowUser(user.id);
                            setState(() {}); // Refresh UI
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Following'),
                      )
                      : hasPendingRequest
                      ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        child: const Text('Requested'),
                      )
                      : ElevatedButton(
                        onPressed: () async {
                          try {
                            final currentUser = _auth.currentUser!;
                            await _requestService.sendFollowRequest(
                              requesterId: currentUser.uid,
                              targetId: user.id,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow request sent!'),
                                ),
                              );
                              setState(() {}); // Refresh UI
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Follow'),
                      ),
              onTap: () => _navigateToUserProfile(user),
            );
          },
        );
      },
    );
  }

  Widget _buildPostItem(Post post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<UserModel?>(
                  future: _getUserData(post.userId),
                  builder: (context, snapshot) {
                    return ProfileImageWidget(
                      imageUrl:
                          post.userAvatar.isNotEmpty ? post.userAvatar : null,
                      radius: 20,
                      fallbackName: post.userName,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Posted a review',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.moviePosterUrl,
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.movieTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.movieYear,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (post.rating > 0)
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < post.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: const TextStyle(fontSize: 15),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 16,
                  color:
                      post.likes.contains(_auth.currentUser?.uid)
                          ? Colors.red
                          : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(post.likes.length.toString()),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined, size: 16),
                const SizedBox(width: 4),
                Text(post.commentCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieItem(Movie movie) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          movie.posterUrl,
          width: 50,
          height: 75,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 75,
              color: Colors.grey[300],
              child: const Icon(Icons.movie),
            );
          },
        ),
      ),
      title: Text(movie.title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(movie.year),
          const SizedBox(height: 4),
          Text(
            movie.overview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
    );
  }

  Widget _buildActorItem(Map<String, dynamic> actor) {
    final profilePath = actor['profile_path'];
    final profileUrl =
        profilePath != null
            ? 'https://image.tmdb.org/t/p/w500$profilePath'
            : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            profileUrl != null
                ? Image.network(
                  profileUrl,
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 75,
                      color: Colors.grey[300],
                      child: const Icon(Icons.person),
                    );
                  },
                )
                : Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person),
                ),
      ),
      title: Text(
        actor['name'],
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        actor['known_for_department'] ?? 'Actor',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActorDetailsScreen(actor: actor),
          ),
        );
      },
    );
  }

  Future<UserModel?> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () async {
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
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((user) => _buildUserItem(user, isRecent: true)),
      ],
    );
  }

  Widget _buildSuggestedUsers() {
    if (_suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Suggested Users',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ..._suggestedUsers.map(
          (user) => _buildUserItem(user, isSuggested: true),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResults() {
    final bool isSearchActive = _searchController.text.isNotEmpty;

    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && _userResults.isEmpty) {
      return _buildEmptyState('No users found', Icons.person_off_outlined);
    }

    if (_userResults.isNotEmpty) {
      return ListView.builder(
        itemCount: _userResults.length,
        itemBuilder: (context, index) => _buildUserItem(_userResults[index]),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentSearches(),
          _buildSuggestedUsers(),
          if (_recentSearches.isEmpty && _suggestedUsers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Find Friends',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search for users to follow and connect with',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostResults() {
    final bool isSearchActive = _searchController.text.isNotEmpty;

    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && _postResults.isEmpty) {
      return _buildEmptyState('No posts found', Icons.article_outlined);
    }

    if (_postResults.isNotEmpty) {
      return ListView.builder(
        itemCount: _postResults.length,
        itemBuilder: (context, index) => _buildPostItem(_postResults[index]),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text('Search Posts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Find posts by movie titles or content',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieResults() {
    final bool isSearchActive = _searchController.text.isNotEmpty;

    if (_isLoadingMovies) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && _movieResults.isEmpty) {
      return _buildEmptyState('No movies found', Icons.movie_filter);
    }

    if (_movieResults.isNotEmpty) {
      return ListView.builder(
        itemCount: _movieResults.length,
        itemBuilder: (context, index) => _buildMovieItem(_movieResults[index]),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text('Search Movies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Find movies by title, actors, or genre',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActorResults() {
    final bool isSearchActive = _searchController.text.isNotEmpty;

    if (_isLoadingActors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && _actorResults.isEmpty) {
      return _buildEmptyState('No actors found', Icons.person_off_outlined);
    }

    if (_actorResults.isNotEmpty) {
      return ListView.builder(
        itemCount: _actorResults.length,
        itemBuilder: (context, index) => _buildActorItem(_actorResults[index]),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text('Search Actors', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Find actors by name', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
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
            prefixIcon: const Icon(Icons.search),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _userResults = [];
                          _postResults = [];
                          _movieResults = [];
                          _actorResults = [];
                          _currentQuery = '';
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
          tabs: const [
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
          _buildUserResults(),
          _buildPostResults(),
          _buildMovieResults(),
          _buildActorResults(),
        ],
      ),
    );
  }
}
