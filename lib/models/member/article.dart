class MemberArticleDataModel {
  MemberArticleDataModel({
    this.hasMore,
    this.items,
    this.offset,
    this.updateNum,
  });

  bool? hasMore;
  List<MemberArticleItemModel>? items;
  String? offset;
  int? updateNum;

  MemberArticleDataModel.fromJson(Map<String, dynamic> json) {
    hasMore = json['has_more'] == true;
    final rawItems = json['items'];
    items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => MemberArticleItemModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <MemberArticleItemModel>[];
    offset = json['offset']?.toString();
    updateNum = (json['update_num'] as num?)?.toInt() ?? 0;
  }
}

class MemberArticleItemModel {
  MemberArticleItemModel({
    this.content,
    this.cover,
    this.jumpUrl,
    this.opusId,
    this.stat,
  });

  String? content;
  Map? cover;
  String? jumpUrl;
  String? opusId;
  Map? stat;

  MemberArticleItemModel.fromJson(Map<String, dynamic> json) {
    content = json['content']?.toString() ?? '';
    cover = json['cover'] is Map ? json['cover'] : <String, dynamic>{};
    jumpUrl = json['jump_url']?.toString() ?? '';
    opusId = json['opus_id']?.toString() ?? '';
    stat = json['stat'] is Map ? json['stat'] : <String, dynamic>{};
  }
}
