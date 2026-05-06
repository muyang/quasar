import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class MessageScreen extends StatefulWidget {
  final int userId;
  const MessageScreen({super.key, required this.userId});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final ApiService _api = ApiService();

  List<AppMessage> _userMessages = [];
  bool _isLoading = true;

  int get _giftCardCount => _userMessages.where((m) => m.msgSubtype == 'GIFT_CARD' && m.cardInfo != null).length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allMsgs = await _api.getMessages(widget.userId);
      _userMessages = allMsgs.messages.where((m) => m.msgType == 'USER_MSG').toList();
    } catch (e) {
      print('[Messages] 加载失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _acceptGiftCard(AppMessage msg) async {
    final card = msg.cardInfo;
    if (card == null) return;
    try {
      await _api.acceptCard(card.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('卡牌已接收'), backgroundColor: Color(0xFF6B4EFF)),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接收失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('私信'),
            if (_giftCardCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$_giftCardCount', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _buildMessageList(_userMessages, isAnnouncement: false),
    );
  }

  Widget _buildMessageList(List<AppMessage> messages, {required bool isAnnouncement}) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isAnnouncement ? Icons.campaign : Icons.chat, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(isAnnouncement ? '暂无公告' : '暂无私信', style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (ctx, i) {
          final m = messages[i];
          return _buildMessageItem(m);
        },
      ),
    );
  }

  Widget _buildMessageItem(AppMessage msg) {
    if (msg.msgSubtype == 'GIFT_CARD' && msg.cardInfo != null) {
      return _buildGiftCardMessage(msg);
    }
    final isUnread = !msg.isRead && msg.msgType != 'ANNOUNCEMENT';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isUnread ? const Color(0xFF6B4EFF) : const Color(0xFF2A2A4A),
        child: Icon(
          msg.msgType == 'ANNOUNCEMENT' ? Icons.campaign : Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              msg.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isUnread)
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6B4EFF), shape: BoxShape.circle)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            '${msg.senderNickname ?? "平台"} · ${_formatTime(msg.createdAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      onTap: () {
        if (isUnread) {
          _api.markMessageRead(msg.id, widget.userId);
          setState(() => msg = AppMessage(
            id: msg.id, msgType: msg.msgType, msgSubtype: msg.msgSubtype,
            title: msg.title, content: msg.content,
            senderId: msg.senderId, senderNickname: msg.senderNickname,
            isRead: true, createdAt: msg.createdAt, cardInfo: msg.cardInfo,
          ));
        }
        _showMessageDetail(msg);
      },
    );
  }

  Widget _buildGiftCardMessage(AppMessage msg) {
    final card = msg.cardInfo!;
    final color = Color(int.parse('FF${card.colorCode.replaceAll('#', '')}', radix: 16));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.3), const Color(0xFF2A2A4A)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.6)),
            child: Center(
              child: Text('Lv${card.energyLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${card.cardTypeName} · ${card.energyLevelName}级卡牌',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(card.mantra, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 2),
                Text('${msg.senderNickname ?? "用户"} · ${_formatTime(msg.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _acceptGiftCard(msg),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('接收'),
          ),
        ],
      ),
    );
  }

  void _showMessageDetail(AppMessage msg) {
    final isGift = msg.msgSubtype == 'GIFT_CARD' && msg.cardInfo != null;
    final card = msg.cardInfo;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: Text(msg.title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.content, style: const TextStyle(color: Colors.white70)),
            if (isGift && card != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Color(int.parse('FF${card.colorCode.replaceAll('#', '')}', radix: 16)).withOpacity(0.3),
                      const Color(0xFF1A1A2E),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(int.parse('FF${card.colorCode.replaceAll('#', '')}', radix: 16)).withOpacity(0.6),
                      ),
                      child: Center(child: Text('Lv${card.energyLevel}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${card.cardTypeName} · ${card.energyLevelName}级',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isGift)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _acceptGiftCard(msg);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
              ),
              child: const Text('接收卡牌'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

}
