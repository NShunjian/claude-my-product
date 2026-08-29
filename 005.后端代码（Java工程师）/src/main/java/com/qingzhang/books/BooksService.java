package com.qingzhang.books;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.books.dto.AddMemberRequest;
import com.qingzhang.books.dto.BookResponse;
import com.qingzhang.books.dto.CreateBookRequest;
import com.qingzhang.books.dto.MemberResponse;
import com.qingzhang.books.dto.UpdateBookRequest;
import com.qingzhang.books.dto.UpdateMemberRoleRequest;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.entity.BookMember;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.books.mapper.BookMemberMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 账本域业务。spec §5.3 20xx 区间。
 *
 *   2001  BOOK_NOT_FOUND
 *   2002  BOOK_NOT_ACCESSIBLE
 *   2003  BOOK_NAME_REQUIRED
 *   2004  BOOK_DEFAULT_NOT_DELETABLE
 *   2005  BOOK_NOT_EMPTY (本阶段不抛,默认级联删)
 *   2010  MEMBER_NOT_FOUND
 *   2011  MEMBER_ALREADY_EXISTS
 *   2012  MEMBER_USER_NOT_FOUND
 *   2013  INVALID_ROLE
 *   2014  NOT_OWNER
 *   2015  CANNOT_REMOVE_SELF
 *   2016  CANNOT_REMOVE_LAST_OWNER
 *   2017  INVALID_BOOK_TYPE
 *
 * 设计要点:
 *   1. 创建账本时同时插入 book_members 行(role=owner),保证成员视角一致。
 *   2. 「owner」概念既来自 books.owner_id,也来自 book_members.role='owner'。
 *      实际只有 books.owner_id 那位是「不可移除的 owner」;member 表里的 owner 角色目前保留
 *      给将来转让场景,本阶段无流转逻辑。
 *   3. 「设为默认账本」(POST /default)在 owner 视角会更新 books.is_default;
 *      对非 owner 成员只返回 200 ok,前端用 localStorage 持久化(见 plan)。
 */
@Service
public class BooksService {

    private static final int CODE_BOOK_NOT_FOUND         = 2001;
    private static final int CODE_BOOK_NOT_ACCESSIBLE    = 2002;
    private static final int CODE_BOOK_NAME_REQUIRED     = 2003;
    private static final int CODE_BOOK_DEFAULT_NOT_DEL   = 2004;
    private static final int CODE_MEMBER_NOT_FOUND       = 2010;
    private static final int CODE_MEMBER_ALREADY_EXISTS  = 2011;
    private static final int CODE_MEMBER_USER_NOT_FOUND  = 2012;
    private static final int CODE_INVALID_ROLE           = 2013;
    private static final int CODE_NOT_OWNER              = 2014;
    private static final int CODE_CANNOT_REMOVE_SELF     = 2015;
    private static final int CODE_CANNOT_REMOVE_LAST_OWN = 2016;
    private static final int CODE_INVALID_BOOK_TYPE      = 2017;

    private static final List<String> VALID_BOOK_TYPES = List.of("personal", "shared", "business");
    private static final List<String> VALID_ROLES      = List.of("admin", "editor", "viewer");

    private final BookMapper bookMapper;
    private final BookMemberMapper memberMapper;
    private final UserMapper userMapper;
    private final RecordMapper recordMapper;

    public BooksService(BookMapper bookMapper,
                        BookMemberMapper memberMapper,
                        UserMapper userMapper,
                        RecordMapper recordMapper) {
        this.bookMapper = bookMapper;
        this.memberMapper = memberMapper;
        this.userMapper = userMapper;
        this.recordMapper = recordMapper;
    }

    // ===== 账本列表 =====

    public List<BookResponse> list(long userId) {
        return bookMapper.listForUser(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    public BookResponse get(long userId, String uuid) {
        Book b = mustAccessibleBook(userId, uuid);
        String role = resolveRole(b, userId);
        return toResponse(b, role);
    }

    // ===== 创建账本 =====

    @Transactional(rollbackFor = Exception.class)
    public BookResponse create(long userId, CreateBookRequest req) {
        if (req.name() == null || req.name().isBlank()) {
            throw new BizException(CODE_BOOK_NAME_REQUIRED, "账本名称不能为空");
        }
        String type = req.type() == null ? "personal" : req.type();
        if (!VALID_BOOK_TYPES.contains(type)) {
            throw new BizException(CODE_INVALID_BOOK_TYPE, "type 必须是 personal / shared / business");
        }
        String currency = (req.currency() == null || req.currency().isBlank()) ? "CNY" : req.currency().toUpperCase();
        Instant now = Instant.now();

        Book book = Book.builder()
                .uuid(UUID.randomUUID().toString())
                .ownerId(userId)
                .name(req.name().trim())
                .description(req.description())
                .type(type)
                .currency(currency)
                .isDefault((byte) 0)   // 新建账本不是默认(默认账本只在注册时建一个)
                .isArchived((byte) 0)
                .sortOrder(0)
                .createdAt(now)
                .updatedAt(now)
                .build();
        bookMapper.insert(book);

        // 创建者写入 book_members(role=owner)—— 统一成员视角
        BookMember owner = BookMember.builder()
                .bookId(book.getId())
                .userId(userId)
                .role("owner")
                .joinedAt(now)
                .invitedBy(userId)
                .build();
        memberMapper.insert(owner);

        return toResponse(book, "owner");
    }

    // ===== 修改账本 =====

    @Transactional(rollbackFor = Exception.class)
    public BookResponse update(long userId, String uuid, UpdateBookRequest req) {
        Book b = mustAccessibleBook(userId, uuid);
        mustBeOwner(b, userId);

        if (req.name() != null) {
            if (req.name().isBlank()) {
                throw new BizException(CODE_BOOK_NAME_REQUIRED, "账本名称不能为空");
            }
            b.setName(req.name().trim());
        }
        if (req.description() != null) b.setDescription(req.description());
        if (req.type() != null) {
            if (!VALID_BOOK_TYPES.contains(req.type())) {
                throw new BizException(CODE_INVALID_BOOK_TYPE, "type 必须是 personal / shared / business");
            }
            b.setType(req.type());
        }
        if (req.isArchived() != null) b.setIsArchived((byte) (req.isArchived() ? 1 : 0));
        b.setUpdatedAt(Instant.now());
        bookMapper.updateById(b);

        return toResponse(b, "owner");
    }

    // ===== 删除账本 =====

    @Transactional(rollbackFor = Exception.class)
    public void delete(long userId, String uuid) {
        Book b = mustAccessibleBook(userId, uuid);
        mustBeOwner(b, userId);
        if (b.getIsDefault() != null && b.getIsDefault() == 1) {
            throw new BizException(CODE_BOOK_DEFAULT_NOT_DEL, "默认账本不可删除");
        }
        // 删账本前清账目:records.fk_records_book 是 RESTRICT,book_members 是 CASCADE。
        // 这里走软删(@TableLogic 自动加 deleted_at IS NULL),不级联 records 实体。
        recordMapper.delete(Wrappers.<com.qingzhang.records.entity.Record>lambdaQuery()
                .eq(com.qingzhang.records.entity.Record::getBookId, b.getId()));
        bookMapper.deleteById(b.getId());
    }

    // ===== 设为默认 =====
    // 仅对账本 owner 在 DB 上更新 is_default;非 owner 成员也接受请求(返回 200),
    // 由前端 localStorage 持久化(见 plan)。
    @Transactional(rollbackFor = Exception.class)
    public BookResponse setDefault(long userId, String uuid) {
        Book b = mustAccessibleBook(userId, uuid);
        if (b.getOwnerId() == userId) {
            // 单选:先把 owner 名下其它账本的 is_default 清掉
            bookMapper.update(null, Wrappers.<Book>lambdaUpdate()
                    .set(Book::getIsDefault, (byte) 0)
                    .eq(Book::getOwnerId, userId)
                    .ne(Book::getId, b.getId()));
            b.setIsDefault((byte) 1);
            b.setUpdatedAt(Instant.now());
            bookMapper.updateById(b);
        }
        String role = resolveRole(b, userId);
        return toResponse(b, role);
    }

    // ===== 成员列表 =====

    public List<MemberResponse> listMembers(long userId, String bookUuid) {
        Book b = mustAccessibleBook(userId, bookUuid);
        List<BookMember> members = memberMapper.selectList(
                Wrappers.<BookMember>lambdaQuery().eq(BookMember::getBookId, b.getId())
        );
        if (members.isEmpty()) return List.of();

        // 一次性把成员对应的 user 拉出来
        List<Long> userIds = members.stream().map(BookMember::getUserId).toList();
        Map<Long, User> userById = userMapper.selectBatchIds(userIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u, (a, c) -> a, HashMap::new));

        List<MemberResponse> out = new ArrayList<>(members.size());
        for (BookMember m : members) {
            User u = userById.get(m.getUserId());
            if (u == null) continue; // 极端:user 已被删但成员行没清
            out.add(new MemberResponse(
                    u.getUuid(),
                    u.getUsername(),
                    u.getDisplayName(),
                    u.getAvatar(),
                    m.getRole(),
                    m.getJoinedAt(),
                    m.getInvitedBy() == null ? null : uuidOfUser(m.getInvitedBy())
            ));
        }
        return out;
    }

    // ===== 邀请成员 =====

    @Transactional(rollbackFor = Exception.class)
    public MemberResponse addMember(long userId, String bookUuid, AddMemberRequest req) {
        Book b = mustAccessibleBook(userId, bookUuid);
        mustBeOwnerOrAdmin(b, userId);

        if (!VALID_ROLES.contains(req.role())) {
            throw new BizException(CODE_INVALID_ROLE, "role 必须是 admin / editor / viewer");
        }
        User target = userMapper.selectOne(
                Wrappers.<User>lambdaQuery().eq(User::getUsername, req.username())
        );
        if (target == null) {
            throw new BizException(CODE_MEMBER_USER_NOT_FOUND, "用户不存在: " + req.username());
        }
        if (target.getId() == b.getOwnerId()) {
            throw new BizException(CODE_MEMBER_ALREADY_EXISTS, "账本 owner 无需再添加");
        }
        BookMember exists = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, target.getId()));
        if (exists != null) {
            throw new BizException(CODE_MEMBER_ALREADY_EXISTS, "该用户已是账本成员");
        }

        Instant now = Instant.now();
        BookMember m = BookMember.builder()
                .bookId(b.getId())
                .userId(target.getId())
                .role(req.role())
                .joinedAt(now)
                .invitedBy(userId)
                .build();
        memberMapper.insert(m);

        return new MemberResponse(
                target.getUuid(), target.getUsername(), target.getDisplayName(), target.getAvatar(),
                m.getRole(), m.getJoinedAt(), uuidOfUser(userId)
        );
    }

    @Transactional(rollbackFor = Exception.class)
    public MemberResponse updateMemberRole(long userId, String bookUuid, String userUuid, UpdateMemberRoleRequest req) {
        Book b = mustAccessibleBook(userId, bookUuid);
        mustBeOwner(b, userId);

        if (!VALID_ROLES.contains(req.role())) {
            throw new BizException(CODE_INVALID_ROLE, "role 必须是 admin / editor / viewer");
        }
        User target = userMapper.selectOne(
                Wrappers.<User>lambdaQuery().eq(User::getUuid, userUuid)
        );
        if (target == null) {
            throw new BizException(CODE_MEMBER_USER_NOT_FOUND, "用户不存在");
        }
        if (target.getId() == b.getOwnerId()) {
            throw new BizException(CODE_CANNOT_REMOVE_LAST_OWN, "owner 角色不可修改");
        }
        BookMember m = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, target.getId()));
        if (m == null) {
            throw new BizException(CODE_MEMBER_NOT_FOUND, "用户不是账本成员");
        }
        m.setRole(req.role());
        memberMapper.updateById(m);

        return new MemberResponse(
                target.getUuid(), target.getUsername(), target.getDisplayName(), target.getAvatar(),
                m.getRole(), m.getJoinedAt(), uuidOfUser(m.getInvitedBy())
        );
    }

    // ===== 移除成员 =====

    @Transactional(rollbackFor = Exception.class)
    public void removeMember(long userId, String bookUuid, String userUuid) {
        Book b = mustAccessibleBook(userId, bookUuid);
        mustBeOwner(b, userId);

        User target = userMapper.selectOne(
                Wrappers.<User>lambdaQuery().eq(User::getUuid, userUuid)
        );
        if (target == null) {
            throw new BizException(CODE_MEMBER_USER_NOT_FOUND, "用户不存在");
        }
        if (target.getId() == b.getOwnerId()) {
            throw new BizException(CODE_CANNOT_REMOVE_LAST_OWN, "owner 不可被移除");
        }
        if (target.getId() == userId) {
            throw new BizException(CODE_CANNOT_REMOVE_SELF, "owner 不可移除自己");
        }
        BookMember m = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, target.getId()));
        if (m == null) {
            throw new BizException(CODE_MEMBER_NOT_FOUND, "用户不是账本成员");
        }
        memberMapper.deleteById(m.getId());
    }

    // ===== 内部 =====

    /**
     * 取用户当前活跃默认账本(books.is_default=1)。
     * 没有默认账本时抛错 —— 注册时已自动建一个,正常情况不会为 null。
     */
    public Book defaultBookOf(long userId) {
        Book b = bookMapper.selectOne(Wrappers.<Book>lambdaQuery()
                .eq(Book::getOwnerId, userId)
                .eq(Book::getIsDefault, (byte) 1));
        if (b == null) {
            throw new BizException(ErrorCode.INTERNAL, "未找到默认账本");
        }
        return b;
    }

    /** 必须存在且当前用户能访问(拥有 OR 是成员)。 */
    public Book mustAccessibleBook(long userId, String uuid) {
        Book b = bookMapper.selectOne(Wrappers.<Book>lambdaQuery()
                .eq(Book::getUuid, uuid));
        if (b == null) {
            throw new BizException(CODE_BOOK_NOT_FOUND, "账本不存在");
        }
        if (b.getOwnerId() == userId) {
            return b; // owner 直接放行
        }
        BookMember m = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, userId));
        if (m == null) {
            throw new BizException(CODE_BOOK_NOT_ACCESSIBLE, "无权访问该账本");
        }
        return b;
    }

    private void mustBeOwner(Book b, long userId) {
        if (b.getOwnerId() != userId) {
            throw new BizException(CODE_NOT_OWNER, "仅账本 owner 可执行此操作");
        }
    }

    private void mustBeOwnerOrAdmin(Book b, long userId) {
        if (b.getOwnerId() == userId) return;
        BookMember m = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, userId));
        if (m == null || !"admin".equals(m.getRole())) {
            throw new BizException(CODE_NOT_OWNER, "仅 owner / admin 可执行此操作");
        }
    }

    private String resolveRole(Book b, long userId) {
        if (b.getOwnerId() == userId) return "owner";
        BookMember m = memberMapper.selectOne(Wrappers.<BookMember>lambdaQuery()
                .eq(BookMember::getBookId, b.getId())
                .eq(BookMember::getUserId, userId));
        return m == null ? null : m.getRole();
    }

    private String uuidOfUser(Long userId) {
        if (userId == null) return null;
        User u = userMapper.selectById(userId);
        return u == null ? null : u.getUuid();
    }

    private BookResponse toResponse(BookMapper.BookWithRole row) {
        Book b = Book.builder()
                .id(row.id()).uuid(row.uuid()).ownerId(row.ownerId())
                .name(row.name()).description(row.description())
                .type(row.type()).currency(row.currency())
                .isDefault(row.isDefault()).isArchived(row.isArchived())
                .sortOrder(row.sortOrder())
                .createdAt(row.createdAt()).updatedAt(row.updatedAt())
                .build();
        return toResponse(b, row.userRole());
    }

    private BookResponse toResponse(Book b, String role) {
        String ownerUuid = b.getOwnerId() == null ? null : uuidOfUser(b.getOwnerId());
        return new BookResponse(
                b.getUuid(),
                b.getName(),
                b.getDescription(),
                b.getType(),
                b.getCurrency(),
                b.getIsDefault() != null && b.getIsDefault() == 1,
                b.getIsArchived() != null && b.getIsArchived() == 1,
                role,
                ownerUuid,
                b.getCreatedAt(),
                b.getUpdatedAt()
        );
    }
}
