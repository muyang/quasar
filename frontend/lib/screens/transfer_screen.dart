import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../models/stone.dart';

class TransferScreen extends StatefulWidget {
  final int userId;
  final List<StoneDetail> stones;
  final VoidCallback? onTransferComplete;

  const TransferScreen({
    super.key,
    required this.userId,
    required this.stones,
    this.onTransferComplete,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  StoneDetail? _fromStone;
  bool _isLoading = false;
  bool _isTransferring = false;
  bool _isCheckingReceiver = false;
  StoneDetail? _receiverStone;
  User? _receiverUser;
  String? _receiverError;
  double _pressProgress = 0.0;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _fromStone = widget.stones.where((s) => s.canTransfer).firstOrNull;
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _checkReceiver() async {
    final input = _receiverController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _receiverStone = null;
        _receiverUser = null;
        _receiverError = null;
      });
      return;
    }

    setState(() {
      _isCheckingReceiver = true;
      _receiverError = null;
      _receiverStone = null;
      _receiverUser = null;
    });

    try {
      // 判断输入是否为纯数字（用户ID）
      final isUserId = RegExp(r'^\d+$').hasMatch(input);

      if (!isUserId) {
        // 作为水晶编号查询
        final stone = await _apiService.getStoneByCode(input.toUpperCase());
        // 检查类型匹配
        if (_fromStone != null && stone.stoneType != _fromStone!.stoneType) {
          setState(() {
            _isCheckingReceiver = false;
            _receiverError = '类型不匹配：你的水晶是【${_fromStone!.stoneTypeName}】，接收方水晶是【${stone.stoneTypeName}】';
          });
          return;
        }
        setState(() {
          _isCheckingReceiver = false;
          _receiverStone = stone;
        });
      } else {
        // 作为用户ID，获取用户信息
        final userId = int.parse(input);
        final user = await _apiService.getUser(userId);
        // 查找该用户同类型的水晶
        final userStones = await _apiService.getUserStones(userId);
        final matchingStone = userStones.where((s) =>
          s.stoneType == _fromStone?.stoneType && s.status == 'ALIVE'
        ).firstOrNull;

        if (matchingStone == null && _fromStone != null) {
          setState(() {
            _isCheckingReceiver = false;
            _receiverUser = user;
            _receiverError = '该用户没有【${_fromStone!.stoneTypeName}】类型的可用水晶';
          });
          return;
        }

        setState(() {
          _isCheckingReceiver = false;
          _receiverUser = user;
          _receiverStone = matchingStone;
        });
      }
    } catch (e) {
      setState(() {
        _isCheckingReceiver = false;
        _receiverError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onReceiverChanged(Timer? timer) {
    _checkReceiver();
  }

  Future<void> _playChant() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/chant.mp3'));
    } catch (e) {
      print('[Audio] 播放音频失败: $e');
    }
  }

  Future<void> _stopChant() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('[Audio] 停止音频失败: $e');
    }
  }

  void _startTransfer() {
    if (_fromStone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要转赠的水晶'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_receiverError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_receiverError!), backgroundColor: Colors.red),
      );
      return;
    }

    if (_receiverStone == null && _receiverController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入接收者'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的能量值（最小1）'), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > 81) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('单次转赠最大值为81'), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > _fromStone!.currentEnergy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('能量不足，当前能量: ${_fromStone!.currentEnergy}'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isPressed = true;
      _pressProgress = 0.0;
    });
    _playChant();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (_isPressed) {
        _executeTransfer(amount);
      }
    });

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPressed) {
        timer.cancel();
        return;
      }
      setState(() {
        _pressProgress += 0.05 / 3.0;
      });
      if (_pressProgress >= 1.0) {
        timer.cancel();
      }
    });
  }

  void _cancelTransfer() {
    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });
    _stopChant();
  }

  Future<void> _executeTransfer(int amount) async {
    setState(() {
      _isTransferring = true;
    });
    _stopChant();
    HapticFeedback.heavyImpact();

    try {
      final receiver = _receiverController.text.trim();
      final result = await _apiService.transferEnergy(_fromStone!.id, receiver, amount);

      setState(() {
        _isTransferring = false;
        _isPressed = false;
        _pressProgress = 0.0;
        if (_fromStone != null) {
          _fromStone = StoneDetail(
            id: _fromStone!.id,
            uniqueCode: _fromStone!.uniqueCode,
            stoneType: _fromStone!.stoneType,
            stoneTypeName: _fromStone!.stoneTypeName,
            colorCode: _fromStone!.colorCode,
            ownerId: _fromStone!.ownerId,
            ownerNickname: _fromStone!.ownerNickname,
            currentEnergy: result.fromStoneEnergy,
            energyCap: _fromStone!.energyCap,
            deathCount: _fromStone!.deathCount,
            status: _fromStone!.status,
            consecutiveDays: _fromStone!.consecutiveDays,
            nextMultiplier: _fromStone!.nextMultiplier,
            canTransfer: result.fromStoneEnergy > 0,
          );
        }
      });

      if (widget.onTransferComplete != null) {
        widget.onTransferComplete!();
      }

      final receiverName = result.toOwnerNickname ?? _receiverStone?.uniqueCode ?? receiver;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('转赠成功', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Color(0xFFB794FF)),
              const SizedBox(height: 16),
              Text('成功转赠 $amount 点能量', style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Text('接收者: $receiverName', style: const TextStyle(color: Color(0xFFB794FF))),
              const SizedBox(height: 8),
              Text('剩余能量: ${result.fromStoneEnergy}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _receiverController.clear();
                _amountController.clear();
                setState(() {
                  _receiverStone = null;
                  _receiverUser = null;
                  _receiverError = null;
                });
              },
              child: const Text('完成', style: TextStyle(color: Color(0xFFB794FF))),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isTransferring = false;
        _isPressed = false;
        _pressProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转赠失败: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('能量转赠'),
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
        child: widget.stones.isEmpty
            ? _buildNoStonesHint()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 当前能量显示
                    if (_fromStone != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _parseColor(_fromStone!.colorCode).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, color: _parseColor(_fromStone!.colorCode)),
                            const SizedBox(width: 8),
                            Text(
                              '当前能量: ${_fromStone!.currentEnergy}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // 选择发送方石头
                    const Text('选择你的水晶', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 12),
                    _buildStoneSelector(),
                    const SizedBox(height: 24),

                    // 输入接收者
                    const Text('接收者', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('可输入用户ID（如 5）或水晶编号（如 CRY-000005）', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _receiverController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => Future.delayed(const Duration(milliseconds: 500), _checkReceiver),
                      decoration: InputDecoration(
                        hintText: '输入接收者ID或编号',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2A4A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: _isCheckingReceiver
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB794FF)))
                            : _receiverError != null
                                ? const Icon(Icons.error, color: Colors.red)
                                : _receiverStone != null || _receiverUser != null
                                    ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                                    : null,
                      ),
                    ),
                    if (_receiverError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_receiverError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_receiverStone != null)
                      _buildReceiverInfo(),
                    if (_receiverUser != null && _receiverStone == null && _receiverError == null)
                      _buildReceiverUserInfo(),
                    const SizedBox(height: 24),

                    // 输入能量值
                    const Text('转赠能量值', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('最大: 81', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                        const SizedBox(width: 16),
                        Text('当前可用: ${_fromStone?.currentEnergy ?? 0}', style: TextStyle(color: _parseColor(_fromStone?.colorCode ?? '#6B4EFF'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '1-81',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              filled: true,
                              fillColor: const Color(0xFF2A2A4A),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 快捷按钮
                        _buildQuickAmountButton(10),
                        const SizedBox(width: 8),
                        _buildQuickAmountButton(30),
                        const SizedBox(width: 8),
                        _buildQuickAmountButton(50),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 转赠按钮
                    if (_fromStone != null && _fromStone!.canTransfer)
                      _buildTransferButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount) {
    return GestureDetector(
      onTap: () {
        _amountController.text = amount.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$amount', style: const TextStyle(color: Color(0xFFB794FF), fontSize: 14)),
      ),
    );
  }

  Widget _buildReceiverInfo() {
    final stone = _receiverStone!;
    final color = _parseColor(stone.colorCode);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.2), const Color(0xFF2A2A4A)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0.5)]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stone.stoneTypeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(stone.uniqueCode, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stone.currentEnergy}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('能量', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverUserInfo() {
    final user = _receiverUser!;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFFB794FF)),
          const SizedBox(width: 12),
          Text(user.nickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('ID: ${user.id}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNoStonesHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 48, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('还没有绑定水晶', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildStoneSelector() {
    if (widget.stones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF2A2A4A), borderRadius: BorderRadius.circular(12)),
        child: const Text('暂无可用水晶', style: TextStyle(color: Colors.white54)),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.stones.length,
        itemBuilder: (context, index) {
          final stone = widget.stones[index];
          final isSelected = _fromStone?.id == stone.id;
          final color = _parseColor(stone.colorCode);
          final canSelect = stone.canTransfer;

          return GestureDetector(
            onTap: canSelect
                ? () {
                    setState(() {
                      _fromStone = stone;
                      _checkReceiver();
                    });
                  }
                : null,
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(isSelected ? 0.4 : 0.2), const Color(0xFF2A2A4A)]),
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? Border.all(color: color, width: 2) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: canSelect ? color.withOpacity(0.8) : Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text('${stone.currentEnergy}', style: TextStyle(color: canSelect ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                  Text(stone.stoneTypeName, style: TextStyle(color: Colors.white.withOpacity(canSelect ? 0.6 : 0.4), fontSize: 12)),
                  if (!canSelect)
                    Text('不可用', style: TextStyle(color: Colors.red.withOpacity(0.6), fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransferButton() {
    final color = _parseColor(_fromStone!.colorCode);
    return GestureDetector(
      onLongPressStart: (_) => _startTransfer(),
      onLongPressEnd: (_) => _cancelTransfer(),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF6B4EFF).withOpacity(_isPressed ? 0.8 : 0.6), color.withOpacity(_isPressed ? 0.8 : 0.6)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            if (_isPressed)
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                  width: (MediaQuery.of(context).size.width - 48) * _pressProgress,
                ),
              ),
            Center(
              child: _isTransferring
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: 32, color: Colors.white.withOpacity(_isPressed ? 1.0 : 0.8)),
                        const SizedBox(height: 4),
                        Text(
                          _isPressed ? '${(_pressProgress * 3).toStringAsFixed(1)}s' : '长按发送',
                          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(_isPressed ? 1.0 : 0.8)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}