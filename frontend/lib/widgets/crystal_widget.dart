import 'dart:math';
import 'package:flutter/material.dart';

/// 水晶视觉组件 - 绘制具有能量映射的水晶造型
class CrystalWidget extends StatefulWidget {
  final int currentEnergy;
  final int maxEnergy;
  final Color baseColor;
  final bool isDead;
  final bool isCharging;
  final double chargeProgress;
  final VoidCallback? onTap;

  const CrystalWidget({
    super.key,
    required this.currentEnergy,
    this.maxEnergy = 100,
    required this.baseColor,
    this.isDead = false,
    this.isCharging = false,
    this.chargeProgress = 0.0,
    this.onTap,
  });

  @override
  State<CrystalWidget> createState() => _CrystalWidgetState();
}

class _CrystalWidgetState extends State<CrystalWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// 根据能量值计算亮度等级
  double _getEnergyBrightness() {
    if (widget.isDead) return 0.1;
    final ratio = widget.currentEnergy / widget.maxEnergy;
    // 能量映射：0-20: 0.3, 21-40: 0.5, 41-60: 0.7, 61-80: 0.85, 81-100: 1.0
    if (ratio <= 0.2) return 0.3;
    if (ratio <= 0.4) return 0.5;
    if (ratio <= 0.6) return 0.7;
    if (ratio <= 0.8) return 0.85;
    return 1.0;
  }

  /// 计算光晕强度
  double _getGlowIntensity() {
    if (widget.isDead) return 0.0;
    final brightness = _getEnergyBrightness();
    final pulse = _pulseAnimation.value;
    return brightness * (0.5 + pulse * 0.5);
  }

  /// 计算颜色
  Color _getDisplayColor() {
    if (widget.isDead) return Colors.grey;

    final brightness = _getEnergyBrightness();
    // 充电时颜色更亮
    if (widget.isCharging) {
      final chargeBoost = widget.chargeProgress * 0.5;
      return Color.lerp(widget.baseColor, Colors.white, chargeBoost + brightness * 0.3) ?? widget.baseColor;
    }

    return Color.lerp(widget.baseColor, Colors.white, brightness * 0.2) ?? widget.baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final displayColor = _getDisplayColor();
    final glowIntensity = _getGlowIntensity();
    final brightness = _getEnergyBrightness();

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 200,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 外层光晕
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 160 + glowIntensity * 80,
              height: 200 + glowIntensity * 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: displayColor.withOpacity(0.2 + glowIntensity * 0.3),
                    blurRadius: 20 + glowIntensity * 40,
                    spreadRadius: glowIntensity * 15,
                  ),
                  BoxShadow(
                    color: displayColor.withOpacity(0.3 + glowIntensity * 0.2),
                    blurRadius: 40 + glowIntensity * 30,
                    spreadRadius: glowIntensity * 10,
                  ),
                ],
              ),
            ),
            // 水晶主体
            CustomPaint(
              size: const Size(120, 180),
              painter: CrystalPainter(
                color: displayColor,
                brightness: brightness,
                glowIntensity: glowIntensity,
                isDead: widget.isDead,
                isCharging: widget.isCharging,
                chargeProgress: widget.chargeProgress,
              ),
            ),
            // 能量数值
            Positioned(
              bottom: 20,
              child: Column(
                children: [
                  Text(
                    '${widget.currentEnergy}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: widget.isDead ? Colors.grey : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '能量',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(widget.isDead ? 0.3 : 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // 充电进度指示
            if (widget.isCharging)
              Positioned(
                bottom: 60,
                child: Container(
                  width: 100,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.chargeProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.baseColor, displayColor],
                        ),
                        borderRadius: BorderRadius.circular(3),
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
}

/// 水晶绘制器 - 绘制六角棱柱水晶形状
class CrystalPainter extends CustomPainter {
  final Color color;
  final double brightness;
  final double glowIntensity;
  final bool isDead;
  final bool isCharging;
  final double chargeProgress;

  CrystalPainter({
    required this.color,
    required this.brightness,
    required this.glowIntensity,
    this.isDead = false,
    this.isCharging = false,
    this.chargeProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerWidth = size.width / 2;
    final crystalColor = isDead ? Colors.grey.withOpacity(0.3) : color;

    // 绘制水晶形状
    final path = _createCrystalPath(centerWidth, size.height);

    // 创建渐变填充
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        crystalColor.withOpacity(0.9),
        crystalColor.withOpacity(0.6),
        crystalColor.withOpacity(0.3),
        const Color(0xFF1A1A3A).withOpacity(0.8),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // 绘制边缘发光
    if (!isDead && glowIntensity > 0) {
      final edgePaint = Paint()
        ..color = crystalColor.withOpacity(glowIntensity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + glowIntensity * 2;

      canvas.drawPath(path, edgePaint);
    }

    // 绘制内部折射线
    if (!isDead && brightness > 0.4) {
      _drawInternalReflections(canvas, centerWidth, size.height, crystalColor);
    }

    // 充电时绘制能量涌动效果
    if (isCharging) {
      _drawChargeEffect(canvas, centerWidth, size.height, color, chargeProgress);
    }
  }

  /// 创建水晶路径（六角棱柱 + 顶部尖角）
  Path _createCrystalPath(double centerX, double height) {
    final path = Path();

    // 水晶尺寸参数
    final topTip = 15.0;        // 顶部尖角高度
    final topWidth = 20.0;      // 顶部宽度
    final midWidth = 50.0;      // 中部宽度
    final bottomWidth = 35.0;   // 底部宽度
    final topSection = 40.0;    // 上部高度
    final midSection = 80.0;    // 中部高度

    // 从顶部尖角开始
    path.moveTo(centerX, topTip);

    // 右侧上斜面
    path.lineTo(centerX + topWidth / 2, topTip + 15);
    path.lineTo(centerX + midWidth / 2, topTip + topSection);

    // 右侧垂直边
    path.lineTo(centerX + midWidth / 2, topTip + topSection + midSection);

    // 右侧下斜面
    path.lineTo(centerX + bottomWidth / 2, height - 30);

    // 底部
    path.lineTo(centerX, height - 10);
    path.lineTo(centerX - bottomWidth / 2, height - 30);

    // 左侧下斜面
    path.lineTo(centerX - midWidth / 2, topTip + topSection + midSection);

    // 左侧垂直边
    path.lineTo(centerX - midWidth / 2, topTip + topSection);

    // 左侧上斜面
    path.lineTo(centerX - topWidth / 2, topTip + 15);

    // 回到顶部尖角
    path.close();

    return path;
  }

  /// 绘制内部折射线
  void _drawInternalReflections(Canvas canvas, double centerX, double height, Color color) {
    final reflectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.15 + brightness * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 左侧折射线
    canvas.drawLine(
      Offset(centerX - 15, height * 0.3),
      Offset(centerX - 5, height * 0.7),
      reflectionPaint,
    );

    // 中间折射线
    canvas.drawLine(
      Offset(centerX + 5, height * 0.2),
      Offset(centerX, height * 0.5),
      reflectionPaint,
    );

    // 右侧折射线
    canvas.drawLine(
      Offset(centerX + 20, height * 0.35),
      Offset(centerX + 10, height * 0.65),
      reflectionPaint,
    );
  }

  /// 绘制充电效果
  void _drawChargeEffect(Canvas canvas, double centerX, double height, Color color, double progress) {
    // 能量涌动光点
    final sparkCount = 5;
    final sparkPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sparkCount; i++) {
      final sparkY = height * (0.2 + progress * 0.6 + (i * 0.1));
      final sparkX = centerX + (Random().nextDouble() - 0.5) * 30;
      final sparkSize = 2 + Random().nextDouble() * 3;

      canvas.drawCircle(Offset(sparkX, sparkY), sparkSize, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CrystalPainter oldDelegate) {
    return color != oldDelegate.color ||
        brightness != oldDelegate.brightness ||
        glowIntensity != oldDelegate.glowIntensity ||
        isDead != oldDelegate.isDead ||
        isCharging != oldDelegate.isCharging ||
        chargeProgress != oldDelegate.chargeProgress;
  }
}