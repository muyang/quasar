import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stone.dart';

class ApiService {
  // 动态baseUrl，启动时从SharedPreferences加载
  static String baseUrl = 'http://192.168.0.109:8002/api';
  static const String _defaultBaseUrl = 'http://192.168.0.109:8002/api';

  /// 初始化baseUrl，从SharedPreferences加载保存的地址
  static Future<void> initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('server_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl;
      print('[API] 加载保存的服务器地址: $baseUrl');
    } else {
      baseUrl = _defaultBaseUrl;
      print('[API] 使用默认服务器地址: $baseUrl');
    }
    setImageBaseUrl(currentServerUrl);
  }

  /// 保存新的baseUrl到SharedPreferences
  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // 确保url格式正确
    if (!url.endsWith('/api')) {
      url = '$url/api';
    }
    await prefs.setString('server_url', url);
    baseUrl = url;
    setImageBaseUrl(currentServerUrl);
    print('[API] 保存服务器地址: $baseUrl');
  }

  /// 获取当前baseUrl（不含/api后缀）
  static String get currentServerUrl {
    return baseUrl.replaceAll('/api', '');
  }

  // ==================== 用户接口 ====================

  Future<User> registerUser(String nickname) async {
    final url = Uri.parse('$baseUrl/user/register');
    print('[API] 注册用户: $url, nickname: $nickname');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nickname': nickname}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 注册成功: ${data}');
        return User.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '注册失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<User> getUser(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId');
    print('[API] 获取用户信息: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 用户信息: ${data}');
        return User.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('用户不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<List<StoneDetail>> getUserStones(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId/stones');
    print('[API] 获取用户石头列表: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stones = data['stones'] as List;
        print('[API] 获取到 ${stones.length} 颗石头');
        return stones.map((s) => StoneDetail.fromJson(s)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('用户不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== 石头接口 ====================

  Future<StoneDetail> createStone(int userId, String stoneType) async {
    final url = Uri.parse('$baseUrl/stone/create');
    print('[API] 创建石头: $url, userId: $userId, type: $stoneType');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'stone_type': stoneType}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 创建成功: ${data}');
        return StoneDetail.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '创建失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<StoneDetail> bindStone(int userId, String uniqueCode) async {
    final url = Uri.parse('$baseUrl/stone/bind');
    print('[API] 绑定石头: $url, userId: $userId, code: $uniqueCode');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'unique_code': uniqueCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 绑定成功: ${data}');
        return StoneDetail.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '绑定失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<StoneDetail> getStoneDetail(int stoneId) async {
    final url = Uri.parse('$baseUrl/stone/$stoneId');
    print('[API] 获取石头详情: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 石头详情: ${data}');
        return StoneDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('石头不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<StoneDetail> getStoneByCode(String uniqueCode) async {
    final url = Uri.parse('$baseUrl/stone/code/${uniqueCode.toUpperCase()}');
    print('[API] 通过编号获取石头: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 石头详情: ${data}');
        return StoneDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('水晶不存在');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '查询失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<ChargeResponse> chargeStone(int stoneId) async {
    final url = Uri.parse('$baseUrl/stone/$stoneId/charge');
    print('[API] 调用充能接口: $url');

    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 充能成功: ${data}');
        return ChargeResponse.fromJson(data);
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '充能失败');
      } else if (response.statusCode == 404) {
        throw Exception('石头不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<CheckInStatus> getCheckInStatus(int stoneId) async {
    final url = Uri.parse('$baseUrl/stone/$stoneId/check-in-status');
    print('[API] 获取打卡状态: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 打卡状态: ${data}');
        return CheckInStatus.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('石头不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<List<CheckInRecord>> getCheckInRecords(int stoneId) async {
    final url = Uri.parse('$baseUrl/stone/$stoneId/records');
    print('[API] 获取打卡记录: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final records = data['records'] as List;
        print('[API] 获取到 ${records.length} 条打卡记录');
        return records.map((r) => CheckInRecord.fromJson(r)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('石头不存在');
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== 转赠接口 ====================

  Future<TransferResponse> transferEnergy(int fromStoneId, String toReceiver, int amount) async {
    final url = Uri.parse('$baseUrl/stone/transfer');
    print('[API] 转赠能量: $url, from: $fromStoneId, to: $toReceiver, amount: $amount');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_stone_id': fromStoneId,
          'to_receiver': toReceiver,
          'energy_amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 转赠成功: ${data}');
        return TransferResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '转赠失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== 登录接口 ====================

  /// 检查石头编号是否存在及绑定状态
  Future<StoneDetail> checkStoneStatus(String uniqueCode) async {
    final url = Uri.parse('$baseUrl/stone/code/${uniqueCode.toUpperCase()}');
    print('[API] 检查石头状态: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 石头信息: ${data}');
        return StoneDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('石头不存在');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '查询失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  /// 为未绑定的石头创建新用户并绑定
  Future<User> bindStoneToNewUser(String uniqueCode, String nickname) async {
    final url = Uri.parse('$baseUrl/stone/code/${uniqueCode.toUpperCase()}/bind-new-user');
    print('[API] 绑定石头到新用户: $url, code: $uniqueCode, nickname: $nickname');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nickname': nickname}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 绑定成功: ${data}');
        return User.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '绑定失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<User> loginByStoneCode(String uniqueCode) async {
    final url = Uri.parse('$baseUrl/user/login-by-stone');
    print('[API] 通过石头编号登录: $url, code: $uniqueCode');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'unique_code': uniqueCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 登录成功: ${data}');
        return User.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '登录失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== 卡牌接口 ====================

  Future<DrawStatus> getDrawStatus(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId/draw-status');
    print('[API] 获取抽卡状态: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 抽卡状态: ${data}');
        return DrawStatus.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<DrawCardResponse> drawCard(int userId, String drawType) async {
    final url = Uri.parse('$baseUrl/card/draw');
    print('[API] 抽卡: $url, userId: $userId, type: $drawType');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'draw_type': drawType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 抽卡成功: ${data}');
        return DrawCardResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '抽卡失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<List<Card>> getUserCards(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId/cards');
    print('[API] 获取用户卡牌: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cards = data['cards'] as List;
        print('[API] 获取到 ${cards.length} 张卡牌');
        return cards.map((c) => Card.fromJson(c)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<ChargeCardResponse> chargeCardToStone(int cardId, int stoneId) async {
    final url = Uri.parse('$baseUrl/card/$cardId/charge');
    print('[API] 卡牌充值: $url, cardId: $cardId, stoneId: $stoneId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'stone_id': stoneId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 充值成功: ${data}');
        return ChargeCardResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '充值失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<bool> giftCard(int cardId, int toUserId) async {
    final url = Uri.parse('$baseUrl/card/$cardId/gift');
    print('[API] 赠送卡牌: $url, cardId: $cardId, toUserId: $toUserId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to_user_id': toUserId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 赠送成功: ${data}');
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '赠送失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== 待接收卡牌接口 ====================

  Future<List<PendingCard>> getPendingCards(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId/pending-cards');
    print('[API] 获取待接收卡牌: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cards = data['cards'] as List;
        print('[API] 获取到 ${cards.length} 张待接收卡牌');
        return cards.map((c) => PendingCard.fromJson(c)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<bool> acceptCard(int cardId, int userId) async {
    final url = Uri.parse('$baseUrl/card/$cardId/accept?user_id=$userId');
    print('[API] 确认接收卡牌: $url, cardId: $cardId, userId: $userId');

    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 接收成功: ${data}');
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '接收失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 合成接口 ====================

  Future<SynthesizeResponse> synthesizeCards(int userId, List<int> cardIds) async {
    final url = Uri.parse('$baseUrl/card/synthesize');
    print('[API] 合成卡牌: $url, userId: $userId, cardIds: $cardIds');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'card_ids': cardIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 合成成功: ${data}');
        return SynthesizeResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '合成失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 收藏接口 ====================

  Future<List<CollectionProgress>> getCollection(int userId) async {
    final url = Uri.parse('$baseUrl/user/$userId/collection');
    print('[API] 获取收藏进度: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['collections'] as List;
        return list.map((c) => CollectionProgress.fromJson(c)).toList();
      } else {
        throw Exception('获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 商店接口 ====================

  Future<List<StoreItem>> getStoreItems() async {
    final url = Uri.parse('$baseUrl/store/items');
    print('[API] 获取商店物品: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['items'] as List;
        return list.map((i) => StoreItem.fromJson(i)).toList();
      } else {
        throw Exception('获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<PurchaseResponse> purchaseItem(int userId, int itemId) async {
    final url = Uri.parse('$baseUrl/store/purchase');
    print('[API] 购买物品: $url, userId: $userId, itemId: $itemId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'item_id': itemId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] 购买成功: ${data}');
        return PurchaseResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '购买失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 消息接口 ====================

  Future<MessageListResponse> getMessages(int userId, {String? msgType}) async {
    var url = '$baseUrl/user/$userId/messages';
    if (msgType != null) url += '?msg_type=$msgType';
    print('[API] 获取消息: $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessageListResponse.fromJson(data);
      } else {
        throw Exception('获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<AppMessage> sendMessage(int senderId, int receiverId, String title, String content) async {
    final url = Uri.parse('$baseUrl/message/send');
    print('[API] 发送消息: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': senderId, 'receiver_id': receiverId,
          'title': title, 'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppMessage.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '发送失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<void> markMessageRead(int messageId, int userId) async {
    final url = Uri.parse('$baseUrl/message/$messageId/read?user_id=$userId');
    print('[API] 标记已读: $url');
    await http.post(url);
  }

  Future<MessageListResponse> getAnnouncements() async {
    final url = Uri.parse('$baseUrl/announcements');
    print('[API] 获取公告: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessageListResponse.fromJson(data);
      } else {
        throw Exception('获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 广场接口 ====================

  Future<List<PlazaPost>> getPlazaPosts({String? postType, int? userId, int skip = 0}) async {
    var url = '$baseUrl/plaza/posts?skip=$skip&limit=50';
    if (postType != null) url += '&post_type=$postType';
    if (userId != null) url += '&user_id=$userId';
    print('[API] 获取广场帖子: $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['posts'] as List;
        return list.map((p) => PlazaPost.fromJson(p)).toList();
      } else {
        throw Exception('获取失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<PlazaPost> createPlazaPost(int userId, String postType, String content) async {
    final url = Uri.parse('$baseUrl/plaza/post');
    print('[API] 创建广场帖子: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'post_type': postType, 'content': content}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PlazaPost.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '发布失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  Future<Map<String, dynamic>> prayPost(int postId, int userId) async {
    final url = Uri.parse('$baseUrl/plaza/post/$postId/pray?user_id=$userId');
    print('[API] 祈福: $url');

    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '祈福失败');
      }
    } catch (e) {
      print('[API] 请求异常: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // ==================== v0.5.0 管理员接口 ====================

  static const String _adminToken = 'quasar-admin-2024';

  Future<bool> adminLogin(String token) async {
    final url = Uri.parse('$baseUrl/admin/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_token': token}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<PresetCardManage>> adminGetPresetCards({String? cardType}) async {
    var urlStr = '$baseUrl/admin/preset-cards';
    if (cardType != null) urlStr += '?card_type=$cardType';
    try {
      final response = await http.get(Uri.parse(urlStr), headers: {'X-Admin-Token': _adminToken});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['cards'] as List;
        return list.map((c) => PresetCardManage.fromJson(c)).toList();
      }
      throw Exception('获取失败');
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<PresetCardManage> adminCreatePresetCard(String cardType, String mantra, int energyLevel) async {
    final url = Uri.parse('$baseUrl/admin/preset-cards');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Admin-Token': _adminToken},
        body: jsonEncode({'card_type': cardType, 'mantra': mantra, 'energy_level': energyLevel}),
      );
      if (response.statusCode == 200) {
        return PresetCardManage.fromJson(jsonDecode(response.body));
      }
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '创建失败');
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<void> adminDeletePresetCard(int cardId) async {
    final url = Uri.parse('$baseUrl/admin/preset-cards/$cardId');
    try {
      await http.delete(url, headers: {'X-Admin-Token': _adminToken});
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<List<StoreItem>> adminGetStoreItems() async {
    final url = Uri.parse('$baseUrl/admin/store-items');
    try {
      final response = await http.get(url, headers: {'X-Admin-Token': _adminToken});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['items'] as List;
        return list.map((i) => StoreItem.fromJson(i)).toList();
      }
      throw Exception('获取失败');
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<StoreItem> adminCreateStoreItem(String itemType, String name, {String? stoneType, int energyAmount = 0, int price = 0}) async {
    final url = Uri.parse('$baseUrl/admin/store-items');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Admin-Token': _adminToken},
        body: jsonEncode({
          'item_type': itemType, 'name': name,
          'stone_type': stoneType, 'energy_amount': energyAmount, 'price': price,
        }),
      );
      if (response.statusCode == 200) {
        return StoreItem.fromJson(jsonDecode(response.body));
      }
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '创建失败');
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<void> adminDeleteStoreItem(int itemId) async {
    final url = Uri.parse('$baseUrl/admin/store-items/$itemId');
    try {
      await http.delete(url, headers: {'X-Admin-Token': _adminToken});
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<void> adminSendAnnouncement(String title, String content) async {
    final url = Uri.parse('$baseUrl/admin/announcements');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Admin-Token': _adminToken},
        body: jsonEncode({'title': title, 'content': content}),
      );
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  Future<void> adminCreateActivity(String content) async {
    final url = Uri.parse('$baseUrl/admin/activities');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-Admin-Token': _adminToken},
        body: jsonEncode({'content': content}),
      );
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }
}