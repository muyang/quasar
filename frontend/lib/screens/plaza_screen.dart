import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/stone.dart';
import 'plaza_detail_screen.dart';

class PlazaScreen extends StatefulWidget {
  final int userId;
  const PlazaScreen({super.key, required this.userId});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  final ApiService _api = ApiService();
  List<PlazaPost> _posts = [];
  bool _isLoading = true;
  String _filterType = ''; // '' = all, BLESSING, WISH, ACTIVITY

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      _posts = await _api.getPlazaPosts(
        postType: _filterType.isEmpty ? null : _filterType,
        userId: widget.userId,
      );
    } catch (e) {
      print('[Plaza] 加载失败: $e');
    }
    setState(() => _isLoading = false);
  }

  void _showCreateDialog() {
    String postType = 'BLESSING';
    String? tag = null;
    final contentCtrl = TextEditingController();
    const tagOptions = [
      {'key': null, 'label': '无'},
      {'key': 'HEALTH', 'label': '健康'},
      {'key': 'LOVE', 'label': '爱情'},
      {'key': 'WEALTH', 'label': '财富'},
      {'key': 'CAREER', 'label': '事业'},
      {'key': 'FAMILY', 'label': '家庭'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A4A),
          title: const Text('发布帖子', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'BLESSING', label: Text('祈福'), icon: Icon(Icons.favorite)),
                  ButtonSegment(value: 'WISH', label: Text('许愿'), icon: Icon(Icons.star)),
                ],
                selected: {postType},
                onSelectionChanged: (s) => setDialogState(() => postType = s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return const Color(0xFF6B4EFF);
                    return null;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              const Text('能量标签（他人赠送的能量将充入此类型能量石）', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: tagOptions.map((t) => ChoiceChip(
                  label: Text(t['label'] as String, style: const TextStyle(fontSize: 12)),
                  selected: tag == t['key'],
                  selectedColor: _tagDisplayColor(t['key']).withOpacity(0.4),
                  backgroundColor: const Color(0xFF3A3A5A),
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: tag == t['key'] ? _tagDisplayColor(t['key']) : Colors.white12),
                  onSelected: (_) => setDialogState(() => tag = t['key'] as String?),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '写下你想说的话...',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B4EFF))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                if (contentCtrl.text.isEmpty) return;
                try {
                  await _api.createPlazaPost(widget.userId, postType, contentCtrl.text, tag: tag);
                  Navigator.pop(ctx);
                  _loadPosts();
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('广场'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF121212)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _buildFilterChip('全部', ''),
                  const SizedBox(width: 8),
                  _buildFilterChip('祈福', 'BLESSING'),
                  const SizedBox(width: 8),
                  _buildFilterChip('许愿', 'WISH'),
                  const SizedBox(width: 8),
                  _buildFilterChip('公告', 'ANNOUNCEMENT'),
                  const SizedBox(width: 8),
                  _buildFilterChip('活动', 'ACTIVITY'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
                  : _posts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.public, size: 48, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text('广场暂无帖子', style: TextStyle(color: Colors.white38)),
                              const SizedBox(height: 4),
                              const Text('成为第一个发帖的人吧', style: TextStyle(color: Colors.white24, fontSize: 12)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPosts,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _posts.length,
                            itemBuilder: (ctx, i) => _buildPostCard(_posts[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF6B4EFF),
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = type);
        _loadPosts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B4EFF) : const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 13)),
      ),
    );
  }

  Widget _buildPostCard(PlazaPost post) {
    final isActivity = post.postType == 'ACTIVITY';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlazaDetailScreen(
              post: post,
              userId: widget.userId,
              onChanged: _loadPosts,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActivity ? const Color(0xFF1A1A3A) : const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(16),
          border: isActivity ? Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.3)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _postTypeColor(post.postType).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.postTypeLabel,
                    style: TextStyle(color: _postTypeColor(post.postType), fontSize: 12),
                  ),
                ),
                if (post.tag != null && post.tag!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: post.tagColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(post.tagLabel, style: TextStyle(color: post.tagColor, fontSize: 11)),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  post.userNickname ?? '平台',
                  style: TextStyle(
                    color: isActivity ? const Color(0xFFB794FF) : Colors.white54,
                    fontSize: 13,
                    fontWeight: isActivity ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                Text(_formatTime(post.createdAt), style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.content, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: post.hasPrayed ? null : () => _giftEnergy(post),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        size: 18,
                        color: post.hasPrayed ? const Color(0xFFFFD700) : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.hasPrayed ? '已赠送' : '赠送能量',
                        style: TextStyle(
                          color: post.hasPrayed ? const Color(0xFFFFD700) : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.bolt, size: 14, color: const Color(0xFFFFD700).withOpacity(0.6)),
                const SizedBox(width: 2),
                Text('${post.totalEnergyReceived}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _giftEnergy(PlazaPost post) async {
    try {
      final result = await _api.giftEnergyToPost(post.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '赠送成功'), backgroundColor: const Color(0xFF4CAF50)),
        );
      }
      _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Color _tagDisplayColor(String? tag) {
    switch (tag) {
      case 'HEALTH': return const Color(0xFF4CAF50);
      case 'LOVE': return const Color(0xFFE91E63);
      case 'WEALTH': return const Color(0xFFFFD700);
      case 'CAREER': return const Color(0xFFF44336);
      case 'FAMILY': return const Color(0xFF2196F3);
      default: return const Color(0xFF888888);
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
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
