import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/post.dart';
import '../../../models/user.dart';
import '../../../widgets/profile_image_widget.dart';
import '../../../screens/post_screen.dart';

class PostListItem extends StatelessWidget {
  final Post post;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const PostListItem({
    Key? key,
    required this.post,
    required this.auth,
    required this.firestore,
  }) : super(key: key);

  Future<UserModel?> _getUserData(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
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
              MaterialPageRoute(builder: (context) => PostScreen(post: post)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              post.userAvatar.isNotEmpty
                                  ? post.userAvatar
                                  : null,
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Posted a review',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 12,
                            ),
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
                            post.movieTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.movieYear,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (post.rating > 0)
                            Row(
                              children: List.generate(post.rating.ceil(), (
                                index,
                              ) {
                                if (index < post.rating.floor()) {
                                  return const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                } else if (index == post.rating.floor() &&
                                    post.rating % 1 >= 0.5) {
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
                          post.likes.contains(auth.currentUser?.uid)
                              ? Colors.red
                              : Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.likes.length.toString(),
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
                      post.commentCount.toString(),
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
