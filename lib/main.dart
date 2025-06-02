import 'package:flutter/material.dart';
import 'package:illumina/screens/main_page.dart';
import 'package:illumina/screens/map_screen.dart';
import 'package:illumina/screens/report_screen.dart';

void main() {
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
      routes: {
        '/': (context) => const MainPage(),
        '/map': (context) => const MapScreen(),
        '/report': (context) => const ReportScreen(),
      },
      initialRoute: '/',
    );
  }
}
