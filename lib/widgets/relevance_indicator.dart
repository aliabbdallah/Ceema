// lib/widgets/relevance_indicator.dart
import 'package:flutter/material.dart';
import '../models/timeline_activity.dart';

class RelevanceIndicator extends StatelessWidget {
  final String reason;
  final IconData? icon;
  final Color? color;
  final double relevanceScore;
  final TimelineItemType? itemType;

  const RelevanceIndicator({
    Key? key,
    required this.reason,
    this.icon,
    this.color,
    this.relevanceScore = 0.0,
    this.itemType,
  }) : super(key: key);

  IconData _getReasonIcon() {
    if (icon != null) return icon!;
    if (itemType == null) return Icons.recommend;

    switch (itemType) {
      case TimelineItemType.friendPost:
        return Icons.people;
      case TimelineItemType.friendRating:
        return Icons.star;
      case TimelineItemType.recommendation:
        return Icons.recommend;
      case TimelineItemType.trendingMovie:
        return Icons.trending_up;
      case TimelineItemType.similarToLiked:
        return Icons.thumb_up;
      case TimelineItemType.friendWatched:
        return Icons.visibility;
      case TimelineItemType.newReleaseGenre:
        return Icons.movie_filter;
      default:
        return Icons.recommend;
    }
  }

  Color _getReasonColor(BuildContext context) {
    if (color != null) return color!;
    final colorScheme = Theme.of(context).colorScheme;

    if (itemType == null) return colorScheme.primary;

    switch (itemType) {
      case TimelineItemType.friendPost:
        return Colors.blue;
      case TimelineItemType.friendRating:
        return Colors.amber;
      case TimelineItemType.recommendation:
        return colorScheme.primary;
      case TimelineItemType.trendingMovie:
        return Colors.orange;
      case TimelineItemType.similarToLiked:
        return Colors.purple;
      case TimelineItemType.friendWatched:
        return Colors.teal;
      case TimelineItemType.newReleaseGenre:
        return Colors.indigo;
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usedColor = _getReasonColor(context);
    final usedIcon = _getReasonIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: usedColor.withOpacity(0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: usedColor.withOpacity(0.3), width: 1),
          left: BorderSide(color: usedColor.withOpacity(0.3), width: 1),
          right: BorderSide(color: usedColor.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            usedIcon,
            size: 16,
            color: usedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (relevanceScore > 0) ...[
            // Show relevance dots
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                // Calculate dot color based on relevance score (0-1)
                final dotValue = (index + 1) * 0.2;
                final isActive = relevanceScore >= dotValue;
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? usedColor : usedColor.withOpacity(0.2),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
