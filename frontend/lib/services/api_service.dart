import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stone.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.113:8000/api/stone';

  Future<ChargeResponse> chargeStone(int stoneId) async {
    final url = Uri.parse('$baseUrl/$stoneId/charge');
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
    final url = Uri.parse('$baseUrl/$stoneId/check-in-status');
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
    final url = Uri.parse('$baseUrl/$stoneId/records');
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
}