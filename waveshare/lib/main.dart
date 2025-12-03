import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_page.dart';
import 'utils/constants.dart';
import 'screens/organization_registration.dart';
import 'screens/admin_login_screen.dart';
import 'screens/csv_upload_screen.dart';
import 'screens/admin_dashboard.dart';
import 'package:waveshare/screens/received_files_screen.dart';
import 'screens/supervisor_dashboard.dart';
import 'screens/student_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/student_dashboard.dart';
import 'screens/supervisor_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/universal_share_screen.dart';
import 'screens/my_shared_files_screen.dart';
import 'screens/my_students_screen.dart';

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

  // ✅ ADD THIS METHOD HERE (before build method)
  Future<Map<String, dynamic>> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // ✅ STRICT PASSWORD CHECK
    bool hasPassword = prefs.getBool('has_password') ?? false;
    bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    bool firstLoginComplete = prefs.getBool('first_login_complete') ?? false;
    String userId = prefs.getString('user_id') ?? '';
    String role = prefs.getString('user_role') ?? '';

    print('🔍 LOGIN STATUS CHECK:');
    print('   User ID: $userId');
    print('   Role: $role');
    print('   Has Password: $hasPassword');
    print('   Is Logged In: $isLoggedIn');
    print('   First Login Complete: $firstLoginComplete');

    // ✅ ALL CONDITIONS MUST BE TRUE
    bool shouldAutoLogin = hasPassword && isLoggedIn && firstLoginComplete && userId.isNotEmpty;

    return {
      'isLoggedIn': shouldAutoLogin,
      'role': role,
    };
  }

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
      home: FutureBuilder<Map<String, dynamic>>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data!['isLoggedIn'] == true) {
            String role = snapshot.data!['role'] ?? '';
            if (role == 'supervisor') {
              return SupervisorDashboard();
            } else if (role == 'student') {
              return StudentDashboard();
            } else if (role == 'admin') {
              return AdminDashboard();
            }
          }

          return LandingPage();
        },
      ),

      // Add to your main.dart MaterialApp

      routes: {
        '/organization-registration': (context) => const OrganizationRegistration(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/csv-upload': (context) => const CSVUploadScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/received-files': (context) => const ReceivedFilesScreen(),
        '/supervisor-dashboard': (context) => const SupervisorDashboard(), // ✅ ADD THIS
        '/student-dashboard': (context) => const StudentDashboard(),
        '/universal-share': (context) => const UniversalShareScreen(),  // ✅ ADD
        '/my-shared-files': (context) => const MySharedFilesScreen(),  // ✅ ADD
        '/my-students': (context) => const MyStudentsScreen(),  // ✅ ADD
      },
      // routes: {
      //   '/landing': (context) => const LandingPage(),
      //   '/organization': (context) => const OrganizationPage(),
      //   // Add more routes as you create new pages
      // },
    );
  }
}