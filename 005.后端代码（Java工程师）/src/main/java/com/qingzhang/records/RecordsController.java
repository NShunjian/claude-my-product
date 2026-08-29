package com.qingzhang.records;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.records.dto.CreateRecordRequest;
import com.qingzhang.records.dto.RecordResponse;
import com.qingzhang.records.dto.UpdateRecordRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 *   GET    /api/records[?month|from|to|type|categoryId|accountId]    -> {items:[Record]}
 *   POST   /api/records                                              -> {record:Record}
 *   PATCH  /api/records/{uuid}                                       -> {record:Record}
 *   DELETE /api/records/{uuid}                                       -> {ok:true}
 *
 * spec §6.3:列表 + CRUD;filter 不可解析 → 1000。
 */
@RestController
@RequestMapping("/api/records")
public class RecordsController {

    private final RecordsService service;

    public RecordsController(RecordsService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Map<String, Object>> list(HttpServletRequest req,
                                                 @RequestParam(required = false) String month,
                                                 @RequestParam(required = false) String from,
                                                 @RequestParam(required = false) String to,
                                                 @RequestParam(required = false) String type,
                                                 @RequestParam(required = false) String categoryId,
                                                 @RequestParam(required = false) String accountId,
                                                 @RequestParam(required = false) String bookId) {
        long userId = userId(req);
        if (type != null && !type.equals("expense") && !type.equals("income") && !type.equals("transfer")) {
            throw new BizException(ErrorCode.VALIDATION_FAILED, "type 必须是 expense / income / transfer");
        }
        Map<String, String> filters = new HashMap<>();
        filters.put("month",      month);
        filters.put("from",       from);
        filters.put("to",         to);
        filters.put("type",       type);
        filters.put("categoryId", categoryId);
        filters.put("accountId",  accountId);
        filters.put("bookId",     bookId);
        List<RecordResponse> items = service.list(userId, filters);
        return ApiResponse.ok(Map.of("items", items));
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> create(HttpServletRequest req,
                                                   @Valid @RequestBody CreateRecordRequest body) {
        long userId = userId(req);
        RecordResponse r = service.create(userId, body);
        return ApiResponse.ok(Map.of("record", r));
    }

    @PatchMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> update(HttpServletRequest req,
                                                   @PathVariable String uuid,
                                                   @Valid @RequestBody UpdateRecordRequest body) {
        long userId = userId(req);
        RecordResponse r = service.update(userId, uuid, body);
        return ApiResponse.ok(Map.of("record", r));
    }

    @DeleteMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> delete(HttpServletRequest req,
                                                   @PathVariable String uuid) {
        long userId = userId(req);
        service.delete(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        return id;
    }
}