import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/watchlist_item.dart';
import '../services/watchlist_service.dart';
import '../widgets/star_rating.dart';
import 'movie_details_screen.dart';
import 'diary_entry_form.dart';

class WatchlistScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const WatchlistScreen({
    Key? key,
    required this.userId,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  _WatchlistScreenState createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final WatchlistService _watchlistService = WatchlistService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<WatchlistItem> _watchlistItems = [];
  bool _isLoading = true;
  String? _selectedGenre;
  String? _selectedYear;
  String _sortBy = 'addedAt';
  bool _sortDescending = true;

  // List of available genres (this would typically come from your data)
  final List<String> _genres = [
    'Action',
    'Adventure',
    'Animation',
    'Comedy',
    'Crime',
    'Documentary',
    'Drama',
    'Family',
    'Fantasy',
    'History',
    'Horror',
    'Music',
    'Mystery',
    'Romance',
    'Science Fiction',
    'Thriller',
    'War',
    'Western',
  ];

  // List of years (last 100 years)
  final List<String> _years = List.generate(
    100,
    (index) => (DateTime.now().year - index).toString(),
  );

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _watchlistService.getFilteredWatchlist(
        userId: widget.userId,
        genre: _selectedGenre,
        year: _selectedYear,
        sortBy: _sortBy,
        descending: _sortDescending,
      );

      setState(() {
        _watchlistItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading watchlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? tempGenre = _selectedGenre;
        String? tempYear = _selectedYear;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Watchlist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Genre'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: tempGenre,
                      hint: const Text('All Genres'),
                      onChanged: (value) {
                        setState(() {
                          tempGenre = value;
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Genres'),
                        ),
                        ..._genres.map((genre) {
                          return DropdownMenuItem<String>(
                            value: genre,
                            child: Text(genre),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Year'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: tempYear,
                      hint: const Text('All Years'),
                      onChanged: (value) {
                        setState(() {
                          tempYear = value;
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Years'),
                        ),
                        ..._years.map((year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedGenre = tempGenre;
                      _selectedYear = tempYear;
                    });
                    _loadWatchlist();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempSortBy = _sortBy;
        bool tempSortDescending = _sortDescending;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Sort Watchlist'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Recently Added'),
                    value: 'addedAt',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      setState(() {
                        tempSortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Title'),
                    value: 'title',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      setState(() {
                        tempSortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Year'),
                    value: 'year',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      setState(() {
                        tempSortBy = value!;
                      });
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      tempSortDescending ? 'Descending' : 'Ascending',
                    ),
                    value: tempSortDescending,
                    onChanged: (value) {
                      setState(() {
                        tempSortDescending = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _sortBy = tempSortBy;
                      _sortDescending = tempSortDescending;
                    });
                    _loadWatchlist();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showItemActions(WatchlistItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('View Movie Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MovieDetailsScreen(movie: item.movie),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.rate_review),
                title: const Text('Mark as Watched'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaryEntryForm(movie: item.movie),
                    ),
                  ).then((_) {
                    // Remove from watchlist after adding to diary
                    _watchlistService.removeFromWatchlist(
                      item.id,
                      widget.userId,
                    );
                    _loadWatchlist();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove from Watchlist'),
                onTap: () async {
                  Navigator.pop(context);
                  await _watchlistService.removeFromWatchlist(
                    item.id,
                    widget.userId,
                  );
                  _loadWatchlist();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from watchlist'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatchlistItem(WatchlistItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: item.movie),
            ),
          );
        },
        onLongPress: () => _showItemActions(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.movie.posterUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              // Movie details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.movie.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.movie.year,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.movie.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Added ${_formatDate(item.addedAt)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            DiaryEntryForm(movie: item.movie),
                                  ),
                                ).then((_) {
                                  // Remove from watchlist after adding to diary
                                  _watchlistService.removeFromWatchlist(
                                    item.id,
                                    widget.userId,
                                  );
                                  _loadWatchlist();
                                });
                              },
                              tooltip: 'Mark as watched',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await _watchlistService.removeFromWatchlist(
                                  item.id,
                                  widget.userId,
                                );
                                _loadWatchlist();
                              },
                              tooltip: 'Remove from watchlist',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Sort',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _watchlistItems.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your watchlist is empty',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add movies you want to watch later',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _watchlistItems.length,
                itemBuilder: (context, index) {
                  return _buildWatchlistItem(_watchlistItems[index]);
                },
              ),
    );
  }
}
