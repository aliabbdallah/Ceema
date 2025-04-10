import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:like_button/like_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post.dart';
import '../../models/movie.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';
import '../../screens/movie_details_screen.dart';
import '../../screens/comments_screen.dart';
import '../../screens/post_screen.dart';
import '../../widgets/profile_image_widget.dart';

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

  Future<bool> _onLikeButtonTapped(bool isLiked) async {
    try {
      await _postService.toggleLike(widget.post.id, _auth.currentUser!.uid);
      setState(() {
        _isLiked = !_isLiked;
      });
      return !isLiked;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return isLiked;
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
                    final controller = TextEditingController(
                      text: widget.post.content,
                    );
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Edit Post'),
                            content: TextField(
                              controller: controller,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Edit your post...',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await _postService.updatePostContent(
                                      widget.post.id,
                                      controller.text,
                                    );
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Post updated successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error updating post: $e',
                                          ),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostScreen(post: widget.post),
          ),
        );
      },
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
                        radius: 20,
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
                    LikeButton(
                      size: 25,
                      isLiked: _isLiked,
                      onTap: _onLikeButtonTapped,
                      likeBuilder: (bool isLiked) {
                        return Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color:
                              isLiked
                                  ? Colors.red
                                  : colorScheme.onSurfaceVariant,
                          size: 25,
                        );
                      },
                      likeCount: widget.post.likes.length,
                      countBuilder: (int? count, bool isLiked, String text) {
                        return Text(
                          text,
                          style: TextStyle(
                            color:
                                isLiked
                                    ? Colors.red
                                    : colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                      animationDuration: const Duration(milliseconds: 1000),
                      bubblesColor: const BubblesColor(
                        dotPrimaryColor: Colors.red,
                        dotSecondaryColor: Colors.redAccent,
                      ),
                      circleColor: const CircleColor(
                        start: Colors.red,
                        end: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CommentsScreen(post: widget.post),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.comment),
                          const SizedBox(width: 4),
                          Text(
                            widget.post.commentCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
