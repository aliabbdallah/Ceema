// widgets/timeline_item.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import '../screens/movie_details_screen.dart';
import '../screens/user_profile_screen.dart';
import '../models/movie.dart';

class TimelineItem extends StatelessWidget {
  final Post post;
  final String?
  relevanceReason; // Why this is shown (e.g., "Because you liked Inception")
  final bool isHighlighted;
  final double?
  relevanceScore; // Optional score (0.0-1.0) to show how relevant this is

  const TimelineItem({
    Key? key,
    required this.post,
    this.relevanceReason,
    this.isHighlighted = false,
    this.relevanceScore,
  }) : super(key: key);

  Color _getRelevanceColor(BuildContext context, double score) {
    final colorScheme = Theme.of(context).colorScheme;

    if (score >= 0.8) return colorScheme.primary;
    if (score >= 0.6) return colorScheme.secondary;
    if (score >= 0.4) return colorScheme.tertiary;
    return colorScheme.onSurfaceVariant;
  }

  IconData _getRelevanceIcon(String? reason) {
    if (reason == null) return Icons.recommend;

    final lowerReason = reason.toLowerCase();

    if (lowerReason.contains('friend') || lowerReason.contains('follow')) {
      return Icons.people;
    } else if (lowerReason.contains('liked') ||
        lowerReason.contains('enjoyed')) {
      return Icons.thumb_up;
    } else if (lowerReason.contains('watched') ||
        lowerReason.contains('viewed')) {
      return Icons.visibility;
    } else if (lowerReason.contains('genre') ||
        lowerReason.contains('similar')) {
      return Icons.movie_filter;
    } else if (lowerReason.contains('trending') ||
        lowerReason.contains('popular')) {
      return Icons.trending_up;
    } else if (lowerReason.contains('director') ||
        lowerReason.contains('actor')) {
      return Icons.person;
    }

    return Icons.recommend;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isHighlighted ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            isHighlighted
                ? BorderSide(
                  color: colorScheme.primary.withOpacity(0.5),
                  width: 1,
                )
                : BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If there's a relevance reason, show it at the top with improved styling
          if (relevanceReason != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getRelevanceIcon(relevanceReason),
                    size: 16,
                    color:
                        relevanceScore != null
                            ? _getRelevanceColor(context, relevanceScore!)
                            : colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: 'Recommendation: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  relevanceScore != null
                                      ? _getRelevanceColor(
                                        context,
                                        relevanceScore!,
                                      )
                                      : colorScheme.primary,
                            ),
                          ),
                          TextSpan(text: relevanceReason!),
                        ],
                      ),
                    ),
                  ),
                  if (relevanceScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRelevanceColor(
                          context,
                          relevanceScore!,
                        ).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(relevanceScore! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getRelevanceColor(context, relevanceScore!),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Post content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info with profile navigation
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => UserProfileScreen(
                              userId: post.userId,
                              username: post.userName,
                            ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(post.userAvatar),
                        radius: 20,
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
                            Text(
                              timeago.format(post.createdAt),
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
                ),
                const SizedBox(height: 12),

                // Post text content
                Text(
                  post.content,
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 16),

                // Movie card
                if (post.movieId.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MovieDetailsScreen(
                                movie: Movie(
                                  id: post.movieId,
                                  title: post.movieTitle,
                                  posterUrl: post.moviePosterUrl,
                                  year: post.movieYear,
                                  overview: post.movieOverview,
                                ),
                              ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: Image.network(
                              post.moviePosterUrl,
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
                                  post.movieTitle,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.movieYear,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (post.rating > 0)
                                  Row(
                                    children: List.generate(
                                      post.rating.ceil(),
                                      (index) {
                                        if (index < post.rating.floor()) {
                                          return Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          );
                                        } else if (index ==
                                                post.rating.floor() &&
                                            post.rating % 1 >= 0.5) {
                                          return Icon(
                                            Icons.star_half,
                                            color: Colors.amber,
                                            size: 16,
                                          );
                                        } else {
                                          return Icon(
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
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),

                // Post interaction stats
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        post.likes.length.toString(),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.comment,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.commentCount.toString(),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
