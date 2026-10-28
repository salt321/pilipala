import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/services/offline_playlist_service.dart';

import 'offline_playlist_editor_test.dart' as editor;

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('playlist-transaction-');
    file = File('${directory.path}/playlists.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  test('空操作不写盘，读取结果不能反向修改已提交状态', () async {
    var writes = 0;
    final service = OfflinePlaylistService.forTesting(file,
        replaceFile: (temporary, target) async {
      writes++;
      await temporary.rename(target);
    });
    await service.create(name: '原名', cacheKeys: ['a']);
    await service.delete('missing');
    await service.removeCacheKey('missing');
    expect(writes, 1);
    final result = (await service.listPlaylists()).single;
    expect(() => result.cacheKeys.add('bad'), throwsUnsupportedError);
    expect((await service.listPlaylists()).single.cacheKeys, ['a']);
  });

  test('替换失败保留磁盘、内存与通知；下一次任务仍可成功', () async {
    var fail = false;
    final service = OfflinePlaylistService.forTesting(file,
        replaceFile: (temporary, target) async {
      if (fail) throw const FileSystemException('injected replacement failure');
      await temporary.rename(target);
    });
    final playlist = await service.create(name: '原名', cacheKeys: ['a']);
    final original = await file.readAsString();
    final revision = service.revision.value;
    fail = true;
    await expectLater(service.update(id: playlist.id, name: '失败修改'),
        throwsA(isA<FileSystemException>()));
    expect(await file.readAsString(), original);
    expect((await service.listPlaylists()).single.name, '原名');
    expect(service.revision.value, revision);
    fail = false;
    await service.update(id: playlist.id, name: '成功修改');
    expect((await service.listPlaylists()).single.name, '成功修改');
    expect(service.revision.value, revision + 1);
    expect(
        (await OfflinePlaylistService.forTesting(file).listPlaylists())
            .single
            .name,
        '成功修改');
  });

  test('临时文件写入失败不丢旧文件且可重试', () async {
    final service = OfflinePlaylistService.forTesting(file);
    final playlist = await service.create(name: '原名', cacheKeys: ['a']);
    final old = await file.readAsString();
    final blocker = await Directory('${file.path}.tmp').create();
    await expectLater(
        service.delete(playlist.id), throwsA(isA<FileSystemException>()));
    expect(await file.readAsString(), old);
    expect((await service.listPlaylists()).length, 1);
    await blocker.delete();
    await service.delete(playlist.id);
    expect(await service.listPlaylists(), isEmpty);
  });

  test('创建失败不会留下幽灵项目或重试重复项', () async {
    final service = OfflinePlaylistService.forTesting(file);
    final blocker = await Directory('${file.path}.tmp').create();
    await expectLater(service.create(name: '创建', cacheKeys: ['a']),
        throwsA(isA<FileSystemException>()));
    expect(await service.listPlaylists(), isEmpty);
    await blocker.delete();
    await service.create(name: '创建', cacheKeys: ['a']);
    expect((await service.listPlaylists()).length, 1);
  });

  test('整个修改串行化，读取不提前暴露未落盘状态', () async {
    Completer<void>? gate;
    final service = OfflinePlaylistService.forTesting(file,
        replaceFile: (temporary, target) async {
      if (gate != null) await gate.future;
      await temporary.rename(target);
    });
    final playlist = await service.create(name: '原名', cacheKeys: ['a', 'b']);
    gate = Completer<void>();
    final rename = service.update(id: playlist.id, name: '新名');
    final mode =
        service.update(id: playlist.id, playMode: OfflinePlayMode.shuffle);
    final remove = service.removeCacheKey('a');
    expect((await service.listPlaylists()).single.name, '原名');
    gate.complete();
    await Future.wait([rename, mode, remove]);
    final result = (await service.listPlaylists()).single;
    expect(result.name, '新名');
    expect(result.playMode, OfflinePlayMode.shuffle);
    expect(result.cacheKeys, ['b']);
    expect((jsonDecode(await file.readAsString()) as List).single['cacheKeys'],
        ['b']);
  });

  test('排队任务在前一个失败后使用最后成功状态', () async {
    var writes = 0;
    final service = OfflinePlaylistService.forTesting(file,
        replaceFile: (temporary, target) async {
      if (++writes == 2) throw const FileSystemException('injected');
      await temporary.rename(target);
    });
    final playlist = await service.create(name: '原名', cacheKeys: ['a']);
    final failure = expectLater(service.update(id: playlist.id, name: '失败名'),
        throwsA(isA<FileSystemException>()));
    final following =
        service.update(id: playlist.id, playMode: OfflinePlayMode.listRepeat);
    await Future.wait([failure, following]);
    final result = (await service.listPlaylists()).single;
    expect(result.name, '原名');
    expect(result.playMode, OfflinePlayMode.listRepeat);
  });

  test('损坏文件不被覆盖，修复后初始化可以重试', () async {
    await file.writeAsString('not json');
    final service = OfflinePlaylistService.forTesting(file);
    await expectLater(
        service.create(name: '新建', cacheKeys: []), throwsFormatException);
    expect(await file.readAsString(), 'not json');
    await file.writeAsString('[]');
    await service.create(name: '新建', cacheKeys: []);
    expect((await service.listPlaylists()).length, 1);
  });

  testWidgets('失败后重试成功才更新界面', (tester) async {
    var calls = 0;
    await editor.openEditor(tester, (_) async {
      if (++calls == 1) throw const FileSystemException('disk full');
    });
    await tester.tap(find.byTooltip('从列表移除').first);
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('取消失败修改不重试且恢复编辑能力', (tester) async {
    var calls = 0;
    await editor.openEditor(tester, (_) async {
      calls++;
      throw const FileSystemException('disk full');
    });
    await tester.tap(find.byTooltip('从列表移除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.byTooltip('从列表移除').first);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
}
