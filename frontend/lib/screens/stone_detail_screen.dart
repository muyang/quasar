import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'calendar_screen.dart';

class StoneDetailScreen extends StatefulWidget {
  final StoneDetail stone;
  final int userId;

  const StoneDetailScreen({super.key, required this.stone, required this.userId});

  @override
  State<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends State<StoneDetailScreen> {
  final ApiService _apiService = ApiService();
  StoneDetail? _currentStone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStone = widget.stone;
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _refreshStone() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stone = await _apiService.getStoneDetail(widget.stone.id);
      setState(() {
        _currentStone = stone;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stone = _currentStone ?? widget.stone;
    final color = _parseColor(stone.colorCode);
    final isDead = stone.status == 'DEAD';

    return Scaffold(
      appBar: AppBar(
        title: Text(stone.stoneTypeName),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStone,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 石头展示
                    _buildStoneVisual(stone, color),
                    const SizedBox(height: 24),

                    // 基本信息
                    _buildInfoCard(stone, color, isDead),
                    const SizedBox(height: 16),

                    // 打卡信息
                    if (!isDead) _buildCheckInInfo(stone, color),
                    const SizedBox(height: 16),

                    // 打卡记录入口
                    if (!isDead)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendarScreen(stoneId: stone.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('查看打卡记录'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B4EFF),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStoneVisual(StoneDetail stone, Color color) {
    final isDead = stone.status == 'DEAD';
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: isDead
                ? [Colors.grey.withOpacity(0.3), const Color(0xFF1A1A2A)]
                : [color.withOpacity(0.9), color.withOpacity(0.4), const Color(0xFF1A1A3A)],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: isDead
              ? null
              : [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 40, spreadRadius: 10),
                ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDead)
                Icon(Icons.warning_rounded, size: 48, color: Colors.red.withOpacity(0.6))
              else
                const SizedBox(),
              Text(
                '${stone.currentEnergy}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDead ? Colors.grey : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '能量',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(isDead ? 0.4 : 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(StoneDetail stone, Color color, bool isDead) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.diamond, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stone.stoneTypeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(stone.uniqueCode, style: TextStyle(fontSize: 14, color: color.withOpacity(0.8))),
                  ],
                ),
              ),
              if (isDead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                  child: const Text('枯竭', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('当前能量', '${stone.currentEnergy}', color),
              _buildStatItem('能量上限', '${stone.energyCap}', Colors.white54),
              _buildStatItem('枯竭次数', '${stone.deathCount}', Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildCheckInInfo(StoneDetail stone, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), const Color(0xFF2A2A4A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('连续打卡', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
              Text('${stone.consecutiveDays} 天', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('下次打卡倍数', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                child: Text('${stone.nextMultiplier}x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '可获得 ${stone.nextMultiplier} - ${stone.nextMultiplier * 5} 点能量',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}