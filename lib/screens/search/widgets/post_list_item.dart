import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/post.dart';
import '../../../models/user.dart';
import '../../../widgets/profile_image_widget.dart';
import '../../../screens/post_screen.dart';
import '../../../services/profile_service.dart';
import 'package:intl/intl.dart';
import '../../../screens/user_profile_screen.dart';
import '../../../screens/movie_details_screen.dart';
import '../../../models/movie.dart';

class PostListItem extends StatefulWidget {
  final Post post;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const PostListItem({
    Key? key,
    required this.post,
    required this.auth,
    required this.firestore,
  }) : super(key: key);

  @override
  _PostListItemState createState() => _PostListItemState();
}

class _PostListItemState extends State<PostListItem> {
  final ProfileService _profileService = ProfileService();
  UserModel? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final user = await _profileService.getUserProfile(widget.post.userId);
      if (mounted) {
        setState(() {
          _userData = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data for post: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostScreen(post: widget.post),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _isLoading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : ProfileImageWidget(
                          imageUrl:
                              _userData?.profileImageUrl ??
                              widget.post.userAvatar,
                          radius: 20,
                          fallbackName:
                              _userData?.username ?? widget.post.userName,
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?.displayName ??
                                _userData?.username ??
                                widget.post.userName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DateFormat(
                              'MMM d, yyyy '
                              'h:mm a',
                            ).format(widget.post.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
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
                        widget.post.moviePosterUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 90,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.1),
                            child: Icon(
                              Icons.movie,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.5),
                            ),
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
                            widget.post.movieTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.post.movieYear,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.post.rating > 0)
                            Row(
                              children: List.generate(
                                widget.post.rating.ceil(),
                                (index) {
                                  if (index < widget.post.rating.floor()) {
                                    return const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  } else if (index ==
                                          widget.post.rating.floor() &&
                                      widget.post.rating % 1 >= 0.5) {
                                    return const Icon(
                                      Icons.star_half,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  } else {
                                    return const Icon(
                                      Icons.star_outlined,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.post.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.color?.withOpacity(0.9),
                  ),
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
                          widget.post.likes.contains(
                                widget.auth.currentUser?.uid,
                              )
                              ? Colors.red
                              : Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.likes.length.toString(),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.commentCount.toString(),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
