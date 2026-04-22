import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BindStoneScreen extends StatefulWidget {
  final int userId;

  const BindStoneScreen({super.key, required this.userId});

  @override
  State<BindStoneScreen> createState() => _BindStoneScreenState();
}

class _BindStoneScreenState extends State<BindStoneScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _bindStone() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入水晶编号')),
      );
      return;
    }

    if (!code.startsWith('CRY-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('编号格式应为 CRY-XXXXXX')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final stone = await _apiService.bindStone(widget.userId, code);

      setState(() {
        _isLoading = false;
      });

      // 显示成功提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '绑定成功',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Color(0xFFB794FF)),
              const SizedBox(height: 16),
              Text(
                stone.stoneTypeName,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '编号: ${stone.uniqueCode}',
                style: const TextStyle(color: Color(0xFFB794FF)),
              ),
              const SizedBox(height: 8),
              Text(
                '当前能量: ${stone.currentEnergy}',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text(
                '开始使用',
                style: TextStyle(color: Color(0xFFB794FF)),
              ),
            ),
          ],
        ),
      );

      print('[Bind] 绑定成功，石头编号: ${stone.uniqueCode}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('绑定水晶'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.link,
                  size: 80,
                  color: Color(0xFFB794FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  '输入水晶编号',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '每颗水晶都有唯一编号，如 CRY-000001',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    hintText: 'CRY-XXXXXX',
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
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _bindStone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '绑定',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
                const Spacer(),
                Text(
                  '如果还没有水晶，请前往商店购买',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
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
    _codeController.dispose();
    super.dispose();
  }
}