import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/video/later.dart';
import 'package:pilipala/pages/video/detail/widgets/watch_later_list.dart';
import 'package:pilipala/utils/global_data_cache.dart';

void main() {
  testWidgets('播放列表顶部可以切换自定义队列锁', (tester) async {
    var toggleCount = 0;
    var progressToggleCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaListPanel(
            sheetHeight: 500,
            mediaList: <MediaVideoItemModel>[].obs,
            activeBvid: 'BV1test'.obs,
            panelTitle: '测试收藏夹',
            playlistLocked: true,
            onPlaylistLockChanged: () => toggleCount++,
            onResumeProgressChanged: () => progressToggleCount++,
          ),
        ),
      ),
    );

    expect(find.text('自动播放：当前队列'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    final ListView virtualList = tester.widget<ListView>(find.byType(ListView));
    final SliverChildBuilderDelegate delegate =
        virtualList.childrenDelegate as SliverChildBuilderDelegate;
    expect(virtualList.itemExtent, 104);
    expect(virtualList.cacheExtent, 208);
    expect(delegate.addAutomaticKeepAlives, isFalse);

    await tester.tap(find.byTooltip('切换视频时继承历史进度'));
    await tester.pump();

    expect(progressToggleCount, 1);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byTooltip('切换视频时从头播放'), findsOneWidget);

    await tester.tap(find.byTooltip('解锁并使用视频原始列表'));
    await tester.pump();

    expect(toggleCount, 1);
    expect(find.text('自动播放：视频原始列表'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('自动切换视频后播放列表当前项高亮会刷新', (tester) async {
    GlobalDataCache().imgQuality = 10;
    final activeBvid = 'BV-current'.obs;
    final mediaList = <MediaVideoItemModel>[
      MediaVideoItemModel(
        id: 1,
        bvid: 'BV-current',
        title: '当前视频',
        cover: '',
        duration: 60,
        upper: Upper(name: 'UP主'),
        cntInfo: {'play': 1, 'danmaku': 0},
      ),
    ].obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaListPanel(
            sheetHeight: 500,
            mediaList: mediaList,
            activeBvid: activeBvid,
          ),
        ),
      ),
    );

    Text title = tester.widget<Text>(find.text('当前视频'));
    expect(title.style?.color, isNotNull);

    activeBvid.value = 'BV-next';
    await tester.pump();

    title = tester.widget<Text>(find.text('当前视频'));
    expect(title.style?.color, isNull);
  });

  testWidgets('一万条播放队列只构建可见范围', (tester) async {
    GlobalDataCache().imgQuality = 10;
    final mediaList = List<MediaVideoItemModel>.generate(
      10000,
      (index) => MediaVideoItemModel(
        id: index,
        bvid: 'BV$index',
        title: '视频$index',
        cover: '',
        duration: 60,
        upper: Upper(name: 'UP主'),
        cntInfo: {'play': 1, 'danmaku': 0},
      ),
    ).obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaListPanel(
            sheetHeight: 500,
            mediaList: mediaList,
            activeBvid: 'BV0'.obs,
          ),
        ),
      ),
    );

    final int builtItems = find.byType(InkWell).evaluate().length;
    expect(builtItems, greaterThan(0));
    expect(builtItems, lessThan(20));
    expect(find.text('视频9999'), findsNothing);
  });
}
