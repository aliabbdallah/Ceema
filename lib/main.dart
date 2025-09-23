import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
import 'services/theme_service.dart';
import 'services/profile_service.dart';
import 'navigation/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Update watched count for current user if logged in
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final profileService = ProfileService();
    await profileService.updateUserFriendStats(currentUser.uid);
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Update email verification status in Firestore
  Future<void> _updateEmailVerificationStatus(User user) async {
    try {
      // Reload user to get the latest verification status
      await user.reload();

      // Update Firestore with the current verification status
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'emailVerified': user.emailVerified},
      );
    } catch (e) {
      debugPrint('Error updating email verification status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    // Update system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            themeService.isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            themeService.isDarkMode
                ? const Color(0xFF1E1E22)
                : const Color(0xFFF1F1F3),
        systemNavigationBarIconBrightness:
            themeService.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Ceema',
      debugShowCheckedModeBanner: false,
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show splash screen while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          // Navigate based on auth state
          if (snapshot.hasData) {
            // Check if email is verified
            if (!snapshot.data!.emailVerified) {
              // Sign out unverified users
              FirebaseAuth.instance.signOut();
              return const SignInScreen();
            }

            // Check and update email verification status in Firestore
            _updateEmailVerificationStatus(snapshot.data!);
            return const AppNavigator();
          }

          return const SignInScreen();
        },
      ),
    );
  }
}
