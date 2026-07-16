import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/services/offline_cache_service.dart';

class OfflineMediaController extends GetxController {
  final OfflineCacheService cacheService = OfflineCacheService.instance;
  final RxList<OfflineMediaItem> mediaList = <OfflineMediaItem>[].obs;
  final RxBool isLoading = true.obs;

  Worker? _revisionWorker;

  @override
  void onInit() {
    super.onInit();
    _revisionWorker = ever(cacheService.revision, (_) => loadMedia());
    loadMedia();
  }

  Future<void> loadMedia() async {
    isLoading.value = true;
    try {
      mediaList.assignAll(await cacheService.listMedia());
    } finally {
      isLoading.value = false;
    }
  }

  void play(OfflineMediaItem item) {
    Get.toNamed('/offlinePlayer', arguments: item);
  }

  Future<void> delete(OfflineMediaItem item) async {
    await cacheService.delete(item.cacheKey);
    SmartDialog.showToast('已删除离线缓存');
  }

  @override
  void onClose() {
    _revisionWorker?.dispose();
    super.onClose();
  }
}
