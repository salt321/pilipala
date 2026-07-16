class FansDataModel {
  FansDataModel({
    this.total,
    this.list,
  });

  int? total;
  List<FansItemModel>? list;

  FansDataModel.fromJson(Map<String, dynamic> json) {
    total = json['total'] is int
        ? json['total']
        : int.tryParse(json['total']?.toString() ?? '') ?? 0;
    final dynamic rawList = json['list'];
    list = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => FansItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <FansItemModel>[];
  }
}

class FansItemModel {
  FansItemModel({
    this.mid,
    this.attribute,
    this.mtime,
    this.tag,
    this.special,
    this.uname,
    this.face,
    this.sign,
    this.officialVerify,
  });

  int? mid;
  int? attribute;
  int? mtime;
  List? tag;
  int? special;
  String? uname;
  String? face;
  String? sign;
  Map? officialVerify;

  FansItemModel.fromJson(Map<String, dynamic> json) {
    mid = json['mid'] is int
        ? json['mid']
        : int.tryParse(json['mid']?.toString() ?? '');
    attribute = json['attribute'];
    mtime = json['mtime'];
    tag = json['tag'];
    special = json['special'];
    uname = json['uname']?.toString() ?? '未知用户';
    face = json['face']?.toString() ?? '';
    sign = json['sign'] == null || json['sign'].toString().isEmpty
        ? '还没有签名'
        : json['sign'].toString();
    officialVerify = json['official_verify'];
  }
}
