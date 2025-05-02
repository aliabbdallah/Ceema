import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../widgets/user_list_item.dart';
import '../../../services/follow_service.dart';
import '../../../services/follow_request_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchInitialView extends StatelessWidget {
  final List<UserModel> recentSearches;
  final List<UserModel> suggestedUsers;
  final FollowService followService;
  final FollowRequestService requestService;
  final FirebaseAuth auth;
  final Function(UserModel) onRemoveFromHistory;
  final Function() onRefresh;

  const SearchInitialView({
    Key? key,
    required this.recentSearches,
    required this.suggestedUsers,
    required this.followService,
    required this.requestService,
    required this.auth,
    required this.onRemoveFromHistory,
    required this.onRefresh,
  }) : super(key: key);

  Widget _buildRecentSearches() {
    if (recentSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('userSearches')
                        .doc(auth.currentUser!.uid)
                        .collection('recent')
                        .get()
                        .then((snapshot) {
                          for (final doc in snapshot.docs) {
                            doc.reference.delete();
                          }
                        });
                    onRefresh();
                  } catch (e) {
                    print('Error clearing search history: $e');
                  }
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        ...recentSearches.map(
          (user) => UserListItem(
            user: user,
            isRecent: true,
            followService: followService,
            requestService: requestService,
            auth: auth,
            onRemoveFromHistory: onRemoveFromHistory,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedUsers() {
    if (suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Suggested Users',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ...suggestedUsers.map(
          (user) => UserListItem(
            user: user,
            isSuggested: true,
            followService: followService,
            requestService: requestService,
            auth: auth,
            onRemoveFromHistory: onRemoveFromHistory,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentSearches(),
          _buildSuggestedUsers(),
          if (recentSearches.isEmpty && suggestedUsers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Find Friends',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Search for users to follow and connect with',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
