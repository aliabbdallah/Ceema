import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trending_movies_section.dart';
import 'compose_post_section.dart';
import 'post_list.dart';
import 'app_bar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isComposing = false;

  void _showComposeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ComposePostSection(
                onCancel: () => Navigator.pop(context),
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const CustomAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Create Post Card
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: _showComposeSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              FirebaseAuth.instance.currentUser?.photoURL ??
                                  'https://ui-avatars.com/api/?name=${FirebaseAuth.instance.currentUser?.displayName ?? "User"}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Share your thoughts about a movie...',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.movie_outlined),
                            onPressed: _showComposeSheet,
                            tooltip: 'Select Movie',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const TrendingMoviesSection(),
              ],
            ),
          ),
          const PostList(),
        ],
      ),
    );
  }
}
