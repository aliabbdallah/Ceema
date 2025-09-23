// home/components/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/post_service.dart';
import '../services/profile_service.dart';
import '../services/diary_service.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';
import '../screens/watchlist_screen.dart';
import '../widgets/profile_image_widget.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'follow_requests_screen.dart';
import '../home/components/post_card.dart';
import 'diary_entry_details.dart';
import 'package:intl/intl.dart';
import 'podium_edit_screen.dart';
import '../widgets/podium_widget.dart';
import '../screens/movie_details_screen.dart';
import 'watched_movies_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'full_screen_image_viewer.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    Key? key,
    required this.userId,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostService _postService = PostService();
  final ProfileService _profileService = ProfileService();
  final DiaryService _diaryService = DiaryService();
  late TabController _tabController;
  String _selectedTab = 'posts';
  late BehaviorSubject<UserModel> _userSubject;
  StreamSubscription? _userSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userSubject = BehaviorSubject<UserModel>();
    _setupUserStream();
  }

  void _setupUserStream() {
    // Cancel any existing subscription
    _userSubscription?.cancel();

    // Create new subscription with error handling
    _userSubscription = _profileService
        .getUserProfileStream(widget.userId)
        .listen(
          (user) {
            if (mounted) {
              _userSubject.add(user);
            }
          },
          onError: (error) {
            if (mounted) {
              // Show error in UI
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading profile: $error'),
                  backgroundColor: Colors.red,
                ),
              );
              // Try to refresh the data
              _refreshProfile();
            }
          },
        );
  }

  // Method to manually refresh profile data
  Future<void> _refreshProfile() async {
    try {
      final user = await _profileService.getUserProfile(widget.userId);
      if (mounted) {
        _userSubject.add(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSubscription?.cancel();
    _userSubject.close();
    _scrollController.dispose();
    super.dispose();
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                entry.moviePosterUrl,
                width: 60,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM d, yyyy').format(entry.watchedDate),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < entry.rating ? Icons.star : Icons.star_border,
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
                      const Spacer(),
                      if (entry.isFavorite)
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                      if (entry.isRewatch) ...[
                        if (entry.isFavorite) const SizedBox(width: 8),
                        const Icon(Icons.replay, size: 16),
                      ],
                    ],
                  ),
                  if (entry.review.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.review,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryList() {
    return StreamBuilder<List<DiaryEntry>>(
      stream: _diaryService.getDiaryEntries(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!;

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No diary entries yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isNewMonth =
                index == 0 ||
                DateFormat(
                      'MMMM yyyy',
                    ).format(entries[index - 1].watchedDate) !=
                    DateFormat('MMMM yyyy').format(entry.watchedDate);

            return Column(
              children: [
                if (isNewMonth)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.surface,
                    child: Text(
                      DateFormat(
                        'MMMM yyyy',
                      ).format(entry.watchedDate).toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                _buildDiaryEntry(entry),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, int value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStats(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Following', user.followingCount, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => FollowingScreen(targetUserId: widget.userId),
              ),
            );
          }),
          _buildStatItem('Followers', user.followersCount, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => FollowersScreen(targetUserId: widget.userId),
              ),
            );
          }),
          _buildStatItem('Watchlist', user.watchlistCount, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => WatchlistScreen(
                      userId: widget.userId,
                      isCurrentUser: widget.isCurrentUser,
                    ),
              ),
            );
          }),
          _buildStatItem('Watched', user.watchedCount ?? 0, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => WatchedMoviesScreen(
                      userId: widget.userId,
                      isCurrentUser: widget.isCurrentUser,
                    ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPodiumSection(UserModel user) {
    bool hasPodium = user.podiumMovies.isNotEmpty;

    if (!hasPodium && !widget.isCurrentUser) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Podium',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          hasPodium
              ? PodiumWidget(
                movies: user.podiumMovies,
                isEditable: widget.isCurrentUser,
                onMovieTap: (movie) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MovieDetailsScreen(
                            movie: Movie(
                              id: movie.tmdbId,
                              title: movie.title,
                              posterUrl: movie.posterUrl,
                              year: '',
                              overview: '',
                            ),
                          ),
                    ),
                  );
                },
                onRankTap:
                    widget.isCurrentUser
                        ? (rank) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PodiumEditScreen(),
                            ),
                          );
                        }
                        : null,
              )
              : Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Set Up Your Podium'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PodiumEditScreen(),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return FutureBuilder<List<Post>>(
      future: _postService.fetchUserPostsOnce(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!;

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No posts yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return SeamlessPostCard(post: posts[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<UserModel>(
        stream: _userSubject.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(user.username),
                pinned: true,
                actions: [
                  if (widget.isCurrentUser) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Profile',
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileEditScreen(),
                            ),
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_active_outlined),
                      tooltip: 'Follow Requests',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FollowRequestsScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          ),
                    ),
                  ],
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1.0),
                  child: Container(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    height: 1.0,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    ProfileImageWidget(
                      imageUrl: user.profileImageUrl ?? '',
                      radius: 50,
                      fallbackName: user.username,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            barrierColor: Colors.transparent,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    FullScreenImageViewer(
                                      imageUrl: user.profileImageUrl ?? '',
                                      fallbackText: user.username,
                                    ),
                            transitionsBuilder: (
                              context,
                              animation,
                              secondaryAnimation,
                              child,
                            ) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.displayName ?? user.username,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildProfileStats(user),
                    _buildPodiumSection(user),
                    TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        setState(() {
                          _selectedTab = index == 0 ? 'posts' : 'diary';
                        });
                      },
                      tabs: const [Tab(text: 'Posts'), Tab(text: 'Diary')],
                      labelColor: Theme.of(context).colorScheme.secondary,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: Theme.of(context).colorScheme.secondary,
                      indicatorWeight: 3.0,
                    ),
                    const Divider(height: 1, thickness: 1),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _selectedTab == 'posts'
                              ? _buildPostList()
                              : _buildDiaryList(),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
