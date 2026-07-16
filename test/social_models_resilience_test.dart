import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/models/fans/result.dart';
import 'package:pilipala/models/member/article.dart';
import 'package:pilipala/models/member/seasons.dart';
import 'package:pilipala/models/user/fav_folder.dart';

void main() {
  test('粉丝响应缺少列表时返回空列表', () {
    final FansDataModel model = FansDataModel.fromJson(<String, dynamic>{
      'total': '0',
      'list': null,
    });

    expect(model.total, 0);
    expect(model.list, isEmpty);
  });

  test('动态响应跳过结构异常的单条卡片', () {
    final DynamicsDataModel model =
        DynamicsDataModel.fromJson(<String, dynamic>{
      'has_more': false,
      'offset': '',
      'items': <dynamic>[
        <String, dynamic>{'type': 'UNKNOWN', 'modules': null},
        <String, dynamic>{
          'id_str': '1',
          'type': 'DYNAMIC_TYPE_WORD',
          'modules': <String, dynamic>{
            'module_author': <String, dynamic>{
              'mid': 1,
              'name': 'tester',
              'face': '',
              'pub_time': '',
              'pub_action': '',
            },
            'module_dynamic': <String, dynamic>{},
          },
        },
      ],
    });

    expect(model.items, hasLength(1));
    expect(model.items!.single.idStr, '1');
    expect(model.rawItemCount, 2);
    expect(model.skippedItemCount, 1);
  });

  test('动态可选模块字段变化时保留基础卡片', () {
    final model = DynamicsDataModel.fromJson(<String, dynamic>{
      'items': <dynamic>[
        <String, dynamic>{
          'id_str': '2',
          'type': 'DYNAMIC_TYPE_DRAW',
          'modules': <String, dynamic>{
            'module_author': <String, dynamic>{
              'mid': '42',
              'name': 'tester',
              'pub_ts': '1746450829',
            },
            'module_dynamic': <String, dynamic>{
              'major': <String, dynamic>{
                'type': 'MAJOR_TYPE_OPUS',
                'opus': <String, dynamic>{
                  'pics': <dynamic>[],
                  'summary': <String, dynamic>{'rich_text_nodes': null},
                },
              },
            },
            'module_stat': <String, dynamic>{'like': null},
          },
        },
      ],
    });

    expect(model.items, hasLength(1));
    expect(model.items!.single.modules!.moduleAuthor!.mid, 42);
    expect(model.items!.single.modules!.moduleAuthor!.pubTs, 1746450829);
  });

  test('视频动态的数字统计字段不会导致 archive 被丢弃', () {
    final item = DynamicItemModel.fromJson(<String, dynamic>{
      'id_str': '3',
      'type': 'DYNAMIC_TYPE_AV',
      'modules': <String, dynamic>{
        'module_author': <String, dynamic>{'mid': 1, 'name': 'tester'},
        'module_dynamic': <String, dynamic>{
          'major': <String, dynamic>{
            'type': 'MAJOR_TYPE_ARCHIVE',
            'archive': <String, dynamic>{
              'aid': '170001',
              'bvid': 'BV1xx411c7mD',
              'title': '测试视频',
              'cover': '',
              'stat': <String, dynamic>{'play': 1234, 'danmaku': 56},
            },
          },
        },
      },
    });

    final archive = item.modules?.moduleDynamic?.major?.archive;
    expect(archive, isNotNull);
    expect(archive!.stat!.play, '1234');
    expect(archive.stat!.danmaku, '56');
  });

  test('派生视频的 additional UGC 字段可兼容数字类型', () {
    final item = DynamicItemModel.fromJson(<String, dynamic>{
      'id_str': '4',
      'type': 'DYNAMIC_TYPE_WORD',
      'modules': <String, dynamic>{
        'module_author': <String, dynamic>{'mid': 1, 'name': 'tester'},
        'module_dynamic': <String, dynamic>{
          'additional': <String, dynamic>{
            'type': 'ADDITIONAL_TYPE_UGC',
            'ugc': <String, dynamic>{
              'title': '派生视频',
              'cover': '',
              'duration': 123,
              'id_str': 456,
              'multi_line': 1,
              'jump_url': 'https://www.bilibili.com/video/BV1xx411c7mD',
            },
          },
        },
      },
    });

    final ugc = item.modules?.moduleDynamic?.additional?.ugc;
    expect(ugc, isNotNull);
    expect(ugc!.duration, '123');
    expect(ugc.idStr, '456');
    expect(ugc.multiLine, isTrue);
  });

  test('收藏、专栏和合集缺少可选字段时仍可解析为空列表', () {
    final favorite = FavFolderData.fromJson(const <String, dynamic>{});
    final articles = MemberArticleDataModel.fromJson(
      const <String, dynamic>{'items': null},
    );
    final collections = MemberSeasonsDataModel.fromJson(
      const <String, dynamic>{
        'seasons_list': null,
        'series_list': null,
      },
    );

    expect(favorite.list, isEmpty);
    expect(favorite.hasMore, isFalse);
    expect(articles.items, isEmpty);
    expect(articles.hasMore, isFalse);
    expect(collections.seasonsList, isEmpty);
  });

  test('合集视频缺少 stat 时使用安全默认值', () {
    final collection = MemberSeasonsList.fromJson(<String, dynamic>{
      'meta': <String, dynamic>{'name': '测试合集'},
      'archives': <dynamic>[
        <String, dynamic>{'aid': 1, 'title': '测试视频'},
      ],
    });

    expect(collection.archives, hasLength(1));
    expect(collection.archives!.single.view, 0);
  });
}
