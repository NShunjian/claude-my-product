package com.qingzhang.accounts;

import com.qingzhang.accounts.dto.AccountResponse;
import com.qingzhang.accounts.dto.CreateAccountRequest;
import com.qingzhang.accounts.dto.UpdateAccountRequest;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
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

import java.util.List;
import java.util.Map;

/**
 *   GET    /api/accounts                       -> {items:[Account]}
 *   POST   /api/accounts                       -> {account}
 *   GET    /api/accounts/{uuid}                -> {account}
 *   PATCH  /api/accounts/{uuid}                -> {account}
 *   DELETE /api/accounts/{uuid}                -> {ok:true}
 *   POST   /api/accounts/{uuid}/archive        -> {ok:true}    归档(隐藏,数据保留)
 *   DELETE /api/accounts/{uuid}/archive        -> {ok:true}    取消归档
 *
 * 余额取自 v_account_balance 视图,响应字段对应前端 src/api/accounts.ts 的 Account。
 *
 * includeArchived 默认 false(隐藏已归档);前端账户列表 filter chip 切到"全部"
 * 时传 true,后端返回包含 archived=1 的账户。
 *
 * 归档与软删的区别:
 *   - archived:is_archived=1,records 仍生效,current_balance 仍计入总资产
 *   - deleted: deleted_at 非空,UI 不可见,records 仍计入报表(报表口径用户已确认)
 */
@RestController
@RequestMapping("/api/accounts")
public class AccountsController {

    private final AccountsService service;

    public AccountsController(AccountsService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Map<String, Object>> list(HttpServletRequest req,
                                                  @RequestParam(required = false) String bookId,
                                                  @RequestParam(required = false, defaultValue = "false") boolean includeArchived) {
        long userId = userId(req);
        List<AccountResponse> items = service.list(userId, bookId, includeArchived);
        return ApiResponse.ok(Map.of("items", items));
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> create(HttpServletRequest req,
                                                    @Valid @RequestBody CreateAccountRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("account", service.create(userId, body)));
    }

    @GetMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> get(HttpServletRequest req,
                                                  @PathVariable String uuid) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("account", service.get(userId, uuid)));
    }

    @PatchMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> update(HttpServletRequest req,
                                                    @PathVariable String uuid,
                                                    @Valid @RequestBody UpdateAccountRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("account", service.update(userId, uuid, body)));
    }

    @DeleteMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> delete(HttpServletRequest req,
                                                    @PathVariable String uuid) {
        long userId = userId(req);
        service.delete(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    @PostMapping("/{uuid}/archive")
    public ApiResponse<Map<String, Object>> archive(HttpServletRequest req,
                                                     @PathVariable String uuid) {
        long userId = userId(req);
        service.archive(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    @DeleteMapping("/{uuid}/archive")
    public ApiResponse<Map<String, Object>> unarchive(HttpServletRequest req,
                                                       @PathVariable String uuid) {
        long userId = userId(req);
        service.unarchive(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        }
        return id;
    }
}
