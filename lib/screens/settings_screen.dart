import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../screens/profile_edit_screen.dart';
import '../screens/sign_in_screen.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
import '../services/haptic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SettingsService _settingsService = SettingsService();
  final HapticService _hapticService = HapticService();

  // Admin emails for development tools
  final List<String> _adminEmails = [
    'admin@example.com',
    // Add other admin emails
  ];

  // Settings state
  bool _notificationsEnabled = true;
  bool _privacyModeEnabled = false;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final userDoc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();

      if (userDoc.exists) {
        setState(() {
          _notificationsEnabled =
              userDoc.data()?['notificationsEnabled'] ?? true;
          _privacyModeEnabled = userDoc.data()?['privacyModeEnabled'] ?? false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading settings: $e');
    }
  }

  Future<void> _updateSetting(String field, dynamic value) async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        field: value,
      });

      _showSuccessSnackBar('Settings updated');
    } catch (e) {
      _showErrorSnackBar('Error updating settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    await _settingsService.initialize();
    setState(() {
      _hapticEnabled = _settingsService.hapticEnabled;
    });
  }

  Future<void> _toggleHapticFeedback(bool value) async {
    setState(() {
      _hapticEnabled = value;
    });
    await _settingsService.setHapticEnabled(value);
    _hapticService.setEnabled(value);
    if (value) {
      await _hapticService.selection();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Check if current user is an admin
  bool _isAdminUser() {
    return _adminEmails.contains(_auth.currentUser?.email);
  }

  // Sign out method
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error signing out: $e');
    }
  }

  // Account deletion method
  Future<void> _deleteAccount() async {
    try {
      final userId = _auth.currentUser!.uid;

      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete user's notifications
      final notifications =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .get();
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      // Delete user's search history
      final searchHistory =
          await _firestore
              .collection('userSearches')
              .doc(userId)
              .collection('recent')
              .get();
      for (var doc in searchHistory.docs) {
        await doc.reference.delete();
      }

      // Delete user's preferences
      await _firestore.collection('user_preferences').doc(userId).delete();

      // Delete user's profile image from Storage if it exists
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final profileImageUrl = userDoc.data()?['profileImageUrl'];
        if (profileImageUrl != null && profileImageUrl.startsWith('http')) {
          final ref = FirebaseStorage.instance.refFromURL(profileImageUrl);
          await ref.delete();
        }
      } catch (e) {
        print('Error deleting profile image: $e');
      }

      // Delete user authentication
      await _auth.currentUser!.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting account: $e');
    }
  }

  // Settings section widget
  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  // Settings item widget
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account & Profile Section
          _buildSettingsSection(
            title: 'Account',
            children: [
              // Profile Edit
              _buildSettingsItem(
                icon: Icons.person,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileEditScreen(),
                      ),
                    ),
              ),

              // Email Verification Status
              StreamBuilder<DocumentSnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(_auth.currentUser!.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  bool isVerified = false;

                  if (snapshot.hasData && snapshot.data != null) {
                    isVerified = snapshot.data!['emailVerified'] ?? false;
                  }

                  return _buildSettingsItem(
                    icon: Icons.email,
                    title: 'Email',
                    subtitle: _auth.currentUser?.email ?? 'No email',
                    trailing:
                        isVerified
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.warning, color: Colors.orange),
                  );
                },
              ),
            ],
          ),

          // Security Section
          _buildSettingsSection(
            title: 'Security',
            children: [
              // Change Password
              _buildSettingsItem(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your account password',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement password change
                  _showErrorSnackBar('Feature coming soon');
                },
              ),
            ],
          ),
          // Account Actions Section
          _buildSettingsSection(
            title: 'Account Actions',
            children: [
              // Sign Out
              _buildSettingsItem(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Log out of your account',
                onTap: _signOut,
              ),

              // Delete Account
              _buildSettingsItem(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                subtitle: 'Permanently remove your account',
                onTap: () => _showDeleteConfirmationDialog(),
              ),
            ],
          ),

          // About Section
          _buildSettingsSection(
            title: 'About',
            children: [
              _buildSettingsItem(
                icon: Icons.info,
                title: 'App Version',
                subtitle: 'Ceema v1.0.0',
              ),
              _buildSettingsItem(
                icon: Icons.description,
                title: 'Terms of Service',
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: Implement Terms of Service
                  _showErrorSnackBar('Feature coming soon');
                },
              ),
              _buildSettingsItem(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: Implement Privacy Policy
                  _showErrorSnackBar('Feature coming soon');
                },
              ),
            ],
          ),

          // Appearance Section
          _buildSettingsSection(
            title: 'Appearance',
            children: [
              _buildSettingsItem(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Toggle between light and dark theme',
                trailing: Consumer<ThemeService>(
                  builder: (context, themeService, child) {
                    return Switch(
                      value: themeService.isDarkMode,
                      onChanged: (value) {
                        themeService.toggleTheme();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
              ),
            ],
          ),

          // Haptic Feedback Section
          _buildSettingsSection(
            title: 'Haptic Feedback',
            children: [
              _buildSettingsItem(
                icon: Icons.vibration,
                title: 'Haptic Feedback',
                subtitle: 'Enable or disable haptic feedback',
                trailing: Switch(
                  value: _hapticEnabled,
                  onChanged: _toggleHapticFeedback,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
