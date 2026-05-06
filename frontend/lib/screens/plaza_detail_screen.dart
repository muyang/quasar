import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class PlazaDetailScreen extends StatefulWidget {
  final PlazaPost post;
  final int userId;
  final VoidCallback? onChanged;

  const PlazaDetailScreen({super.key, required this.post, required this.userId, this.onChanged});

  @override
  State<PlazaDetailScreen> createState() => _PlazaDetailScreenState();
}

class _PlazaDetailScreenState extends State<PlazaDetailScreen> {
  final ApiService _api = ApiService();
  List<PlazaGifter> _gifters = [];
  bool _isLoading = true;
  late PlazaPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadGifters();
  }

  Future<void> _loadGifters() async {
    setState(() => _isLoading = true);
    try {
      _gifters = await _api.getPostGifters(_post.id);
    } catch (e) {
      print('[Detail] 加载赠送者失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _giftEnergy() async {
    try {
      final result = await _api.giftEnergyToPost(_post.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '赠送成功'), backgroundColor: const Color(0xFF4CAF50)),
        );
        _loadGifters();
        widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Color _postTypeColor(String type) {
    switch (type) {
      case 'BLESSING': return const Color(0xFFE91E63);
      case 'WISH': return const Color(0xFFFFD700);
      case 'ANNOUNCEMENT': return const Color(0xFFFF9800);
      case 'ACTIVITY': return const Color(0xFF6B4EFF);
      default: return Colors.grey;
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _post.userId == widget.userId;
    final canGift = !isSelf && !_post.hasPrayed;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('帖子详情'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post content
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _postTypeColor(_post.postType).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _post.postTypeLabel,
                          style: TextStyle(color: _postTypeColor(_post.postType), fontSize: 13),
                        ),
                      ),
                      if (_post.tag != null && _post.tag!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _post.tagColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_post.tagLabel, style: TextStyle(color: _post.tagColor, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_post.content, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(_post.userNickname ?? '平台', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      const Spacer(),
                      Text(_formatTime(_post.createdAt), style: const TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // Gift stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(Icons.people_outline, '${_post.prayCount}', '赠送人次'),
                  _buildStatItem(Icons.bolt, '${_post.totalEnergyReceived}', '累计能量'),
                ],
              ),
            ),

            // Gift button
            if (canGift) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _giftEnergy,
                  icon: const Icon(Icons.bolt, color: Colors.white),
                  label: const Text('赠送 ⚡1 能量', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            // Gifter list
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('赠送记录', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
              ))
            else if (_gifters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无赠送记录', style: TextStyle(color: Colors.white24))),
              )
            else
              ..._gifters.map((g) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6B4EFF).withOpacity(0.3),
                      ),
                      child: const Center(child: Icon(Icons.person, color: Color(0xFF6B4EFF), size: 20)),
                    ),
                    const SizedBox(width: 12),
                    Text(g.userNickname ?? '匿名', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 14, color: Color(0xFFFFD700)),
                        const SizedBox(width: 2),
                        Text('+${g.energyValue}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Text(_formatTime(g.createdAt), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6B4EFF), size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
