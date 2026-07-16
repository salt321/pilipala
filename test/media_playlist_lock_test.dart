import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/pages/video/detail/widgets/watch_later_list.dart';

void main() {
  testWidgets('播放列表顶部可以切换自定义队列锁', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaListPanel(
            sheetHeight: 500,
            mediaList: const [],
            panelTitle: '测试收藏夹',
            playlistLocked: true,
            onPlaylistLockChanged: () => toggleCount++,
          ),
        ),
      ),
    );

    expect(find.text('自动播放：当前队列'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.tap(find.byTooltip('解锁并使用视频原始列表'));
    await tester.pump();

    expect(toggleCount, 1);
    expect(find.text('自动播放：视频原始列表'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });
}
