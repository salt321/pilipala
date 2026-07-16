import 'dart:convert';

int? _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

class DynamicsDataModel {
  DynamicsDataModel({
    this.hasMore,
    this.items,
    this.offset,
    this.rawItemCount = 0,
    this.skippedItemCount = 0,
    this.parseErrors = const [],
  });
  bool? hasMore;
  List<DynamicItemModel>? items;
  String? offset;
  int rawItemCount;
  int skippedItemCount;
  List<String> parseErrors;

  DynamicsDataModel.fromJson(Map<String, dynamic> json)
      : rawItemCount = 0,
        skippedItemCount = 0,
        parseErrors = <String>[] {
    hasMore = json['has_more'];
    items = <DynamicItemModel>[];
    final dynamic rawItems = json['items'];
    if (rawItems is List) {
      rawItemCount = rawItems.length;
      final errors = <String>[];
      for (var index = 0; index < rawItems.length; index++) {
        final dynamic rawItem = rawItems[index];
        if (rawItem is! Map || rawItem['modules'] is! Map) continue;
        try {
          final DynamicItemModel item =
              DynamicItemModel.fromJson(Map<String, dynamic>.from(rawItem));
          if (item.modules?.moduleAuthor != null &&
              item.modules?.moduleDynamic != null) {
            items!.add(item);
          }
        } catch (error) {
          errors.add('#$index ${rawItem['type'] ?? 'UNKNOWN'}: '
              '${error.runtimeType}: $error');
        }
      }
      skippedItemCount = rawItemCount - items!.length;
      parseErrors = errors.take(3).toList();
    }
    offset = json['offset'];
  }
}

// 单个动态
class DynamicItemModel {
  DynamicItemModel({
    this.basic,
    this.idStr,
    this.modules,
    this.orig,
    this.type,
    this.visible,
  });

  Map? basic;
  String? idStr;
  ItemModulesModel? modules;
  ItemOrigModel? orig;
  String? type;
  bool? visible;

  DynamicItemModel.fromJson(Map<String, dynamic> json) {
    basic = json['basic'];
    idStr = json['id_str'];
    modules = ItemModulesModel.fromJson(
      Map<String, dynamic>.from(json['modules'] as Map),
    );
    if (json['orig'] is Map) {
      try {
        orig = ItemOrigModel.fromJson(
          Map<String, dynamic>.from(json['orig'] as Map),
        );
      } catch (_) {
        orig = null;
      }
    }
    type = json['type'];
    visible = json['visible'];
  }
}

class ItemOrigModel {
  ItemOrigModel({
    this.basic,
    this.isStr,
    this.modules,
    this.type,
    this.visible,
  });

  Map? basic;
  String? isStr;
  ItemModulesModel? modules;
  String? type;
  bool? visible;

  ItemOrigModel.fromJson(Map<String, dynamic> json) {
    basic = json['basic'];
    // 接口字段为 id_str；兼容早期错误拼写 is_str。
    isStr = json['id_str']?.toString() ?? json['is_str']?.toString();
    modules = ItemModulesModel.fromJson(json['modules']);
    type = json['type'];
    visible = json['visible'];
  }
}

// 单个动态详情
class ItemModulesModel {
  ItemModulesModel({
    this.moduleAuthor,
    this.moduleDynamic,
    // this.moduleInter,
    this.moduleStat,
    this.moduleTag,
  });

  ModuleAuthorModel? moduleAuthor;
  ModuleDynamicModel? moduleDynamic;
  // ModuleInterModel? moduleInter;
  ModuleStatModel? moduleStat;
  Map? moduleTag;

  ItemModulesModel.fromJson(Map<String, dynamic> json) {
    moduleAuthor = json['module_author'] is Map
        ? ModuleAuthorModel.fromJson(
            Map<String, dynamic>.from(json['module_author'] as Map),
          )
        : null;
    moduleDynamic = json['module_dynamic'] is Map
        ? ModuleDynamicModel.fromJson(
            Map<String, dynamic>.from(json['module_dynamic'] as Map),
          )
        : null;
    // moduleInter = ModuleInterModel.fromJson(json['module_interaction']);
    if (json['module_stat'] is Map) {
      try {
        moduleStat = ModuleStatModel.fromJson(
          Map<String, dynamic>.from(json['module_stat'] as Map),
        );
      } catch (_) {
        moduleStat = null;
      }
    }
    moduleTag = json['module_tag'];
  }
}

// 单个动态详情 - 作者信息
class ModuleAuthorModel {
  ModuleAuthorModel({
    // this.avatar,
    // this.decorate,
    this.face,
    this.following,
    this.jumpUrl,
    this.label,
    this.mid,
    this.name,
    // this.officialVerify,
    // this.pandant,
    this.pubAction,
    // this.pubLocationText,
    this.pubTime,
    this.pubTs,
    this.type,
    this.vip,
  });

  String? face;
  bool? following;
  String? jumpUrl;
  String? label;
  int? mid;
  String? name;
  String? pubAction;
  String? pubTime;
  int? pubTs;
  String? type;
  Map? vip;

  ModuleAuthorModel.fromJson(Map<String, dynamic> json) {
    face = json['face']?.toString() ?? '';
    following = json['following'] == true;
    jumpUrl = json['jump_url']?.toString() ?? '';
    label = json['label']?.toString() ?? '';
    mid = json['mid'] is num
        ? (json['mid'] as num).toInt()
        : int.tryParse(json['mid']?.toString() ?? '');
    name = json['name']?.toString() ?? '';
    pubAction = json['pub_action']?.toString() ?? '';
    pubTime = json['pub_time']?.toString() ?? '';
    pubTs = json['pub_ts'] is num
        ? (json['pub_ts'] as num).toInt()
        : int.tryParse(json['pub_ts']?.toString() ?? '');
    if (pubTs == 0) pubTs = null;
    type = json['type']?.toString();
    vip = json['vip'] is Map ? json['vip'] : null;
  }
}

// 单个动态详情 - 动态信息
class ModuleDynamicModel {
  ModuleDynamicModel({
    this.additional,
    this.desc,
    this.major,
    this.topic,
  });

  DynamicAddModel? additional;
  DynamicDescModel? desc;
  DynamicMajorModel? major;
  DynamicTopicModel? topic;

  ModuleDynamicModel.fromJson(Map<String, dynamic> json) {
    if (json['additional'] is Map) {
      try {
        additional = DynamicAddModel.fromJson(
          Map<String, dynamic>.from(json['additional'] as Map),
        );
      } catch (_) {}
    }
    if (json['desc'] is Map) {
      try {
        desc = DynamicDescModel.fromJson(
          Map<String, dynamic>.from(json['desc'] as Map),
        );
      } catch (_) {}
    }
    if (json['major'] is Map) {
      try {
        major = DynamicMajorModel.fromJson(
          Map<String, dynamic>.from(json['major'] as Map),
        );
      } catch (_) {}
    }
    if (json['topic'] is Map) {
      try {
        topic = DynamicTopicModel.fromJson(
          Map<String, dynamic>.from(json['topic'] as Map),
        );
      } catch (_) {}
    }
  }
}

// 单个动态详情 - 评论？信息
// class ModuleInterModel {
//   ModuleInterModel({

//   });

//   ModuleInterModel.fromJson(Map<String, dynamic> json) {

//   }
// }
class DynamicAddModel {
  DynamicAddModel({
    this.type,
    this.vote,
    this.ugc,
    this.reserve,
    this.goods,
  });

  String? type;
  Vote? vote;
  Ugc? ugc;
  Reserve? reserve;
  Good? goods;

  /// TODO 比赛vs
  String? match;

  /// TODO 游戏信息
  String? common;

  DynamicAddModel.fromJson(Map<String, dynamic> json) {
    type = json['type']?.toString();
    vote = json['vote'] is Map
        ? Vote.fromJson(Map<String, dynamic>.from(json['vote'] as Map))
        : null;
    ugc = json['ugc'] is Map
        ? Ugc.fromJson(Map<String, dynamic>.from(json['ugc'] as Map))
        : null;
    reserve = json['reserve'] is Map
        ? Reserve.fromJson(Map<String, dynamic>.from(json['reserve'] as Map))
        : null;
    goods = json['goods'] is Map
        ? Good.fromJson(Map<String, dynamic>.from(json['goods'] as Map))
        : null;
  }
}

class Vote {
  Vote({
    this.choiceCnt,
    this.defaultShare,
    this.share,
    this.endTime,
    this.joinNum,
    this.status,
    this.type,
    this.uid,
    this.voteId,
  });

  int? choiceCnt;
  String? share;
  int? defaultShare;
  int? endTime;
  int? joinNum;
  int? status;
  int? type;
  int? uid;
  int? voteId;

  Vote.fromJson(Map<String, dynamic> json) {
    choiceCnt = json['choice_cnt'];
    share = json['share'];
    defaultShare = json['default_share'];
    endTime = _intValue(json['end_time']);
    joinNum = json['join_num'];
    status = json['status'];
    type = json['type'];
    uid = json['uid'];
    voteId = json['vote_id'];
  }
}

class Ugc {
  Ugc({
    this.cover,
    this.descSecond,
    this.duration,
    this.headText,
    this.idStr,
    this.jumpUrl,
    this.multiLine,
    this.title,
  });

  String? cover;
  String? descSecond;
  String? duration;
  String? headText;
  String? idStr;
  String? jumpUrl;
  bool? multiLine;
  String? title;

  Ugc.fromJson(Map<String, dynamic> json) {
    cover = json['cover']?.toString() ?? '';
    descSecond = json['desc_second']?.toString() ?? '';
    duration = json['duration']?.toString() ?? '';
    headText = json['head_text']?.toString() ?? '';
    idStr = json['id_str']?.toString() ?? '';
    jumpUrl = json['jump_url']?.toString() ?? '';
    multiLine = json['multi_line'] == true || json['multi_line'] == 1;
    title = json['title']?.toString() ?? '';
  }
}

class Reserve {
  Reserve({
    this.button,
    this.desc1,
    this.desc2,
    this.jumpUrl,
    this.reserveTotal,
    this.rid,
    this.state,
    this.stype,
    this.title,
    this.upMid,
  });

  Map? button;
  Map? desc1;
  Map? desc2;
  String? jumpUrl;
  int? reserveTotal;
  int? rid;
  int? state;
  int? stype;
  String? title;
  int? upMid;

  Reserve.fromJson(Map<String, dynamic> json) {
    button = json['button'];
    desc1 = json['desc1'];
    desc2 = json['desc2'];
    jumpUrl = json['jump_url'];
    reserveTotal = json['reserve_total'];
    rid = json['rid'];
    state = json['state'];
    state = json['state'];
    stype = json['stype'];
    title = json['title'];
    upMid = json['up_mid'];
  }
}

class Good {
  Good({
    this.headIcon,
    this.headText,
    this.items,
    this.jumpUrl,
  });

  String? headIcon;
  String? headText;
  List<GoodItem>? items;
  String? jumpUrl;

  Good.fromJson(Map<String, dynamic> json) {
    headIcon = json['head_icon'];
    headText = json['head_text'];
    final rawItems = json['items'];
    items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => GoodItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <GoodItem>[];
    jumpUrl = json['jump_url'];
  }
}

class GoodItem {
  GoodItem({
    this.brief,
    this.cover,
    this.id,
    this.jumpDesc,
    this.jumpUrl,
    this.name,
    this.price,
  });

  String? brief;
  String? cover;
  dynamic id;
  String? jumpDesc;
  String? jumpUrl;
  String? name;
  String? price;

  GoodItem.fromJson(Map<String, dynamic> json) {
    brief = json['brief'];
    cover = json['cover'];
    id = json['id'];
    jumpDesc = json['jump_desc'];
    jumpUrl = json['jump_url'];
    name = json['name'];
    price = json['price'];
  }
}

class DynamicDescModel {
  DynamicDescModel({
    this.richTextNodes,
    this.text,
  });

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  DynamicDescModel.fromJson(Map<String, dynamic> json) {
    richTextNodes = json['rich_text_nodes'] != null
        ? json['rich_text_nodes']
            .map<RichTextNodeItem>((e) => RichTextNodeItem.fromJson(e))
            .toList()
        : [];
    text = json['text'];
  }
}

//
class DynamicMajorModel {
  DynamicMajorModel({
    this.archive,
    this.draw,
    this.ugcSeason,
    this.opus,
    this.pgc,
    this.liveRcmd,
    this.live,
    this.none,
    this.type,
    this.courses,
    this.common,
    this.music,
  });

  DynamicArchiveModel? archive;
  DynamicDrawModel? draw;
  DynamicArchiveModel? ugcSeason;
  DynamicOpusModel? opus;
  DynamicArchiveModel? pgc;
  DynamicLiveModel? liveRcmd;
  DynamicLive2Model? live;
  DynamicNoneModel? none;
  // MAJOR_TYPE_DRAW 图片
  // MAJOR_TYPE_ARCHIVE 视频
  // MAJOR_TYPE_OPUS 图文/文章
  String? type;
  Map? courses;
  Map? common;
  Map? music;

  DynamicMajorModel.fromJson(Map<String, dynamic> json) {
    T? parsePart<T>(String key, T Function(Map<String, dynamic>) parser) {
      final raw = json[key];
      if (raw is! Map) return null;
      try {
        return parser(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }

    archive = parsePart('archive', DynamicArchiveModel.fromJson);
    draw = parsePart('draw', DynamicDrawModel.fromJson);
    ugcSeason = parsePart('ugc_season', DynamicArchiveModel.fromJson);
    opus = parsePart('opus', DynamicOpusModel.fromJson);
    pgc = parsePart('pgc', DynamicArchiveModel.fromJson);
    liveRcmd = parsePart('live_rcmd', DynamicLiveModel.fromJson);
    live = parsePart('live', DynamicLive2Model.fromJson);
    none = parsePart('none', DynamicNoneModel.fromJson);
    type = json['type']?.toString();
    courses = json['courses'] is Map ? json['courses'] : <String, dynamic>{};
    common = json['common'] is Map ? json['common'] : <String, dynamic>{};
    music = json['music'] is Map ? json['music'] : <String, dynamic>{};
  }
}

class DynamicTopicModel {
  DynamicTopicModel({
    this.id,
    this.jumpUrl,
    this.name,
  });

  int? id;
  String? jumpUrl;
  String? name;

  DynamicTopicModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jumpUrl = json['jump_url'];
    name = json['name'];
  }
}

class DynamicArchiveModel {
  DynamicArchiveModel({
    this.aid,
    this.badge,
    this.bvid,
    this.cover,
    this.desc,
    this.disablePreview,
    this.durationText,
    this.jumpUrl,
    this.stat,
    this.title,
    this.type,
    this.epid,
    this.seasonId,
  });

  int? aid;
  Map? badge;
  String? bvid;
  String? cover;
  String? desc;
  int? disablePreview;
  String? durationText;
  String? jumpUrl;
  Stat? stat;
  String? title;
  int? type;
  int? epid;
  int? seasonId;

  DynamicArchiveModel.fromJson(Map<String, dynamic> json) {
    // Web 动态接口会把 aid 等数字字段返回为字符串，不能先强转 num。
    aid = _intValue(json['aid']);
    badge = json['badge'] is Map ? Map.from(json['badge'] as Map) : null;
    bvid = json['bvid']?.toString() ?? json['epid']?.toString() ?? '';
    cover = json['cover']?.toString() ?? '';
    disablePreview = _intValue(json['disable_preview']);
    durationText = json['duration_text']?.toString() ?? '';
    jumpUrl = json['jump_url']?.toString() ?? '';
    stat = json['stat'] is Map
        ? Stat.fromJson(Map<String, dynamic>.from(json['stat'] as Map))
        : Stat.fromJson(const <String, dynamic>{});
    title = json['title']?.toString() ?? '';
    type = _intValue(json['type']);
    epid = _intValue(json['epid']);
    seasonId = _intValue(json['season_id']);
  }
}

class DynamicDrawModel {
  DynamicDrawModel({
    this.id,
    this.items,
  });

  int? id;
  List<DynamicDrawItemModel>? items;

  DynamicDrawModel.fromJson(Map<String, dynamic> json) {
    id = _intValue(json['id']);
    // ignore: prefer_null_aware_operators
    final rawItems = json['items'];
    items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => DynamicDrawItemModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DynamicDrawItemModel>[];
  }
}

class DynamicOpusModel {
  DynamicOpusModel({
    this.jumpUrl,
    this.pics,
    this.summary,
    this.title,
  });

  String? jumpUrl;
  List<OpusPicsModel>? pics;
  SummaryModel? summary;
  String? title;
  DynamicOpusModel.fromJson(Map<String, dynamic> json) {
    jumpUrl = json['jump_url'];
    final rawPics = json['pics'];
    pics = rawPics is List
        ? rawPics
            .whereType<Map>()
            .map((e) => OpusPicsModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OpusPicsModel>[];
    summary =
        json['summary'] != null ? SummaryModel.fromJson(json['summary']) : null;
    title = json['title'];
  }
}

class SummaryModel {
  SummaryModel({
    this.richTextNodes,
    this.text,
  });

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  SummaryModel.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['rich_text_nodes'];
    richTextNodes = rawNodes is List
        ? rawNodes
            .whereType<Map>()
            .map((e) => RichTextNodeItem.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <RichTextNodeItem>[];
    text = json['text']?.toString() ?? '';
  }
}

class RichTextNodeItem {
  RichTextNodeItem({
    this.emoji,
    this.origText,
    this.text,
    this.type,
    this.rid,
  });
  Emoji? emoji;
  String? origText;
  String? text;
  String? type;
  String? rid;

  RichTextNodeItem.fromJson(Map<String, dynamic> json) {
    emoji = json['emoji'] != null ? Emoji.fromJson(json['emoji']) : null;
    origText = json['orig_text'];
    text = json['text'];
    type = json['type'];
    rid = json['rid'];
  }
}

class Emoji {
  Emoji({
    this.iconUrl,
    this.size,
    this.text,
    this.type,
  });

  String? iconUrl;
  double? size;
  String? text;
  int? type;
  Emoji.fromJson(Map<String, dynamic> json) {
    iconUrl = json['icon_url'];
    size = _doubleValue(json['size']) ?? 1;
    text = json['text'];
    type = json['type'];
  }
}

class DynamicNoneModel {
  DynamicNoneModel({
    this.tips,
  });
  String? tips;
  DynamicNoneModel.fromJson(Map<String, dynamic> json) {
    tips = json['tips'];
  }
}

class OpusPicsModel {
  OpusPicsModel({
    this.width,
    this.height,
    this.size,
    this.src,
    this.url,
  });

  int? width;
  int? height;
  int? size;
  String? src;
  String? url;

  OpusPicsModel.fromJson(Map<String, dynamic> json) {
    width = _intValue(json['width']);
    height = _intValue(json['height']);
    size = _intValue(json['size']) ?? 0;
    src = json['src'];
    url = json['url'];
  }
}

class DynamicDrawItemModel {
  DynamicDrawItemModel({
    this.height,
    this.size,
    this.src,
    this.tags,
    this.width,
  });
  int? height;
  int? size;
  String? src;
  List? tags;
  int? width;
  DynamicDrawItemModel.fromJson(Map<String, dynamic> json) {
    height = _intValue(json['height']);
    size = _intValue(json['size']) ?? 0;
    src = json['src'];
    tags = json['tags'];
    width = _intValue(json['width']);
  }
}

class DynamicLiveModel {
  DynamicLiveModel({
    this.content,
  });

  String? content;
  int? type;
  Map? livePlayInfo;
  int? uid;
  String? parentAreaName;
  int? roomId;
  String? liveId;
  int? liveStatus;
  String? cover;
  int? online;
  String? areaName;
  String? title;
  int? liveStartTime;
  Map? watchedShow;

  DynamicLiveModel.fromJson(Map<String, dynamic> json) {
    content = json['content'];
    if (json['content'] != null) {
      Map<String, dynamic> data = jsonDecode(json['content']);

      type = data['type'];
      Map livePlayInfo = data['live_play_info'];
      uid = livePlayInfo['uid'];
      parentAreaName = livePlayInfo['parent_area_name'];
      roomId = livePlayInfo['room_id'];
      liveId = livePlayInfo['live_id'];
      liveStatus = livePlayInfo['live_status'];
      cover = livePlayInfo['cover'];
      online = livePlayInfo['online'];
      areaName = livePlayInfo['area_name'];
      title = livePlayInfo['title'];
      liveStartTime = livePlayInfo['live_start_time'];
      watchedShow = livePlayInfo['watched_show'];
    }
  }
}

class DynamicLive2Model {
  DynamicLive2Model({
    this.badge,
    this.cover,
    this.descFirst,
    this.descSecond,
    this.id,
    this.jumpUrl,
    this.liveState,
    this.reserveType,
    this.title,
  });

  Map? badge;
  String? cover;
  String? descFirst;
  String? descSecond;
  int? id;
  String? jumpUrl;
  int? liveState;
  int? reserveType;
  String? title;

  DynamicLive2Model.fromJson(Map<String, dynamic> json) {
    badge = json['badge'];
    cover = json['cover'];
    descFirst = json['desc_first'];
    descSecond = json['desc_second'];
    id = json['id'];
    jumpUrl = json['jump_url'];
    liveState = json['liv_state'];
    reserveType = json['reserve_type'];
    title = json['title'];
  }
}

// 动态状态 转发、评论、点赞
class ModuleStatModel {
  ModuleStatModel({
    this.comment,
    this.forward,
    this.like,
  });

  Comment? comment;
  ForWard? forward;
  Like? like;

  ModuleStatModel.fromJson(Map<String, dynamic> json) {
    comment = json['comment'] is Map
        ? Comment.fromJson(Map<String, dynamic>.from(json['comment']))
        : Comment(count: null, forbidden: false);
    forward = json['forward'] is Map
        ? ForWard.fromJson(Map<String, dynamic>.from(json['forward']))
        : ForWard(count: null, forbidden: false);
    like = json['like'] is Map
        ? Like.fromJson(Map<String, dynamic>.from(json['like']))
        : Like(count: null, forbidden: false, status: false);
  }
}

// 动态状态 评论
class Comment {
  Comment({
    this.count,
    this.forbidden,
  });

  String? count;
  bool? forbidden;

  Comment.fromJson(Map<String, dynamic> json) {
    count = json['count'] == 0 ? null : json['count'].toString();
    forbidden = json['forbidden'] == true || json['forbidden'] == 1;
  }
}

class ForWard {
  ForWard({this.count, this.forbidden});
  String? count;
  bool? forbidden;

  ForWard.fromJson(Map<String, dynamic> json) {
    count = json['count'] == 0 ? null : json['count'].toString();
    forbidden = json['forbidden'] == true || json['forbidden'] == 1;
  }
}

// 动态状态 点赞
class Like {
  Like({
    this.count,
    this.forbidden,
    this.status,
  });

  String? count;
  bool? forbidden;
  bool? status;

  Like.fromJson(Map<String, dynamic> json) {
    count = json['count'] == 0 ? null : json['count'].toString();
    forbidden = json['forbidden'] == true || json['forbidden'] == 1;
    status = json['status'] == true || json['status'] == 1;
  }
}

class Stat {
  Stat({
    this.danmaku,
    this.play,
  });

  String? danmaku;
  String? play;

  Stat.fromJson(Map<String, dynamic> json) {
    danmaku = json['danmaku']?.toString() ?? '0';
    play = json['play']?.toString() ?? '0';
  }
}
