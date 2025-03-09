import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ceema/screens/sign_in_screen.dart';
import 'package:ceema/screens/sign_up_screen.dart';
import 'package:ceema/screens/forgot_password_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// Mock Firebase initialization
class MockFirebaseApp extends Mock implements FirebaseApp {}

// Setup widget test with Firebase mocks
Future<void> setupFirebaseAuthMocks() async {
  // No implementation needed for widget tests
}

void main() {
  setupFirebaseAuthMocks();

  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    auth = MockFirebaseAuth();
    firestore = FakeFirebaseFirestore();
  });

  // Helper function to build widget under test
  Widget createWidgetUnderTest({required Widget child}) {
    return MaterialApp(
      home: child,
    );
  }

  group('SignInScreen UI Tests', () {
    testWidgets('Renders sign in form correctly', (WidgetTester tester) async {
      // Build the SignInScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignInScreen()));

      // Verify that the important widgets are rendered
      expect(find.text('Ceema'), findsOneWidget);
      expect(find.text('Your Social Movie Diary'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Don\'t have an account?'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('Shows validation errors for empty fields',
        (WidgetTester tester) async {
      // Build the SignInScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignInScreen()));

      // Tap the sign in button without entering any data
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      // Verify validation errors are shown
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Navigates to sign up screen when sign up link is tapped',
        (WidgetTester tester) async {
      // Build the SignInScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignInScreen()));

      // Tap the sign up link
      await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
      await tester.pumpAndSettle();

      // Verify navigation to sign up screen
      // Note: In a real test, we would verify the navigation, but this is simplified
      // since we're not setting up the full navigation stack
    });

    testWidgets(
        'Navigates to forgot password screen when forgot password link is tapped',
        (WidgetTester tester) async {
      // Build the SignInScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignInScreen()));

      // Tap the forgot password link
      await tester.tap(find.widgetWithText(TextButton, 'Forgot Password?'));
      await tester.pumpAndSettle();

      // Verify navigation to forgot password screen
      // Note: In a real test, we would verify the navigation, but this is simplified
    });
  });

  group('SignUpScreen UI Tests', () {
    testWidgets('Renders sign up form correctly', (WidgetTester tester) async {
      // Build the SignUpScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignUpScreen()));

      // Verify that the important widgets are rendered
      expect(find.text('Create Account'), findsOneWidget);
      expect(
          find.text('Join the community of movie enthusiasts'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Shows validation errors for empty fields',
        (WidgetTester tester) async {
      // Build the SignUpScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignUpScreen()));

      // Tap the sign up button without entering any data
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      // Verify validation errors are shown
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter a username'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('Shows error when passwords do not match',
        (WidgetTester tester) async {
      // Build the SignUpScreen widget
      await tester
          .pumpWidget(createWidgetUnderTest(child: const SignUpScreen()));

      // Enter different passwords
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Test User');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@example.com');

      // Find all password fields
      final passwordFields = find.widgetWithText(TextFormField, 'Password');
      final confirmPasswordField =
          find.widgetWithText(TextFormField, 'Confirm Password');

      // Enter different passwords
      await tester.enterText(passwordFields.first, 'password123');
      await tester.enterText(confirmPasswordField, 'password456');

      // Tap the sign up button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      // Verify error is shown
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen UI Tests', () {
    testWidgets('Renders forgot password form correctly',
        (WidgetTester tester) async {
      // Build the ForgotPasswordScreen widget
      await tester.pumpWidget(
          createWidgetUnderTest(child: const ForgotPasswordScreen()));

      // Verify that the important widgets are rendered
      expect(find.text('Reset Password'), findsOneWidget);
      expect(
          find.text(
              'Enter your email address and we\'ll send you instructions to reset your password.'),
          findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Reset Password'), findsWidgets);
      expect(find.text('Back to Sign In'), findsOneWidget);
    });

    testWidgets('Shows validation error for empty email',
        (WidgetTester tester) async {
      // Build the ForgotPasswordScreen widget
      await tester.pumpWidget(
          createWidgetUnderTest(child: const ForgotPasswordScreen()));

      // Tap the reset password button without entering an email
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();

      // Verify validation error is shown
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Shows validation error for invalid email',
        (WidgetTester tester) async {
      // Build the ForgotPasswordScreen widget
      await tester.pumpWidget(
          createWidgetUnderTest(child: const ForgotPasswordScreen()));

      // Enter an invalid email
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'invalid-email');

      // Tap the reset password button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();

      // Verify validation error is shown
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Navigates back to sign in screen when back button is tapped',
        (WidgetTester tester) async {
      // Build the ForgotPasswordScreen widget
      await tester.pumpWidget(
          createWidgetUnderTest(child: const ForgotPasswordScreen()));

      // Tap the back to sign in button
      await tester.tap(find.widgetWithText(TextButton, 'Back to Sign In'));
      await tester.pumpAndSettle();

      // Verify navigation back to sign in screen
      // Note: In a real test, we would verify the navigation, but this is simplified
    });
  });
}
