enum OfflinePlayMode {
  sequential('顺序播放'),
  listRepeat('列表循环'),
  singleRepeat('单曲循环'),
  shuffle('随机播放');

  const OfflinePlayMode(this.label);
  final String label;

  static OfflinePlayMode fromValue(Object? value) => values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => sequential,
      );
}

class OfflinePlaylist {
  const OfflinePlaylist({
    required this.id,
    required this.name,
    required this.cacheKeys,
    required this.createdAt,
    required this.updatedAt,
    this.playMode = OfflinePlayMode.sequential,
  });

  final String id;
  final String name;
  final List<String> cacheKeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OfflinePlayMode playMode;

  factory OfflinePlaylist.fromJson(Map<String, dynamic> json) {
    return OfflinePlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名播放列表',
      playMode: OfflinePlayMode.fromValue(json['playMode']),
      cacheKeys: (json['cacheKeys'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'playMode': playMode.name,
      'cacheKeys': cacheKeys,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  OfflinePlaylist copyWith({
    String? name,
    List<String>? cacheKeys,
    DateTime? updatedAt,
    OfflinePlayMode? playMode,
  }) {
    return OfflinePlaylist(
      id: id,
      name: name ?? this.name,
      cacheKeys: cacheKeys ?? this.cacheKeys,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      playMode: playMode ?? this.playMode,
    );
  }
}
