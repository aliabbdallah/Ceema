// home/components/post_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post.dart';
import '../../models/movie.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';
import '../../screens/movie_details_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likes.contains(_auth.currentUser?.uid);
  }

  Future<void> _handleLike() async {
    try {
      await _postService.toggleLike(widget.post.id, _auth.currentUser!.uid);
      setState(() {
        _isLiked = !_isLiked;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPostOptions() {
    final bool isCurrentUser = widget.post.userId == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentUser) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Post'),
              onTap: () {
                // TODO: Implement edit functionality
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Post',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Post'),
                    content: const Text(
                        'Are you sure you want to delete this post?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  try {
                    await _postService.deletePost(widget.post.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting post: $e')),
                    );
                  }
                }
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Post'),
            onTap: () {
              // TODO: Implement share functionality
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Report Post'),
            onTap: () {
              // TODO: Implement report functionality
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return GestureDetector(
      onTap: () {
        if (widget.post.userId != _auth.currentUser?.uid) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: widget.post.userId,
                username: widget.post.userName,
              ),
            ),
          );
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.post.userAvatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showPostOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(
              movie: Movie(
                id: widget.post.movieId,
                title: widget.post.movieTitle,
                posterUrl: widget.post.moviePosterUrl,
                year: widget.post.movieYear,
                overview: widget.post.movieOverview,
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: Image.network(
                widget.post.moviePosterUrl,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.movieTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.post.movieYear,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                  if (widget.post.rating > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < widget.post.rating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActions() {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : null,
          ),
          onPressed: _handleLike,
        ),
        Text(widget.post.likes.length.toString()),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.comment_outlined),
          onPressed: () {
            // TODO: Implement comments
          },
        ),
        Text(widget.post.commentCount.toString()),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            // TODO: Implement share functionality
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            const SizedBox(height: 12),
            Text(widget.post.content),
            const SizedBox(height: 12),
            if (widget.post.movieId.isNotEmpty) ...[
              _buildMovieCard(),
              const SizedBox(height: 12),
            ],
            _buildPostActions(),
          ],
        ),
      ),
    );
  }
}
