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
      builder: (context) => Column(
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
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Your Movie Stats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                  _isStatsExpanded ? Icons.expand_less : Icons.expand_more),
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
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
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
                      color: _selectedFilter == 'all'
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: _selectedFilter == 'Favorites',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'Favorites');
                    },
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'Favorites'
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Rewatches'),
                    selected: _selectedFilter == 'Rewatches',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'Rewatches');
                    },
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'Rewatches'
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _sortAndFilterEntries(List<DiaryEntry> entries) {
    // Apply filters
    var filteredEntries = entries.where((entry) {
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

  Widget _buildDiaryEntry(DiaryEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryEntryDetails(entry: entry),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.moviePosterUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.movieTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (entry.isFavorite)
                          const Icon(Icons.favorite,
                              color: Colors.red, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM d, yyyy').format(entry.watchedDate),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < entry.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          entry.rating.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (entry.review.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.review,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    if (entry.isRewatch) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.replay, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Rewatch',
                            style: TextStyle(
                              color: Colors.grey[600],
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
        ),
      ),
    );
  }

  void _handleMovieSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) => MovieSelectionDialog(
        onMovieSelected: (Movie selectedMovie) {
          // Close the dialog
          Navigator.pop(context);

          // Navigate to the DiaryEntryForm
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryEntryForm(
                movie: selectedMovie,
              ),
            ),
          ).then((_) {
            // Refresh stats when returning from the form
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
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              // TODO: Navigate to detailed stats/analytics screen
            },
          ),
        ],
      ),
      body: StreamBuilder<List<DiaryEntry>>(
        stream: _diaryService.getDiaryEntries(_auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
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
                child: entries.isEmpty
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
                    : GroupedListView<DiaryEntry, String>(
                        elements: entries,
                        groupBy: (entry) =>
                            DateFormat('MMMM yyyy').format(entry.watchedDate),
                        groupSeparatorBuilder: (String groupByValue) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            groupByValue,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        itemBuilder: (context, entry) =>
                            _buildDiaryEntry(entry),
                        useStickyGroupSeparators: true,
                        floatingHeader: true,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MovieSelectionDialog(
              onMovieSelected: (movie) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiaryEntryForm(movie: movie),
                  ),
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
