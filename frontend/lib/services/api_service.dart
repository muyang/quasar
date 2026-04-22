import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stone.dart';

class ApiService {
  // 根据环境切换地址
  // 真机测试使用实际 IP
  // 模拟器使用 10.0.2.2
  static String baseUrl = 'http://192.168.43.6:8000/api';

  void setBaseUrl(String url) {
    baseUrl = url;
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
}