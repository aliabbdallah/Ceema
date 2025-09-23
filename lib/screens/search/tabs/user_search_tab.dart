import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../widgets/user_list_item.dart';
import '../widgets/search_initial_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/follow_service.dart';
import '../../../services/follow_request_service.dart';

class UserSearchTab extends StatelessWidget {
  final List<UserModel> userResults;
  final List<UserModel> recentSearches;
  final List<UserModel> suggestedUsers;
  final bool isLoading;
  final bool isSearchActive;
  final FollowService followService;
  final FollowRequestService requestService;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Function(UserModel) onRemoveFromHistory;
  final Function() onRefresh;

  const UserSearchTab({
    Key? key,
    required this.userResults,
    required this.recentSearches,
    required this.suggestedUsers,
    required this.isLoading,
    required this.isSearchActive,
    required this.followService,
    required this.requestService,
    required this.auth,
    required this.firestore,
    required this.onRemoveFromHistory,
    required this.onRefresh,
  }) : super(key: key);

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && userResults.isEmpty) {
      return _buildEmptyState();
    }

    if (userResults.isNotEmpty) {
      return ListView.builder(
        itemCount: userResults.length,
        itemBuilder:
            (context, index) => UserListItem(
              user: userResults[index],
              followService: followService,
              requestService: requestService,
              auth: auth,
              onRemoveFromHistory: onRemoveFromHistory,
              onRefresh: onRefresh,
            ),
      );
    }

    return SearchInitialView(
      recentSearches: recentSearches,
      suggestedUsers: suggestedUsers,
      followService: followService,
      requestService: requestService,
      auth: auth,
      onRemoveFromHistory: onRemoveFromHistory,
      onRefresh: onRefresh,
    );
  }
}
