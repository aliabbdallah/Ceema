// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/loading_indicator.dart';
import 'settings_screen.dart';
import '../widgets/profile_image_widget.dart';
import '../services/follow_service.dart';
import '../services/follow_request_service.dart';
import '../models/follow_request.dart';
import '../services/diary_service.dart';
import '../models/diary_entry.dart';
import 'diary_entry_details.dart';
import 'package:intl/intl.dart';
import 'watchlist_screen.dart';
import 'following_screen.dart';
import 'followers_screen.dart';
import '../home/components/post_card.dart';
import '../widgets/podium_widget.dart';
import '../screens/podium_edit_screen.dart';
import '../models/movie.dart';
import '../screens/movie_details_screen.dart';
import 'watched_movies_screen.dart';
import '../services/dm_service.dart';
import 'conversation_screen.dart';
import 'full_screen_image_viewer.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _profileService = ProfileService();
  final _postService = PostService();
  final _followService = FollowService();
  final _requestService = FollowRequestService();
  final _diaryService = DiaryService();
  late TabController _tabController;
  String _selectedTab = 'posts';
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingFriendship = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != (_selectedTab == 'posts' ? 0 : 1)) {
        setState(() {
          _selectedTab = _tabController.index == 0 ? 'posts' : 'diary';
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _checkFollowingStatus() async {
    try {
      return await _followService.isFollowing(widget.userId);
    } catch (e) {
      print('Error checking following status: $e');
      return false;
    }
  }

  Future<FollowRequest?> _checkPendingRequest() async {
    try {
      final requests =
          await _requestService.getPendingRequests(widget.userId).first;
      if (requests.isEmpty) return null;

      return requests.firstWhere(
        (request) => request.requesterId == _auth.currentUser!.uid,
        orElse: () => null as FollowRequest,
      );
    } catch (e) {
      print('Error checking pending request: $e');
      return null;
    }
  }

  Widget _buildMessageButton(UserModel user) {
    if (_auth.currentUser!.uid == widget.userId) {
      return Container();
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.message_outlined, size: 18),
      label: const Text('Message'),
      style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () async {
        final dmService = DMService();
        final conversationId = await dmService.createConversation(
          widget.userId,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ConversationScreen(
                    conversationId: conversationId,
                    otherUserId: widget.userId,
                    otherUsername: user.username,
                  ),
            ),
          );
        }
      },
    );
  }

  Widget _buildFollowButton(UserModel user) {
    if (_auth.currentUser!.uid == widget.userId) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit Profile'),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      );
    }

    return FutureBuilder<bool>(
      future: _checkFollowingStatus(),
      builder: (context, followingSnapshot) {
        if (!followingSnapshot.hasData) {
          return const SizedBox(
            height: 36,
            width: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final isFollowing = followingSnapshot.data!;

        if (isFollowing) {
          return OutlinedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Following'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
            ),
            onPressed: _isLoadingFriendship ? null : () => _unfollowUser(user),
          );
        }

        return FutureBuilder<FollowRequest?>(
          future: _checkPendingRequest(),
          builder: (context, requestSnapshot) {
            if (requestSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 36,
                width: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final hasPendingRequest = requestSnapshot.data != null;

            if (hasPendingRequest) {
              return OutlinedButton.icon(
                icon: const Icon(Icons.hourglass_empty, size: 18),
                label: const Text('Request Sent'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                onPressed:
                    _isLoadingFriendship
                        ? null
                        : () => _cancelRequest(requestSnapshot.data!.id, user),
              );
            }

            return ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Follow'),
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _isLoadingFriendship ? null : () => _followUser(user),
            );
          },
        );
      },
    );
  }

  Future<void> _unfollowUser(UserModel user) async {
    setState(() {
      _isLoadingFriendship = true;
      _errorMessage = null;
    });
    try {
      await _followService.unfollowUser(widget.userId);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to unfollow: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriendship = false);
      }
    }
  }

  Future<void> _cancelRequest(String requestId, UserModel user) async {
    setState(() {
      _isLoadingFriendship = true;
      _errorMessage = null;
    });
    try {
      await _requestService.cancelFollowRequest(requestId);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Failed to cancel request: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriendship = false);
      }
    }
  }

  Future<void> _followUser(UserModel user) async {
    setState(() {
      _isLoadingFriendship = true;
      _errorMessage = null;
    });
    try {
      final currentUser = _auth.currentUser!;
      await _requestService.sendFollowRequest(
        requesterId: currentUser.uid,
        targetId: widget.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow request sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Failed to send request: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriendship = false);
      }
    }
  }

  Widget _buildUserStats(UserModel user) {
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
                      isCurrentUser: _auth.currentUser?.uid == widget.userId,
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
                      isCurrentUser: _auth.currentUser?.uid == widget.userId,
                    ),
              ),
            );
          }),
        ],
      ),
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
            final post = posts[index];
            return SeamlessPostCard(post: post);
          },
        );
      },
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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

  // *** Start Add: Podium Section ***
  Widget _buildPodiumSection(UserModel user) {
    bool hasPodium = user.podiumMovies.isNotEmpty;

    // Only show if the user has set up their podium
    if (!hasPodium) {
      return const SizedBox.shrink(); // Return empty space if no podium
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
          PodiumWidget(
            movies: user.podiumMovies,
            isEditable: false, // Cannot edit other users' podiums
            onMovieTap: (movie) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MovieDetailsScreen(
                        // Adapt Movie creation based on PodiumMovie structure
                        movie: Movie(
                          id: movie.tmdbId,
                          title: movie.title,
                          posterUrl: movie.posterUrl,
                          year: '', // Add if available
                          overview: '', // Add if available
                        ),
                      ),
                ),
              );
            },
            onRankTap: null, // No action needed when tapping rank
          ),
        ],
      ),
    );
  }
  // *** End Add: Podium Section ***

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<UserModel>(
        stream: _profileService.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const LoadingIndicator(message: 'Loading profile...');
          }

          final user = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(user.username),
                actions: [
                  if (_auth.currentUser?.uid == widget.userId)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                ],
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
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

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFollowButton(user),
                          if (_auth.currentUser!.uid != widget.userId)
                            const SizedBox(width: 8),
                          _buildMessageButton(user),
                        ],
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

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),

                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    _buildUserStats(user),
                    const SizedBox(height: 8),

                    _buildPodiumSection(user),
                    TabBar(
                      controller: _tabController,
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

                    const SizedBox(height: 30),
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
