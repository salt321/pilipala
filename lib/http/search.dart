import 'dart:convert';
import 'dart:developer' as developer;

import 'package:hive/hive.dart';
import 'package:pilipala/models/search/all.dart';
import 'package:pilipala/utils/wbi_sign.dart';
import '../models/bangumi/info.dart';
import '../models/common/search_type.dart';
import '../models/search/hot.dart';
import '../models/search/result.dart';
import '../models/search/suggest.dart';
import '../utils/storage.dart';
import 'index.dart';

class SearchHttp {
  static Box setting = GStrorage.setting;

  static String _responseShape(dynamic data) {
    if (data is Map) {
      return 'Map(keys: ${data.keys.take(12).join(', ')})';
    }
    if (data is List) {
      return 'List(length: ${data.length})';
    }
    if (data is String) {
      return 'String(length: ${data.length})';
    }
    return data.runtimeType.toString();
  }

  static String _responsePreview(dynamic data) {
    final String value = data?.toString() ?? 'null';
    const int maxLength = 800;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}…';
  }

  static Map<String, dynamic> _searchFailure({
    required String stage,
    required SearchType searchType,
    required int page,
    dynamic response,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final dynamic body = response?.data;
    final int? httpStatus = response?.statusCode;
    final dynamic apiCode = body is Map ? body['code'] : null;
    final dynamic apiMessage = body is Map ? body['message'] : null;
    final dynamic requestUri = response?.requestOptions?.uri;
    final String detail = <String>[
      '搜索请求失败（$stage）',
      '接口: ${Api.searchByType}',
      '类型: ${searchType.type}，页码: $page',
      if (requestUri != null && requestUri.toString().isNotEmpty)
        '请求地址: $requestUri',
      if (httpStatus != null) 'HTTP 状态: $httpStatus',
      if (apiCode != null) 'Bilibili API code: $apiCode',
      if (apiMessage != null && apiMessage.toString().trim().isNotEmpty)
        'API 信息: $apiMessage',
      '响应结构: ${_responseShape(body)}',
      '响应内容: ${_responsePreview(body)}',
      if (error != null) '异常: ${error.runtimeType}: $error',
    ].join('\n');

    developer.log(
      detail,
      name: 'SearchHttp.searchByType',
      error: error,
      stackTrace: stackTrace,
    );
    return {'status': false, 'data': [], 'msg': detail};
  }

  static Future hotSearchList() async {
    var res = await Request().get(Api.hotSearchList);
    if (res.data is String) {
      Map<String, dynamic> resultMap = json.decode(res.data);
      if (resultMap['code'] == 0) {
        return {
          'status': true,
          'data': HotSearchModel.fromJson(resultMap),
        };
      }
    } else if (res.data is Map<String, dynamic> && res.data['code'] == 0) {
      return {
        'status': true,
        'data': HotSearchModel.fromJson(res.data),
      };
    }

    return {
      'status': false,
      'data': [],
      'msg': '请求错误 🙅',
    };
  }

  // 获取搜索建议
  static Future searchSuggest({required term}) async {
    var res = await Request().get(Api.searchSuggest,
        data: {'term': term, 'main_ver': 'v1', 'highlight': term});
    if (res.data is String) {
      Map<String, dynamic> resultMap = json.decode(res.data);
      if (resultMap['code'] == 0) {
        if (resultMap['result'] is Map) {
          resultMap['result']['term'] = term;
        }
        return {
          'status': true,
          'data': resultMap['result'] is Map
              ? SearchSuggestModel.fromJson(resultMap['result'])
              : [],
        };
      } else {
        return {
          'status': false,
          'data': [],
          'msg': '请求错误 🙅',
        };
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }

  // 分类搜索
  static Future searchByType({
    required SearchType searchType,
    required String keyword,
    required int page,
    String? order,
    int? duration,
    int? tids,
  }) async {
    final Map<String, dynamic> reqData = <String, dynamic>{
      'search_type': searchType.type,
      'keyword': keyword,
      'page': page,
      'web_location': 1430654,
      if (order != null) 'order': order,
      if (duration != null) 'duration': duration,
      if (tids != null && tids != -1) 'tids': tids,
    };
    dynamic res;
    try {
      // search/type 是 WBI 接口。未签名请求目前会被 Bilibili 以风控错误拒绝。
      final Map<String, dynamic> signedParams =
          await WbiSign().makSign(Map<String, dynamic>.from(reqData));
      res = await Request().get(Api.searchByType, data: signedParams);
    } catch (error, stackTrace) {
      return _searchFailure(
        stage: 'WBI 签名或网络请求异常',
        searchType: searchType,
        page: page,
        response: res,
        error: error,
        stackTrace: stackTrace,
      );
    }
    final dynamic body = res.data;
    if (body is! Map) {
      return _searchFailure(
        stage: '响应格式异常',
        searchType: searchType,
        page: page,
        response: res,
      );
    }
    if (body['code'] == 0) {
      if (body['data'] is! Map) {
        return _searchFailure(
          stage: '缺少 data 字段',
          searchType: searchType,
          page: page,
          response: res,
        );
      }
      if (body['data']['numPages'] == 0) {
        // 我想返回数据，使得可以通过data.list 取值，结果为[]
        return {'status': true, 'data': Data()};
      }
      Object data;
      try {
        switch (searchType) {
          case SearchType.video:
            List<int> blackMidsList =
                setting.get(SettingBoxKey.blackMidsList, defaultValue: [-1]);
            for (var i in body['data']['result']) {
              // 屏蔽推广和拉黑用户
              i['available'] = !blackMidsList.contains(i['mid']);
            }
            data = SearchVideoModel.fromJson(body['data']);
            break;
          case SearchType.live_room:
            data = SearchLiveModel.fromJson(body['data']);
            break;
          case SearchType.bili_user:
            data = SearchUserModel.fromJson(body['data']);
            break;
          case SearchType.media_bangumi:
            data = SearchMBangumiModel.fromJson(body['data']);
            break;
          case SearchType.article:
            data = SearchArticleModel.fromJson(body['data']);
            break;
        }
        return {
          'status': true,
          'data': data,
        };
      } catch (error, stackTrace) {
        return _searchFailure(
          stage: '响应解析失败',
          searchType: searchType,
          page: page,
          response: res,
          error: error,
          stackTrace: stackTrace,
        );
      }
    } else {
      return _searchFailure(
        stage: body.containsKey('code') ? 'API 拒绝请求' : '网络请求失败',
        searchType: searchType,
        page: page,
        response: res,
      );
    }
  }

  static Future<int> ab2c({int? aid, String? bvid}) async {
    Map<String, dynamic> data = {};
    if (aid != null) {
      data['aid'] = aid;
    } else if (bvid != null) {
      data['bvid'] = bvid;
    }
    final dynamic res =
        await Request().get(Api.ab2c, data: <String, dynamic>{...data});
    if (res.data['code'] == 0) {
      return res.data['data'].first['cid'];
    } else {
      return -1;
    }
  }

  static Future<Map<String, dynamic>> bangumiInfo(
      {int? seasonId, int? epId}) async {
    final Map<String, dynamic> data = {};
    if (seasonId != null) {
      data['season_id'] = seasonId;
    } else if (epId != null) {
      data['ep_id'] = epId;
    }
    final dynamic res =
        await Request().get(Api.bangumiInfo, data: <String, dynamic>{...data});
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': BangumiInfoModel.fromJson(res.data['result']),
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }

  static Future<Map<String, dynamic>> ab2cWithPic(
      {int? aid, String? bvid}) async {
    Map<String, dynamic> data = {};
    if (aid != null) {
      data['aid'] = aid;
    } else if (bvid != null) {
      data['bvid'] = bvid;
    }
    final dynamic res =
        await Request().get(Api.ab2c, data: <String, dynamic>{...data});
    return {
      'cid': res.data['data'].first['cid'],
      'pic': res.data['data'].first['first_frame'],
    };
  }

  static Future<Map<String, dynamic>> searchCount(
      {required String keyword}) async {
    Map<String, dynamic> data = {
      'keyword': keyword,
      'web_location': 333.999,
    };
    Map params = await WbiSign().makSign(data);
    final dynamic res = await Request().get(Api.searchCount, data: params);
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': SearchAllModel.fromJson(res.data['data']),
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }
}

class Data {
  List<dynamic> list;

  Data({this.list = const []});
}
