// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../utils/storage.dart';

class ApiInterceptor extends Interceptor {
  ApiInterceptor({required Dio dio}) : _dio = dio;

  static const int maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _reconnectTimeout = Duration(seconds: 5);
  static const String _retryCountKey = 'api_retry_count';

  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // print("请求之前");
    // 在请求之前添加头部或认证信息
    // options.headers['Authorization'] = 'Bearer token';
    // options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      if (response.statusCode == 302) {
        final List<String> locations = response.headers['location']!;
        if (locations.isNotEmpty) {
          if (locations.first.startsWith('https://www.mcbbs.net')) {
            final Uri uri = Uri.parse(locations.first);
            final String? accessKey = uri.queryParameters['access_key'];
            final String? mid = uri.queryParameters['mid'];
            try {
              Box localCache = GStrorage.localCache;
              localCache.put(LocalCacheKey.accessKey,
                  <String, String?>{'mid': mid, 'value': accessKey});
            } catch (_) {}
          }
        }
      }
    } catch (err) {
      print('ApiInterceptor: $err');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final int retryCount =
        err.requestOptions.extra[_retryCountKey] as int? ?? 0;
    _logNetworkError(err, retryCount);

    if (!_canRetry(err, retryCount)) {
      handler.next(err);
      return;
    }

    if (!await _waitForConnection()) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_retryDelay);
    err.requestOptions.extra[_retryCountKey] = retryCount + 1;

    try {
      handler.resolve(await _retryRequest(err.requestOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _canRetry(DioException error, int retryCount) {
    final String method = error.requestOptions.method.toUpperCase();
    final bool isSafeMethod = method == 'GET' || method == 'HEAD';
    final bool isRetryableError = switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.unknown =>
        true,
      _ => false,
    };
    return isSafeMethod && isRetryableError && retryCount < maxRetries;
  }

  Future<bool> _waitForConnection() async {
    final Connectivity connectivity = Connectivity();
    final List<ConnectivityResult> current =
        await connectivity.checkConnectivity();
    if (!_isDisconnected(current)) {
      return true;
    }

    final Completer<bool> completer = Completer<bool>();
    StreamSubscription<List<ConnectivityResult>>? subscription;
    Timer? timeoutTimer;

    Future<void> finish(bool connected) async {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(connected);
      timeoutTimer?.cancel();
      await subscription?.cancel();
    }

    subscription = connectivity.onConnectivityChanged.listen((results) {
      if (!_isDisconnected(results)) {
        finish(true);
      }
    });
    timeoutTimer = Timer(_reconnectTimeout, () => finish(false));
    return completer.future;
  }

  bool _isDisconnected(List<ConnectivityResult> results) {
    return results.isEmpty ||
        (results.length == 1 && results.contains(ConnectivityResult.none));
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) {
    return _dio.fetch<dynamic>(options);
  }

  void _logNetworkError(DioException error, int retryCount) {
    log(
      'HTTP ${error.requestOptions.method} ${error.requestOptions.uri} '
      'failed: type=${error.type.name}, retry=$retryCount/$maxRetries, '
      'message=${error.message}, cause=${error.error}',
      name: 'ApiInterceptor',
    );
  }

  static Future<String> dioError(DioException error) async {
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return '证书有误！';
      case DioExceptionType.badResponse:
        return '服务器异常，请稍后重试！';
      case DioExceptionType.cancel:
        return '请求已被取消，请重新请求';
      case DioExceptionType.connectionError:
        return '连接错误，请检查网络设置';
      case DioExceptionType.connectionTimeout:
        return '网络连接超时，请检查网络设置';
      case DioExceptionType.receiveTimeout:
        return '响应超时，请稍后重试！';
      case DioExceptionType.sendTimeout:
        return '发送请求超时，请检查网络设置';
      case DioExceptionType.unknown:
        final List<ConnectivityResult> connectivityResult =
            await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          return '未连接到网络，请检查网络设置';
        }
        final String? detail = error.message?.trim();
        if (detail != null && detail.isNotEmpty) {
          return '网络请求异常：$detail';
        }
        return '网络请求异常，请稍后重试';
    }
  }
}
