package com.qingzhang.common;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * 图表撞色重映射(同色差异化)。
 *
 * 对齐跨端实现:
 *   - 003 React src/lib/chart-color.ts
 *   - 007 Flutter lib/core/utils/chart_color.dart
 *   - 007 uniapp components/DonutChart.vue (inline)
 *
 * 算法:
 *   1) 同色按出现顺序:第 1 个保持原色,第 2 个 +L,第 3 个 -L,第 4 个 +2L ...
 *      奇偶交错 +L/-L,避免全往一边偏。
 *   2) 两套策略 — 按 S 分支:
 *      - **彩色**(S ≥ 0.30):调 L ±20% 阶梯,clamp 到 [0.3, 0.7],保留色相。
 *      - **灰/低饱和**(S < 0.30,含 #A0AEC0 这种擦边灰):加饱和 + 偏色相 +
 *        L 锁中段 ±10%,让肉眼能区分。
 *
 * 用法:在 report API 把同一图表里出现的多个分类 color 过一次这个函数,
 * 返回的列表与原列表顺序一致,可直接替换原 color 字段返回给前端,
 * 这样 4 端(React / Flutter / uniapp / Admin)拉同一份数据都看到一致色。
 */
public final class ChartColors {

    /** 灰/低饱和判定阈值(S < 此值走灰策略)。 */
    private static final double SAT_THRESHOLD = 0.30;

    /** 调亮/调暗封顶,避免 0.89 这种"太浅"或 0.10 这种"太暗"。 */
    private static final double L_MIN = 0.30;
    private static final double L_MAX = 0.70;

    /** 灰系 L 锁中段 ±10%。 */
    private static final double GRAY_L_CENTER = 0.50;
    private static final double GRAY_L_OFFSET = 0.08;

    private static final double STEP = 0.20;

    /** idx → 偏色相的色相池(蓝/暖橙/紫/绿/红/紫蓝/青)。 */
    private static final double[] HUE_POOL = {220, 30, 290, 140, 10, 260, 180};

    private ChartColors() {}

    /**
     * 输入一组 hex 颜色,返回去重后的同长度数组。
     * - 非 hex 格式 / null / blank 原样保留。
     * - 空数组返回空数组。
     * - 单元素返回单元素(浅拷贝)。
     *
     * 撞色识别分两层:
     *   1) **完全相同 hex** — 走 hex 索引,按出现顺序差异化
     *   2) **低饱和度撞色**(S < SAT_THRESHOLD,如 #A0AEC0 / #718096 这种擦边灰):
     *      跨不同 hex 也算撞色 — 因为肉眼看不出区别,必须拉开来。
     *      用 grayCount 跨 hex 累计,让第二个灰起就被改色。
     *
     * idx 决定怎么 remap:
     *   - 完全相同 hex → 用 hexCount(第 1 个 0、第 2 个 1、第 3 个 2 …)
     *   - 跨 hex 但都是低饱和 → 用 grayCount - 1(同上 0-indexed)
     *   - 首次出现且彩色 → 保持原色
     */
    public static String[] deduplicate(String[] colors) {
        if (colors == null || colors.length <= 1) {
            return colors == null ? new String[0] : colors.clone();
        }
        Map<String, Integer> hexIndex = new LinkedHashMap<>();
        int grayCount = 0;  // 累计低饱和度颜色出现次数
        String[] out = new String[colors.length];
        for (int i = 0; i < colors.length; i++) {
            String c = colors[i];
            if (c == null) {
                out[i] = null;
                continue;
            }
            String key = c.trim().toUpperCase(Locale.ROOT);
            Integer hexCount = hexIndex.get(key);
            if (hexCount == null) hexCount = 0;
            hexIndex.put(key, hexCount + 1);

            int[] rgb = hexToRgb(c);
            if (rgb == null) {
                out[i] = c;  // 非 hex 不动
                continue;
            }
            double[] hsl = rgbToHsl(rgb[0], rgb[1], rgb[2]);
            boolean isGray = hsl[1] < SAT_THRESHOLD;

            int idx;
            if (hexCount > 0) {
                idx = hexCount;
            } else if (isGray) {
                grayCount++;
                idx = grayCount - 1;  // 1st gray idx=0, 2nd gray idx=1, ...
            } else {
                idx = 0;  // 首次 + 彩色,保持原色
            }

            out[i] = (idx == 0) ? c : remap(c, hsl, idx);
        }
        return out;
    }

    /**
     * 给定原始颜色 + HSL + idx,返回差异化后的 hex。
     * idx=1 是第 1 次撞色,idx=2 是第 2 次,以此类推。
     */
    private static String remap(String original, double[] hsl, int idx) {
        double magnitude = Math.ceil(idx / 2.0) * STEP;
        int direction = (idx % 2 == 1) ? 1 : -1;
        double newH = hsl[0];
        double newS = hsl[1];
        double newL = clamp(hsl[2] + direction * magnitude, L_MIN, L_MAX);

        if (hsl[1] < SAT_THRESHOLD) {
            // 灰/低饱和:加饱和 + 偏色相 + L 锁中段
            newS = Math.min(0.7, 0.55 + magnitude * 0.3);
            newH = HUE_POOL[(idx - 1) % HUE_POOL.length];
            newL = clamp(GRAY_L_CENTER + direction * GRAY_L_OFFSET, 0.35, 0.65);
        }

        int[] outRgb = hslToRgb(newH, newS, newL);
        return rgbToHex(outRgb[0], outRgb[1], outRgb[2]);
    }

    /** 列表版糖。 */
    public static List<String> deduplicate(List<String> colors) {
        if (colors == null) return new ArrayList<>();
        String[] arr = colors.toArray(new String[0]);
        String[] out = deduplicate(arr);
        return new ArrayList<>(List.of(out));
    }

    // ===== 颜色转换工具 =====

    /** '#RRGGBB' → {r,g,b} 0..255。失败返回 null。 */
    private static int[] hexToRgb(String hex) {
        if (hex == null) return null;
        String s = hex.trim();
        if (s.startsWith("#")) s = s.substring(1);
        if (s.length() != 6) return null;
        try {
            int r = Integer.parseInt(s.substring(0, 2), 16);
            int g = Integer.parseInt(s.substring(2, 4), 16);
            int b = Integer.parseInt(s.substring(4, 6), 16);
            return new int[]{r, g, b};
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String rgbToHex(int r, int g, int b) {
        return String.format("#%02X%02X%02X", clamp255(r), clamp255(g), clamp255(b));
    }

    /** 0..255 RGB → HSL。返回 [h:0..360, s:0..1, l:0..1]。 */
    private static double[] rgbToHsl(int r, int g, int b) {
        double rn = r / 255.0, gn = g / 255.0, bn = b / 255.0;
        double max = Math.max(rn, Math.max(gn, bn));
        double min = Math.min(rn, Math.min(gn, bn));
        double l = (max + min) / 2.0;
        double h = 0, s = 0;
        if (max != min) {
            double d = max - min;
            s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
            if (max == rn) {
                h = ((gn - bn) / d + (gn < bn ? 6 : 0)) * 60;
            } else if (max == gn) {
                h = ((bn - rn) / d + 2) * 60;
            } else {
                h = ((rn - gn) / d + 4) * 60;
            }
        }
        return new double[]{h, s, l};
    }

    /** HSL → 0..255 RGB。 */
    private static int[] hslToRgb(double h, double s, double l) {
        double c = (1 - Math.abs(2 * l - 1)) * s;
        double hp = h / 60.0;
        double x = c * (1 - Math.abs((hp % 2) - 1));
        double r1 = 0, g1 = 0, b1 = 0;
        if (hp >= 0 && hp < 1) { r1 = c; g1 = x; }
        else if (hp < 2) { r1 = x; g1 = c; }
        else if (hp < 3) { g1 = c; b1 = x; }
        else if (hp < 4) { g1 = x; b1 = c; }
        else if (hp < 5) { r1 = x; b1 = c; }
        else { r1 = c; b1 = x; }
        double m = l - c / 2.0;
        return new int[]{
                (int) Math.round((r1 + m) * 255),
                (int) Math.round((g1 + m) * 255),
                (int) Math.round((b1 + m) * 255)
        };
    }

    private static double clamp(double v, double min, double max) {
        return Math.max(min, Math.min(max, v));
    }

    private static int clamp255(int v) {
        return Math.max(0, Math.min(255, v));
    }
}
