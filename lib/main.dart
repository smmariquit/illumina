import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/main_page.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/contacts_screen.dart';
import 'utils/ml_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      name: 'illumina',
      options: const FirebaseOptions(
        apiKey: "AIzaSyDnXdm-YHLdQS-8E0Hnmfgg5E0TClOkiiE",
        authDomain: "illumina-spark-pup.firebaseapp.com",
        projectId: "illumina-spark-pup",
        storageBucket: "illumina-spark-pup.firebasestorage.app",
        messagingSenderId: "560333200922",
        appId: "1:560333200922:web:b9d826cc91a0ae4b137ba3",
        measurementId: "G-1DQ4B8E02Z",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Initialize ML Kit
  if (!kIsWeb) {
    print('\n[Main] Initializing ML Kit...');
    await MLUtils.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Illumina',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const MainPage(),
        '/map': (context) => const MapScreen(),
        '/report': (context) => const ReportScreen(),
        '/contacts': (context) => ContactsScreen(),
      },
    );
  }
}
