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

  bool _isLoadingFriendship = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index == 0 ? 'posts' : 'diary';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Widget _buildFollowButton() {
    if (_auth.currentUser!.uid == widget.userId) {
      return Container();
    }

    return FutureBuilder<bool>(
      future: _checkFollowingStatus(),
      builder: (context, followingSnapshot) {
        if (!followingSnapshot.hasData) {
          return const SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(),
          );
        }

        if (followingSnapshot.data!) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Following'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            onPressed:
                _isLoadingFriendship
                    ? null
                    : () async {
                      setState(() {
                        _isLoadingFriendship = true;
                        _errorMessage = null;
                      });

                      try {
                        await _followService.unfollowUser(widget.userId);
                      } catch (e) {
                        setState(() {
                          _errorMessage = 'Failed to unfollow: $e';
                        });
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoadingFriendship = false;
                          });
                        }
                      }
                    },
          );
        }

        return FutureBuilder<FollowRequest?>(
          future: _checkPendingRequest(),
          builder: (context, requestSnapshot) {
            if (!requestSnapshot.hasData) {
              return const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(),
              );
            }

            if (requestSnapshot.data != null) {
              return ElevatedButton.icon(
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Request Sent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                onPressed:
                    _isLoadingFriendship
                        ? null
                        : () async {
                          setState(() {
                            _isLoadingFriendship = true;
                            _errorMessage = null;
                          });

                          try {
                            await _requestService.cancelFollowRequest(
                              requestSnapshot.data!.id,
                            );
                          } catch (e) {
                            setState(() {
                              _errorMessage = 'Failed to cancel request: $e';
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoadingFriendship = false;
                              });
                            }
                          }
                        },
              );
            }

            return ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Follow'),
              onPressed:
                  _isLoadingFriendship
                      ? null
                      : () async {
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
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            _errorMessage = 'Failed to send request: $e';
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoadingFriendship = false;
                            });
                          }
                        }
                      },
            );
          },
        );
      },
    );
  }

  Widget _buildUserStats(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InkWell(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  FollowingScreen(targetUserId: widget.userId),
                        ),
                      ),
                  child: _buildStatItem('Following', user.followingCount),
                ),
                InkWell(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  FollowersScreen(targetUserId: widget.userId),
                        ),
                      ),
                  child: _buildStatItem('Followers', user.followersCount),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => WatchlistScreen(
                              userId: widget.userId,
                              isCurrentUser:
                                  _auth.currentUser?.uid == widget.userId,
                            ),
                      ),
                    );
                  },
                  child: _buildStatItem('Watchlist', user.watchlistCount),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (user.podiumMovies.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              PodiumWidget(
                movies: user.podiumMovies,
                isEditable: _auth.currentUser?.uid == widget.userId,
                onMovieTap: (movie) {
                  // TODO: Navigate to movie details
                },
                onRankTap:
                    _auth.currentUser?.uid == widget.userId
                        ? (rank) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PodiumEditScreen(),
                            ),
                          );
                        }
                        : null,
              ),
            ] else if (_auth.currentUser?.uid == widget.userId) ...[
              const Divider(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create Your Podium'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PodiumEditScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildPostList() {
    return StreamBuilder<List<Post>>(
      stream: _postService.getUserPosts(widget.userId),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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
                expandedHeight: 200,
                floating: false,
                pinned: true,
                title: Text(
                  user.username,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                actions: [
                  if (_auth.currentUser?.uid == widget.userId)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  _buildFollowButton(),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.all(8),
                        color: Colors.red[100],
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ProfileImageWidget(
                      imageUrl: user.profileImageUrl,
                      radius: 50,
                      fallbackName: user.username,
                    ),
                    const SizedBox(height: 16),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildUserStats(user),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      tabs: const [Tab(text: 'Posts'), Tab(text: 'Diary')],
                    ),
                    const SizedBox(height: 16),
                    _selectedTab == 'posts'
                        ? _buildPostList()
                        : _buildDiaryList(),
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
