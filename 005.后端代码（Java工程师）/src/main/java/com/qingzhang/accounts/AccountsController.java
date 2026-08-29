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
 *   GET    /api/accounts            -> {items:[Account]}
 *   POST   /api/accounts            -> {account}
 *   GET    /api/accounts/{uuid}     -> {account}
 *   PATCH  /api/accounts/{uuid}     -> {account}
 *   DELETE /api/accounts/{uuid}     -> {ok:true}
 *
 * 余额取自 v_account_balance 视图,响应字段对应前端 src/api/accounts.ts 的 Account。
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
                                                  @RequestParam(required = false) String bookId) {
        long userId = userId(req);
        List<AccountResponse> items = service.list(userId, bookId);
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

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        }
        return id;
    }
}
