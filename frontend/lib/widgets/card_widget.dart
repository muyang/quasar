import 'package:flutter/material.dart';

/// 卡牌视觉组件 - 英伦古典质感设计
class CardWidget extends StatefulWidget {
  final String cardType;
  final String cardTypeName;
  final String mantra;
  final int energyLevel;
  final String energyLevelName;
  final int energyValue;
  final int remainingEnergy;
  final Color color;
  final bool canCharge;
  final VoidCallback? onCharge;
  final VoidCallback? onGift;
  final bool showActions;

  const CardWidget({
    super.key,
    required this.cardType,
    required this.cardTypeName,
    required this.mantra,
    required this.energyLevel,
    required this.energyLevelName,
    required this.energyValue,
    required this.remainingEnergy,
    required this.color,
    this.canCharge = false,
    this.onCharge,
    this.onGift,
    this.showActions = true,
  });

  /// 获取类型图标
  IconData _getTypeIcon() {
    switch (cardType) {
      case 'HEALTH':
        return Icons.favorite_rounded;
      case 'LOVE':
        return Icons.local_florist_rounded;
      case 'WEALTH':
        return Icons.monetization_on_rounded;
      case 'CAREER':
        return Icons.trending_up_rounded;
      case 'FAMILY':
        return Icons.home_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 280,
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(0.6 + _glowAnimation.value * 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 背景渐变
              _buildBackground(),
              // 古典边框装饰
              _buildOrnateBorder(),
              // 内容
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 顶部：类型图标和等级
                    _buildHeader(),
                    const SizedBox(height: 24),
                    // 中部：咒语
                    Expanded(child: _buildMantraSection()),
                    const SizedBox(height: 24),
                    // 底部：能量和操作
                    if (widget.showActions) _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 背景渐变
  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withOpacity(0.15),
              const Color(0xFF1A1A2E),
              const Color(0xFF0A0A14),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  /// 古典边框装饰
  Widget _buildOrnateBorder() {
    return Positioned.fill(
      child: CustomPaint(
        painter: OrnateBorderPainter(color: widget.color),
      ),
    );
  }

  /// 顶部头部
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 类型图标
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.3),
            border: Border.all(color: widget.color.withOpacity(0.5), width: 2),
          ),
          child: Icon(
            widget._getTypeIcon(),
            color: widget.color,
            size: 28,
          ),
        ),
        // 类型名称和等级
        Column(
          children: [
            Text(
              widget.cardTypeName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.energyLevelName,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ),
        // 等级数字
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.8),
                widget.color.withOpacity(0.3),
              ],
            ),
          ),
          child: Center(
            child: Text(
              '${widget.energyLevel}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 咒语展示区
  Widget _buildMantraSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          widget.mantra,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.9),
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  /// 底部能量和操作
  Widget _buildFooter() {
    return Column(
      children: [
        // 能量条
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: widget.color, size: 20),
            const SizedBox(width: 8),
            Text(
              '能量: ${widget.remainingEnergy}/${widget.energyValue}',
              style: TextStyle(
                fontSize: 16,
                color: widget.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 操作按钮
        if (widget.remainingEnergy > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.canCharge)
                ElevatedButton.icon(
                  onPressed: widget.onCharge,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('充值'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: widget.onGift,
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('赠送'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 古典边框绘制器
class OrnateBorderPainter extends CustomPainter {
  final Color color;

  OrnateBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cornerSize = 20.0;

    // 四角装饰
    _drawCornerDecoration(canvas, size, paint, cornerSize, isTopLeft: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isTopRight: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isBottomLeft: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isBottomRight: true);

    // 中间分隔线
    final midY = size.height * 0.35;
    canvas.drawLine(
      Offset(size.width * 0.1, midY),
      Offset(size.width * 0.9, midY),
      paint,
    );
  }

  void _drawCornerDecoration(Canvas canvas, Size size, Paint paint, double cornerSize, {
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    double x = 0;
    double y = 0;

    if (isTopRight) x = size.width - cornerSize;
    if (isBottomLeft) y = size.height - cornerSize;
    if (isBottomRight) {
      x = size.width - cornerSize;
      y = size.height - cornerSize;
    }

    final path = Path();
    path.moveTo(x, y + cornerSize / 2);
    path.lineTo(x + cornerSize / 2, y + cornerSize / 2);
    path.lineTo(x + cornerSize / 2, y);
    path.lineTo(x + cornerSize, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant OrnateBorderPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}