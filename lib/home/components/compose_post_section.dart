// lib/home/components/compose_post_section.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/movie.dart';
import '../../services/post_service.dart';
import '../../widgets/movie_selection_dialog.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/profile_image_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComposePostSection extends StatefulWidget {
  final VoidCallback onCancel;
  final double? maxHeight;

  const ComposePostSection({Key? key, required this.onCancel, this.maxHeight})
    : super(key: key);

  @override
  _ComposePostSectionState createState() => _ComposePostSectionState();
}

class _ComposePostSectionState extends State<ComposePostSection> {
  final TextEditingController _postController = TextEditingController();
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Movie? _selectedMovie;
  double _rating = 0.0;
  bool _isLoading = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _postController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() => _showEmojiPicker = false);
    }
  }

  void _showMovieSelection() async {
    final Movie? selectedMovie = await showDialog<Movie>(
      context: context,
      builder:
          (context) => MovieSelectionDialog(
            onMovieSelected: (movie) {
              Navigator.pop(context, movie);
            },
          ),
    );

    if (selectedMovie != null) {
      setState(() => _selectedMovie = selectedMovie);
    }
  }

  Future<void> _handlePost() async {
    if (_postController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something about the movie'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedMovie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a movie'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser!;

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      await _postService.createPost(
        userId: user.uid,
        userName: userData['username'] ?? user.displayName ?? 'Anonymous',
        userAvatar: userData['profileImageUrl'] ?? user.photoURL ?? '',
        content: _postController.text.trim(),
        movie: _selectedMovie!,
        rating: _rating,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSelectedMovieCard() {
    if (_selectedMovie == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Movie Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              _selectedMovie!.posterUrl,
              width: 40,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.movie),
                  ),
            ),
          ),
          const SizedBox(width: 12),

          // Movie Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMovie!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _selectedMovie!.year,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Remove Movie Button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedMovie = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSelector() {
    if (_selectedMovie == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Rating: ', style: TextStyle(fontSize: 14)),
        StarRating(
          rating: _rating,
          size: 24,
          spacing: 4,
          allowHalfRating: true,
          onRatingChanged: (rating) {
            setState(() {
              _rating = rating;
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Add Movie Button
        IconButton(
          icon: const Icon(Icons.movie_outlined),
          onPressed: _showMovieSelection,
          tooltip: 'Select Movie',
        ),

        // Add Emoji Button
        IconButton(
          icon: const Icon(Icons.emoji_emotions_outlined),
          onPressed: () {
            _focusNode.unfocus();
            setState(() => _showEmojiPicker = !_showEmojiPicker);
          },
          tooltip: 'Add Emoji',
        ),

        const Spacer(),

        // Cancel Button
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),

        // Post Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePost,
          child:
              _isLoading
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Post'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: widget.maxHeight ?? double.infinity,
      ),
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileImageWidget(
                    imageUrl: _auth.currentUser?.photoURL,
                    radius: 20,
                    fallbackName: _auth.currentUser?.displayName ?? "User",
                  ),
                  const SizedBox(width: 12),

                  // Post Input
                  Expanded(
                    child: TextField(
                      controller: _postController,
                      focusNode: _focusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Share your thoughts about a movie...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Selected Movie Card
              if (_selectedMovie != null) ...[
                _buildSelectedMovieCard(),
                const SizedBox(height: 12),
                _buildRatingSelector(),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
