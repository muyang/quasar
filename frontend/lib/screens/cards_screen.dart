import 'package:flutter/material.dart' hide Card;
import '../services/api_service.dart';
import '../models/stone.dart';
import 'draw_card_screen.dart';

class CardsScreen extends StatefulWidget {
  final int userId;
  final List<StoneDetail> stones;
  final VoidCallback? onRefresh;

  const CardsScreen({
    super.key,
    required this.userId,
    required this.stones,
    this.onRefresh,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final ApiService _apiService = ApiService();
  List<Card> _cards = [];
  DrawStatus? _drawStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cards = await _apiService.getUserCards(widget.userId);
      final status = await _apiService.getDrawStatus(widget.userId);
      setState(() {
        _cards = cards;
        _drawStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _goToDraw() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawCardScreen(
          userId: widget.userId,
          drawStatus: _drawStatus,
          stones: widget.stones,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _chargeCard(Card card) async {
    // 找到匹配类型的石头
    final matchingStones = widget.stones.where(
      (s) => s.stoneType == card.cardType && s.status == 'ALIVE'
    ).toList();

    if (matchingStones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('没有【${card.cardTypeName}】类型的石头，无法充值'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 选择第一个匹配的石头
    final stone = matchingStones.first;

    try {
      final result = await _apiService.chargeCardToStone(card.id, stone.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );
      _loadData();
      if (widget.onRefresh != null) widget.onRefresh!();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('充值失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的卡牌'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
            : Column(
                children: [
                  // 抽卡状态和按钮
                  _buildDrawSection(),
                  const SizedBox(height: 16),
                  // 卡牌列表
                  Expanded(
                    child: _cards.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cards.length,
                            itemBuilder: (context, index) => _buildCardItem(_cards[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDrawSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4EFF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '免费抽卡: ${_drawStatus?.freeDrawsAvailable ?? 0}次',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                '能量抽卡: ${_drawStatus?.energyDrawsRemaining ?? 3}次剩余',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _goToDraw,
            icon: const Icon(Icons.shuffle),
            label: const Text('抽卡'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB794FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('还没有卡牌', style: TextStyle(fontSize: 18, color: Colors.white)),
          const SizedBox(height: 8),
          Text('打卡或消耗能量抽卡吧', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildCardItem(Card card) {
    final color = _parseColor(card.colorCode);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), const Color(0xFF2A2A4A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.6),
                    ),
                    child: Center(
                      child: Text(
                        '${card.energyLevel}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${card.cardTypeName} · ${card.energyLevelName}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        '能量: ${card.remainingEnergy}/${card.energyValue}',
                        style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              if (card.canCharge && card.remainingEnergy > 0)
                ElevatedButton(
                  onPressed: () => _chargeCard(card),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('充值', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              card.mantra,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}