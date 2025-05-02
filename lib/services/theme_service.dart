import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isDarkMode = true;

  ThemeService() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadThemePreference() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _isDarkMode = userDoc.data()?['darkModeEnabled'] ?? true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'darkModeEnabled': _isDarkMode,
        });
      }
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.poppins().fontFamily,

      // Color Scheme - Updated for better cohesion
      colorScheme: ColorScheme.light(
        surface: const Color(0xFFF0F2F5), // Slightly softer background
        surfaceContainerHighest: const Color(
          0xFFE4E6EB,
        ), // Deeper container color
        primary: const Color(0xFF3A7BFD), // Blue primary - complements orange
        secondary: const Color(0xFFFF8C42), // Original vibrant orange
        onSurface: const Color(0xFF1C1C1E), // Softer black for text
        onSurfaceVariant: const Color(
          0xFF6E6E70,
        ), // Secondary text color (lightened)
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        error: Colors.red[700]!,
        primaryContainer: const Color(0xFFDCEAFF), // Light blue for containers
        onPrimaryContainer: const Color(
          0xFF0A438C,
        ), // Dark blue for text on containers
        secondaryContainer: const Color(
          0xFFFFEEE4,
        ), // Light orange for containers
        onSecondaryContainer: const Color(
          0xFF9C4A15,
        ), // Dark orange for text on containers
      ),

      // Scaffold and Background
      scaffoldBackgroundColor: const Color(0xFFF0F2F5), // Match surface color
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF0F2F5), // Match surface color
        foregroundColor: const Color(0xFF1C1C1E), // Match onSurface
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: const Color(0xFFE4E6EB), // Match surfaceContainerHighest
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE4E6EB), // Match surfaceContainerHighest
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF3A7BFD), // Match primary
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[700]!),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        // Headings: Bold/SemiBold (600-700 weight)
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),

        // UI Elements: Medium/SemiBold (500-600 weight)
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1C1C1E), // Match onSurface
        ),

        // Body Text: Regular (400 weight)
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6E6E70), // Match onSurfaceVariant
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6E6E70), // Match onSurfaceVariant
        ),

        // Captions/Small Text: Light/Regular (300-400 weight)
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: const Color(0xFF6E6E70), // Match onSurfaceVariant
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A7BFD), // Match primary
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3A7BFD), // Match primary
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: Color(0xFF6E6E70),
        size: 24,
      ), // Match onSurfaceVariant
      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(
          0xFFE4E6EB,
        ), // Match surfaceContainerHighest
        indicatorColor: const Color(0xFF3A7BFD), // Match primary
        labelTextStyle: MaterialStatePropertyAll(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: const MaterialStatePropertyAll(IconThemeData(size: 24)),
        height: 64,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: const Color(
          0xFFE4E6EB,
        ), // Match surfaceContainerHighest
        selectedColor: const Color(0xFF3A7BFD), // Match primary
        disabledColor: Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: const Color(
          0xFFE4E6EB,
        ), // Match surfaceContainerHighest
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF3A7BFD), // Match primary
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF3A7BFD), // Match primary
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C2C2E), // Darker for contrast
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.poppins().fontFamily,

      // Color Scheme - Oceanic Depth Theme
      colorScheme: ColorScheme.dark(
        surface: const Color(0xFF02111B), // Midnight Blue
        surfaceContainerHighest: const Color(0xFF04243C), // Navy Blue
        primary: const Color(0xFF046380), // Deep Teal
        secondary: const Color(0xFFFF8C42), // Coral Orange
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        error: Colors.red[400]!,
        tertiary: const Color(0xFFA5CC82), // Seafoam Green for accent elements
      ),

      // Scaffold and Background
      scaffoldBackgroundColor: const Color(0xFF02111B), // Midnight Blue
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF02111B), // Midnight Blue
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: const Color(0xFF04243C), // Navy Blue
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF04243C), // Navy Blue
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF046380)), // Deep Teal
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        // Headings: Bold/SemiBold (600-700 weight)
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),

        // UI Elements: Medium/SemiBold (500-600 weight)
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),

        // Body Text: Regular (400 weight)
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),

        // Captions/Small Text: Light/Regular (300-400 weight)
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF046380), // Deep Teal
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFF8C42), // Coral Orange
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: Colors.white, size: 24),

      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF04243C), // Navy Blue
        indicatorColor: const Color(0xFF046380), // Deep Teal
        labelTextStyle: MaterialStatePropertyAll(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: const MaterialStatePropertyAll(IconThemeData(size: 24)),
        height: 64,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF04243C), // Navy Blue
        selectedColor: const Color(0xFF046380), // Deep Teal
        disabledColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: const Color(0xFF04243C), // Navy Blue
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF046380), // Deep Teal
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFFFF8C42), // Coral Orange for contrast
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF04243C), // Navy Blue
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
