package com.qingzhang.books;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.books.dto.AddMemberRequest;
import com.qingzhang.books.dto.BookResponse;
import com.qingzhang.books.dto.CreateBookRequest;
import com.qingzhang.books.dto.MemberResponse;
import com.qingzhang.books.dto.UpdateBookRequest;
import com.qingzhang.books.dto.UpdateMemberRoleRequest;
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
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 *   GET    /api/books                           -> {items:[Book]}
 *   POST   /api/books                           -> {book:Book}
 *   GET    /api/books/{uuid}                    -> {book:Book}
 *   PATCH  /api/books/{uuid}                    -> {book:Book}
 *   DELETE /api/books/{uuid}                    -> {ok:true}
 *   POST   /api/books/{uuid}/default            -> {book:Book}
 *   GET    /api/books/{uuid}/members            -> {items:[Member]}
 *   POST   /api/books/{uuid}/members            -> {member:Member}
 *   PATCH  /api/books/{uuid}/members/{userUuid} -> {member:Member}
 *   DELETE /api/books/{uuid}/members/{userUuid} -> {ok:true}
 */
@RestController
@RequestMapping("/api/books")
public class BooksController {

    private final BooksService service;

    public BooksController(BooksService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Map<String, Object>> list(HttpServletRequest req) {
        long userId = userId(req);
        List<BookResponse> items = service.list(userId);
        return ApiResponse.ok(Map.of("items", items));
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> create(HttpServletRequest req,
                                                    @Valid @RequestBody CreateBookRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("book", service.create(userId, body)));
    }

    @GetMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> get(HttpServletRequest req,
                                                  @PathVariable String uuid) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("book", service.get(userId, uuid)));
    }

    @PatchMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> update(HttpServletRequest req,
                                                    @PathVariable String uuid,
                                                    @Valid @RequestBody UpdateBookRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("book", service.update(userId, uuid, body)));
    }

    @DeleteMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> delete(HttpServletRequest req,
                                                    @PathVariable String uuid) {
        long userId = userId(req);
        service.delete(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    @PostMapping("/{uuid}/default")
    public ApiResponse<Map<String, Object>> setDefault(HttpServletRequest req,
                                                        @PathVariable String uuid) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("book", service.setDefault(userId, uuid)));
    }

    @GetMapping("/{uuid}/members")
    public ApiResponse<Map<String, Object>> listMembers(HttpServletRequest req,
                                                        @PathVariable String uuid) {
        long userId = userId(req);
        List<MemberResponse> items = service.listMembers(userId, uuid);
        return ApiResponse.ok(Map.of("items", items));
    }

    @PostMapping("/{uuid}/members")
    public ApiResponse<Map<String, Object>> addMember(HttpServletRequest req,
                                                      @PathVariable String uuid,
                                                      @Valid @RequestBody AddMemberRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("member", service.addMember(userId, uuid, body)));
    }

    @PatchMapping("/{uuid}/members/{userUuid}")
    public ApiResponse<Map<String, Object>> updateMemberRole(HttpServletRequest req,
                                                              @PathVariable String uuid,
                                                              @PathVariable String userUuid,
                                                              @Valid @RequestBody UpdateMemberRoleRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("member", service.updateMemberRole(userId, uuid, userUuid, body)));
    }

    @DeleteMapping("/{uuid}/members/{userUuid}")
    public ApiResponse<Map<String, Object>> removeMember(HttpServletRequest req,
                                                          @PathVariable String uuid,
                                                          @PathVariable String userUuid) {
        long userId = userId(req);
        service.removeMember(userId, uuid, userUuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        return id;
    }
}
