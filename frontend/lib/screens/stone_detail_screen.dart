import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'calendar_screen.dart';
import 'transfer_screen.dart';

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

  void _goToTransfer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferScreen(
          userId: widget.userId,
          stones: [_currentStone!],
          onTransferComplete: () {
            _refreshStone();
          },
        ),
      ),
    );
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
                    // 水晶展示
                    _buildCrystalVisual(stone, color),
                    const SizedBox(height: 32),

                    // 基本信息
                    _buildInfoCard(stone, color, isDead),
                    const SizedBox(height: 20),

                    // 能量条
                    _buildEnergyBar(stone, color),
                    const SizedBox(height: 20),

                    // 打卡信息
                    if (!isDead) _buildCheckInInfo(stone, color),
                    const SizedBox(height: 24),

                    // 操作按钮
                    _buildActionButtons(stone, color, isDead),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCrystalVisual(StoneDetail stone, Color color) {
    final isDead = stone.status == 'DEAD';
    return Center(
      child: Container(
        width: 180,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDead
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景光晕
            if (!isDead)
              Container(
                width: 160,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            // 水晶图标
            Icon(
              Icons.diamond,
              size: 80,
              color: isDead ? Colors.grey.withOpacity(0.5) : color,
            ),
            // 能量数值
            Positioned(
              bottom: 20,
              child: Column(
                children: [
                  Text(
                    '${stone.currentEnergy}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isDead ? Colors.grey : Colors.white,
                    ),
                  ),
                  Text(
                    '能量',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(isDead ? 0.4 : 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(StoneDetail stone, Color color, bool isDead) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.3),
                ),
                child: Icon(Icons.diamond, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.stoneTypeName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stone.uniqueCode,
                      style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              if (isDead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('枯竭', style: TextStyle(color: Colors.red, fontSize: 14)),
                ),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
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
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildEnergyBar(StoneDetail stone, Color color) {
    final energyRatio = stone.currentEnergy / stone.energyCap;
    final isDead = stone.status == 'DEAD';

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
              Text('能量值', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
              Text(
                '${stone.currentEnergy} / ${stone.energyCap}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 能量条
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: isDead ? 0.0 : energyRatio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDead
                        ? [Colors.grey, Colors.grey.withOpacity(0.5)]
                        : [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
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

  Widget _buildActionButtons(StoneDetail stone, Color color, bool isDead) {
    return Column(
      children: [
        // 查看打卡记录
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
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        // 转赠能量（仅在存活且有能量时显示）
        if (!isDead && stone.currentEnergy > 0)
          ElevatedButton.icon(
            onPressed: _goToTransfer,
            icon: const Icon(Icons.send),
            label: const Text('转赠能量'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.6),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}