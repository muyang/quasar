import 'package:flutter/material.dart';
import '../widgets/energy_stone_widget.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int _stoneId = 1;
  int _currentEnergy = 10;
  String _status = 'ALIVE';
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _canCheckIn = true;
  String? _statusMessage;
  String? _lastBlessing;
  bool _showBlessingPanel = false;

  @override
  void initState() {
    super.initState();
    _loadCheckInStatus();
    print('[HomeScreen] 初始化，石头 ID: $_stoneId');
  }

  Future<void> _loadCheckInStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await _apiService.getCheckInStatus(_stoneId);
      setState(() {
        _canCheckIn = status.canCheckIn;
        _statusMessage = status.message;
        _isCheckingStatus = false;
      });
      print('[HomeScreen] 打卡状态: canCheckIn=${status.canCheckIn}, message=${status.message}');
    } catch (e) {
      setState(() {
        _canCheckIn = true;
        _isCheckingStatus = false;
      });
      print('[HomeScreen] 获取打卡状态失败: $e');
    }
  }

  Future<void> _handleChargeComplete(int oldEnergy, String placeholder) async {
    if (_isLoading || !_canCheckIn) return;

    setState(() {
      _isLoading = true;
    });

    print('[HomeScreen] 开始调用充能 API，石头 ID: $_stoneId');

    try {
      final response = await _apiService.chargeStone(_stoneId);

      setState(() {
        _currentEnergy = response.energyAfter;
        _status = response.status;
        _lastBlessing = response.blessing;
        _isLoading = false;
        _showBlessingPanel = true;
        _canCheckIn = false;
        _statusMessage = '今日已充能，明天再来吧';
      });

      print('[HomeScreen] 充能成功: ${response.energyBefore} -> ${response.energyAfter}');
      print('[HomeScreen] 祝福语: ${response.blessing}');
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

      print('[HomeScreen] 充能失败: $e');
    }
  }

  void _showAlreadyCheckedInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '今日已充能',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          _statusMessage ?? '今天已经充能过了，明天再来吧',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '好的',
              style: TextStyle(color: Color(0xFFB794FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _closeBlessingPanel() {
    setState(() {
      _showBlessingPanel = false;
    });
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarScreen(stoneId: _stoneId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDead = _status == 'DEAD';

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF121212),
                  Color(0xFF0A0A14),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '能量石',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, color: Color(0xFFB794FF)),
                          onPressed: _openCalendar,
                          tooltip: '查看打卡记录',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isCheckingStatus)
                      const Text(
                        '正在检查状态...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      )
                    else if (isDead)
                      Text(
                        '已枯竭',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red.withOpacity(0.7),
                        ),
                      )
                    else if (!_canCheckIn)
                      Text(
                        '今日已充能',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFB794FF).withOpacity(0.8),
                        ),
                      )
                    else
                      Text(
                        '长按充能',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF6B4EFF).withOpacity(0.8),
                        ),
                      ),
                    const SizedBox(height: 40),
                    if (_isLoading)
                      const CircularProgressIndicator(
                        color: Color(0xFF6B4EFF),
                      )
                    else if (isDead)
                      _buildDeadStone()
                    else if (!_canCheckIn)
                      _buildDisabledStone()
                    else
                      EnergyStoneWidget(
                        stoneId: _stoneId,
                        currentEnergy: _currentEnergy,
                        onChargeComplete: _handleChargeComplete,
                      ),
                    const SizedBox(height: 40),
                    if (!isDead && _canCheckIn)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          '持续长按 3 秒为石头注入能量',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showBlessingPanel && _lastBlessing != null)
            _buildBlessingPanel(),
        ],
      ),
    );
  }

  Widget _buildDeadStone() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Colors.grey.withOpacity(0.3),
            const Color(0xFF1A1A2A),
            const Color(0xFF0A0A1A),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_rounded,
              size: 48,
              color: Colors.red.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              '0',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledStone() {
    return GestureDetector(
      onTap: _showAlreadyCheckedInDialog,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              const Color(0xFF6B4EFF).withOpacity(0.3),
              const Color(0xFF2A2A4A),
              const Color(0xFF1A1A3A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Color(0xFFB794FF),
              ),
              const SizedBox(height: 8),
              Text(
                '$_currentEnergy',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '能量',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlessingPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: _closeBlessingPanel,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2A2A4A),
                const Color(0xFF1A1A3A),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4EFF).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
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
                      Text(
                        '充能完成',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: _closeBlessingPanel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFB794FF),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '能量: $_currentEnergy / 100',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _lastBlessing!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFB794FF),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}