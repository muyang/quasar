import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'stone_detail_screen.dart';

class MyStonesScreen extends StatefulWidget {
  final int userId;
  final Function(StoneDetail)? onStoneTap;
  final VoidCallback? onRefresh;

  const MyStonesScreen({super.key, required this.userId, this.onStoneTap, this.onRefresh});

  @override
  State<MyStonesScreen> createState() => _MyStonesScreenState();
}

class _MyStonesScreenState extends State<MyStonesScreen> {
  final ApiService _apiService = ApiService();
  List<StoneDetail> _stones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStones();
  }

  Future<void> _loadStones() async {
    try {
      final stones = await _apiService.getUserStones(widget.userId);
      setState(() {
        _stones = stones;
        _isLoading = false;
      });
      print('[MyStones] 加载了 ${stones.length} 颗石头');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  void _onStoneTap(StoneDetail stone) {
    if (widget.onStoneTap != null) {
      widget.onStoneTap!(stone);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoneDetailScreen(stone: stone, userId: widget.userId),
        ),
      ).then((_) => _loadStones());
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的水晶'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadStones();
              if (widget.onRefresh != null) widget.onRefresh!();
            },
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
            : _stones.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadStones,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _stones.length,
                      itemBuilder: (context, index) => _buildStoneCard(_stones[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('还没有绑定水晶', style: TextStyle(fontSize: 18, color: Colors.white)),
          const SizedBox(height: 8),
          Text('前往设置页面购买或绑定', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildStoneCard(StoneDetail stone) {
    final color = _parseColor(stone.colorCode);
    final isDead = stone.status == 'DEAD';

    return GestureDetector(
      onTap: () => _onStoneTap(stone),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(isDead ? 0.1 : 0.3), const Color(0xFF2A2A4A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // 水晶图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: isDead
                      ? [Colors.grey, Colors.grey.withOpacity(0.3)]
                      : [color, color.withOpacity(0.5)],
                ),
              ),
              child: Center(
                child: Text(
                  '${stone.currentEnergy}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDead ? Colors.grey : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        stone.stoneTypeName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      if (isDead)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                          child: const Text('枯竭', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(stone.uniqueCode, style: TextStyle(fontSize: 14, color: color.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('能量: ${stone.currentEnergy}/${stone.energyCap}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      const SizedBox(width: 16),
                      Icon(Icons.trending_up, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text('${stone.nextMultiplier}x', style: TextStyle(color: color)),
                    ],
                  ),
                ],
              ),
            ),
            // 箭头
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}