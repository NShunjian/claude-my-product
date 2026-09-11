import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 图表撞色重映射(对齐 003 React lib/chart-color.ts):
/// 同一图表内出现 ≥2 个 hex 相同的扇区时,挨个调亮/调暗 ±20% L 阶梯,
/// 同色按出现顺序:第 1 个不动,第 2 个 +20%,第 3 个 -20%,第 4 个 +40% …
/// Flutter 这层用 Color 对象,内部转 0xAARRGGBB int 处理。

/// 把 Color 转成 '#RRGGBB'(hex)。Color.toARGB32() 返回 32-bit int。
String colorToHex(Color c) {
  // 0xAARRGGBB → 只取 RRGGBB
  final argb = c.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  String h(int n) => n.toRadixString(16).padLeft(2, '0');
  return '#${h(r)}${h(g)}${h(b)}';
}

Color hexToColor(String hex) {
  final m = RegExp(r'^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$',
          caseSensitive: false)
      .firstMatch(hex.trim());
  if (m == null) return const Color(0xFF000000);
  final r = int.parse(m.group(1)!, radix: 16);
  final g = int.parse(m.group(2)!, radix: 16);
  final b = int.parse(m.group(3)!, radix: 16);
  return Color.fromARGB(255, r, g, b);
}

/// 0..255 RGB → HSL。L 范围 [0,1]
({double h, double s, double l}) rgbToHsl(int r, int g, int b) {
  final rn = r / 255, gn = g / 255, bn = b / 255;
  final maxV = math.max(rn, math.max(gn, bn));
  final minV = math.min(rn, math.min(gn, bn));
  final l = (maxV + minV) / 2;
  double h = 0, s = 0;
  if (maxV != minV) {
    final d = maxV - minV;
    s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    if (maxV == rn) {
      h = ((gn - bn) / d + (gn < bn ? 6 : 0)) * 60;
    } else if (maxV == gn) {
      h = ((bn - rn) / d + 2) * 60;
    } else {
      h = ((rn - gn) / d + 4) * 60;
    }
  }
  return (h: h, s: s, l: l);
}

({int r, int g, int b}) hslToRgb(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final hp = h / 60;
  final x = c * (1 - ((hp % 2) - 1).abs());
  double r = 0, g = 0, b = 0;
  if (hp >= 0 && hp < 1) {
    r = c;
    g = x;
  } else if (hp < 2) {
    r = x;
    g = c;
  } else if (hp < 3) {
    g = c;
    b = x;
  } else if (hp < 4) {
    g = x;
    b = c;
  } else if (hp < 5) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  final m = l - c / 2;
  return (
    r: ((r + m) * 255).round(),
    g: ((g + m) * 255).round(),
    b: ((b + m) * 255).round(),
  );
}

/// 给定一组 Color,挨个调整同色 Color 的亮度。
/// 返回新 List,顺序不变;color 不合法(非 hex 对应纯色)原样保留。
///
/// 两套策略(对齐 003 React lib/chart-color.ts):
/// - **彩色**(S ≥ 0.30):调 L ±20% 阶梯,封顶 [0.3, 0.7],保留色相。
/// - **灰/低饱和**(S < 0.30,含 #A0AEC0 这种擦边灰):加饱和 + 偏色相 + L 锁中段 ±10%。
List<Color> deduplicateColors(List<Color> colors) {
  if (colors.length <= 1) return List.of(colors);
  final sameIdx = <String, int>{};
  final out = <Color>[];
  for (final c in colors) {
    final key = colorToHex(c).toUpperCase();
    final idx = sameIdx[key] ?? 0;
    sameIdx[key] = idx + 1;
    if (idx == 0) {
      out.add(c);
      continue;
    }
    final argb = c.toARGB32();
    final alpha = ((argb >> 24) & 0xFF) == 0 ? 255 : (argb >> 24) & 0xFF;
    final hsl = rgbToHsl((argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF, argb & 0xFF);
    const step = 0.2;
    final magnitude = ((idx + 1) ~/ 2) * step;
    final direction = idx.isOdd ? 1 : -1;
    var newH = hsl.h;
    var newS = hsl.s;
    // 调亮/调暗封顶 [0.3, 0.7],避免 0.89 这种"太浅"或 0.10"太暗"
    var newL = (hsl.l + direction * magnitude).clamp(0.3, 0.7);
    if (hsl.s < 0.3) {
      newS = (0.55 + magnitude * 0.3).clamp(0.0, 0.7);
      const huePool = [220.0, 30.0, 290.0, 140.0, 10.0, 260.0, 180.0];
      newH = huePool[(idx - 1) % huePool.length];
      // 灰系锁中段 ±10%,L = 0.5 ± 0.08 锁 [0.35, 0.65]
      newL = (0.5 + direction * 0.08).clamp(0.35, 0.65);
    }
    final rgb = hslToRgb(newH, newS, newL);
    out.add(Color.fromARGB(
      alpha,
      rgb.r.clamp(0, 255),
      rgb.g.clamp(0, 255),
      rgb.b.clamp(0, 255),
    ));
  }
  return out;
}
