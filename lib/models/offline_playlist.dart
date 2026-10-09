class OfflinePlaylist {
  const OfflinePlaylist({
    required this.id,
    required this.name,
    required this.cacheKeys,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> cacheKeys;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory OfflinePlaylist.fromJson(Map<String, dynamic> json) {
    return OfflinePlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名播放列表',
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
      'cacheKeys': cacheKeys,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  OfflinePlaylist copyWith({
    String? name,
    List<String>? cacheKeys,
    DateTime? updatedAt,
  }) {
    return OfflinePlaylist(
      id: id,
      name: name ?? this.name,
      cacheKeys: cacheKeys ?? this.cacheKeys,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
