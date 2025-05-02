import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/post.dart';
import '../models/movie.dart';
import '../services/post_service.dart';
import '../widgets/movie_selection_dialog.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({Key? key, required this.post}) : super(key: key);

  @override
  _EditPostScreenState createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  Movie? _selectedMovie;
  double _rating = 0.0;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    if (widget.post.movieId.isNotEmpty) {
      _selectedMovie = Movie(
        id: widget.post.movieId,
        title: widget.post.movieTitle,
        posterUrl: widget.post.moviePosterUrl,
        year: widget.post.movieYear,
        overview: widget.post.movieOverview,
      );
    }
    _rating = widget.post.rating;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _showMovieSelectionDialog() async {
    final selected = await showDialog<Movie>(
      context: context,
      builder:
          (context) => MovieSelectionDialog(
            onMovieSelected: (movie) {
              Navigator.pop(context, movie);
            },
          ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedMovie = selected;
      });
    }
  }

  Future<void> _savePost() async {
    if (_selectedMovie == null && _rating > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a movie to assign a rating.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post content cannot be empty.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _postService.updatePostDetails(
        widget.post.id,
        _contentController.text.trim(),
        _selectedMovie,
        _selectedMovie != null ? _rating : 0.0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          _isLoading
              ? const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.save),
                onPressed: _savePost,
                tooltip: 'Save Post',
              ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _contentController,
                minLines: 5,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12.0),
                ),
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              _buildMovieSelectionArea(context),

              const SizedBox(height: 20),

              if (_selectedMovie != null) _buildRatingArea(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieSelectionArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected Movie', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _selectedMovie == null
            ? Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Select Movie'),
                onPressed: _showMovieSelectionDialog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            )
            : Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    if (_selectedMovie!.posterUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _selectedMovie!.posterUrl,
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                width: 60,
                                height: 90,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceVariant,
                                child: Icon(
                                  Icons.movie,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 90,
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.movie,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMovie!.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _selectedMovie!.year,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Change Movie',
                      onPressed: _showMovieSelectionDialog,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Remove Movie',
                      onPressed: () {
                        setState(() {
                          _selectedMovie = null;
                          _rating = 0.0;
                        });
                      },
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildRatingArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Rating', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        RatingBar.builder(
          initialRating: _rating,
          minRating: 0,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          itemBuilder:
              (context, _) => Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.secondary,
              ),
          onRatingUpdate: (rating) {
            setState(() {
              _rating = rating;
            });
          },
          glow: false,
        ),
      ],
    );
  }
}
