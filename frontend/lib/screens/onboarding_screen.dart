import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _stoneCodeController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  StoneDetail? _pendingStone; // 待绑定的新用户石头

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

  /// 输入水晶编号后的主流程
  Future<void> _processStoneCode() async {
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
      // 检查石头状态
      final stone = await _apiService.checkStoneStatus(code);

      setState(() {
        _isLoading = false;
      });

      if (stone.ownerId != null) {
        // 老用户：石头已绑定，直接登录
        _loginExistingUser(stone);
      } else {
        // 新用户：石头未绑定，弹出设置昵称
        _showNicknameDialog(stone);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('查询失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 老用户登录流程
  void _loginExistingUser(StoneDetail stone) {
    // 石头已绑定用户，获取用户信息并登录
    setState(() {
      _isLoading = true;
    });

    _apiService.getUser(stone.ownerId!).then((user) {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) => p.setInt('user_id', user.id));

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: user.id)),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('欢迎回来，${user.nickname}！'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );
    }).catchError((e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: $e'), backgroundColor: Colors.red),
      );
    });
  }

  /// 显示设置昵称对话框（新用户）
  void _showNicknameDialog(StoneDetail stone) {
    _pendingStone = stone;
    _nicknameController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.diamond, color: _parseColor(stone.colorCode), size: 28),
            const SizedBox(width: 12),
            Text('${stone.stoneTypeName}水晶', style: const TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '这是一颗全新的水晶！',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              stone.uniqueCode,
              style: TextStyle(color: _parseColor(stone.colorCode), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              '请设置你的昵称',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nicknameController,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: '输入昵称',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pendingStone = null;
            },
            child: Text('取消', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: _bindNewUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: _parseColor(stone.colorCode),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确认', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 新用户绑定流程
  Future<void> _bindNewUser() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }

    if (_pendingStone == null) return;

    Navigator.pop(context); // 关闭对话框

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _apiService.bindStoneToNewUser(_pendingStone!.uniqueCode, nickname);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);

      setState(() {
        _isLoading = false;
        _pendingStone = null;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: user.id)),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('欢迎加入，$nickname！你的专属ID: ${user.id}'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Icon(
                  Icons.diamond,
                  size: 100,
                  color: Color(0xFFB794FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  '能量石',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '情绪治愈与仪式感的习惯养成',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 48),

                // 输入水晶编号
                Text(
                  '输入你的水晶编号',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '新用户首次登录将自动创建账户',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _stoneCodeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    hintText: '如 HRY-000001',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: const Color(0xFF2A2A4A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processStoneCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '登录',
                            style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const Spacer(),

                // 提示
                Text(
                  '后续支持扫码/NFC登录',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stoneCodeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }
}