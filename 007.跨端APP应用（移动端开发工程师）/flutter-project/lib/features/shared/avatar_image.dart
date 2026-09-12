// ponytail: 2026-09-12 — 头像 Image 抽象三种输入格式:
//          1) HTTP(S) URL(http/https://...)  → Image.network
//          2) data URI(data:image/...;base64,xxx)  → 取逗号后 base64Decode
//          3) 纯 base64(/9j/... 开头)              → 直接 base64Decode
//
// 后端 /api/auth/me 实际返的是纯 base64(UsersService.toDto 透传 u.getAvatar(),
//         从来没在 UserDTO 这层包过 data: 前缀),所以单认 src.startsWith('data:')
//         会漏掉 3),误把 "/9j/4AAQSk..." 当 URL 喂给 Image.network → 加载失败
//         → errorBuilder 兜底显示昵称首字母(用户在 profile_edit / settings
//         用户卡片看到的"小")。
//
// 改成:含 :// 或以 http 开头 → URL,否则一律 base64Decode。data URI 自动兼容
//      (逗号前是 mime type 描述,base64Decode 跳过取逗号后那段就行)。
import 'dart:convert';

import 'package:flutter/material.dart';

/// 头像 Image:支持 HTTP(S) URL + data URI + 纯 base64(后端 /me 实际返纯 base64)。
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

  /// 只有"含 :// 协议头"或"以 http 开头"才视为 URL。data URI 的"data:" 不算
  /// (只有 1 个冒号,没有 //);data:foo;base64,xxx 落到 base64 分支,逗号前是
  /// mime type 描述,base64Decode 取逗号后那段就行,跟纯 base64 一致。
  bool get _isUrl => src.contains('://') || src.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isUrl) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
    // 走 base64 分支(data URI 或纯 base64 都进这里):
    //  - data URI 格式 "data:image/jpeg;base64,/9j/4AAQSk..." → 取逗号后那段
    //  - 纯 base64 "/9j/4AAQSk..." → 整段就是 payload
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
}