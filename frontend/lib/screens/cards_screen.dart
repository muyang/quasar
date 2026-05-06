import 'package:flutter/material.dart' hide Card;
import '../services/api_service.dart';
import '../models/stone.dart';
import '../widgets/card_widget.dart';
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
  final PageController _pageController = PageController();

  List<Card> _cards = [];
  List<CollectionProgress> _collections = [];
  DrawStatus? _drawStatus;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isCardView = true;
  bool _synthesisMode = false;
  bool _showCollection = false;
  final Set<int> _selectedForSynthesis = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cards = await _apiService.getUserCards(widget.userId);
      final status = await _apiService.getDrawStatus(widget.userId);
      final collections = await _apiService.getCollection(widget.userId);
      setState(() {
        _cards = cards;
        _drawStatus = status;
        _collections = collections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('[Cards] 加载失败: $e');
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

  void _showGiftDialog(Card card) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: const Text('赠送卡牌', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '输入接收者用户ID',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '如: 5',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () async {
              final toUserId = int.tryParse(controller.text.trim());
              if (toUserId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的用户ID'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              await _executeGift(card, toUserId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
            ),
            child: const Text('赠送', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeGift(Card card, int toUserId) async {
    try {
      await _apiService.giftCard(card.id, toUserId);

      // 执行动画
      if (_isCardView) {
        // 卡片视图：飞出淡出动画
        _animateCardFlyOut(card);
      } else {
        // 列表视图：从列表消失
        setState(() {
          _cards.removeWhere((c) => c.id == card.id);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('卡牌已发送，等待对方确认接收'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('赠送失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _animateCardFlyOut(Card card) {
    // 简化实现：直接刷新列表
    setState(() {
      _cards.removeWhere((c) => c.id == card.id);
      if (_currentPage >= _cards.length) {
        _currentPage = _cards.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_synthesisMode ? '选择3张同类型同等级卡牌' : (_showCollection ? '收藏进度' : '我的卡牌')),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        leading: _synthesisMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() { _synthesisMode = false; _selectedForSynthesis.clear(); }),
              )
            : null,
        actions: [
          if (_synthesisMode)
            TextButton(
              onPressed: _selectedForSynthesis.length == 3 ? _executeSynthesis : null,
              child: Text('合成(${_selectedForSynthesis.length}/3)',
                  style: TextStyle(color: _selectedForSynthesis.length == 3 ? const Color(0xFFB794FF) : Colors.white38)),
            )
          else ...[
            // 收藏进度按钮
            IconButton(
              icon: Icon(_showCollection ? Icons.style : Icons.collections_bookmark, color: _showCollection ? const Color(0xFFB794FF) : Colors.white),
              onPressed: () => setState(() => _showCollection = !_showCollection),
              tooltip: '收藏进度',
            ),
            // 合成按钮
            IconButton(
              icon: const Icon(Icons.merge, color: Colors.white),
              onPressed: () => setState(() { _synthesisMode = !_synthesisMode; _selectedForSynthesis.clear(); }),
              tooltip: '合成',
            ),
            // 视图切换按钮
            IconButton(
              icon: Icon(_isCardView ? Icons.list : Icons.view_carousel),
              onPressed: () {
                setState(() {
                  _isCardView = !_isCardView;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
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
            : _showCollection
                ? _buildCollectionView()
                : Column(
                    children: [
                      if (!_synthesisMode) ...[
                        _buildDrawSection(),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: _cards.isEmpty
                            ? _buildEmptyState()
                            : _isCardView
                                ? _buildCardView()
                                : _buildListView(),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _toggleCardSelection(Card card) {
    if (!_synthesisMode) return;
    setState(() {
      if (_selectedForSynthesis.contains(card.id)) {
        _selectedForSynthesis.remove(card.id);
      } else {
        if (_selectedForSynthesis.isEmpty) {
          _selectedForSynthesis.add(card.id);
        } else {
          // Check same type and level
          final first = _cards.firstWhere((c) => c.id == _selectedForSynthesis.first);
          if (card.cardType == first.cardType && card.energyLevel == first.energyLevel) {
            if (_selectedForSynthesis.length < 3) {
              _selectedForSynthesis.add(card.id);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('合成需要相同类型和等级的卡牌'), backgroundColor: Colors.orange),
            );
          }
        }
      }
    });
  }

  Future<void> _executeSynthesis() async {
    if (_selectedForSynthesis.length != 3) return;
    try {
      final result = await _apiService.synthesizeCards(widget.userId, _selectedForSynthesis.toList());
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: const Color(0xFF6B4EFF)),
        );
        setState(() {
          _synthesisMode = false;
          _selectedForSynthesis.clear();
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('合成失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildCollectionView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('卡牌收藏进度', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        ..._collections.map((c) => _buildCollectionBar(c)),
      ],
    );
  }

  Widget _buildCollectionBar(CollectionProgress col) {
    final progress = col.total > 0 ? col.collected / col.total : 0.0;
    final color = _cardTypeColor(col.cardType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${col.cardTypeName}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
              Text('${col.collected}/${col.total}', style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _cardTypeColor(String type) {
    switch (type) {
      case 'HEALTH': return const Color(0xFF4CAF50);
      case 'LOVE': return const Color(0xFFE91E63);
      case 'WEALTH': return const Color(0xFFFFD700);
      case 'CAREER': return const Color(0xFFF44336);
      case 'FAMILY': return const Color(0xFF2196F3);
      default: return Colors.grey;
    }
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

  /// 卡片视图（左右滑动）
  Widget _buildCardView() {
    return Column(
      children: [
        // 导航指示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentPage > 0)
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                )
              else
                const SizedBox(width: 48),
              Text(
                '${_currentPage + 1} / ${_cards.length}',
                style: const TextStyle(color: Color(0xFFB794FF), fontSize: 16),
              ),
              if (_currentPage < _cards.length - 1)
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        // 卡牌滑动区域
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _cards.length,
            itemBuilder: (context, index) => _buildCardItem(_cards[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCardItem(Card card) {
    final color = _parseColor(card.colorCode);
    final isSelected = _selectedForSynthesis.contains(card.id);

    return GestureDetector(
      onTap: _synthesisMode ? () => _toggleCardSelection(card) : null,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_synthesisMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6B4EFF).withOpacity(0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? const Color(0xFF6B4EFF) : Colors.white24),
                  ),
                  child: Text(
                    isSelected ? '已选择' : '点击选择',
                    style: TextStyle(color: isSelected ? const Color(0xFFB794FF) : Colors.white38, fontSize: 12),
                  ),
                ),
              CardWidget(
                cardType: card.cardType,
                cardTypeName: card.cardTypeName,
                mantra: card.mantra,
                energyLevel: card.energyLevel,
                energyLevelName: card.energyLevelName,
                energyValue: card.energyValue,
                remainingEnergy: card.remainingEnergy,
                color: color,
                canCharge: !_synthesisMode && card.canCharge,
                imageUrl: card.imageUrl,
                rarity: card.rarity,
                rarityName: card.rarityName,
                cardTypeSubName: card.cardTypeSubName,
                cost: card.cost,
                attack: card.stats?.attack,
                health: card.stats?.health,
                tags: card.tags,
                name: card.name,
                cardWidth: card.cardWidth,
                cardHeight: card.cardHeight,
                imageFit: card.imageFit,
                marginTop: card.marginTop,
                marginLeft: card.marginLeft,
                marginBottom: card.marginBottom,
                marginRight: card.marginRight,
                onCharge: _synthesisMode || !card.canCharge || card.remainingEnergy <= 0
                    ? null
                    : () => _chargeCard(card),
                onGift: _synthesisMode || card.remainingEnergy <= 0
                    ? null
                    : () => _showGiftDialog(card),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 列表视图
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cards.length,
      itemBuilder: (context, index) => _buildListCardItem(_cards[index]),
    );
  }

  Widget _buildListCardItem(Card card) {
    final color = _parseColor(card.colorCode);
    final isSelected = _selectedForSynthesis.contains(card.id);
    return GestureDetector(
      onTap: _synthesisMode ? () => _toggleCardSelection(card) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(isSelected ? 0.6 : 0.3), const Color(0xFF2A2A4A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF6B4EFF) : color.withOpacity(0.5), width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_synthesisMode) ...[
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF6B4EFF) : Colors.transparent,
                          border: Border.all(color: isSelected ? const Color(0xFF6B4EFF) : Colors.white24),
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.6),
                      ),
                      child: Center(
                        child: Text('${card.energyLevel}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${card.cardTypeName} · ${card.energyLevelName}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                        Text('能量: ${card.remainingEnergy}/${card.energyValue}',
                            style: TextStyle(color: color.withOpacity(0.8), fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                if (!_synthesisMode)
                  Row(
                    children: [
                      if (card.canCharge && card.remainingEnergy > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => _chargeCard(card),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('充值', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      if (card.remainingEnergy > 0)
                        ElevatedButton(
                          onPressed: () => _showGiftDialog(card),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4EFF), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('赠送', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(card.mantra, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

}