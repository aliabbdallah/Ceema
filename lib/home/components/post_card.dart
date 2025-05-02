import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post.dart';
import '../../models/movie.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';
import '../../screens/movie_details_screen.dart';
import '../../screens/comments_screen.dart';
import '../../screens/post_screen.dart';
import '../../screens/edit_post_screen.dart';
import '../../widgets/profile_image_widget.dart';
import '../../services/haptic_service.dart';

class SeamlessPostCard extends StatefulWidget {
  final Post post;
  final bool isHighlighted;
  final String? relevanceReason;
  final bool isClickable;

  const SeamlessPostCard({
    Key? key,
    required this.post,
    this.isHighlighted = false,
    this.relevanceReason,
    this.isClickable = true,
  }) : super(key: key);

  @override
  State<SeamlessPostCard> createState() => _SeamlessPostCardState();
}

class _SeamlessPostCardState extends State<SeamlessPostCard> {
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HapticService _hapticService = HapticService();
  bool _isLiked = false;
  bool _isUpdating = false;
  List<String> _localLikes = [];
  DateTime? _lastUpdateTime;
  static const Duration _updateCooldown = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likes.contains(_auth.currentUser?.uid);
    _localLikes = List.from(widget.post.likes);
  }

  Future<void> _handleLike() async {
    if (_isUpdating) return;

    // Rate limiting check
    if (_lastUpdateTime != null &&
        DateTime.now().difference(_lastUpdateTime!) < _updateCooldown) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _lastUpdateTime = DateTime.now();
      if (_isLiked) {
        _localLikes.remove(_auth.currentUser!.uid);
      } else {
        _localLikes.add(_auth.currentUser!.uid);
      }
      _isLiked = !_isLiked;
    });

    try {
      await _hapticService.selection();
      await _firestore.collection('posts').doc(widget.post.id).update({
        'likes': _localLikes,
      });
    } catch (e) {
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          if (_isLiked) {
            _localLikes.add(_auth.currentUser!.uid);
          } else {
            _localLikes.remove(_auth.currentUser!.uid);
          }
          _isLiked = !_isLiked;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showPostOptions() {
    final bool isCurrentUser = widget.post.userId == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUser) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Post'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPostScreen(post: widget.post),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Post'),
                            content: const Text(
                              'Are you sure you want to delete this post?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
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
            ],
          ),
    );
  }

  @override
  void didUpdateWidget(SeamlessPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.likes != widget.post.likes) {
      _localLikes = List.from(widget.post.likes);
      _isLiked = _localLikes.contains(_auth.currentUser?.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          widget.isClickable
              ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostScreen(post: widget.post),
                  ),
                );
              }
              : null,
      child: Column(
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => UserProfileScreen(
                                  userId: widget.post.userId,
                                  username: widget.post.userName,
                                ),
                          ),
                        );
                      },
                      child: ProfileImageWidget(
                        imageUrl: widget.post.userAvatar,
                        radius: 23,
                        fallbackName: widget.post.userName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => UserProfileScreen(
                                    userId: widget.post.userId,
                                    username: widget.post.userName,
                                  ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${widget.post.displayName} ',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  TextSpan(
                                    text: widget.post.formattedUsername,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
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
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPostOptions,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.more_vert),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Post content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.post.content),
                    if (widget.post.movieId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // Movie info
                      Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => MovieDetailsScreen(
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.post.moviePosterUrl,
                                width: 60,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
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
                                if (widget.post.rating > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      ...List.generate(
                                        widget.post.rating.ceil(),
                                        (index) {
                                          if (index <
                                              widget.post.rating.floor()) {
                                            return Icon(
                                              Icons.star,
                                              size: 20,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                            );
                                          } else if (index ==
                                                  widget.post.rating.floor() &&
                                              widget.post.rating % 1 >= 0.5) {
                                            return Icon(
                                              Icons.star_half,
                                              size: 20,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                            );
                                          } else {
                                            return Icon(
                                              Icons.star_outlined,
                                              size: 20,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.post.rating % 1 == 0.5
                                            ? '${widget.post.rating}/5'
                                            : '${widget.post.rating.toInt()}/5',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color:
                            _isLiked
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      onPressed: _handleLike,
                      padding: const EdgeInsets.all(1),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    Text(
                      _localLikes.length.toString(),
                      style: TextStyle(
                        color:
                            _isLiked
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight:
                            _isLiked ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.comment,
                        color: colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      onPressed:
                          widget.isClickable
                              ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            PostScreen(post: widget.post),
                                  ),
                                );
                              }
                              : null,
                      padding: const EdgeInsets.all(1),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    Text(
                      widget.post.commentCount.toString(),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
