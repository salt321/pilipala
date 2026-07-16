import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/plugin/pl_player/models/data_source.dart';

void main() {
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
}
