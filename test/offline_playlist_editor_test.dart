import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/pages/offline_media/playlist_editor.dart';

OfflineMediaItem media(String key) => OfflineMediaItem.fromJson({
      'cacheKey': key,
      'title': key,
    });

Future<void> openEditor(
  WidgetTester tester,
  Future<void> Function(List<OfflineMediaItem>) onSave, {
  OfflinePlayMode mode = OfflinePlayMode.sequential,
  Future<void> Function(OfflinePlayMode)? onModeChanged,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OfflinePlaylistEditorSheet(
        playlist: OfflinePlaylist.fromJson({'id': 'test', 'name': '测试列表'})
            .copyWith(playMode: mode),
        items: [media('A'), media('B')],
        availableItems: [media('A'), media('B'), media('C')],
        onSave: onSave,
        onPlay: (_, __, ___) {},
        onModeChanged: onModeChanged ?? (_) async {},
      ),
    ),
  ));
}

Future<void> selectAll(WidgetTester tester, String action) async {
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
  await tester.tap(find.text('全选结果'));
  await tester.pump();
  await tester.tap(find.text('确认选择'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('播放模式自动保存并在重新打开时显示', (tester) async {
    var saved = OfflinePlayMode.sequential;
    await openEditor(tester, (_) async {}, onModeChanged: (mode) async {
      saved = mode;
    });
    await tester.tap(find.byType(DropdownButton<OfflinePlayMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('随机播放').last);
    await tester.pumpAndSettle();
    expect(saved, OfflinePlayMode.shuffle);
    await tester.pumpWidget(const SizedBox());
    await openEditor(tester, (_) async {}, mode: saved);
    expect(
        tester
            .widget<DropdownButton<OfflinePlayMode>>(
                find.byType(DropdownButton<OfflinePlayMode>))
            .value,
        saved);
  });

  testWidgets('模式保存失败不显示成功状态', (tester) async {
    await openEditor(tester, (_) async {}, onModeChanged: (_) async {
      throw StateError('write failed');
    });
    await tester.tap(find.byType(DropdownButton<OfflinePlayMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('列表循环').last);
    await tester.pumpAndSettle();
    expect(find.text('播放模式保存失败，请重新打开列表检查'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButton<OfflinePlayMode>>(
                find.byType(DropdownButton<OfflinePlayMode>))
            .value,
        OfflinePlayMode.sequential);
  });
  testWidgets('添加后自动保存且不关闭编辑器', (tester) async {
    List<String>? saved;
    await openEditor(tester, (items) async {
      saved = items.map((e) => e.cacheKey).toList();
    });
    expect(find.text('保存修改'), findsNothing);
    expect(find.text('批量添加'), findsNothing);
    await selectAll(tester, '添加');
    expect(saved, ['A', 'B', 'C']);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('测试列表'), findsOneWidget);
  });

  testWidgets('多项删除必须确认，取消不保存', (tester) async {
    var saves = 0;
    await openEditor(tester, (_) async {
      saves++;
    });
    await selectAll(tester, '删除');
    expect(find.text('删除 2 个列表项目？'), findsOneWidget);
    expect(saves, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(saves, 0);
    await selectAll(tester, '删除');
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('播放列表为空'), findsOneWidget);
  });

  testWidgets('单项移除和排序分别自动保存', (tester) async {
    final snapshots = <List<String>>[];
    await openEditor(tester, (items) async {
      snapshots.add(items.map((e) => e.cacheKey).toList());
    });
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder(0, 2);
    await tester.pumpAndSettle();
    expect(snapshots.last, ['B', 'A']);
    await tester.tap(find.byTooltip('从列表移除').first);
    await tester.pumpAndSettle();
    expect(snapshots.last, ['A']);
    expect(snapshots.length, 2);
  });

  testWidgets('保存期间禁止重复修改，失败显示提示并保留可见列表', (tester) async {
    final pending = Completer<void>();
    var saves = 0;
    await openEditor(tester, (_) {
      saves++;
      return pending.future;
    });
    final reorder = tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder;
    reorder(0, 2);
    reorder(0, 2);
    await tester.pump();
    expect(saves, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(StateError('write failed'));
    await tester.pumpAndSettle();
    expect(find.text('自动保存失败，请重新打开列表检查'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
