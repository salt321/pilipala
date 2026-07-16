import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/user/fav_detail.dart';
import 'package:pilipala/pages/fav_detail/widget/playlist_editor.dart';
import 'package:pilipala/utils/global_data_cache.dart';

void main() {
  setUp(() => GlobalDataCache().imgQuality = 10);

  testWidgets('收藏夹播放队列可选择起点、移除并恢复', (tester) async {
    final items = <FavDetailItemData>[
      FavDetailItemData(id: 1, title: '视频一', pic: ''),
      FavDetailItemData(id: 2, title: '视频二', pic: ''),
      FavDetailItemData(id: 3, title: '视频三', pic: ''),
    ];
    int? playedIndex;
    List<FavDetailItemData>? playedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistEditorSheet(
            items: items,
            onPlay: (index, queue) async {
              playedIndex = index;
              playedItems = queue;
            },
          ),
        ),
      ),
    );

    expect(find.text('播放队列 · 3'), findsOneWidget);
    await tester.tap(find.text('视频二'));
    await tester.pump();
    expect(find.text('从第 2 项播放'), findsOneWidget);

    await tester.tap(find.byTooltip('从队列移除').first);
    await tester.pump();
    expect(find.text('播放队列 · 2'), findsOneWidget);
    expect(find.text('从第 1 项播放'), findsOneWidget);

    await tester.tap(find.text('恢复顺序'));
    await tester.pump();
    expect(find.text('播放队列 · 3'), findsOneWidget);

    await tester.tap(find.text('从第 1 项播放'));
    await tester.pump();
    expect(playedIndex, 0);
    expect(playedItems?.map((item) => item.id), <int?>[1, 2, 3]);
  });
}
