import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initBaseUrl();
  runApp(const EnergyStoneApp());
}

class EnergyStoneApp extends StatefulWidget {
  const EnergyStoneApp({super.key});

  @override
  State<EnergyStoneApp> createState() => _EnergyStoneAppState();
}

class _EnergyStoneAppState extends State<EnergyStoneApp> {
  bool _isLoading = true;
  bool _hasUser = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    setState(() {
      _hasUser = userId != null;
      _userId = userId;
      _isLoading = false;
    });
    print('[Main] 用户状态检查: userId=$userId, hasUser=$_hasUser');
  }

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
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
              ),
            )
          : _hasUser && _userId != null
              ? HomeScreen(userId: _userId!)
              : const OnboardingScreen(),
    );
  }
}