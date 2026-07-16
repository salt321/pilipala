import '../models/fans/result.dart';
import 'index.dart';

class FanHttp {
  static Future fans({int? vmid, int? pn, int? ps, String? orderType}) async {
    try {
      final dynamic res = await Request().get(Api.fans, data: {
        'vmid': vmid,
        'pn': pn,
        'ps': ps,
        'order': 'desc',
        'order_type': orderType,
      });
      final dynamic body = res.data;
      if (body is Map && body['code'] == 0 && body['data'] is Map) {
        return {
          'status': true,
          'data': FansDataModel.fromJson(
              Map<String, dynamic>.from(body['data'] as Map))
        };
      }
      return {
        'status': false,
        'data': [],
        'msg': '粉丝列表请求失败\n'
            'API code: ${body is Map ? body['code'] : '未知'}\n'
            '信息: ${body is Map ? body['message'] : body}',
      };
    } catch (error) {
      return {
        'status': false,
        'data': [],
        'msg': '粉丝列表处理异常\n${error.runtimeType}: $error',
      };
    }
  }
}
