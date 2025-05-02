// screens/diary_entry_details.dart
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import 'diary_entry_form.dart';
import '../services/diary_service.dart';

class DiaryEntryDetails extends StatelessWidget {
  final DiaryEntry entry;
  final DiaryService _diaryService = DiaryService();

  DiaryEntryDetails({Key? key, required this.entry}) : super(key: key);

  Future<void> _deleteEntry(BuildContext context) async {
    final bool confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Entry'),
            content: const Text(
              'Are you sure you want to delete this diary entry?',
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

    if (confirm == true) {
      try {
        await _diaryService.deleteDiaryEntry(entry.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = Movie(
      id: entry.movieId,
      title: entry.movieTitle,
      posterUrl: entry.moviePosterUrl,
      year: entry.movieYear,
      overview: '',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          DiaryEntryForm(movie: movie, existingEntry: entry),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteEntry(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie info
            Hero(
              tag: 'movie_${entry.id}',
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        entry.moviePosterUrl,
                        width: 90,
                        height: 135,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.movieTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.movieYear,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(entry.rating.ceil(), (index) {
                                  if (index < entry.rating.floor()) {
                                    return Icon(
                                      Icons.star,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      size: 16,
                                    );
                                  } else if (index == entry.rating.floor() &&
                                      entry.rating % 1 >= 0.5) {
                                    return Icon(
                                      Icons.star_half,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      size: 16,
                                    );
                                  } else {
                                    return Icon(
                                      Icons.star_outlined,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      size: 16,
                                    );
                                  }
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  entry.rating.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 24, thickness: 0.5, color: Colors.grey[300]),

            // Watch info
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  title: const Text(
                    'Watched on',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    entry.watchedDate.toString().split(' ')[0],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (entry.isRewatch)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.replay,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                    title: const Text(
                      'Rewatch',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                if (entry.isFavorite)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 20,
                    ),
                    title: const Text(
                      'Added to favorites',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
            Divider(height: 24, thickness: 0.5, color: Colors.grey[300]),

            // Review
            if (entry.review.isNotEmpty) ...[
              const Text(
                'Your Review',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                entry.review,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
