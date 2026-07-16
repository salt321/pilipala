class OfflineMediaItem {
  const OfflineMediaItem({
    required this.cacheKey,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.ownerName,
    required this.coverPath,
    required this.videoPath,
    required this.audioPath,
    required this.qualityLabel,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String cacheKey;
  final String bvid;
  final int cid;
  final String title;
  final String ownerName;
  final String coverPath;
  final String videoPath;
  final String audioPath;
  final String qualityLabel;
  final int durationSeconds;
  final int sizeBytes;
  final DateTime createdAt;

  bool get hasAudio => audioPath.isNotEmpty;

  static String makeCacheKey(String bvid, int cid) => '${bvid}_$cid';

  factory OfflineMediaItem.fromJson(Map<String, dynamic> json) {
    return OfflineMediaItem(
      cacheKey: json['cacheKey'] as String? ?? '',
      bvid: json['bvid'] as String? ?? '',
      cid: (json['cid'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '未知视频',
      ownerName: json['ownerName'] as String? ?? '',
      coverPath: json['coverPath'] as String? ?? '',
      videoPath: json['videoPath'] as String? ?? '',
      audioPath: json['audioPath'] as String? ?? '',
      qualityLabel: json['qualityLabel'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cacheKey': cacheKey,
      'bvid': bvid,
      'cid': cid,
      'title': title,
      'ownerName': ownerName,
      'coverPath': coverPath,
      'videoPath': videoPath,
      'audioPath': audioPath,
      'qualityLabel': qualityLabel,
      'durationSeconds': durationSeconds,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
