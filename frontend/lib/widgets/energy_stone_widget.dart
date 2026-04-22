import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class EnergyStoneWidget extends StatefulWidget {
  final int stoneId;
  final int currentEnergy;
  final Color stoneColor;
  final Function(int newEnergy, String blessing)? onChargeComplete;

  const EnergyStoneWidget({
    super.key,
    required this.stoneId,
    required this.currentEnergy,
    required this.stoneColor,
    this.onChargeComplete,
  });

  @override
  State<EnergyStoneWidget> createState() => _EnergyStoneWidgetState();
}

class _EnergyStoneWidgetState extends State<EnergyStoneWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPressed = false;
  double _pressProgress = 0.0;
  Timer? _progressTimer;
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;

  static const double chargeDurationSeconds = 3.0;
  static const double heartbeatIntervalSeconds = 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressTimer?.cancel();
    _heartbeatTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playChant() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/chant.mp3'));
      print('[Audio] 开始播放咒语音频');
    } catch (e) {
      print('[Audio] 播放音频失败: $e（请确保 assets/audio/chant.mp3 文件存在）');
    }
  }

  Future<void> _stopChant() async {
    try {
      await _audioPlayer.stop();
      print('[Audio] 停止播放咒语音频');
    } catch (e) {
      print('[Audio] 停止音频失败: $e');
    }
  }

  void _startPress() {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
      _pressProgress = 0.0;
      _heartbeatCount = 0;
    });

    _controller.forward();
    _playChant();

    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        setState(() {
          _pressProgress += 0.05 / chargeDurationSeconds;
        });

        if (_pressProgress >= 1.0) {
          _completeCharge();
          timer.cancel();
        }
      },
    );

    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: (heartbeatIntervalSeconds * 1000).round()),
      (timer) {
        if (_isPressed && _pressProgress < 1.0) {
          HapticFeedback.lightImpact();
          _heartbeatCount++;
          print('[Haptic] 心跳震动 #$_heartbeatCount');
        }
      },
    );
  }

  void _endPress() {
    if (!_isPressed) return;

    _progressTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopChant();

    if (_pressProgress < 1.0) {
      _controller.reverse();
      HapticFeedback.lightImpact();
      print('[Charge] 未充满，能量消散 (进度: ${_pressProgress.toStringAsFixed(2)})');
    }

    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });
  }

  void _completeCharge() {
    _heartbeatTimer?.cancel();
    _stopChant();
    HapticFeedback.heavyImpact();
    print('[Charge] 充能完成!');

    if (widget.onChargeComplete != null) {
      widget.onChargeComplete!(widget.currentEnergy, '');
    }

    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });

    _controller.reverse();
  }

  Color _getGlowColor() {
    final progress = _pressProgress;
    // 使用石头的基础颜色
    final baseColor = widget.stoneColor;
    // 根据进度调整亮度
    if (progress < 0.3) {
      return baseColor.withOpacity(0.6);
    } else if (progress < 0.6) {
      return baseColor.withOpacity(0.8);
    } else if (progress < 0.9) {
      return baseColor;
    } else {
      return Color.lerp(baseColor, Colors.white, 0.3) ?? baseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor();
    final glowIntensity = _glowAnimation.value * _pressProgress;
    final scale = 1.0 + (_scaleAnimation.value - 1.0) * _pressProgress;

    return GestureDetector(
      onLongPressStart: (_) => _startPress(),
      onLongPressEnd: (_) => _endPress(),
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 200 + glowIntensity * 80,
              height: 200 + glowIntensity * 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3 + glowIntensity * 0.4),
                    blurRadius: 30 + glowIntensity * 50,
                    spreadRadius: glowIntensity * 20,
                  ),
                  BoxShadow(
                    color: glowColor.withOpacity(0.5 + glowIntensity * 0.3),
                    blurRadius: 20 + glowIntensity * 30,
                    spreadRadius: glowIntensity * 10,
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [
                      glowColor.withOpacity(0.9),
                      widget.stoneColor.withOpacity(0.4),
                      const Color(0xFF1A1A3A),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.currentEnergy}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '能量',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              child: AnimatedOpacity(
                opacity: _isPressed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 200,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _pressProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.stoneColor, glowColor],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isPressed && _pressProgress < 1.0)
              Positioned(
                top: 20,
                child: Text(
                  '${(_pressProgress * chargeDurationSeconds).toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: glowColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}