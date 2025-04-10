import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/podium_movie.dart';
import '../services/podium_service.dart';
import '../widgets/podium_widget.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _podiumService = PodiumService();

  bool _isLoading = false;
  bool _isImageLoading = false;
  String? _currentProfileUrl;
  File? _selectedImageFile;
  List<PodiumMovie> _podiumMovies = [];

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
    _loadPodiumMovies();
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
      final String userId = _auth.currentUser!.uid;
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPodiumMovies() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final podiumMovies = await _podiumService.getPodiumMovies(userId).first;
      setState(() {
        _podiumMovies = podiumMovies;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading podium movies: $e')),
        );
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
      final String newUsername = _usernameController.text.trim();

      // Get the current user data to check if username changed
      final currentUserDoc =
          await _firestore.collection('users').doc(userId).get();
      final currentUsername = currentUserDoc.data()?['username'] ?? '';

      // Upload the profile image if one was selected
      final String? profileImageUrl = await _uploadImageToStorage();

      // Update the user document
      await _firestore.collection('users').doc(userId).update({
        'username': newUsername,
        'bio': _bioController.text.trim(),
        'profileImageUrl': profileImageUrl,
      });

      // If username changed, update all posts by this user
      if (currentUsername != newUsername) {
        // Get all posts by this user
        final postsSnapshot =
            await _firestore
                .collection('posts')
                .where('userId', isEqualTo: userId)
                .get();

        // Update each post with the new username
        final batch = _firestore.batch();
        for (var doc in postsSnapshot.docs) {
          batch.update(doc.reference, {'username': newUsername});
        }
        await batch.commit();
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
                padding: const EdgeInsets.all(24.0),
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

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Podium Section
                      const Text(
                        'Your Top 3 Movies',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_podiumMovies.isNotEmpty)
                        PodiumWidget(
                          movies: _podiumMovies,
                          isEditable: true,
                          onRankTap: (rank) {
                            // TODO: Navigate to podium edit screen
                          },
                          onMovieTap: (movie) {
                            // TODO: Navigate to movie details
                          },
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Your Podium'),
                          onPressed: () {
                            // TODO: Navigate to podium edit screen
                          },
                        ),
                      const SizedBox(height: 32),

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
