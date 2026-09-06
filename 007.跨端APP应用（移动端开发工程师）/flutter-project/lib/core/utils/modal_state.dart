import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 对齐 utils/modal-state.ts — modalOpen 的全局布尔。
/// AppHeader 监听它来隐藏自身(对齐 uniapp 中 iOS WKWebView sticky 元素的 z-index workaround)。
/// Flutter 不存在该 bug,但保留同一接口保持逻辑一致。
final modalOpenProvider = StateProvider<bool>((_) => false);
