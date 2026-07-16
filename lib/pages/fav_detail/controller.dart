import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/models/user/fav_folder.dart';
import 'package:pilipala/models/video/later.dart' as playback;
import 'package:pilipala/pages/fav/index.dart';
import 'package:pilipala/pages/fav_detail/widget/playlist_editor.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/utils.dart';

class FavDetailController extends GetxController {
  FavFolderItemData? item;
  RxString title = ''.obs;

  int? mediaId;
  late String heroTag;
  int currentPage = 1;
  bool isLoadingMore = false;
  RxMap favInfo = {}.obs;
  RxList<FavDetailItemData> favList = <FavDetailItemData>[].obs;
  RxString loadingText = '加载中...'.obs;
  RxInt mediaCount = 0.obs;
  late String isOwner;

  @override
  void onInit() {
    item = Get.arguments;
    title.value = item!.title!;
    if (Get.parameters.keys.isNotEmpty) {
      mediaId = int.parse(Get.parameters['mediaId']!);
      heroTag = Get.parameters['heroTag']!;
      isOwner = Get.parameters['isOwner']!;
    }
    super.onInit();
  }

  Future<dynamic> queryUserFavFolderDetail({type = 'init'}) async {
    if (type == 'onLoad' && favList.length >= mediaCount.value) {
      loadingText.value = '没有更多了';
      return;
    }
    isLoadingMore = true;
    var res = await UserHttp.userFavFolderDetail(
      pn: currentPage,
      ps: 20,
      mediaId: mediaId!,
    );
    if (res['status']) {
      favInfo.value = res['data'].info;
      if (currentPage == 1 && type == 'init') {
        favList.value = res['data'].medias;
        mediaCount.value = res['data'].info['media_count'];
      } else if (type == 'onLoad') {
        favList.addAll(res['data'].medias);
      }
      if (favList.length >= mediaCount.value) {
        loadingText.value = '没有更多了';
      }
    }
    currentPage += 1;
    isLoadingMore = false;
    return res;
  }

  onCancelFav(int id) async {
    var result = await VideoHttp.favVideo(
        aid: id, addIds: '', delIds: mediaId.toString());
    if (result['status']) {
      List dataList = favList;
      for (var i in dataList) {
        if (i.id == id) {
          dataList.remove(i);
          break;
        }
      }
      SmartDialog.showToast('取消收藏');
    }
  }

  onLoad() {
    queryUserFavFolderDetail(type: 'onLoad');
  }

  onDelFavFolder() async {
    SmartDialog.show(
      useSystem: true,
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('确定删除这个收藏夹吗？'),
          actions: [
            TextButton(
              onPressed: () async {
                SmartDialog.dismiss();
              },
              child: Text(
                '点错了',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                var res = await UserHttp.delFavFolder(mediaIds: mediaId!);
                SmartDialog.dismiss();
                SmartDialog.showToast(res['status'] ? '操作成功' : res['msg']);
                if (res['status']) {
                  FavController favController = Get.find<FavController>();
                  await favController.removeFavFolder(mediaIds: mediaId!);
                  Get.back();
                }
              },
              child: const Text('确认'),
            )
          ],
        );
      },
    );
  }

  onEditFavFolder() async {
    var res = await Get.toNamed(
      '/favEdit',
      arguments: {
        'mediaId': mediaId.toString(),
        'title': item!.title,
        'intro': item!.intro,
        'cover': item!.cover,
        'privacy': [23, 1].contains(item!.attr) ? 1 : 0,
      },
    );
    title.value = res['title'];
    debugPrint(title.value);
  }

  Future<void> toViewPlayAll() async {
    SmartDialog.showLoading(msg: '正在生成播放队列');
    final queue = await _loadCompleteQueue();
    SmartDialog.dismiss();
    if (queue.isEmpty) {
      SmartDialog.showToast('收藏夹中没有可播放的视频');
      return;
    }
    await showModalBottomSheet<void>(
      context: Get.context!,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistEditorSheet(
        items: queue,
        onPlay: _startQueue,
      ),
    );
  }

  Future<List<FavDetailItemData>> _loadCompleteQueue() async {
    final expectedCount = mediaCount.value;
    if (favList.length >= expectedCount) return List.of(favList);

    final result = <FavDetailItemData>[];
    final seenIds = <int>{};
    var page = 1;
    while (result.length < expectedCount) {
      final res = await UserHttp.userFavFolderDetail(
        mediaId: mediaId!,
        pn: page,
        ps: 20,
      );
      if (res['status'] != true) {
        SmartDialog.showToast(res['msg'] ?? '播放队列加载失败');
        break;
      }
      final data = res['data'] as FavDetailData;
      final pageItems = data.medias ?? <FavDetailItemData>[];
      if (pageItems.isEmpty) break;
      for (final item in pageItems) {
        if (item.id != null && seenIds.add(item.id!)) result.add(item);
      }
      if (data.hasMore != true) break;
      page++;
    }
    return result.isNotEmpty ? result : List.of(favList);
  }

  Future<void> _startQueue(
    int startIndex,
    List<FavDetailItemData> items,
  ) async {
    final firstItem = items[startIndex];
    final bvid = _bvidOf(firstItem);
    final cid = await _cidOf(firstItem, bvid);
    if (cid == null) {
      SmartDialog.showToast('无法获取该视频的播放信息');
      return;
    }
    final playbackQueue = items.map(_toMediaItem).toList();
    playbackQueue[startIndex].cid = cid;
    final routeHeroTag = Utils.makeHeroTag(bvid);
    Get.back();
    Get.toNamed(
      '/video?bvid=$bvid&cid=$cid&epId=${firstItem.epId ?? ''}',
      arguments: {
        'videoItem': firstItem,
        'heroTag': routeHeroTag,
        'videoType': firstItem.epId != null
            ? SearchType.media_bangumi
            : SearchType.video,
        'sourceType': 'fav',
        'mediaId': mediaId,
        'oid': firstItem.id,
        'favTitle': title.value,
        'count': playbackQueue.length,
        'mediaList': playbackQueue,
      },
    );
  }

  String _bvidOf(FavDetailItemData item) {
    final bvid = item.bvid ?? item.bvId;
    if (bvid?.isNotEmpty == true) return bvid!;
    return IdUtils.av2bv(item.id!);
  }

  Future<int?> _cidOf(FavDetailItemData item, String bvid) async {
    if (item.cid != null && item.cid! > 0) return item.cid;
    try {
      return await SearchHttp.ab2c(aid: item.id, bvid: bvid);
    } catch (_) {
      return null;
    }
  }

  playback.MediaVideoItemModel _toMediaItem(FavDetailItemData item) {
    return playback.MediaVideoItemModel(
      id: item.id,
      aid: item.id,
      cid: item.cid ?? -1,
      title: item.title,
      intro: item.intro,
      cover: item.pic,
      duration: item.duration,
      page: item.page,
      bvid: _bvidOf(item),
      cntInfo: item.cntInfo,
      upper: playback.Upper(
        mid: item.owner?.mid,
        name: item.owner?.name,
        face: item.owner?.face,
      ),
    );
  }
}
