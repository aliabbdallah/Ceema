import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceema/models/movie.dart';
import 'package:ceema/services/post_service.dart';
import 'package:ceema/services/tmdb_service.dart';
import 'package:ceema/services/diary_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ComposePostScreen extends StatefulWidget {
  final Movie? initialMovie;

  const ComposePostScreen({Key? key, this.initialMovie}) : super(key: key);

  @override
  _ComposePostScreenState createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final PostService _postService = PostService();
  final TMDBService _tmdbService = TMDBService();
  final DiaryService _diaryService = DiaryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Movie> _searchResults = [];
  Movie? _selectedMovie;
  double _rating = 0.0;
  bool _addToDiary = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMovie != null) {
      _selectedMovie = widget.initialMovie;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
      _searchQuery = query;
      _isSearching = true;
    });

    try {
      final results = await _tmdbService.searchMovies(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching movies: $e')));
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectMovie(Movie movie) {
    setState(() {
      _selectedMovie = movie;
      _searchResults = [];
      _searchQuery = '';
    });
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something about the movie')),
      );
      return;
    }

    if (_selectedMovie == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a movie')));
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user data for display name and avatar
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      // Create the post
      await _postService.createPost(
        userId: currentUser.uid,
        userName:
            userData['username'] ?? currentUser.displayName ?? 'Anonymous',
        userAvatar: userData['profileImageUrl'] ?? currentUser.photoURL ?? '',
        content: _contentController.text.trim(),
        movie: _selectedMovie!,
        rating: _rating,
      );

      // If add to diary is enabled, add to diary as well
      if (_addToDiary) {
        await _diaryService.addDiaryEntry(
          userId: currentUser.uid,
          movie: _selectedMovie!,
          rating: _rating,
          review: _contentController.text.trim(),
          watchedDate: DateTime.now(),
          isFavorite: false,
          isRewatch: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _addToDiary
                  ? 'Post created and added to diary successfully!'
                  : 'Post created successfully!',
            ),
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMovieSearchBar() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search for a movie...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: _searchMovies,
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isNotEmpty)
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final movie = _searchResults[index];
                return ListTile(
                  leading:
                      movie.posterUrl.isNotEmpty
                          ? Image.network(
                            movie.posterUrl,
                            width: 50,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.movie, size: 50),
                          )
                          : const Icon(Icons.movie, size: 50),
                  title: Text(movie.title),
                  subtitle: Text(movie.year),
                  onTap: () => _selectMovie(movie),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedMovie() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedMovie!.posterUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _selectedMovie!.posterUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie),
                      ),
                ),
              )
            else
              Container(
                width: 80,
                height: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.movie),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedMovie!.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedMovie!.year,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedMovie!.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMovie = null;
                      });
                    },
                    child: const Text('Change Movie'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Review',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _contentController,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this movie...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '${_contentController.text.length}/500',
              counterStyle: TextStyle(
                color:
                    _contentController.text.length > 450
                        ? Colors.red
                        : Theme.of(context).hintColor,
              ),
            ),
            maxLines: 5,
            maxLength: 500,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              // Use a post-frame callback to ensure the keyboard is properly dismissed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FocusScope.of(context).unfocus();
              });
            },
            onEditingComplete: () {
              // Use a post-frame callback to ensure the keyboard is properly dismissed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FocusScope.of(context).unfocus();
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _submitPost(),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      'Post',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedMovie == null)
                _buildMovieSearchBar()
              else
                _buildSelectedMovie(),
              const SizedBox(height: 24),
              _buildContentInput(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Add to Diary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _addToDiary,
                    onChanged: (value) {
                      setState(() {
                        _addToDiary = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Rate this movie',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RatingBar.builder(
                      initialRating: _rating,
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 32,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder:
                          (context, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
