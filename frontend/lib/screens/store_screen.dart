import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class StoreScreen extends StatefulWidget {
  final int userId;
  final List<StoneDetail> stones;
  const StoreScreen({super.key, required this.userId, required this.stones});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ApiService _api = ApiService();
  List<StoreItem> _items = [];
  bool _isLoading = true;
  int _totalEnergy = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int get totalEnergy {
    return widget.stones.where((s) => s.status == 'ALIVE').fold(0, (sum, s) => sum + s.currentEnergy);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _items = await _api.getStoreItems();
    } catch (e) {
      print('[Store] 加载失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _purchase(StoreItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: const Text('确认购买', style: TextStyle(color: Colors.white)),
        content: Text(
          '${item.name}\n价格: ${item.price} 能量\n\n当前能量: $totalEnergy',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _api.purchaseItem(widget.userId, item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: const Color(0xFF6B4EFF)),
        );
        // Refresh stones through parent
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.withOpacity(0.8)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final energy = totalEnergy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('商店'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF121212)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
            : Column(
                children: [
                  // Energy balance
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6B4EFF), Color(0xFF9D7FFF)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('可用能量', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('$energy', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('商店暂无物品', style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) => _buildItemCard(_items[i], energy),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildItemCard(StoreItem item, int energy) {
    final canAfford = energy >= item.price;
    final isStone = item.itemType == 'STONE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStone ? Icons.diamond : Icons.bolt,
              color: const Color(0xFFB794FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  isStone ? '${CARD_TYPE_NAMES[item.stoneType] ?? item.stoneType} 类型水晶' : '获得 ${item.energyAmount} 点能量',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canAfford ? () => _purchase(item) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: Text('${item.price} 能量'),
          ),
        ],
      ),
    );
  }
}
