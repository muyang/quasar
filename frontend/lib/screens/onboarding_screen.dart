import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'stone_shop_screen.dart';
import 'bind_stone_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _stoneCodeController = TextEditingController();
  int _currentStep = 0;
  bool _isLoading = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
      );
    }
  }

  Future<void> _registerUser() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _apiService.registerUser(_nicknameController.text.trim());
      setState(() {
        _user = user;
        _isLoading = false;
        _currentStep = 1;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);

      print('[Onboarding] 注册成功，用户ID: ${user.id}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注册失败: $e')),
      );
    }
  }

  Future<void> _loginByStone() async {
    final code = _stoneCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入水晶编号')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _apiService.loginByStoneCode(code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: user.id)),
      );

      print('[Onboarding] 登录成功，用户ID: ${user.id}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登录失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoneShopScreen(userId: _user!.id),
      ),
    ).then((result) {
      if (result == true) {
        // 购买成功，跳转主页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userId: _user!.id)),
        );
      }
    });
  }

  void _goToBind() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BindStoneScreen(userId: _user!.id),
      ),
    ).then((result) {
      if (result == true) {
        // 绑定成功，跳转主页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userId: _user!.id)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF121212),
              Color(0xFF0A0A14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 进度指示器
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(0, '设置昵称'),
                    const SizedBox(width: 16),
                    _buildStepIndicator(1, '绑定石头'),
                  ],
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: _currentStep == 0
                      ? _buildNicknameStep()
                      : _buildStoneChoiceStep(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step <= _currentStep;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF6B4EFF) : Colors.grey.withOpacity(0.3),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_outline,
            size: 80,
            color: Color(0xFFB794FF),
          ),
          const SizedBox(height: 24),
          const Text(
            '欢迎使用能量石',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '新用户：设置昵称注册',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nicknameController,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              hintText: '输入昵称',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF2A2A4A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '注册新账户',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 40),
          // 分隔线
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('老用户', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '通过水晶编号登录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stoneCodeController,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: '输入水晶编号 (如 CRY-000001)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF2A2A4A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginByStone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A4A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFB794FF)),
                ),
              ),
              child: const Text(
                '登录',
                style: TextStyle(fontSize: 18, color: Color(0xFFB794FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoneChoiceStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.diamond,
          size: 80,
          color: Color(0xFFB794FF),
        ),
        const SizedBox(height: 24),
        Text(
          '你的专属ID: ${_user?.id ?? ""}',
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFFB794FF),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '现在，选择你的能量石',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _goToShop,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '购买新水晶',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _goToBind,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A4A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link, color: Color(0xFFB794FF)),
                SizedBox(width: 8),
                Text(
                  '绑定已有水晶',
                  style: TextStyle(fontSize: 18, color: Color(0xFFB794FF)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '每颗水晶都有唯一编号',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 32),
        // 退出按钮 - 稍后可在设置页购买或绑定
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen(userId: _user!.id)),
            );
          },
          child: Text(
            '暂时跳过，稍后在设置页添加',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _stoneCodeController.dispose();
    super.dispose();
  }
}