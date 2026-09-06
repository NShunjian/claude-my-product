/// 异常类 — 对齐 api/http.ts 的 ApiError(code/message/status)
class ApiException implements Exception {
  ApiException(this.code, this.message, this.status);

  final dynamic code;
  final String message;
  final int status;

  @override
  String toString() => 'ApiException(code=$code, status=$status, message=$message)';
}

/// 业务码 1401 = token 失效,与 uniapp 端保持一致
const int authInvalidCode = 1401;
