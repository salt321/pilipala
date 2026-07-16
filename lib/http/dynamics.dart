import 'dart:math';
import 'package:dio/dio.dart';
import '../models/dynamics/result.dart';
import '../models/dynamics/up.dart';
import 'index.dart';

class DynamicsHttp {
  static const String dynamicFeatures =
      'itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,'
      'forwardListHidden,decorationCard,commentsNewVersion,'
      'onlyfansAssetsV2,ugcDelete,onlyfansQaCard';

  static Future followDynamic({
    String? type,
    int? page,
    String? offset,
    int? mid,
  }) async {
    Map<String, dynamic> data = {
      'type': type ?? 'all',
      'page': page ?? 1,
      'timezone_offset': '-480',
      'offset': page == 1 ? '' : offset,
      'features': dynamicFeatures,
      'platform': 'web',
      'web_location': 333.1365,
    };
    if (mid != -1) {
      data['host_mid'] = mid;
      data.remove('timezone_offset');
    }
    try {
      final dynamic res = await Request().get(
        Api.followDynamic,
        data: data,
        extra: {'ua': 'pc'},
      );
      final dynamic body = res.data;
      if (body is Map && body['code'] == 0 && body['data'] is Map) {
        final data = DynamicsDataModel.fromJson(
            Map<String, dynamic>.from(body['data'] as Map));
        if (data.rawItemCount > 0 && (data.items ?? []).isEmpty) {
          return {
            'status': false,
            'data': data,
            'msg': '动态接口返回了 ${data.rawItemCount} 条数据，但全部解析失败\n'
                '${data.parseErrors.join('\n')}',
          };
        }
        return {
          'status': true,
          'data': data,
        };
      }
      return {
        'status': false,
        'data': [],
        'msg': '动态请求失败\n'
            'API code: ${body is Map ? body['code'] : '未知'}\n'
            '信息: ${body is Map ? body['message'] : body}',
        'code': body is Map ? body['code'] : null,
      };
    } catch (error) {
      return {
        'status': false,
        'data': [],
        'msg': '动态数据处理异常\n${error.runtimeType}: $error',
      };
    }
  }

  static Future followUp() async {
    try {
      final dynamic res = await Request().get(Api.followUp);
      final dynamic body = res.data;
      if (body is Map && body['code'] == 0 && body['data'] is Map) {
        return {
          'status': true,
          'data': FollowUpModel.fromJson(
              Map<String, dynamic>.from(body['data'] as Map)),
        };
      }
      return {
        'status': false,
        'data': [],
        'msg': body is Map ? body['message'] : '动态用户列表响应异常',
      };
    } catch (error) {
      return {
        'status': false,
        'data': [],
        'msg': '动态用户列表处理异常\n${error.runtimeType}: $error',
      };
    }
  }

  // 动态点赞
  static Future likeDynamic({
    required String? dynamicId,
    required int? up,
  }) async {
    var res = await Request().post(
      Api.likeDynamic,
      data: {
        'dynamic_id': dynamicId,
        'up': up,
        'csrf': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  //
  static Future dynamicDetail({
    String? id,
  }) async {
    var res = await Request().get(Api.dynamicDetail, data: {
      'timezone_offset': -480,
      'id': id,
      'features': 'itemOpusStyle',
    });
    if (res.data['code'] == 0) {
      try {
        return {
          'status': true,
          'data': DynamicItemModel.fromJson(res.data['data']['item']),
        };
      } catch (err) {
        return {
          'status': false,
          'data': [],
          'msg': err.toString(),
        };
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  static Future dynamicForward() async {
    var res = await Request().post(
      Api.dynamicForwardUrl,
      queryParameters: {
        'csrf': await Request.getCsrf(),
        'x-bili-device-req-json': {'platform': 'web', 'device': 'pc'},
        'x-bili-web-req-json': {'spm_id': '333.999'},
      },
      data: {
        'attach_card': null,
        'scene': 4,
        'content': {
          'conetents': [
            {'raw_text': "2", 'type': 1, 'biz_id': ""}
          ]
        }
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  static Future dynamicCreate({
    required int mid,
    required int scene,
    int? oid,
    String? dynIdStr,
    String? rawText,
  }) async {
    DateTime now = DateTime.now();
    int timestamp = now.millisecondsSinceEpoch ~/ 1000;
    Random random = Random();
    int randomNumber = random.nextInt(9000) + 1000;
    String uploadId = '${mid}_${timestamp}_$randomNumber';

    Map<String, dynamic> webRepostSrc = {
      'dyn_id_str': dynIdStr ?? '',
    };

    /// 投稿转发
    if (scene == 5) {
      webRepostSrc = {
        'revs_id': {'dyn_type': 8, 'rid': oid}
      };
    }
    var res = await Request().post(
      Api.dynamicCreate,
      queryParameters: {
        'platform': 'web',
        'csrf': await Request.getCsrf(),
        'x-bili-device-req-json': {'platform': 'web', 'device': 'pc'},
        'x-bili-web-req-json': {'spm_id': '333.999'},
      },
      data: {
        'dyn_req': {
          'content': {
            'contents': [
              {'raw_text': rawText ?? '', 'type': 1, 'biz_id': ''}
            ]
          },
          'scene': scene,
          'attach_card': null,
          'upload_id': uploadId,
          'meta': {
            'app_meta': {'from': 'create.dynamic.web', 'mobi_app': 'web'}
          }
        },
        'web_repost_src': webRepostSrc
      },
      options: Options(contentType: 'application/json'),
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }
}
