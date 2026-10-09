import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/live/item.dart';
import 'package:pilipala/pages/live/widgets/live_item.dart';
import 'package:pilipala/utils/global_data_cache.dart';

void main() {
  test('直播模型兼容字符串 room_id 和缺失的展示字段', () {
    final LiveItemModel item = LiveItemModel.fromJson(
      <String, dynamic>{'room_id': '123'},
    );

    expect(item.roomId, 123);
    expect(item.title, '未命名直播');
    expect(item.uname, '未知主播');
    expect(item.areaName, '未知分区');
    expect(item.cover, isEmpty);
    expect(item.watchedShow, isEmpty);
  });

  testWidgets('直播卡片缺少可选字段时仍可渲染', (tester) async {
    GlobalDataCache().imgQuality = 10;
    final LiveItemModel item = LiveItemModel(roomId: 123);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 320,
              child: LiveCardV(liveItem: item, crossAxisCount: 2),
            ),
          ),
        ),
      ),
    );

    expect(find.text('未命名直播'), findsOneWidget);
    expect(find.text('未知主播'), findsOneWidget);
    expect(find.text('未知分区'), findsOneWidget);
    expect(find.text('观看人数未知'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
