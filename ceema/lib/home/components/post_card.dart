import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post.dart';
import '../../models/movie.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';
import '../../screens/movie_details_screen.dart';
import '../../screens/comments_screen.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/profile_image_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: ProfileImageWidget(
              imageUrl: widget.post.userAvatar,
              radius: 20,
              fallbackName: widget.post.userName,
            ),
            title: Text(
              widget.post.userName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(timeago.format(widget.post.createdAt)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(widget.post.content),
          ),
          if (widget.post.movieId.isNotEmpty)
            ListTile(
              leading: Image.network(widget.post.moviePosterUrl),
              title: Text(widget.post.movieTitle),
              subtitle: Text(widget.post.movieYear),
            ),
          ButtonBar(
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                onPressed: () {},
              ),
              Text('${widget.post.likesCount}'),
              IconButton(
                icon: Icon(Icons.comment),
                onPressed: () {},
              ),
              Text('${widget.post.commentCount}'),
              IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Also include SeamlessPostCard if needed
class SeamlessPostCard extends StatefulWidget {
  final Post post;
  final bool isHighlighted;
  final String? relevanceReason;

  const SeamlessPostCard({
    Key? key,
    required this.post,
    this.isHighlighted = false,
    this.relevanceReason,
  }) : super(key: key);

  @override
  State<SeamlessPostCard> createState() => _SeamlessPostCardState();
}

class _SeamlessPostCardState extends State<SeamlessPostCard> {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  ProfileImageWidget(
                    imageUrl: widget.post.userAvatar,
                    radius: 20,
                    fallbackName: widget.post.userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.userName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          timeago.format(widget.post.createdAt),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
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
              const SizedBox(height: 12),
              // Post content
              Text(widget.post.content),
              if (widget.post.movieId.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Movie info
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        widget.post.moviePosterUrl,
                        width: 40,
                        height: 60,
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
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            widget.post.movieYear,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.relevanceReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.relevanceReason!,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : null,
                    ),
                    onPressed: _handleLike,
                  ),
                  Text(
                    widget.post.likes.length.toString(),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.comment),
                    onPressed: () {
                      // TODO: Implement comment navigation
                    },
                  ),
                  Text(
                    widget.post.commentCount.toString(),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Subtle divider
        Container(
          height: 1,
          color: colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ],
    );
  }
}
