import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:pilipala/utils/global_data_cache.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    GlobalDataCache().imgQuality = 10;
  });

  testWidgets('新版 Opus 动态可在用户动态页安全渲染', (tester) async {
    final item = DynamicItemModel.fromJson(<String, dynamic>{
      'id_str': '1063487284684259332',
      'type': 'DYNAMIC_TYPE_DRAW',
      'modules': <String, dynamic>{
        'module_author': <String, dynamic>{
          'mid': 42,
          'name': '测试用户',
          'face': '',
          'pub_time': '刚刚',
          'pub_ts': 1746450829,
          'vip': <String, dynamic>{'status': null},
        },
        'module_dynamic': <String, dynamic>{
          'desc': null,
          'major': <String, dynamic>{
            'type': 'MAJOR_TYPE_OPUS',
            'opus': <String, dynamic>{
              'title': null,
              'pics': <dynamic>[
                <String, dynamic>{
                  'width': 100,
                  'height': 100,
                  'size': 1,
                  'url': 'https://example.com/1.jpg',
                },
                <String, dynamic>{
                  'width': 100,
                  'height': 100,
                  'size': 1,
                  'url': 'https://example.com/2.jpg',
                },
              ],
              'summary': <String, dynamic>{
                'text': '这是一条新版动态',
                'rich_text_nodes': null,
              },
            },
          },
        },
        'module_stat': <String, dynamic>{
          'comment': <String, dynamic>{'count': 0},
          'forward': <String, dynamic>{'count': 0},
          'like': <String, dynamic>{'count': 1, 'status': false},
        },
      },
    });

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicPanel(
              item: item,
              source: 'member',
              openDetailOnTap: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('这是一条新版动态'), findsOneWidget);
    expect(find.byType(NetworkImgLayer), findsNWidgets(2));
    expect(find.text('DRAW'), findsNothing);
  });

  testWidgets('视频动态在统一渲染器中显示视频卡片', (tester) async {
    final item = DynamicItemModel.fromJson(<String, dynamic>{
      'id_str': '3',
      'type': 'DYNAMIC_TYPE_AV',
      'modules': <String, dynamic>{
        'module_author': <String, dynamic>{
          'mid': 42,
          'name': '视频作者',
          'face': '',
        },
        'module_dynamic': <String, dynamic>{
          'major': <String, dynamic>{
            'type': 'MAJOR_TYPE_ARCHIVE',
            'archive': <String, dynamic>{
              // 真实 Web 动态 API 将 aid 返回为字符串。
              'aid': '170001',
              'bvid': 'BV1xx411c7mD',
              'title': '动态中的视频',
              'cover': '',
              'duration_text': '01:23',
              'stat': <String, dynamic>{'play': 1234, 'danmaku': 56},
            },
          },
        },
      },
    });

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicPanel(
              item: item,
              source: 'member',
              openDetailOnTap: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('动态中的视频'), findsOneWidget);
    expect(find.text('1234次围观'), findsOneWidget);
    expect(find.text('56条弹幕'), findsOneWidget);
    expect(item.modules!.moduleDynamic!.major!.archive!.aid, 170001);
    final videoCover = tester
        .widgetList<NetworkImgLayer>(
          find.byType(NetworkImgLayer),
        )
        .firstWhere((image) => image.width > 200);
    expect(videoCover.width, 360);
  });

  testWidgets('派生视频在统一渲染器中显示 UGC 卡片', (tester) async {
    final item = DynamicItemModel.fromJson(<String, dynamic>{
      'id_str': '4',
      'type': 'DYNAMIC_TYPE_WORD',
      'modules': <String, dynamic>{
        'module_author': <String, dynamic>{
          'mid': 42,
          'name': '派生视频作者',
          'face': '',
        },
        'module_dynamic': <String, dynamic>{
          'additional': <String, dynamic>{
            'type': 'ADDITIONAL_TYPE_UGC',
            'ugc': <String, dynamic>{
              'title': '动态引用的视频',
              'cover': '',
              'desc_second': '视频简介',
              'duration': 123,
              'id_str': 456,
              'multi_line': 1,
              'jump_url': 'https://www.bilibili.com/video/BV1xx411c7mD',
            },
          },
        },
      },
    });

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicPanel(
              item: item,
              source: 'member',
              openDetailOnTap: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('动态引用的视频'), findsOneWidget);
    expect(find.text('视频简介'), findsOneWidget);
  });
}
