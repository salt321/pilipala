import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/plugin/pl_player/models/data_source.dart';
import 'package:pilipala/services/offline_playlist_service.dart';

void main() {
  test('播放模式兼容旧数据及未知值并可完整保存', () {
    expect(OfflinePlaylist.fromJson({}).playMode, OfflinePlayMode.sequential);
    expect(OfflinePlaylist.fromJson({'playMode': 'future'}).playMode,
        OfflinePlayMode.sequential);
    for (final mode in OfflinePlayMode.values) {
      final playlist = OfflinePlaylist.fromJson({}).copyWith(playMode: mode);
      expect(OfflinePlaylist.fromJson(playlist.toJson()).playMode, mode);
      expect(playlist.copyWith(name: '重命名').playMode, mode);
    }
  });
  test('离线媒体缓存键由 bvid 和 cid 唯一确定', () {
    expect(
      OfflineMediaItem.makeCacheKey('BV1test', 123),
      'BV1test_123',
    );
  });

  test('离线媒体元数据可以完整序列化', () {
    final OfflineMediaItem source = OfflineMediaItem(
      cacheKey: 'BV1test_123',
      bvid: 'BV1test',
      cid: 123,
      title: '测试视频',
      ownerName: '测试用户',
      coverPath: '/cache/cover.cache',
      videoPath: '/cache/video.cache',
      audioPath: '/cache/audio.cache',
      qualityLabel: '1080P 高清',
      durationSeconds: 120,
      sizeBytes: 1024,
      createdAt: DateTime.utc(2026, 7, 16),
    );

    final OfflineMediaItem restored =
        OfflineMediaItem.fromJson(source.toJson());

    expect(restored.cacheKey, source.cacheKey);
    expect(restored.bvid, source.bvid);
    expect(restored.cid, source.cid);
    expect(restored.title, source.title);
    expect(restored.ownerName, source.ownerName);
    expect(restored.coverPath, source.coverPath);
    expect(restored.videoPath, source.videoPath);
    expect(restored.audioPath, source.audioPath);
    expect(restored.qualityLabel, source.qualityLabel);
    expect(restored.durationSeconds, source.durationSeconds);
    expect(restored.sizeBytes, source.sizeBytes);
    expect(restored.createdAt, source.createdAt);
    expect(restored.hasAudio, isTrue);
  });

  test('旧 manifest 缺少可选字段时仍可读取', () {
    final OfflineMediaItem item = OfflineMediaItem.fromJson({
      'cacheKey': 'BV1old_1',
      'bvid': 'BV1old',
      'cid': 1,
      'videoPath': '/cache/video.cache',
    });

    expect(item.title, '未知视频');
    expect(item.audioPath, isEmpty);
    expect(item.hasAudio, isFalse);
    expect(item.durationSeconds, 0);
  });

  test('离线媒体可只更新当前分P的标题和时长', () {
    final OfflineMediaItem source = OfflineMediaItem(
      cacheKey: 'BV1multi_2',
      bvid: 'BV1multi',
      cid: 2,
      title: '整个投稿标题',
      ownerName: '测试用户',
      coverPath: '/cover',
      videoPath: '/video',
      audioPath: '/audio',
      qualityLabel: '1080P',
      durationSeconds: 600,
      sizeBytes: 1024,
      createdAt: DateTime.utc(2026, 7, 17),
    );

    final OfflineMediaItem updated = source.copyWith(
      title: '第二集标题',
      durationSeconds: 120,
    );

    expect(updated.title, '第二集标题');
    expect(updated.durationSeconds, 120);
    expect(updated.cacheKey, source.cacheKey);
    expect(updated.videoPath, source.videoPath);
    expect(updated.sizeBytes, source.sizeBytes);
  });

  test('本地播放器数据源支持独立视频和音频路径', () {
    final DataSource source = DataSource(
      videoSource: '/cache/video.cache',
      audioSource: '/cache/audio.cache',
      type: DataSourceType.file,
    );

    expect(source.type, DataSourceType.file);
    expect(source.videoSource, '/cache/video.cache');
    expect(source.audioSource, '/cache/audio.cache');
  });

  test('离线播放列表保持条目顺序并可完整序列化', () {
    final OfflinePlaylist source = OfflinePlaylist(
      id: 'playlist-1',
      name: '通勤列表',
      cacheKeys: const ['BV1_1', 'BV2_2'],
      createdAt: DateTime.utc(2026, 7, 17, 8),
      updatedAt: DateTime.utc(2026, 7, 17, 9),
    );

    final OfflinePlaylist restored = OfflinePlaylist.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.cacheKeys, source.cacheKeys);
    expect(restored.createdAt, source.createdAt);
    expect(restored.updatedAt, source.updatedAt);
  });

  test('解析播放列表时保持顺序并过滤已删除的缓存引用', () {
    final OfflineMediaItem first = OfflineMediaItem(
      cacheKey: 'BV1_1',
      bvid: 'BV1',
      cid: 1,
      title: '第一个',
      ownerName: '',
      coverPath: '',
      videoPath: '/first',
      audioPath: '',
      qualityLabel: '',
      durationSeconds: 1,
      sizeBytes: 1,
      createdAt: DateTime.utc(2026),
    );
    final OfflineMediaItem second = OfflineMediaItem(
      cacheKey: 'BV2_2',
      bvid: 'BV2',
      cid: 2,
      title: '第二个',
      ownerName: '',
      coverPath: '',
      videoPath: '/second',
      audioPath: '',
      qualityLabel: '',
      durationSeconds: 1,
      sizeBytes: 1,
      createdAt: DateTime.utc(2026),
    );
    final OfflinePlaylist playlist = OfflinePlaylist(
      id: 'playlist-1',
      name: '列表',
      cacheKeys: const ['BV2_2', 'missing', 'BV1_1'],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final List<OfflineMediaItem> resolved =
        OfflinePlaylistService.instance.resolveItems(
      playlist,
      [first, second],
    );

    expect(resolved.map((item) => item.cacheKey), ['BV2_2', 'BV1_1']);
  });
}
