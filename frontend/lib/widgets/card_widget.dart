import 'package:flutter/material.dart';
import '../models/stone.dart';

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
  final String? imageUrl;
  final String? rarity;
  final String? rarityName;
  final String? cardTypeSubName;
  final int? cost;
  final int? attack;
  final int? health;
  final List<String>? tags;
  final String? name;
  final int? cardWidth;
  final int? cardHeight;
  final String? imageFit;
  final int marginTop;
  final int marginLeft;
  final int marginBottom;
  final int marginRight;

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
    this.imageUrl,
    this.rarity,
    this.rarityName,
    this.cardTypeSubName,
    this.cost,
    this.attack,
    this.health,
    this.tags,
    this.name,
    this.cardWidth,
    this.cardHeight,
    this.imageFit,
    this.marginTop = 0,
    this.marginLeft = 0,
    this.marginBottom = 0,
    this.marginRight = 0,
  });

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

  IconData _getTypeSubIcon() {
    switch (cardTypeSubName) {
      case '单位':
        return Icons.shield_rounded;
      case '法术':
        return Icons.auto_awesome_rounded;
      case '装备':
        return Icons.inventory_2_rounded;
      case '遗物':
        return Icons.diamond_rounded;
      default:
        return Icons.circle_rounded;
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

  BoxFit _parseImageFit() {
    switch (widget.imageFit) {
      case 'CONTAIN':
        return BoxFit.contain;
      case 'FILL':
        return BoxFit.fill;
      case 'FIT_WIDTH':
        return BoxFit.fitWidth;
      case 'FIT_HEIGHT':
        return BoxFit.fitHeight;
      case 'NONE':
        return BoxFit.none;
      case 'COVER':
      default:
        return BoxFit.cover;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: (widget.cardWidth ?? 280).toDouble(),
          height: (widget.cardHeight ?? 400).toDouble(),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                _buildBackground(),
                _buildOrnateBorder(),
                Column(
                  children: [
                    _buildImageZone(),
                    Expanded(child: _buildInfoSection()),
                    if (widget.showActions) _buildFooter(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildOrnateBorder() {
    return Positioned.fill(
      child: CustomPaint(
        painter: OrnateBorderPainter(color: widget.color),
      ),
    );
  }

  /// 图片区 — 占卡片高度 ~38%，图片全宽填充，叠加类型/等级/稀有度/费用
  Widget _buildImageZone() {
    final cardH = (widget.cardHeight ?? 400).toDouble();
    final zoneH = cardH * 0.38;
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    return SizedBox(
      height: zoneH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片或渐变占位
          if (hasImage)
            Image.network(
              widget.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(zoneH),
            )
          else
            _buildImagePlaceholder(zoneH),

          // 顶部渐隐（保证叠加文字可读）
          Positioned(
            top: 0, left: 0, right: 0,
            height: zoneH * 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 底部渐隐
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: zoneH * 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0A0A14).withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // --- 叠加元素 ---

          // 左上：稀有度标签
          if (widget.rarityName != null)
            Positioned(
              top: 10, left: 10,
              child: _buildRarityBadge(),
            ),

          // 右上：等级圆圈
          Positioned(
            top: 10, right: 10,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [widget.color.withOpacity(0.9), widget.color.withOpacity(0.35)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                ],
              ),
              child: Center(
                child: Text(
                  '${widget.energyLevel}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),

          // 左下：类型图标圆圈
          Positioned(
            bottom: 10, left: 10,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.35),
                border: Border.all(color: widget.color.withOpacity(0.6), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3),
                ],
              ),
              child: Icon(widget._getTypeIcon(), color: widget.color, size: 18),
            ),
          ),

          // 右下：费用指示器
          if (widget.cost != null)
            Positioned(
              bottom: 10, right: 10,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6B4EFF),
                  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 3)],
                ),
                child: Center(
                  child: Text(
                    '${widget.cost}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.color.withOpacity(0.25),
            widget.color.withOpacity(0.05),
            const Color(0xFF1A1A2E),
          ],
        ),
      ),
    );
  }

  Widget _buildRarityBadge() {
    final rarityColor = widget.rarity != null
        ? Color(RARITY_COLORS[widget.rarity] ?? 0xFF888888)
        : const Color(0xFF888888);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: rarityColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rarityColor.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3)],
      ),
      child: Text(
        widget.rarityName!,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  /// 信息区 — 名称/子类型/属性/标签/咒语
  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 卡片名称
          Text(
            widget.name ?? widget.cardTypeName,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 子类型行
          if (widget.cardTypeSubName != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget._getTypeSubIcon(), size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Text(widget.cardTypeSubName!, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // 属性行
          if (widget.attack != null && widget.health != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(children: [
                      const Icon(Icons.swipe_rounded, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text('${widget.attack}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(children: [
                      const Icon(Icons.favorite_border_rounded, size: 13, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Text('${widget.health}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),

          // 标签行
          if (widget.tags != null && widget.tags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.tags!.take(3).map((t) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: widget.color.withValues(alpha: 0.35)),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 10, color: widget.color)),
                )).toList(),
              ),
            ),

          // 分隔线
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: widget.color.withOpacity(0.15),
          ),

          // 咒语
          Expanded(
            child: Center(
              child: Text(
                widget.mantra,
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.88),
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部能量 + 操作按钮（始终可见）
  Widget _buildFooter() {
    final depleted = widget.remainingEnergy <= 0;
    final progress = widget.energyValue > 0
        ? widget.remainingEnergy / widget.energyValue
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 能量进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                depleted ? Colors.white24 : widget.color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, color: depleted ? Colors.white30 : widget.color, size: 16),
              const SizedBox(width: 4),
              Text(
                '能量: ${widget.remainingEnergy}/${widget.energyValue}',
                style: TextStyle(
                  fontSize: 13,
                  color: depleted ? Colors.white38 : widget.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!depleted)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.canCharge)
                  _actionBtn('充值', Icons.bolt, widget.color, widget.onCharge),
                _actionBtn('赠送', Icons.card_giftcard, const Color(0xFF6B4EFF), widget.onGift),
              ],
            )
          else
            Text('能量耗尽', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color bgColor, VoidCallback? onPressed) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
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

    _drawCornerDecoration(canvas, size, paint, cornerSize, isTopLeft: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isTopRight: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isBottomLeft: true);
    _drawCornerDecoration(canvas, size, paint, cornerSize, isBottomRight: true);

    // 分隔线对齐图片区下沿 (~38%)
    final midY = size.height * 0.38;
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
