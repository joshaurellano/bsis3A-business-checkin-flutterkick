import 'package:flutter/material.dart';

import './screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruServe Pharma Manager',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          secondary: const Color(0xFF2196F3),
          primary: const Color(0xFF0D47A1),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const PharmaDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

