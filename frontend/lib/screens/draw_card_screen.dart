import 'dart:async';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class DrawCardScreen extends StatefulWidget {
  final int userId;
  final DrawStatus? drawStatus;
  final List<StoneDetail> stones;

  const DrawCardScreen({
    super.key,
    required this.userId,
    this.drawStatus,
    required this.stones,
  });

  @override
  State<DrawCardScreen> createState() => _DrawCardScreenState();
}

class _DrawCardScreenState extends State<DrawCardScreen> {
  final ApiService _apiService = ApiService();
  DrawStatus? _drawStatus;
  bool _isDrawing = false;
  Card? _drawnCard;
  bool _showResult = false;
  double _spinProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _drawStatus = widget.drawStatus;
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _apiService.getDrawStatus(widget.userId);
      setState(() {
        _drawStatus = status;
      });
    } catch (e) {
      print('[DrawCard] 加载状态失败: $e');
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _drawCard(String drawType) async {
    if (_isDrawing) return;

    // 检查是否可以抽卡
    if (drawType == 'FREE') {
      final freeAvailable = _drawStatus?.freeDrawsAvailable ?? 0;
      if (freeAvailable <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('免费抽卡次数已用完'), backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      final energyRemaining = _drawStatus?.energyDrawsRemaining ?? 0;
      if (energyRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('能量抽卡次数已达上限'), backgroundColor: Colors.red),
        );
        return;
      }
      // 检查能量是否足够
      final totalEnergy = widget.stones.fold<int>(0, (sum, s) => sum + s.currentEnergy);
      if (totalEnergy < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('能量不足，抽卡需要3点能量'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isDrawing = true;
      _showResult = false;
      _spinProgress = 0.0;
    });

    // 动画效果
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _spinProgress += 0.1;
      });
      if (_spinProgress >= 1.0) {
        timer.cancel();
      }
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final result = await _apiService.drawCard(widget.userId, drawType);
      HapticFeedback.mediumImpact();

      setState(() {
        _isDrawing = false;
        _drawnCard = result.card;
        _showResult = true;
      });

      // 刷新状态
      _loadStatus();
    } catch (e) {
      setState(() {
        _isDrawing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('抽卡失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _closeResult() {
    setState(() {
      _showResult = false;
      _drawnCard = null;
    });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抽卡'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 状态显示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A4A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '免费抽卡: ${_drawStatus?.freeDrawsAvailable ?? 0}次',
                          style: const TextStyle(color: Color(0xFFB794FF), fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '能量抽卡: ${_drawStatus?.energyDrawsRemaining ?? 3}次剩余 (每次消耗3点能量)',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 抽卡按钮
                  if (!_isDrawing && !_showResult)
                    Column(
                      children: [
                        _buildDrawButton('FREE', '免费抽卡', (_drawStatus?.freeDrawsAvailable ?? 0) > 0),
                        const SizedBox(height: 16),
                        _buildDrawButton('ENERGY', '能量抽卡', (_drawStatus?.energyDrawsRemaining ?? 0) > 0),
                      ],
                    ),

                  // 抽卡动画
                  if (_isDrawing)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6B4EFF).withOpacity(_spinProgress),
                            const Color(0xFFB794FF).withOpacity(_spinProgress * 0.5),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                      ),
                    ),
                ],
              ),
            ),

            // 抽卡结果弹窗
            if (_showResult && _drawnCard != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _parseColor(_drawnCard!.colorCode).withOpacity(0.5),
                            const Color(0xFF2A2A4A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _parseColor(_drawnCard!.colorCode).withOpacity(0.6),
                            ),
                            child: Center(
                              child: Text(
                                '${_drawnCard!.energyLevel}',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_drawnCard!.cardTypeName} · ${_drawnCard!.energyLevelName}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '能量值: ${_drawnCard!.energyValue}',
                            style: TextStyle(fontSize: 16, color: _parseColor(_drawnCard!.colorCode)),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _drawnCard!.mantra,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _closeResult,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB794FF),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('太棒了！', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawButton(String type, String label, bool enabled) {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton(
        onPressed: enabled ? () => _drawCard(type) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF6B4EFF) : const Color(0xFF2A2A4A),
          disabledBackgroundColor: const Color(0xFF2A2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}