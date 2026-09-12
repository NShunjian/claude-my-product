// ponytail: 2026-09-12 — 后端 /api/auth/me 返回的 avatar 是
//          data:image/jpeg;base64,... data URI。Flutter Image.network
//          在 mobile (dart:io HttpClient) 不能解析 data: scheme → 抛
//          FormatException → errorBuilder 兜底显示首字母。Web 上
//          XMLHttpRequest 自动支持 data URI 所以 web 端正常显示。
//
// 这里抽公共 widget:检测 `data:` 前缀,用 Image.memory(base64Decode)
// 渲染;否则走 Image.network。两端一致。
import 'dart:convert';

import 'package:flutter/material.dart';

/// 头像 Image:支持 HTTP(S) URL + base64 data URI(后端 /me 实际返的是 data URI)。
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// 加载失败时显示的 widget(不是 string),跟 Image 的 errorBuilder 签名一致。
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  bool get _isDataUri => src.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    if (_isDataUri) {
      // ponytail: 容忍 data URI 格式有 ;base64, / ;charset= 等变化,只取逗号后。
      final commaIdx = src.indexOf(',');
      final b64 = commaIdx >= 0 ? src.substring(commaIdx + 1) : src;
      try {
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      } catch (_) {
        // base64 解码失败(后端传了非法 base64),兜底交 errorBuilder。
        if (errorBuilder != null) {
          return errorBuilder!(context, 'base64 decode failed', StackTrace.current);
        }
        return const SizedBox.shrink();
      }
    }
    return Image.network(
      src,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}
