import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const EnergyStoneApp());
}

class EnergyStoneApp extends StatelessWidget {
  const EnergyStoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '能量石',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF6B4EFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B4EFF),
          secondary: Color(0xFF9D7FFF),
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Color(0xFFB0B0B0),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}