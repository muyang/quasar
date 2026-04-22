import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class StoneShopScreen extends StatefulWidget {
  final int userId;

  const StoneShopScreen({super.key, required this.userId});

  @override
  State<StoneShopScreen> createState() => _StoneShopScreenState();
}

class _StoneShopScreenState extends State<StoneShopScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  StoneType? _selectedType;

  final List<Map<String, dynamic>> _stoneTypes = [
    {'type': StoneType.health, 'name': '健康', 'color': Color(0xFF4CAF50), 'desc': '守护身心健康'},
    {'type': StoneType.love, 'name': '爱情', 'color': Color(0xFFE91E63), 'desc': '守护爱情缘分'},
    {'type': StoneType.wealth, 'name': '财富', 'color': Color(0xFFFFD700), 'desc': '守护财富运势'},
    {'type': StoneType.career, 'name': '事业', 'color': Color(0xFFF44336), 'desc': '守护事业成就'},
    {'type': StoneType.family, 'name': '家庭', 'color': Color(0xFF2196F3), 'desc': '守护家庭和睦'},
  ];

  Future<void> _purchaseStone() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择一种水晶')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final typeString = STONE_TYPE_INFO[_selectedType!]!.name;
      final stone = await _apiService.createStone(widget.userId, typeString);

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
            '购买成功',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Color(0xFFB794FF)),
              const SizedBox(height: 16),
              Text(
                '你的${STONE_TYPE_INFO[_selectedType!]!.displayName}水晶',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '编号: ${stone.uniqueCode}',
                style: const TextStyle(color: Color(0xFFB794FF)),
              ),
              const SizedBox(height: 8),
              Text(
                '初始能量: ${stone.currentEnergy}',
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

      print('[Shop] 创建成功，石头编号: ${stone.uniqueCode}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('购买失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('水晶商店'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '选择你想要守护的领域',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _stoneTypes.length,
                    itemBuilder: (context, index) {
                      final stone = _stoneTypes[index];
                      final isSelected = _selectedType == stone['type'];
                      return _buildStoneCard(stone, isSelected);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _purchaseStone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '确认购买',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoneCard(Map<String, dynamic> stone, bool isSelected) {
    final color = stone['color'] as Color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = stone['type'] as StoneType;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(isSelected ? 0.4 : 0.2),
              const Color(0xFF2A2A4A),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: color, width: 3)
              : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [
                    color,
                    color.withOpacity(0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              stone['name'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stone['desc'] as String,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}