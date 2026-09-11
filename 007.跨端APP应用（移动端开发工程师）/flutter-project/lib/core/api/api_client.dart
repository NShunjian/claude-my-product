import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/prefs.dart';
import 'api_exception.dart';

typedef AuthInvalidListener = void Function();

/// 对齐 uniapp 的 request<T>() + ApiError + 1401 监听 + runSilent + navGrace。
/// 用 Dart dart:io / flutter foundation 的 navigator state 处理 navGrace 的实现
/// 改用一个时间窗口(浏览器刷新 / 后退时由调用方 markNavigation 触发)。
class ApiClient {
  ApiClient({required this.baseUrl, required this.prefs}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  final String baseUrl;
  final Prefs prefs;

  late final Dio _dio;
  Dio get dio => _dio;

  // ===== 1401 监听器 =====
  final Set<AuthInvalidListener> _authInvalidListeners = {};
  void onAuthInvalid(AuthInvalidListener fn) {
    _authInvalidListeners.add(fn);
  }

  void offAuthInvalid(AuthInvalidListener fn) {
    _authInvalidListeners.remove(fn);
  }

  // ===== runSilent / navGrace =====
  bool _suppressAuthInvalid = false;
  DateTime _navGraceUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// H5 刷新 / history.back() 时调用 — 之后 3 秒内的 1401 不踢人。
  void markNavigation() {
    _navGraceUntil = DateTime.now().add(const Duration(seconds: 3));
  }

  /// 初始化阶段用 — 包住 auth.me() / book.reload() 等首次被动加载。
  Future<T> runSilent<T>(Future<T> Function() fn) async {
    final prev = _suppressAuthInvalid;
    _suppressAuthInvalid = true;
    try {
      return await fn();
    } finally {
      _suppressAuthInvalid = prev;
    }
  }

  // ===== 拦截器实现 =====
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.data != null && options.headers['Content-Type'] == null) {
      options.headers['Content-Type'] = 'application/json';
    }
    final token = prefs.token;
    if (token != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    final Map<String, dynamic> env =
        data is Map<String, dynamic> ? data : <String, dynamic>{};
    final code = env['code'] ?? 'INTERNAL';
    final message = env['message']?.toString() ?? 'HTTP ${response.statusCode}';
    final status = response.statusCode ?? 0;

    // ponytail: 任意 HTTP 401 也踢回登录,不只信 1401 —— 后端 UserAuthInterceptor
    //          tokenVersion 不一致返 code=1401 是正常路径,但中间件 / 网关
    //          / 包体非 Map / code 字段意外为空等边界 case 都会让 1401 检测失效,
    //          用户卡在 tab 页看到裸 Dio 错误但没人踢他。兜底改成"401 OR 1401"。
    if ((code == authInvalidCode || status == 401) &&
        !_suppressAuthInvalid &&
        DateTime.now().isAfter(_navGraceUntil)) {
      for (final fn in _authInvalidListeners.toList()) {
        try {
          fn();
        } catch (_) {}
      }
    }

    if (status < 200 || status >= 300 || code != 0) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: ApiException(code, message, status),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.next(response);
  }

  void _onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }

  // ===== 业务方法 =====
  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );
      // 后端 envelope: { code, message, data },已在外层 _onResponse 校验 code==0。
      final env = res.data ?? <String, dynamic>{};
      return env['data'] as T;
    } on DioException catch (e) {
      final inner = e.error;
      // ponytail: 兜底兜底再兜底 —— 不管 DioException.error 是不是 ApiException,
      //          只要 status==401 就当 token 失效:fire listener 让 router 踢登录,
      //          再抛出去让 UI 收到错误(下次进 tab 会自然到 login 页)。
      //          这覆盖了"包体非 Map / code 字段意外为空 / Dio 5.x 内部把
      //          DioException.error 二次封装"等所有 _onResponse 监听器漏踢的边界。
      final status = e.response?.statusCode ?? 0;
      if (status == 401 &&
          !_suppressAuthInvalid &&
          DateTime.now().isAfter(_navGraceUntil)) {
        for (final fn in _authInvalidListeners.toList()) {
          try {
            fn();
          } catch (_) {}
        }
      }
      if (inner is ApiException) throw inner;
      throw ApiException(
        'NETWORK',
        e.message ?? 'Network error',
        status,
      );
    }
  }

  Future<T> get<T>(String path, {Map<String, String>? query}) =>
      request<T>(path, method: 'GET', queryParameters: query);

  Future<T> post<T>(String path, {Object? data}) =>
      request<T>(path, method: 'POST', data: data);

  Future<T> patch<T>(String path, {Object? data}) =>
      request<T>(path, method: 'PATCH', data: data);

  Future<T> delete<T>(String path, {Object? data}) =>
      request<T>(path, method: 'DELETE', data: data);
}
