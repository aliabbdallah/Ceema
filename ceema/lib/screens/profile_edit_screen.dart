import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:ceema/screens/podium_edit_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfileService _profileService = ProfileService();

  bool _isLoading = false;
  bool _isImageLoading = false;
  String? _currentProfileUrl;
  File? _selectedImageFile;

  // Avatar selection variables
  final List<String> _presetAvatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
    'assets/avatars/avatar6.png',
  ];
  String? _selectedPresetAvatar;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userDoc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        setState(() {
          _usernameController.text = userData['username'] ?? '';
          _bioController.text = userData['bio'] ?? '';

          // Load profile image URL
          final profileImageUrl = userData['profileImageUrl'];
          setState(() {
            _currentProfileUrl = profileImageUrl;

            // Check if the current profile image is one of the preset avatars
            if (_presetAvatars.contains(profileImageUrl)) {
              _selectedPresetAvatar = profileImageUrl;
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Method to pick image from gallery
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _selectedPresetAvatar = null; // Clear preset selection
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to take photo with camera
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _selectedImageFile = File(photo.path);
          _selectedPresetAvatar = null; // Clear preset selection
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to upload image to Firebase Storage
  Future<String?> _uploadImageToStorage() async {
    if (_selectedImageFile == null && _selectedPresetAvatar == null) {
      return _currentProfileUrl; // Keep current URL if no new selection
    }

    try {
      setState(() {
        _isImageLoading = true;
      });

      final String userId = _auth.currentUser!.uid;

      if (_selectedImageFile != null) {
        // Upload user-selected image
        final storageRef = _storage.ref().child('user_avatars/$userId.jpg');
        final uploadTask = storageRef.putFile(_selectedImageFile!);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else if (_selectedPresetAvatar != null) {
        // For preset avatars, just return the asset path
        return _selectedPresetAvatar;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isImageLoading = false;
      });
    }

    return _currentProfileUrl;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String userId = _auth.currentUser!.uid;

      // Upload the profile image if one was selected
      final String? profileImageUrl = await _uploadImageToStorage();

      // Update the user document in Firestore
      await _firestore.collection('users').doc(userId).update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileImageUrl': profileImageUrl,
      });

      // Also update the Firebase Auth user profile
      if (_auth.currentUser != null) {
        try {
          // Update display name
          await _auth.currentUser!.updateDisplayName(
            _usernameController.text.trim(),
          );

          // For Firebase Auth photoURL:
          // 1. If it's a network URL (from Storage), use it directly
          // 2. If it's an asset path, we need to save null since Firebase Auth can't handle asset paths
          if (profileImageUrl != null) {
            if (profileImageUrl.startsWith('http')) {
              // Network URL - can be used directly
              await _auth.currentUser!.updatePhotoURL(profileImageUrl);
            } else if (profileImageUrl.startsWith('assets/')) {
              // Asset path - store null in Firebase Auth but keep the asset path in Firestore
              // This is OK because our ProfileImageWidget properly handles both types
              await _auth.currentUser!.updatePhotoURL(null);
            }
          }
        } catch (e) {
          print('Error updating Firebase Auth profile: $e');
          // Don't show this error to the user, as the Firestore update succeeded
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading || _isImageLoading ? null : _saveProfile,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Avatar Section
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                              image:
                                  _selectedImageFile != null
                                      ? DecorationImage(
                                        image: FileImage(_selectedImageFile!),
                                        fit: BoxFit.cover,
                                      )
                                      : _selectedPresetAvatar != null
                                      ? DecorationImage(
                                        image: AssetImage(
                                          _selectedPresetAvatar!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : _currentProfileUrl != null &&
                                          _currentProfileUrl!.startsWith('http')
                                      ? DecorationImage(
                                        image: NetworkImage(
                                          _currentProfileUrl!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                (_selectedImageFile == null &&
                                        _selectedPresetAvatar == null &&
                                        (_currentProfileUrl == null ||
                                            _currentProfileUrl!.isEmpty))
                                    ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    )
                                    : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder:
                                        (context) => Container(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_library,
                                                ),
                                                title: const Text(
                                                  'Choose from Gallery',
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImage();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.camera_alt,
                                                ),
                                                title: const Text(
                                                  'Take a Photo',
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _takePhoto();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_isImageLoading)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Change your avatar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      // Preset Avatars
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _presetAvatars.length,
                          itemBuilder: (context, index) {
                            final avatar = _presetAvatars[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPresetAvatar = avatar;
                                  _selectedImageFile = null;
                                });
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      _selectedPresetAvatar == avatar
                                          ? Border.all(
                                            color:
                                                Theme.of(context).primaryColor,
                                            width: 3,
                                          )
                                          : null,
                                  image: DecorationImage(
                                    image: AssetImage(avatar),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.contains(' ')) {
                            return 'Username cannot contain spaces';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bio field
                      TextFormField(
                        controller: _bioController,
                        decoration: InputDecoration(
                          labelText: 'Bio',
                          prefixIcon: const Icon(Icons.edit),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 3,
                        maxLength: 150,
                      ),
                      const SizedBox(height: 16),

                      // Podium Section
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Your Podium',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Podium'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PodiumEditScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      ElevatedButton(
                        onPressed:
                            _isLoading || _isImageLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _isLoading || _isImageLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
