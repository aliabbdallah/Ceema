// home/components/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Widget _buildProfileStats(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  child: _buildStatColumn('Following', user.followingCount),
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
                  child: _buildStatColumn('Followers', user.followersCount),
                ),
                InkWell(
                  onTap: () {
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
                  },
                  child: _buildStatColumn('Watchlist', user.watchlistCount),
                ),
                InkWell(
                  onTap: () {
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
                  },
                  child: _buildStatColumn('Watched', user.watchedCount),
                ),
              ],
            ),
          ),
          if (user.podiumMovies.isNotEmpty || widget.isCurrentUser) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  user.podiumMovies.isNotEmpty
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
                                      builder:
                                          (context) => const PodiumEditScreen(),
                                    ),
                                  );
                                }
                                : null,
                      )
                      : ElevatedButton.icon(
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
            return SeamlessPostCard(post: posts[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading:
            widget.isCurrentUser
                ? null
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
        actions: [
          if (widget.isCurrentUser) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
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
              icon: const Icon(Icons.settings),
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
      ),
      body: StreamBuilder<UserModel>(
        stream: _profileService.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    ProfileImageWidget(
                      imageUrl: user.profileImageUrl,
                      radius: 50,
                      fallbackName: user.username,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.displayName ?? user.username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
                    _buildProfileStats(user),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        setState(() {
                          _selectedTab = index == 0 ? 'posts' : 'diary';
                        });
                      },
                      tabs: const [Tab(text: 'Posts'), Tab(text: 'Diary')],
                      labelColor: Theme.of(context).colorScheme.secondary,
                      unselectedLabelColor: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.5),
                      indicatorColor: Theme.of(context).colorScheme.secondary,
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
