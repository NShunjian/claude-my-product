package com.qingzhang.users;

/**
 * ponytail: 2026-09-12 — 头像字段的 data URI 包裹/解包工具。
 *
 * 设计动机:DB 里 users.avatar 始终存 plain base64(无 data: 前缀),
 *          因为 MEDIUMTEXT 列搜索/索引/日志都不该被前缀污染。
 *
 *          但前端(/me 之类)拿到的应该是浏览器 / Image.network /
 *          <image src> 标签直接认的 data URI,每个客户端不用各自
 *          拼前缀。Flutter mobile / uniapp 小程序 / 未来的 web 端
 *          都能直接渲染。
 *
 * 用法:
 *   - 服务层 toDto:  return AvatarUri.toDataUri(u.getAvatar())
 *   - 入参校验/落库: 把 req.avatar() 用 AvatarUri.stripPrefix()
 *     剥成 plain base64 再 setAvatar
 *
 * 幂等:已经是 data: 开头的输入,toDataUri / stripPrefix 都不会
 *      二次包装 / 二次剥,避免出现 "data:image/jpeg;base64,data:..."
 *      这种半截前缀污染。
 *
 * MIME 假设 JPEG:目前 mobile 端 flutter_image_compress 已经强制
 * 重编 JPEG 上传,uniapp 同样走 JPEG;若以后接入 PNG 上传,把
 * JPEG_DATA_PREFIX 换成探测 magic bytes 的逻辑即可,接口签名不变。
 */
public final class AvatarUri {

    private static final String JPEG_DATA_PREFIX = "data:image/jpeg;base64,";

    private AvatarUri() {}

    /** 出参:DB 存的 plain base64 → wire 上的 data URI。null 透传。 */
    public static String toDataUri(String raw) {
        if (raw == null) return null;
        if (raw.startsWith("data:")) return raw;
        return JPEG_DATA_PREFIX + raw;
    }

    /** 入参:wire 上的 data URI / plain base64 → 存库的 plain base64。null 透传。 */
    public static String stripPrefix(String raw) {
        if (raw == null) return null;
        int commaIdx = raw.indexOf(',');
        if (raw.startsWith("data:") && commaIdx >= 0) {
            return raw.substring(commaIdx + 1);
        }
        return raw;
    }
}