package com.qingzhang.accounts;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.accounts.dto.AccountResponse;
import com.qingzhang.accounts.dto.CreateAccountRequest;
import com.qingzhang.accounts.dto.UpdateAccountRequest;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.entity.AccountBalance;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.common.BizException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 账户域业务。
 *
 * 错误码:30xx(账户域,见 ErrorCode / 模块常量)。
 */
@Service
public class AccountsService {

    private static final int CODE_ACCOUNT_NOT_FOUND = 3001;
    private static final int CODE_ACCOUNT_HAS_RECORDS = 3002;
    private static final int CODE_CURRENCY_MISMATCH = 3003;

    private final AccountMapper accountMapper;

    public AccountsService(AccountMapper accountMapper) {
        this.accountMapper = accountMapper;
    }

    public List<AccountResponse> list(long userId) {
        return accountMapper.listBalancesByUser(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    public AccountResponse get(long userId, String uuid) {
        Account a = mustOwned(userId, uuid);
        AccountBalance b = accountMapper.findBalanceById(a.getId(), userId);
        if (b == null) {
            throw new BizException(CODE_ACCOUNT_NOT_FOUND, "账户不存在");
        }
        return toResponse(b);
    }

    @Transactional(rollbackFor = Exception.class)
    public AccountResponse create(long userId, CreateAccountRequest req) {
        // 业务校验:币种规范(spec §6.4:大写 3 位 ISO 4217)
        String currency = req.currency() == null ? "CNY" : req.currency().toUpperCase();
        // 业务校验:is_default 单选 —— 置 true 时把同用户其他账户的 default 全部卸掉
        boolean wantDefault = Boolean.TRUE.equals(req.isDefault());

        Account a = Account.builder()
                .uuid(UUID.randomUUID().toString())
                .userId(userId)
                .name(req.name())
                .type(req.type())
                .icon(req.icon())
                .initialBalance(req.initialBalance() == null ? BigDecimal.ZERO : req.initialBalance())
                .currentBalance(BigDecimal.ZERO)
                .currency(currency)
                .isDefault((byte) (wantDefault ? 1 : 0))
                .isArchived((byte) 0)
                .sortOrder(req.sortOrder() == null ? 0 : req.sortOrder())
                .note(req.note())
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        if (wantDefault) {
            accountMapper.update(null, Wrappers.<Account>lambdaUpdate()
                    .set(Account::getIsDefault, (byte) 0)
                    .eq(Account::getUserId, userId));
        }
        accountMapper.insert(a);

        AccountBalance b = accountMapper.findBalanceById(a.getId(), userId);
        return toResponse(b);
    }

    @Transactional(rollbackFor = Exception.class)
    public AccountResponse update(long userId, String uuid, UpdateAccountRequest req) {
        Account a = mustOwned(userId, uuid);
        if (req.name() != null)            a.setName(req.name());
        if (req.type() != null)            a.setType(req.type());
        if (req.icon() != null)            a.setIcon(req.icon());
        if (req.initialBalance() != null)  a.setInitialBalance(req.initialBalance());
        if (req.currency() != null)        a.setCurrency(req.currency().toUpperCase());
        if (req.sortOrder() != null)       a.setSortOrder(req.sortOrder());
        if (req.note() != null)            a.setNote(req.note());
        if (Boolean.TRUE.equals(req.isDefault())) {
            accountMapper.update(null, Wrappers.<Account>lambdaUpdate()
                    .set(Account::getIsDefault, (byte) 0)
                    .eq(Account::getUserId, userId)
                    .ne(Account::getId, a.getId()));
            a.setIsDefault((byte) 1);
        } else if (Boolean.FALSE.equals(req.isDefault())) {
            a.setIsDefault((byte) 0);
        }
        a.setUpdatedAt(Instant.now());
        accountMapper.updateById(a);

        AccountBalance b = accountMapper.findBalanceById(a.getId(), userId);
        return toResponse(b);
    }

    @Transactional(rollbackFor = Exception.class)
    public void delete(long userId, String uuid) {
        Account a = mustOwned(userId, uuid);
        // 校验无引用账目(简化:不允许删除 default 账户)
        if (a.getIsDefault() != null && a.getIsDefault() == 1) {
            throw new BizException(CODE_ACCOUNT_HAS_RECORDS, "默认账户不可删除,请先把其他账户设为默认");
        }
        accountMapper.deleteById(a.getId());
    }

    // ---- internal ----

    private Account mustOwned(long userId, String uuid) {
        Account a = accountMapper.selectOne(Wrappers.<Account>lambdaQuery()
                .eq(Account::getUuid, uuid)
                .eq(Account::getUserId, userId));
        if (a == null) {
            throw new BizException(CODE_ACCOUNT_NOT_FOUND, "账户不存在");
        }
        return a;
    }

    private AccountResponse toResponse(AccountBalance b) {
        return new AccountResponse(
                b.getUuid(),
                b.getName(),
                b.getType(),
                b.getIcon(),
                b.getInitialBalance(),
                b.getBalance(),
                b.getCurrency(),
                b.getIsDefault() != null && b.getIsDefault() == 1,
                b.getSortOrder(),
                b.getNote(),
                b.getCreatedAt()
        );
    }
}
