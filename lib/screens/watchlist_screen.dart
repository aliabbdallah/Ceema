import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/watchlist_item.dart';
import '../services/watchlist_service.dart';
import '../widgets/star_rating.dart'; // Re-import StarRating
import 'movie_details_screen.dart';
import '../services/movie_rating_service.dart';
import '../services/haptic_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _WatchlistScreenState extends State<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  final WatchlistService _watchlistService = WatchlistService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MovieRatingService _movieRatingService = MovieRatingService();
  final HapticService _hapticService = HapticService();
  StreamSubscription? _watchlistSubscription;
  late AnimationController _tutorialController;
  bool _showTutorial = false;
  GlobalKey _tutorialKey = GlobalKey();

  String? _selectedGenre;
  String? _selectedYear;
  String _sortBy = 'addedAt';
  bool _sortDescending = true;

  late Stream<List<WatchlistItem>> _watchlistStream;

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

  final List<String> _years = List.generate(
    100,
    (index) => (DateTime.now().year - index).toString(),
  );

  @override
  void initState() {
    super.initState();
    _setupWatchlistStream();
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _checkTutorialStatus();
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('hasSeenWatchlistTutorial') ?? false;

    if (!hasSeenTutorial && mounted) {
      setState(() {
        _showTutorial = true;
      });
      _tutorialController.repeat(reverse: true);
      await prefs.setBool('hasSeenWatchlistTutorial', true);
    }
  }

  void _setupWatchlistStream() {
    setState(() {
      _watchlistStream = _watchlistService.getFilteredWatchlistStream(
        userId: widget.userId,
        genre: _selectedGenre,
        year: _selectedYear,
        sortBy: _sortBy,
        descending: _sortDescending,
      );
    });
  }

  @override
  void dispose() {
    _watchlistSubscription?.cancel();
    _tutorialController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? tempGenre = _selectedGenre;
        String? tempYear = _selectedYear;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                'Filter Watchlist',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genre',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: tempGenre,
                      hint: Text(
                        'All Genres',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      onChanged: (value) {
                        setStateDialog(() {
                          tempGenre = value;
                        });
                      },
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'All Genres',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ..._genres.map((genre) {
                          return DropdownMenuItem<String>(
                            value: genre,
                            child: Text(
                              genre,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Year',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: tempYear,
                      hint: Text(
                        'All Years',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      onChanged: (value) {
                        setStateDialog(() {
                          tempYear = value;
                        });
                      },
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'All Years',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ..._years.map((year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(
                              year,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedGenre = tempGenre;
                      _selectedYear = tempYear;
                      _setupWatchlistStream();
                    });
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
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                'Sort Watchlist',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text(
                      'Date Added',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: 'addedAt',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      if (value != null)
                        setStateDialog(() => tempSortBy = value);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(
                      'Title',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: 'title',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      if (value != null)
                        setStateDialog(() => tempSortBy = value);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(
                      'Year',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: 'year',
                    groupValue: tempSortBy,
                    onChanged: (value) {
                      if (value != null)
                        setStateDialog(() => tempSortBy = value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      tempSortDescending ? 'Descending' : 'Ascending',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: tempSortDescending,
                    onChanged: (value) {
                      setStateDialog(() => tempSortDescending = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _sortBy = tempSortBy;
                      _sortDescending = tempSortDescending;
                      _setupWatchlistStream();
                    });
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
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('View Details'),
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
                leading: Icon(
                  Icons.visibility_outlined,
                  color: Colors.green[700],
                ),
                title: const Text('Mark as Watched & Rate'),
                onTap: () {
                  Navigator.pop(context);
                  _showRatingDialog(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red[700]),
                title: const Text('Remove from Watchlist'),
                onTap: () async {
                  Navigator.pop(context);
                  _removeFromWatchlist(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRatingDialog(WatchlistItem item) async {
    double? rating;
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rate Movie'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarRating(
                      rating: rating ?? 0,
                      onRatingChanged: (value) async {
                        setState(() => rating = value);
                        await _hapticService.selection();
                      },
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _hapticService.light();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (rating != null) {
                    await _hapticService.success();
                    await _movieRatingService.addOrUpdateRating(
                      userId: widget.userId,
                      movie: item.movie,
                      rating: rating!,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  Future<void> _removeFromWatchlist(WatchlistItem item) async {
    try {
      await _watchlistService.removeFromWatchlist(item.id, widget.userId);
      await _hapticService.success();
    } catch (e) {
      await _hapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove movie: $e')));
      }
    }
  }

  Widget _buildWatchlistItem(WatchlistItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) async {
              await _hapticService.medium();
              _showRatingDialog(item);
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.star,
            label: 'Rate',
          ),
          SlidableAction(
            onPressed: (context) async {
              await _hapticService.heavy();
              _removeFromWatchlist(item);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
          ),
        ],
      ),
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
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.movie.posterUrl,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null
                          ? child
                          : Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.movie.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ', ${item.movie.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (item.movie.director.isNotEmpty)
                      Text(
                        'Dir. ${item.movie.director}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          icon: Icons.visibility_outlined,
                          color: Colors.green[700]!,
                          tooltip: 'Mark as Watched & Rate',
                          onPressed: () => _showRatingDialog(item),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    if (!_showTutorial) return const SizedBox.shrink();

    return Stack(
      children: [
        // Semi-transparent background
        Container(color: Colors.black.withOpacity(0.5)),
        // Tutorial content
        Center(
          child: Container(
            width:
                MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            margin: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.of(context).size.width *
                  0.1, // Center horizontally
              vertical:
                  MediaQuery.of(context).size.height * 0.2, // Position from top
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swipe_left, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Swipe left to delete',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try swiping any movie to the left to remove it from your watchlist',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showTutorial = false;
                    });
                    _tutorialController.stop();
                  },
                  child: const Text('Got it!'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Watchlist'),
            backgroundColor:
                theme.appBarTheme.backgroundColor ?? colorScheme.primary,
            actions: [
              IconButton(
                icon: Icon(Icons.filter_alt_outlined),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
              ),
              IconButton(
                icon: Icon(Icons.sort_by_alpha_outlined),
                onPressed: _showSortDialog,
                tooltip: 'Sort by Date, Title, or Year',
              ),
            ],
          ),
          body: StreamBuilder<List<WatchlistItem>>(
            stream: _watchlistStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading watchlist: ${snapshot.error}',
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context);
              }

              final watchlistItems = snapshot.data!;
              return ListView.builder(
                itemCount: watchlistItems.length,
                itemBuilder: (context, index) {
                  return _buildWatchlistItem(watchlistItems[index]);
                },
              );
            },
          ),
        ),
        _buildTutorialOverlay(),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Watchlist is Empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the bookmark icon on a movie poster or details page to add movies you want to watch later.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
