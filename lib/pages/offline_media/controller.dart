import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/services/offline_cache_service.dart';
import 'package:pilipala/services/offline_playlist_service.dart';
import 'package:pilipala/utils/utils.dart';

class OfflineMediaController extends GetxController {
  final OfflineCacheService cacheService = OfflineCacheService.instance;
  final OfflinePlaylistService playlistService =
      OfflinePlaylistService.instance;
  final RxList<OfflineMediaItem> mediaList = <OfflineMediaItem>[].obs;
  final RxList<OfflinePlaylist> playlists = <OfflinePlaylist>[].obs;
  final RxBool isLoading = true.obs;
  final Map<String, OfflineMediaItem> _mediaByCacheKey = {};

  Worker? _revisionWorker;
  Worker? _playlistRevisionWorker;

  @override
  void onInit() {
    super.onInit();
    _revisionWorker = ever(cacheService.revision, (_) => loadMedia());
    _playlistRevisionWorker =
        ever(playlistService.revision, (_) => loadPlaylists());
    loadMedia();
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    playlists.assignAll(await playlistService.listPlaylists());
  }

  Future<void> loadMedia() async {
    isLoading.value = true;
    try {
      final List<OfflineMediaItem> items = await cacheService.listMedia();
      _mediaByCacheKey
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.cacheKey, item)));
      mediaList.assignAll(items);
    } finally {
      isLoading.value = false;
    }
  }

  void play(OfflineMediaItem item) {
    _openOfflineVideo([item], 0, '离线缓存');
  }

  void playPlaylist(
    OfflinePlaylist playlist,
    List<OfflineMediaItem> items, {
    int startIndex = 0,
  }) {
    if (items.isEmpty) {
      SmartDialog.showToast('播放列表中没有可用的离线视频');
      return;
    }
    Get.back();
    _openOfflineVideo(items, startIndex, playlist.name);
  }

  void _openOfflineVideo(
    List<OfflineMediaItem> items,
    int startIndex,
    String playlistTitle,
  ) {
    if (items.isEmpty) return;
    final int safeIndex = startIndex.clamp(0, items.length - 1);
    final OfflineMediaItem item = items[safeIndex];
    Get.toNamed(
      '/video?bvid=${item.bvid}&cid=${item.cid}&epId=',
      arguments: {
        'heroTag': Utils.makeHeroTag('${item.cacheKey}_${DateTime.now()}'),
        'videoType': SearchType.video,
        'sourceType': 'offline',
        'offlineItems': List<OfflineMediaItem>.of(items),
        'startIndex': safeIndex,
        'playlistTitle': playlistTitle,
      },
    );
  }

  List<OfflineMediaItem> itemsOf(OfflinePlaylist playlist) {
    return playlist.cacheKeys
        .map((key) => _mediaByCacheKey[key])
        .whereType<OfflineMediaItem>()
        .toList(growable: false);
  }

  Future<void> createPlaylist(String name, Iterable<String> cacheKeys) async {
    await playlistService.create(name: name, cacheKeys: cacheKeys);
    SmartDialog.showToast('已创建本地播放列表');
  }

  Future<void> updatePlaylist(
    OfflinePlaylist playlist,
    List<OfflineMediaItem> items,
  ) async {
    await playlistService.update(
      id: playlist.id,
      cacheKeys: items.map((item) => item.cacheKey),
    );
    SmartDialog.showToast('播放列表已更新');
  }

  Future<void> renamePlaylist(OfflinePlaylist playlist, String name) async {
    await playlistService.update(id: playlist.id, name: name);
  }

  Future<void> deletePlaylist(OfflinePlaylist playlist) async {
    await playlistService.delete(playlist.id);
    SmartDialog.showToast('已删除播放列表，缓存视频仍保留');
  }

  Future<void> delete(OfflineMediaItem item) async {
    await cacheService.delete(item.cacheKey);
    SmartDialog.showToast('已删除离线缓存');
  }

  @override
  void onClose() {
    _revisionWorker?.dispose();
    _playlistRevisionWorker?.dispose();
    super.onClose();
  }
}
