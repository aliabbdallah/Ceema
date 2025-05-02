import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import '../services/diary_service.dart';
import '../widgets/movie_selection_dialog.dart';
import '../widgets/loading_indicator.dart';
import 'diary_entry_form.dart';
import 'diary_entry_details.dart';
import 'edit_diary_entry_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({Key? key}) : super(key: key);

  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final DiaryService _diaryService = DiaryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _stats;
  String _selectedFilter = 'all';
  String _selectedSort = 'date_desc';
  bool _isStatsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _diaryService.getDiaryStats(_auth.currentUser!.uid);
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Date (Newest First)'),
                leading: const Icon(Icons.calendar_today),
                selected: _selectedSort == 'date_desc',
                onTap: () {
                  setState(() => _selectedSort = 'date_desc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Date (Oldest First)'),
                leading: const Icon(Icons.calendar_today_outlined),
                selected: _selectedSort == 'date_asc',
                onTap: () {
                  setState(() => _selectedSort = 'date_asc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Rating (High to Low)'),
                leading: const Icon(Icons.star),
                selected: _selectedSort == 'rating_desc',
                onTap: () {
                  setState(() => _selectedSort = 'rating_desc');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Rating (Low to High)'),
                leading: const Icon(Icons.star_border),
                selected: _selectedSort == 'rating_asc',
                onTap: () {
                  setState(() => _selectedSort = 'rating_asc');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  Widget _buildStats() {
    if (_stats == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Your Movie Stats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.2,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                _isStatsExpanded ? Icons.expand_less : Icons.expand_more,
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _isStatsExpanded = !_isStatsExpanded;
                });
              },
            ),
          ),
          if (_isStatsExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Movies\nWatched',
                    _stats!['totalMovies'].toString(),
                    Icons.movie,
                  ),
                  _buildStatItem(
                    'Average\nRating',
                    _stats!['averageRating'].toStringAsFixed(1),
                    Icons.star,
                  ),
                  _buildStatItem(
                    'Total\nRewatches',
                    _stats!['totalRewatches'].toString(),
                    Icons.replay,
                  ),
                  _buildStatItem(
                    'Total\nFavorites',
                    _stats!['totalFavorites'].toString(),
                    Icons.favorite,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'all');
                    },
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color:
                          _selectedFilter == 'all'
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: _selectedFilter == 'favorites',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'favorites');
                    },
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color:
                          _selectedFilter == 'favorites'
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Rewatches'),
                    selected: _selectedFilter == 'rewatches',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'rewatches');
                    },
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color:
                          _selectedFilter == 'rewatches'
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _sortAndFilterEntries(List<DiaryEntry> entries) {
    // Apply filters
    var filteredEntries =
        entries.where((entry) {
          switch (_selectedFilter) {
            case 'favorites':
              return entry.isFavorite;
            case 'rewatches':
              return entry.isRewatch;
            default:
              return true;
          }
        }).toList();

    // Apply sorting
    filteredEntries.sort((a, b) {
      switch (_selectedSort) {
        case 'date_asc':
          return a.watchedDate.compareTo(b.watchedDate);
        case 'rating_desc':
          return b.rating.compareTo(a.rating);
        case 'rating_asc':
          return a.rating.compareTo(b.rating);
        case 'date_desc':
        default:
          return b.watchedDate.compareTo(a.watchedDate);
      }
    });

    return filteredEntries;
  }

  Widget _buildStarRating(double rating) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 16,
      itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
      itemBuilder:
          (context, _) => const Icon(Icons.star, color: Colors.amber, size: 16),
      onRatingUpdate: (_) {},
      ignoreGestures: true,
    );
  }

  Widget _buildDiaryEntry(DiaryEntry entry) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryEntryDetails(entry: entry),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Container(
              width: 44,
              height: 100,
              alignment: Alignment.center,
              child: Text(
                DateFormat('d').format(entry.watchedDate),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Movie poster
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                entry.moviePosterUrl,
                width: 70,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            // Movie details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.movieTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit '),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.delete, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete '),
                                    ],
                                  ),
                                ),
                              ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              // Navigate to edit screen
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          EditDiaryEntryScreen(entry: entry),
                                ),
                              );

                              if (result == true) {
                                // Refresh the diary entries if edit was successful
                                _loadStats();
                              }
                            } else if (value == 'delete') {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Delete Entry'),
                                      content: const Text(
                                        'Are you sure you want to delete this diary entry?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirmed == true) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('diary_entries')
                                      .doc(entry.id)
                                      .delete();

                                  // Refresh the diary entries
                                  _loadStats();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Entry deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error deleting entry: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM d, yyyy').format(entry.watchedDate),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStarRating(entry.rating),
                      const SizedBox(width: 12),
                      Text(
                        entry.rating.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (entry.review.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.rate_review, size: 18),
                      ],
                      const Spacer(),
                      if (entry.isFavorite)
                        const Icon(Icons.favorite, color: Colors.red, size: 18),
                      if (entry.isRewatch) ...[
                        if (entry.isFavorite) const SizedBox(width: 12),
                        const Icon(Icons.replay, size: 18),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMovieSelection() {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => MovieSelectionDialog(
            onMovieSelected: (Movie selectedMovie) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEntryForm(movie: selectedMovie),
                ),
              ).then((_) {
                _loadStats();
              });
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Diary'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_by_alpha),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'date_desc',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        const Text('Date (Newest First)'),
                        if (_selectedSort == 'date_desc')
                          const Icon(Icons.check, size: 20),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'date_asc',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined),
                        const SizedBox(width: 8),
                        const Text('Date (Oldest First)'),
                        if (_selectedSort == 'date_asc')
                          const Icon(Icons.check, size: 20),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rating_desc',
                    child: Row(
                      children: [
                        const Icon(Icons.star),
                        const SizedBox(width: 8),
                        const Text('Rating (High to Low)'),
                        if (_selectedSort == 'rating_desc')
                          const Icon(Icons.check, size: 20),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rating_asc',
                    child: Row(
                      children: [
                        const Icon(Icons.star_border),
                        const SizedBox(width: 8),
                        const Text('Rating (Low to High)'),
                        if (_selectedSort == 'rating_asc')
                          const Icon(Icons.check, size: 20),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              setState(() => _selectedSort = value);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<DiaryEntry>>(
        stream: _diaryService.getDiaryEntries(_auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const LoadingIndicator(message: 'Loading diary...');
          }

          final entries = _sortAndFilterEntries(snapshot.data!);

          return Column(
            children: [
              _buildStats(),
              _buildFilterBar(),
              Expanded(
                child:
                    entries.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No entries found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final isNewMonth =
                                index == 0 ||
                                DateFormat(
                                      'MMMM yyyy',
                                    ).format(entries[index - 1].watchedDate) !=
                                    DateFormat(
                                      'MMMM yyyy',
                                    ).format(entry.watchedDate);

                            return Column(
                              children: [
                                if (isNewMonth)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    child: Text(
                                      DateFormat(
                                        'MMMM yyyy',
                                      ).format(entry.watchedDate).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                _buildDiaryEntry(entry),
                              ],
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleMovieSelection,
        child: const Icon(Icons.add),
      ),
    );
  }
}
