import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceema/home/screens/home_screen.dart';
import 'package:ceema/screens/sign_in_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptTerms = false;
  bool _isLoading = false;

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
  File? _selectedImageFile;
  bool _isUploadingImage = false;

  // Add validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    // Email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    // Password strength validation
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Add method to check password requirements
  Map<String, bool> _checkPasswordRequirements(String password) {
    return {
      '8 characters long': password.length >= 8,
      'Uppercase letter': password.contains(RegExp(r'[A-Z]')),
      'Lowercase letter': password.contains(RegExp(r'[a-z]')),
      'Number': password.contains(RegExp(r'[0-9]')),
      'Special character': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }

    // Username format validation
    if (value.length < 3) {
      return 'Username must be at least 3 characters long';
    }

    if (value.length > 20) {
      return 'Username cannot be longer than 20 characters';
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    if (value.startsWith('_') || value.endsWith('_')) {
      return 'Username cannot start or end with an underscore';
    }

    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }

    // Name format validation
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
  Future<String?> _uploadImageToStorage(String uid) async {
    if (_selectedImageFile == null && _selectedPresetAvatar == null) {
      return null;
    }

    try {
      setState(() {
        _isUploadingImage = true;
      });

      if (_selectedImageFile != null) {
        // Upload user-selected image
        final storageRef = _storage.ref().child('user_avatars/$uid.jpg');
        final uploadTask = storageRef.putFile(_selectedImageFile!);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else if (_selectedPresetAvatar != null) {
        // For preset avatars, we can either copy them to storage with the user's ID
        // or just return the asset path as is
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
        _isUploadingImage = false;
      });
    }

    return null;
  }

  // Add method to check if email exists
  Future<bool> _checkEmailExists(String email) async {
    try {
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Add method to capitalize name
  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if email already exists
    final emailExists = await _checkEmailExists(_emailController.text.trim());
    if (emailExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An account with this email already exists'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate username uniqueness before proceeding
    try {
      final usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: _usernameController.text.trim())
              .get();

      if (usernameQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This username is already taken'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking username: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Capitalize the name before creating the account
      final capitalizedName = _capitalizeName(_nameController.text.trim());

      // Create the user account
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (userCredential.user != null) {
        // Send verification email
        await userCredential.user!.sendEmailVerification();

        // Upload profile image if selected
        final String? profileImageUrl = await _uploadImageToStorage(
          userCredential.user!.uid,
        );

        // Store user data in Firestore with capitalized name
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': _usernameController.text.trim(),
          'displayName': capitalizedName,
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'bio': '',
          'profileImageUrl': profileImageUrl ?? '',
          'favoriteGenres': [],
          'followersCount': 0,
          'followingCount': 0,
          'mutualFriendsCount': 0,
          'emailVerified': false,
        });

        // Show success message and redirect to sign-in screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent! Please check your inbox.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to sign-in screen after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SignInScreen()),
                (route) => false,
              );
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during registration';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email';
          break;
        case 'invalid-email':
          errorMessage = 'Please provide a valid email address';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the community of movie enthusiasts',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Profile Avatar Selection
                Center(
                  child: Column(
                    children: [
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
                                      : null,
                            ),
                            child:
                                _selectedImageFile == null &&
                                        _selectedPresetAvatar == null
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose your avatar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
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
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                _selectedPresetAvatar == avatar
                                    ? Border.all(
                                      color: Theme.of(context).primaryColor,
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

                // Name field with auto-capitalization
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),

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
                  validator: _validateUsername,
                ),
                const SizedBox(height: 16),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild to update requirements
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 8),
                // Password requirements
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      _checkPasswordRequirements(_passwordController.text)
                          .entries
                          .map(
                            (requirement) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    requirement.value
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color:
                                        requirement.value
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    requirement.key,
                                    style: TextStyle(
                                      color:
                                          requirement.value
                                              ? Colors.green
                                              : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 16),

                // Terms and conditions checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'I accept the Terms of Service and Privacy Policy',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sign up button
                ElevatedButton(
                  onPressed:
                      (_isLoading || _isUploadingImage || !_acceptTerms)
                          ? null
                          : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading || _isUploadingImage
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
                            'Sign Up',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
