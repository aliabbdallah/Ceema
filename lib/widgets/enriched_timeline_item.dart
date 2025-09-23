// widgets/enriched_timeline_item.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/timeline_activity.dart';
import '../models/post.dart';
import '../models/movie.dart';
import '../screens/movie_details_screen.dart';
import '../screens/user_profile_screen.dart';

class EnrichedTimelineItem extends StatelessWidget {
  final TimelineItem item;
  final VoidCallback? onActionPressed;

  const EnrichedTimelineItem({
    Key? key,
    required this.item,
    this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = item.getColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: item.relevanceScore > 0.7 ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              item.relevanceScore > 0.7
                  ? itemColor.withOpacity(0.5)
                  : colorScheme.outlineVariant,
          width: item.relevanceScore > 0.7 ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Relevance reason banner (if available)
          if (item.relevanceReason != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(item.getIcon(), size: 16, color: itemColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.relevanceReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content based on item type
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Build appropriate content based on the item type
    switch (item.type) {
      case TimelineItemType.friendPost:
        return _buildPostContent(context);
      case TimelineItemType.recommendation:
      case TimelineItemType.trendingMovie:
      case TimelineItemType.similarToLiked:
      case TimelineItemType.newReleaseGenre:
        return _buildMovieContent(context);
      case TimelineItemType.friendRating:
      case TimelineItemType.friendWatched:
        return _buildUserActivityContent(context);
    }
  }

  Widget _buildPostContent(BuildContext context) {
    final Post? post = item.post;
    if (post == null) return _buildDefaultContent(context);

    return Column(
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onActionPressed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Post text content
        Text(post.content, style: const TextStyle(fontSize: 15)),

        // Movie info (if available)
        if (post.movieId.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMovieCard(
            context,
            Movie(
              id: post.movieId,
              title: post.movieTitle,
              posterUrl: post.moviePosterUrl,
              year: post.movieYear,
              overview: post.movieOverview,
            ),
            showRating: post.rating > 0,
            rating: post.rating,
          ),
        ],

        // Post stats
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.red[400]),
              const SizedBox(width: 4),
              Text(
                post.likes.length.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.comment,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                post.commentCount.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovieContent(BuildContext context) {
    final Movie? movie = item.movie;
    if (movie == null) return _buildDefaultContent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Movie Type Label (Recommendation, Trending, etc)
        Row(
          children: [
            Icon(item.getIcon(), color: item.getColor(context), size: 20),
            const SizedBox(width: 8),
            Text(
              item.getDescription(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: item.getColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Movie card
        _buildMovieCard(context, movie, isLarge: true),

        // Action buttons
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add to Watchlist'),
              onPressed: () {
                // Add to watchlist functionality would go here
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.movie),
              label: const Text('View Details'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsScreen(movie: movie),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserActivityContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Extract user and movie data from item
    final String userName = item.data['userName'] ?? 'A user';
    final String movieTitle = item.data['movieTitle'] ?? 'a movie';
    final double? rating =
        item.data['rating'] is double ? item.data['rating'] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User activity description
        Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(item.data['userAvatar'] ?? ''),
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                  children: [
                    TextSpan(
                      text: userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' ${item.getDescription()} '),
                    TextSpan(
                      text: movieTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Rating if available
        if (rating != null) ...[
          Row(
            children: [
              ...List.generate(5, (index) {
                if (index < rating.floor()) {
                  return Icon(Icons.star, color: Colors.amber, size: 20);
                } else if (index == rating.floor() && rating % 1 > 0) {
                  return Icon(Icons.star_half, color: Colors.amber, size: 20);
                } else {
                  return Icon(Icons.star_border, color: Colors.amber, size: 20);
                }
              }),
              const SizedBox(width: 8),
              Text(
                rating.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Movie card if movie data available
        if (item.movie != null) _buildMovieCard(context, item.movie!),

        // Timestamp
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            timeago.format(item.timestamp),
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultContent(BuildContext context) {
    // Fallback content for unhandled item types
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline Update', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          item.data.toString(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildMovieCard(
    BuildContext context,
    Movie movie, {
    bool isLarge = false,
    bool showRating = false,
    double rating = 0.0,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie poster
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                movie.posterUrl,
                width: isLarge ? 100 : 80,
                height: isLarge ? 150 : 120,
                fit: BoxFit.cover,
              ),
            ),

            // Movie details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isLarge ? 18 : 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.year,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (showRating && rating > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            );
                          } else if (index == rating.floor() &&
                              rating % 1 > 0) {
                            return Icon(
                              Icons.star_half,
                              color: Colors.amber,
                              size: 16,
                            );
                          } else {
                            return Icon(
                              Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }
                        }),
                      ),
                    ],
                    if (isLarge && movie.overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movie.overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
