import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/models/offline_media.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  static const int _maxAttempts = 5;
  static const String _manifestName = 'manifest.json';
  static const Map<String, String> _downloadHeaders = {
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
    'referer': HttpString.baseUrl,
  };

  final Dio _dio = Dio();
  final RxMap<String, double> activeProgress = <String, double>{}.obs;
  final RxSet<String> completedKeys = <String>{}.obs;
  final RxInt revision = 0.obs;
  final Map<String, CancelToken> _cancelTokens = {};

  Directory? _rootDirectory;
  Future<void>? _initialization;

  bool isDownloading(String cacheKey) => activeProgress.containsKey(cacheKey);

  bool isDownloaded(String cacheKey) => completedKeys.contains(cacheKey);

  double progressOf(String cacheKey) => activeProgress[cacheKey] ?? 0;

  Future<void> ensureInitialized() {
    return _initialization ??= _loadCompletedKeys();
  }

  Future<Directory> _getRootDirectory() async {
    if (_rootDirectory != null) return _rootDirectory!;
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory root = Directory(
      '${documents.path}${Platform.pathSeparator}offline_media',
    );
    await root.create(recursive: true);
    _rootDirectory = root;
    return root;
  }

  Future<void> _loadCompletedKeys() async {
    final Directory root = await _getRootDirectory();
    final Set<String> keys = {};
    await for (final FileSystemEntity entity in root.list()) {
      if (entity is! Directory) {
        continue;
      }
      if (entity.path.endsWith('.downloading')) {
        await entity.delete(recursive: true);
        continue;
      }
      final File manifest = File(
        '${entity.path}${Platform.pathSeparator}$_manifestName',
      );
      if (!await manifest.exists()) continue;
      try {
        final Map<String, dynamic> json =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final OfflineMediaItem item = OfflineMediaItem.fromJson(json);
        final bool hasVideo = await File(item.videoPath).exists();
        final bool hasRequiredAudio =
            !item.hasAudio || await File(item.audioPath).exists();
        if (hasVideo && hasRequiredAudio) keys.add(item.cacheKey);
      } catch (_) {
        // 损坏或不完整的缓存不加入已完成索引。
      }
    }
    completedKeys.assignAll(keys);
  }

  Future<bool> download({
    required String bvid,
    required int cid,
    required String title,
    required String ownerName,
    required String coverUrl,
    required String videoUrl,
    required String audioUrl,
    required String qualityLabel,
    required int durationSeconds,
  }) async {
    await ensureInitialized();
    final String cacheKey = OfflineMediaItem.makeCacheKey(bvid, cid);
    if (isDownloaded(cacheKey)) return true;
    if (isDownloading(cacheKey) || videoUrl.isEmpty) return false;

    final Directory root = await _getRootDirectory();
    final Directory finalDirectory = Directory(
      '${root.path}${Platform.pathSeparator}$cacheKey',
    );
    final Directory temporaryDirectory = Directory(
      '${root.path}${Platform.pathSeparator}$cacheKey.downloading',
    );
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
    await temporaryDirectory.create(recursive: true);

    final CancelToken cancelToken = CancelToken();
    _cancelTokens[cacheKey] = cancelToken;
    activeProgress[cacheKey] = 0;

    try {
      final File temporaryVideo = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}video.cache',
      );
      final bool hasAudio = audioUrl.isNotEmpty;
      await _downloadFileWithRetry(
        url: videoUrl,
        destination: temporaryVideo,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final double fraction = total > 0 ? received / total : 0;
          activeProgress[cacheKey] = fraction * (hasAudio ? 0.8 : 1);
        },
      );

      File? temporaryAudio;
      if (hasAudio) {
        temporaryAudio = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}audio.cache',
        );
        await _downloadFileWithRetry(
          url: audioUrl,
          destination: temporaryAudio,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            final double fraction = total > 0 ? received / total : 0;
            activeProgress[cacheKey] = 0.8 + fraction * 0.2;
          },
        );
      }

      String coverPath = '';
      if (coverUrl.isNotEmpty && !cancelToken.isCancelled) {
        final File temporaryCover = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}cover.cache',
        );
        try {
          await _downloadFileWithRetry(
            url: coverUrl.startsWith('//') ? 'https:$coverUrl' : coverUrl,
            destination: temporaryCover,
            cancelToken: cancelToken,
            onProgress: (_, __) {},
          );
          coverPath =
              '${finalDirectory.path}${Platform.pathSeparator}cover.cache';
        } catch (_) {
          if (cancelToken.isCancelled) rethrow;
        }
      }

      final int videoBytes = await temporaryVideo.length();
      final int audioBytes =
          temporaryAudio == null ? 0 : await temporaryAudio.length();
      final OfflineMediaItem item = OfflineMediaItem(
        cacheKey: cacheKey,
        bvid: bvid,
        cid: cid,
        title: title,
        ownerName: ownerName,
        coverPath: coverPath,
        videoPath: '${finalDirectory.path}${Platform.pathSeparator}video.cache',
        audioPath: hasAudio
            ? '${finalDirectory.path}${Platform.pathSeparator}audio.cache'
            : '',
        qualityLabel: qualityLabel,
        durationSeconds: durationSeconds,
        sizeBytes: videoBytes + audioBytes,
        createdAt: DateTime.now(),
      );
      final File manifest = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}$_manifestName',
      );
      await manifest.writeAsString(jsonEncode(item.toJson()), flush: true);

      if (await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }
      await temporaryDirectory.rename(finalDirectory.path);
      completedKeys.add(cacheKey);
      revision.value++;
      return true;
    } catch (error) {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
      if (error is DioException && CancelToken.isCancel(error)) return false;
      rethrow;
    } finally {
      activeProgress.remove(cacheKey);
      _cancelTokens.remove(cacheKey);
    }
  }

  Future<void> _downloadFileWithRetry({
    required String url,
    required File destination,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (cancelToken.isCancelled) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(path: url),
          reason: cancelToken.cancelError,
        );
      }
      try {
        await _dio.download(
          url,
          destination.path,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: onProgress,
          options: Options(headers: _downloadHeaders),
        );
        return;
      } catch (error) {
        if (error is DioException && CancelToken.isCancel(error)) rethrow;
        lastError = error;
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }
    throw lastError ?? StateError('离线文件下载失败');
  }

  void cancel(String cacheKey) {
    _cancelTokens[cacheKey]?.cancel('用户取消离线缓存');
  }

  Future<List<OfflineMediaItem>> listMedia() async {
    await ensureInitialized();
    final Directory root = await _getRootDirectory();
    final List<OfflineMediaItem> items = [];
    for (final String cacheKey in completedKeys) {
      final File manifest = File(
        '${root.path}${Platform.pathSeparator}$cacheKey'
        '${Platform.pathSeparator}$_manifestName',
      );
      try {
        final Map<String, dynamic> json =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final OfflineMediaItem item = OfflineMediaItem.fromJson(json);
        if (await File(item.videoPath).exists()) items.add(item);
      } catch (_) {
        // 损坏的 manifest 不展示，删除时仍可通过 cacheKey 清理目录。
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> delete(String cacheKey) async {
    final Directory root = await _getRootDirectory();
    final Directory directory = Directory(
      '${root.path}${Platform.pathSeparator}$cacheKey',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
    completedKeys.remove(cacheKey);
    revision.value++;
  }
}
