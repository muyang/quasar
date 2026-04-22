import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/crystal_widget.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'calendar_screen.dart';
import 'stone_detail_screen.dart';
import 'cards_screen.dart';
import 'settings_screen.dart';
import 'draw_card_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PageController _pageController = PageController();

  List<StoneDetail> _stones = [];
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isCheckingStatus = true;
  bool _canCheckIn = true;
  String? _statusMessage;
  String? _lastBlessing;
  int? _lastMultiplier;
  int? _lastConsecutiveDays;
  bool _showBlessingPanel = false;
  bool _showDrawPrompt = false;
  int _currentTabIndex = 0;

  // 石头视图模式：卡片 or 列表
  bool _isStoneCardView = true;
  bool _isPressed = false;
  double _pressProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stones = await _apiService.getUserStones(widget.userId);
      setState(() {
        _stones = stones;
        _isLoading = false;
      });

      if (stones.isNotEmpty) {
        await _checkStatus(stones[_currentPage].id);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('[HomeScreen] 加载失败: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _checkStatus(int stoneId) async {
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await _apiService.getCheckInStatus(stoneId);
      setState(() {
        _canCheckIn = status.canCheckIn;
        _statusMessage = status.message;
        _isCheckingStatus = false;
      });
    } catch (e) {
      setState(() {
        _canCheckIn = true;
        _isCheckingStatus = false;
      });
      print('[HomeScreen] 获取打卡状态失败: $e');
    }
  }

  Future<void> _handleChargeComplete() async {
    if (_isLoading || !_canCheckIn || _stones.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stoneId = _stones[_currentPage].id;
      final response = await _apiService.chargeStone(stoneId);

      _stones[_currentPage] = StoneDetail(
        id: _stones[_currentPage].id,
        uniqueCode: _stones[_currentPage].uniqueCode,
        stoneType: _stones[_currentPage].stoneType,
        stoneTypeName: _stones[_currentPage].stoneTypeName,
        colorCode: _stones[_currentPage].colorCode,
        ownerId: _stones[_currentPage].ownerId,
        ownerNickname: _stones[_currentPage].ownerNickname,
        currentEnergy: response.energyAfter,
        energyCap: _stones[_currentPage].energyCap,
        deathCount: _stones[_currentPage].deathCount,
        status: response.status,
        consecutiveDays: response.consecutiveDays,
        nextMultiplier: _calculateNextMultiplier(response.consecutiveDays),
        canTransfer: response.energyAfter > 0 && response.status == 'ALIVE',
      );

      setState(() {
        _isLoading = false;
        _showBlessingPanel = true;
        _showDrawPrompt = response.freeDrawAvailable;
        _canCheckIn = false;
        _statusMessage = '今日已充能，明天再来吧';
        _lastBlessing = response.blessing;
        _lastMultiplier = response.multiplier;
        _lastConsecutiveDays = response.consecutiveDays;
      });

      print('[HomeScreen] 充能成功: ${response.energyBefore} -> ${response.energyAfter}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('充能失败: $e'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
    }
  }

  int _calculateNextMultiplier(int consecutiveDays) {
    return (consecutiveDays + 1 > 9) ? 9 : consecutiveDays + 1;
  }

  void _closeBlessingPanel() {
    setState(() {
      _showBlessingPanel = false;
    });
  }

  void _openCalendar() {
    if (_stones.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarScreen(stoneId: _stones[_currentPage].id),
        ),
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    if (_stones.isNotEmpty && index < _stones.length) {
      _checkStatus(_stones[index].id);
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentTabIndex = index;
    });
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _navigateToStoneDetail(StoneDetail stone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoneDetailScreen(stone: stone, userId: widget.userId),
      ),
    ).then((_) => _refreshData());
  }

  // 长按充能逻辑
  void _startPress() {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
      _pressProgress = 0.0;
    });

    _playChant();

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPressed) {
        timer.cancel();
        return;
      }
      setState(() {
        _pressProgress += 0.05 / 3.0;
      });
      if (_pressProgress >= 1.0) {
        timer.cancel();
        _completeCharge();
      }
    });
  }

  void _endPress() {
    if (!_isPressed) return;
    _stopChant();
    if (_pressProgress < 1.0) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });
  }

  void _completeCharge() {
    _stopChant();
    HapticFeedback.heavyImpact();
    _handleChargeComplete();
    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });
  }

  Future<void> _playChant() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/chant.mp3'));
    } catch (e) {
      print('[Audio] 播放音频失败: $e');
    }
  }

  Future<void> _stopChant() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('[Audio] 停止音频失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildStonesPage(),
              CardsScreen(userId: widget.userId, stones: _stones, onRefresh: _refreshData),
              SettingsScreen(userId: widget.userId, onRefresh: _refreshData),
            ],
          ),
          if (_showBlessingPanel && _lastBlessing != null)
            _buildBlessingPanel(),
          if (_showDrawPrompt)
            _buildDrawPromptPanel(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// 石头页面（卡片视图或列表视图）
  Widget _buildStonesPage() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
          ),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      );
    }

    if (_stones.isEmpty) {
      return _buildNoStonesPage();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('我的水晶'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          // 视图切换按钮
          IconButton(
            icon: Icon(_isStoneCardView ? Icons.list : Icons.view_carousel),
            onPressed: () {
              setState(() {
                _isStoneCardView = !_isStoneCardView;
              });
            },
            tooltip: _isStoneCardView ? '切换到列表视图' : '切换到卡片视图',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
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
        child: _isStoneCardView
            ? _buildCardView()
            : _buildListView(),
      ),
    );
  }

  /// 卡片视图（左右滑动）
  Widget _buildCardView() {
    return Column(
      children: [
        // 顶部导航指示
        _buildTopBar(),
        // 石头卡片滑动区域
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _stones.length,
            itemBuilder: (context, index) => _buildStoneCard(index),
          ),
        ),
        // 底部日历入口
        if (_stones.isNotEmpty && _stones[_currentPage].status == 'ALIVE')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: const Icon(Icons.calendar_today, color: Color(0xFFB794FF)),
              onPressed: _openCalendar,
              tooltip: '查看打卡记录',
            ),
          ),
      ],
    );
  }

  /// 顶部导航栏
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            _stones.isNotEmpty ? _stones[_currentPage].uniqueCode : '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB794FF),
            ),
          ),
          if (_currentPage < _stones.length - 1)
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
    );
  }

  /// 单个石头卡片
  Widget _buildStoneCard(int index) {
    final stone = _stones[index];
    final stoneColor = _parseColor(stone.colorCode);
    final isDead = stone.status == 'DEAD';
    final isCurrent = index == _currentPage;

    return GestureDetector(
      onTap: () => _navigateToStoneDetail(stone),
      onLongPressStart: isCurrent && _canCheckIn && !isDead ? (_) => _startPress() : null,
      onLongPressEnd: isCurrent && _canCheckIn && !isDead ? (_) => _endPress() : null,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 石头类型
              Text(
                '${stone.stoneTypeName}水晶',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stoneColor),
              ),
              const SizedBox(height: 8),
              // 状态提示
              if (_isCheckingStatus && isCurrent)
                const Text('正在检查状态...', style: TextStyle(color: Colors.white54))
              else if (isDead)
                Text('已枯竭', style: TextStyle(color: Colors.red.withOpacity(0.7)))
              else if (isCurrent && !_canCheckIn)
                Text('今日已充能', style: TextStyle(color: stoneColor.withOpacity(0.8)))
              else if (isCurrent)
                Text('长按充能', style: TextStyle(color: stoneColor.withOpacity(0.8))),
              // 倍数提示
              if (!isDead && stone.nextMultiplier > 1 && isCurrent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: stoneColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '连续${stone.consecutiveDays}天 · 下次${stone.nextMultiplier}x倍',
                      style: TextStyle(color: stoneColor, fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // 水晶组件
              CrystalWidget(
                currentEnergy: stone.currentEnergy,
                maxEnergy: stone.energyCap,
                baseColor: stoneColor,
                isDead: isDead,
                isCharging: isCurrent && _isPressed && _canCheckIn,
                chargeProgress: _pressProgress,
              ),
              const SizedBox(height: 24),
              // 能量显示
              Text(
                '能量: ${stone.currentEnergy}/${stone.energyCap}',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              // 查看详情按钮
              ElevatedButton.icon(
                onPressed: () => _navigateToStoneDetail(stone),
                icon: const Icon(Icons.info_outline),
                label: const Text('查看详情'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stoneColor.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 列表视图
  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stones.length,
        itemBuilder: (context, index) => _buildStoneListItem(_stones[index]),
      ),
    );
  }

  /// 列表项
  Widget _buildStoneListItem(StoneDetail stone) {
    final color = _parseColor(stone.colorCode);
    final isDead = stone.status == 'DEAD';

    return GestureDetector(
      onTap: () => _navigateToStoneDetail(stone),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(isDead ? 0.1 : 0.3), const Color(0xFF2A2A4A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // 水晶缩略图
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: RadialGradient(
                  colors: isDead
                      ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)]
                      : [color.withOpacity(0.8), color.withOpacity(0.3)],
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
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
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
                      Text('能量: ${stone.currentEnergy}/${stone.energyCap}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      const SizedBox(width: 16),
                      if (!isDead)
                        Icon(Icons.trending_up, size: 16, color: color),
                      if (!isDead)
                        const SizedBox(width: 4),
                      if (!isDead)
                        Text('${stone.nextMultiplier}x', style: TextStyle(color: color)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStonesPage() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('我的水晶'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF121212)]),
        ),
        child: Center(
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
        ),
      ),
    );
  }

  Widget _buildBlessingPanel() {
    final stone = _stones.isNotEmpty ? _stones[_currentPage] : null;
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: _closeBlessingPanel,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A2A4A), Color(0xFF1A1A3A)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: const Color(0xFF6B4EFF).withOpacity(0.3), blurRadius: 30)],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('充能完成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: _closeBlessingPanel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_lastMultiplier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${_lastMultiplier}x倍能量 · 连续${_lastConsecutiveDays ?? 0}天',
                            style: const TextStyle(color: Color(0xFFB794FF))),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4EFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFB794FF), size: 24),
                          const SizedBox(width: 8),
                          Text('能量: ${stone?.currentEnergy ?? 0} / ${stone?.energyCap ?? 100}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_lastBlessing!, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Color(0xFFB794FF), fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawPromptPanel() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A4A),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.style, size: 64, color: Color(0xFFB794FF)),
                const SizedBox(height: 16),
                const Text('打卡成功！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('获得一次免费抽卡机会', style: TextStyle(fontSize: 16, color: Color(0xFFB794FF))),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showDrawPrompt = false;
                      _showBlessingPanel = false;
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrawCardScreen(userId: widget.userId, stones: _stones),
                      ),
                    ).then((_) => _refreshData());
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('去抽卡'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4EFF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showDrawPrompt = false;
                    });
                  },
                  child: Text('稍后再抽', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onTabChanged,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFFB794FF),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.diamond), label: '水晶'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: '卡牌'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}