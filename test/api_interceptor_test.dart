import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/http/interceptor.dart';

class _SequencedAdapter implements HttpClientAdapter {
  _SequencedAdapter({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (requestCount <= failuresBeforeSuccess) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated connection failure',
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') {
        return <String>['wifi'];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  test('GET 连接失败后会自动重试并成功', () async {
    final Dio dio = Dio();
    final _SequencedAdapter adapter =
        _SequencedAdapter(failuresBeforeSuccess: 2);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ApiInterceptor(dio: dio));

    final Response<dynamic> response = await dio.get('https://example.test');

    expect(response.statusCode, 200);
    expect(response.data, <String, dynamic>{'ok': true});
    expect(adapter.requestCount, 3);
  });

  test('POST 连接失败不会自动重试', () async {
    final Dio dio = Dio();
    final _SequencedAdapter adapter =
        _SequencedAdapter(failuresBeforeSuccess: 1);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ApiInterceptor(dio: dio));

    await expectLater(
      dio.post<dynamic>('https://example.test'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requestCount, 1);
  });

  test('GET 最多重试五次', () async {
    final Dio dio = Dio();
    final _SequencedAdapter adapter =
        _SequencedAdapter(failuresBeforeSuccess: 10);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ApiInterceptor(dio: dio));

    await expectLater(
      dio.get<dynamic>('https://example.test'),
      throwsA(isA<DioException>()),
    );
    expect(ApiInterceptor.maxRetries, 5);
    expect(adapter.requestCount, 6);
  });
}
