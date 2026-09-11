package com.qingzhang.common;

import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChartColors 算法对齐跨端:003 React src/lib/chart-color.ts + 007 Flutter chart_color.dart
 * + 007 uniapp DonutChart.vue。
 */
class ChartColorsTest {

    @Test
    void emptyAndSingle_returnAsIs() {
        assertEquals(0, ChartColors.deduplicate((String[]) null).length);
        assertEquals(0, ChartColors.deduplicate(new String[0]).length);
        String[] single = new String[]{"#FF0000"};
        String[] out = ChartColors.deduplicate(single);
        assertArrayEquals(new String[]{"#FF0000"}, out);
        // 单元素应返回新数组(避免外部修改污染)
        assertNotSame(single, out);
    }

    @Test
    void firstOccurrence_keepsOriginal_sameColor_collides() {
        String[] in = {"#888888", "#888888", "#888888"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#888888", out[0]); // 第 1 个不动
        assertNotEquals("#888888", out[1]); // 后续差异化
        assertNotEquals("#888888", out[2]);
        assertNotEquals(out[1], out[2]); // 互相也不同
    }

    @Test
    void differentColorsInInput_stayUntouched() {
        String[] in = {"#FF0000", "#00FF00", "#0000FF"};
        String[] out = ChartColors.deduplicate(in);
        assertArrayEquals(in, out);
    }

    @Test
    void caseInsensitive_collisionDetected() {
        String[] in = {"#888888", "#888888"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#888888", out[0]);
        assertNotEquals(out[0].toUpperCase(), out[1].toUpperCase());
    }

    @Test
    void nonHexColors_passThroughUnchanged() {
        String[] in = {"red", "red"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("red", out[0]);
        assertEquals("red", out[1]); // 解析失败,不动
    }

    @Test
    void grayColors_injectSaturationAndHueShift() {
        // #A0AEC0 S≈0.20 L≈0.69 — 走灰策略
        String[] in = {"#A0AEC0", "#A0AEC0"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#A0AEC0", out[0]);
        // 第 2 个必须变成有饱和度的色(灰通道不全接近)
        assertFalse(isMonochrome(out[1]), "灰系 dedup 后不该还是 monochrome: " + out[1]);
    }

    @Test
    void colorfulColors_brightDarkAlternation_keepsBlueFamily() {
        // #4299E1(蓝 S≈0.83 L≈0.61)— 走调 L 阶梯,保留色相
        String[] in = {"#4299E1", "#4299E1", "#4299E1"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#4299E1", out[0]);
        // B 通道 > R 通道(idx=1 调亮 + idx=2 调暗 都还是蓝色家族)
        assertTrue(blueDominant(out[1]), out[1] + " should be blue-dominant");
        assertTrue(blueDominant(out[2]), out[2] + " should be blue-dominant");
    }

    @Test
    void listOverload_matchesArrayOverload() {
        List<String> in = Arrays.asList("#888888", "#888888");
        List<String> out = ChartColors.deduplicate(in);
        assertEquals(2, out.size());
        assertEquals("#888888", out.get(0));
        assertNotEquals("#888888", out.get(1));
    }

    @Test
    void veryDarkColors_clampL_soOutputIsHex() {
        String[] in = new String[10];
        Arrays.fill(in, "#000000");
        String[] out = ChartColors.deduplicate(in);
        for (String s : out) {
            assertNotNull(s);
            assertTrue(s.matches("^#[0-9A-F]{6}$"), "malformed hex: " + s);
        }
    }

    @Test
    void userCaseExpenseReport_sameGrayA0AEC0_dedupesVisibly() {
        // 用户实测场景:月报里有多个 "#A0AEC0"(旧默认色),撞色后彼此不同
        String[] in = {"#FF0000", "#A0AEC0", "#A0AEC0", "#00FF00", "#A0AEC0"};
        String[] out = ChartColors.deduplicate(in);
        // 第 1 个保持
        assertEquals("#FF0000", out[0]);
        // 后两个不同
        Set<String> uniq = new HashSet<>();
        for (String s : out) uniq.add(s.toUpperCase());
        assertEquals(5, uniq.size(), "所有 5 个输出应当各不相同");
    }

    @Test
    void crossHexGrayCollision_dedupesRegardlessOfHex() {
        // 用户实测场景:Flutter 月报收入占比里
        //   其他 = #A0AEC0 (preset S=0.20)
        //   13   = #718096 (preset 通讯色 S=0.14)
        // 两个 hex 不同但都是低饱和度灰,肉眼看不出区别 → 必须 dedup
        String[] in = {"#4299E1", "#38A169", "#A0AEC0", "#718096", "#805AD5", "#E53E3E"};
        String[] out = ChartColors.deduplicate(in);
        // 1st gray (#A0AEC0) 保持
        assertEquals("#A0AEC0", out[2]);
        // 2nd gray (#718096) 必须被改色 — 走 gray 策略 → 中段饱和蓝
        assertNotEquals("#718096", out[3]);
        assertFalse(isMonochrome(out[3]), "2nd gray dedup 后不该还是 monochrome: " + out[3]);
        // 6 个输出全部不同(用户截图场景)
        Set<String> uniq = new HashSet<>();
        for (String s : out) uniq.add(s.toUpperCase());
        assertEquals(6, uniq.size(), "6 个颜色应当各不相同");
    }

    @Test
    void firstGrayStaysGray_evenWhenLaterGraysAreDeduped() {
        // 第 1 个灰保持原色(避免误改用户选的灰色)
        String[] in = {"#A0AEC0", "#718096", "#94A3B8"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#A0AEC0", out[0]);
        assertNotEquals("#718096", out[1]);
        assertNotEquals("#94A3B8", out[2]);
    }

    @Test
    void mixedGrayAndColorful_grayStillDedups() {
        // 灰穿插在彩色中:跨整个数组的灰都应该被 dedup
        String[] in = {"#A0AEC0", "#4299E1", "#718096", "#38A169", "#94A3B8"};
        String[] out = ChartColors.deduplicate(in);
        assertEquals("#A0AEC0", out[0]); // 1st gray
        assertEquals("#4299E1", out[1]); // colorful 不动
        assertNotEquals("#718096", out[2]); // 2nd gray 被改
        assertEquals("#38A169", out[3]); // colorful 不动
        assertNotEquals("#94A3B8", out[4]); // 3rd gray 被改
    }

    private static boolean isMonochrome(String hex) {
        int r = Integer.parseInt(hex.substring(1, 3), 16);
        int g = Integer.parseInt(hex.substring(3, 5), 16);
        int b = Integer.parseInt(hex.substring(5, 7), 16);
        return Math.max(r, Math.max(g, b)) - Math.min(r, Math.min(g, b)) < 8;
    }

    private static boolean blueDominant(String hex) {
        int r = Integer.parseInt(hex.substring(1, 3), 16);
        int b = Integer.parseInt(hex.substring(5, 7), 16);
        return b > r;
    }
}
