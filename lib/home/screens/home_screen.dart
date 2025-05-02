import 'package:flutter/material.dart';
import '../components/feed_screen.dart';
import 'package:ceema/screens/diary_screen.dart';
import 'package:ceema/screens/profile_screen.dart';
import 'package:ceema/screens/watchlist_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isInitializing = true;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Mark initialization as complete
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show loading indicator if preferences are being initialized
      body:
          _isInitializing
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Personalizing your experience...'),
                  ],
                ),
              )
              : FadeTransition(
                opacity: _fadeAnimation,
                child: const SeamlessFeedScreen(),
              ),
    );
  }
}
