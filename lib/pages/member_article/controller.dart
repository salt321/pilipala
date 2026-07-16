import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/member.dart';
import 'package:pilipala/models/member/article.dart';

class MemberArticleController extends GetxController {
  final ScrollController scrollController = ScrollController();
  late int mid;
  int pn = 1;
  String? offset;
  bool hasMore = true;
  String? wWebid;
  RxBool isLoading = false.obs;
  RxList<MemberArticleItemModel> articleList = <MemberArticleItemModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    mid = int.parse(Get.parameters['mid']!);
  }

  // 获取wWebid
  Future getWWebid() async {
    var res = await MemberHttp.getWWebid(mid: mid);
    if (res['status']) {
      wWebid = res['data'];
    } else {
      wWebid = '-1';
      SmartDialog.showToast(res['msg']);
    }
  }

  Future getMemberArticle(type) async {
    if (isLoading.value) {
      return {'status': false, 'msg': '专栏正在加载，请稍候'};
    }
    if (!hasMore && type == 'onLoad') {
      return {'status': true, 'data': null};
    }
    isLoading.value = true;
    try {
      if (wWebid == null) {
        final credential = await MemberHttp.getWWebid(mid: mid);
        if (credential['status'] != true) return credential;
        wWebid = credential['data']?.toString();
      }
      if (type == 'init') {
        pn = 1;
        offset = null;
        hasMore = true;
        articleList.clear();
      }
      var res = await MemberHttp.getMemberArticle(
        mid: mid,
        pn: pn,
        offset: offset,
        wWebid: wWebid!,
      );
      if (res['status']) {
        final items = res['data'].items ?? <MemberArticleItemModel>[];
        offset = res['data'].offset;
        hasMore = res['data'].hasMore ?? false;
        if (type == 'init') {
          articleList.assignAll(items);
        } else {
          articleList.addAll(items);
        }
        pn += 1;
      } else {
        SmartDialog.showToast(res['msg']?.toString() ?? '专栏请求异常');
      }
      return res;
    } catch (error) {
      return {
        'status': false,
        'msg': '专栏页面处理异常\n${error.runtimeType}: $error',
      };
    } finally {
      isLoading.value = false;
    }
  }
}
