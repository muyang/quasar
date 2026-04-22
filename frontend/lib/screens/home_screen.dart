import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/energy_stone_widget.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'calendar_screen.dart';
import 'my_stones_screen.dart';
import 'transfer_screen.dart';
import 'settings_screen.dart';
import 'stone_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
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
  int _currentTabIndex = 0;

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

  Future<void> _handleChargeComplete(int oldEnergy, String placeholder) async {
    if (_isLoading || !_canCheckIn || _stones.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stoneId = _stones[_currentPage].id;
      final response = await _apiService.chargeStone(stoneId);

      // 更新石头数据
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
          behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildMainPage(),
              MyStonesScreen(userId: widget.userId, onStoneTap: _navigateToStoneDetail, onRefresh: _refreshData),
              TransferScreen(userId: widget.userId, stones: _stones, onTransferComplete: _refreshData),
              SettingsScreen(userId: widget.userId, onRefresh: _refreshData),
            ],
          ),
          if (_showBlessingPanel && _lastBlessing != null)
            _buildBlessingPanel(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  void _navigateToStoneDetail(StoneDetail stone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoneDetailScreen(stone: stone, userId: widget.userId),
      ),
    ).then((_) => _refreshData());
  }

  Widget _buildMainPage() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
          ),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      );
    }

    if (_stones.isEmpty) {
      return _buildNoStonesPage();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF121212), Color(0xFF0A0A14)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(),
            // 石头页面滑动区域
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _stones.length,
                itemBuilder: (context, index) => _buildStonePage(index),
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
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
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
          // 石头编号
          Text(
            _stones.isNotEmpty ? _stones[_currentPage].uniqueCode : '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB794FF),
            ),
          ),
          // 右箭头
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

  Widget _buildStonePage(int index) {
    final stone = _stones[index];
    final stoneColor = _parseColor(stone.colorCode);
    final isDead = stone.status == 'DEAD';

    return Center(
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
          if (_isCheckingStatus && index == _currentPage)
            const Text('正在检查状态...', style: TextStyle(color: Colors.white54))
          else if (isDead)
            Text('已枯竭', style: TextStyle(color: Colors.red.withOpacity(0.7)))
          else if (index == _currentPage && !_canCheckIn)
            Text('今日已充能', style: TextStyle(color: stoneColor.withOpacity(0.8)))
          else if (index == _currentPage)
            Text('长按充能', style: TextStyle(color: stoneColor.withOpacity(0.8))),
          // 倍数提示
          if (!isDead && stone.nextMultiplier > 1 && index == _currentPage)
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
          // 石头组件
          if (index == _currentPage)
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF6B4EFF))
                : isDead
                    ? _buildDeadStone(stoneColor)
                    : !_canCheckIn
                        ? _buildDisabledStone(stone, stoneColor)
                        : EnergyStoneWidget(
                            stoneId: stone.id,
                            currentEnergy: stone.currentEnergy,
                            stoneColor: stoneColor,
                            onChargeComplete: _handleChargeComplete,
                          )
          else
            _buildPreviewStone(stone, stoneColor),
          const SizedBox(height: 24),
          // 能量显示
          Text(
            '能量: ${stone.currentEnergy}/${stone.energyCap}',
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStone(StoneDetail stone, Color color) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [color.withOpacity(0.6), color.withOpacity(0.2), const Color(0xFF1A1A3A)],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Text('${stone.currentEnergy}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildDeadStone(Color color) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [Colors.grey.withOpacity(0.3), const Color(0xFF1A1A2A), const Color(0xFF0A0A1A)],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_rounded, size: 48, color: Colors.red.withOpacity(0.6)),
            const SizedBox(height: 8),
            const Text('0', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledStone(StoneDetail stone, Color color) {
    return GestureDetector(
      onTap: _showAlreadyCheckedInDialog,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [color.withOpacity(0.3), const Color(0xFF2A2A4A), const Color(0xFF1A1A3A)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFFB794FF)),
              const SizedBox(height: 8),
              Text('${stone.currentEnergy}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white54)),
              const SizedBox(height: 4),
              Text('能量', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4))),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlreadyCheckedInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('今日已充能', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_statusMessage ?? '今天已经充能过了，明天再来吧', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            if (_lastMultiplier != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('本次获得 ${_lastMultiplier}x 倍能量\n连续打卡 ${_lastConsecutiveDays ?? 0} 天', style: const TextStyle(color: Color(0xFFB794FF))),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('好的', style: TextStyle(color: Color(0xFFB794FF)))),
        ],
      ),
    );
  }

  Widget _buildNoStonesPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A1A2E), Color(0xFF121212)]),
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
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2A4A), Color(0xFF1A1A3A)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: const Color(0xFF6B4EFF).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
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
                        Text('充能完成', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: _closeBlessingPanel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_lastMultiplier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF6B4EFF).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_lastMultiplier}x倍能量 · 连续${_lastConsecutiveDays ?? 0}天', style: const TextStyle(color: Color(0xFFB794FF))),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFF6B4EFF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFB794FF), size: 24),
                          const SizedBox(width: 8),
                          Text('能量: ${stone?.currentEnergy ?? 0} / ${stone?.energyCap ?? 100}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_lastBlessing!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFFB794FF), fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onTabChanged,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFFB794FF),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
          BottomNavigationBarItem(icon: Icon(Icons.diamond), label: '我的'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: '转赠'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}