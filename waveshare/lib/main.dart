import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_page.dart';
import 'utils/constants.dart';
import 'screens/organization_registration.dart';
import 'screens/admin_login_screen.dart';
import 'screens/csv_upload_screen.dart';
import 'screens/admin_dashboard.dart';


void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait only)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style (status bar color)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App Title
      title: AppConstants.appName,

      // Remove debug banner
      debugShowCheckedModeBanner: false,

      // Theme
      theme: ThemeData(
        primaryColor: AppConstants.primaryBlue,
        scaffoldBackgroundColor: AppConstants.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,

        // Font family (you can change this later)
        fontFamily: 'Roboto',

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppConstants.primaryBlue),
          titleTextStyle: TextStyle(
            color: AppConstants.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Home screen (Landing Page)
      home: const LandingPage(),

      // Add to your main.dart MaterialApp

      routes: {
        '/organization-registration': (context) => const OrganizationRegistration(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/csv-upload': (context) => const CSVUploadScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        // ... your other routes
      },
      // routes: {
      //   '/landing': (context) => const LandingPage(),
      //   '/organization': (context) => const OrganizationPage(),
      //   // Add more routes as you create new pages
      // },
    );
  }
}