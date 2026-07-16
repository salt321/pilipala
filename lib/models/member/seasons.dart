class MemberSeasonsDataModel {
  MemberSeasonsDataModel({
    this.page,
    this.seasonsList,
    this.seriesList,
  });

  Map? page;
  List<MemberSeasonsList>? seasonsList;
  List<MemberArchiveItem>? seriesList;

  MemberSeasonsDataModel.fromJson(Map<String, dynamic> json) {
    page = json['page'] is Map ? json['page'] : <String, dynamic>{};
    var tempList1 = json['seasons_list'] != null
        ? json['seasons_list']
            .map<MemberSeasonsList>((e) => MemberSeasonsList.fromJson(e))
            .toList()
        : [];
    var tempList2 = json['series_list'] != null
        ? json['series_list']
            .map<MemberSeasonsList>((e) => MemberSeasonsList.fromJson(e))
            .toList()
        : [];
    seriesList = json['archives'] != null
        ? json['archives']
            .map<MemberArchiveItem>((e) => MemberArchiveItem.fromJson(e))
            .toList()
        : [];

    seasonsList = [...tempList1, ...tempList2];
  }
}

class MemberSeasonsList {
  MemberSeasonsList({
    this.archives,
    this.meta,
    this.recentAids,
    this.page,
  });

  List<MemberArchiveItem>? archives;
  MamberMeta? meta;
  List? recentAids;
  Map? page;

  MemberSeasonsList.fromJson(Map<String, dynamic> json) {
    archives = json['archives'] != null
        ? json['archives']
            .map<MemberArchiveItem>((e) => MemberArchiveItem.fromJson(e))
            .toList()
        : [];
    meta = json['meta'] is Map
        ? MamberMeta.fromJson(Map<String, dynamic>.from(json['meta']))
        : MamberMeta();
    page = json['page'] is Map ? json['page'] : <String, dynamic>{};
  }
}

class MemberArchiveItem {
  MemberArchiveItem({
    this.aid,
    this.bvid,
    this.ctime,
    this.duration,
    this.pic,
    this.cover,
    this.pubdate,
    this.view,
    this.title,
  });

  int? aid;
  String? bvid;
  int? ctime;
  int? duration;
  String? pic;
  String? cover;
  int? pubdate;
  int? view;
  String? title;

  MemberArchiveItem.fromJson(Map<String, dynamic> json) {
    aid = json['aid'];
    bvid = json['bvid'];
    ctime = json['ctime'];
    duration = json['duration'];
    pic = json['pic'];
    cover = json['pic'];
    pubdate = json['pubdate'];
    view = json['stat'] is Map ? (json['stat']['view'] as num?)?.toInt() : 0;
    title = json['title']?.toString() ?? '';
  }
}

class MamberMeta {
  MamberMeta({
    this.cover,
    this.description,
    this.mid,
    this.name,
    this.ptime,
    this.seasonId,
    this.total,
    this.seriesId,
    this.category,
  });

  String? cover;
  String? description;
  int? mid;
  String? name;
  int? ptime;
  int? seasonId;
  int? total;
  int? seriesId;
  int? category;

  MamberMeta.fromJson(Map<String, dynamic> json) {
    cover = json['cover']?.toString() ?? '';
    description = json['description']?.toString() ?? '';
    mid = (json['mid'] as num?)?.toInt();
    name = json['name']?.toString() ?? '';
    ptime = (json['ptime'] as num?)?.toInt();
    seasonId = (json['season_id'] as num?)?.toInt();
    total = (json['total'] as num?)?.toInt() ?? 0;
    seriesId = (json['series_id'] as num?)?.toInt();
    category = (json['category'] as num?)?.toInt() ?? 0;
  }
}
