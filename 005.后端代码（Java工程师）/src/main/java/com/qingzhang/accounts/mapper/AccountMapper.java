package com.qingzhang.accounts.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.entity.AccountBalance;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface AccountMapper extends BaseMapper<Account> {

    /**
     * 单账户实时余额(走 v_account_balance 视图)。
     */
    @Select("""
            SELECT id, uuid, user_id, book_id, name, type, icon,
                   initial_balance, balance, currency, is_default, is_archived,
                   sort_order, note, created_at
            FROM v_account_balance
            WHERE id = #{id} AND user_id = #{userId}
            """)
    AccountBalance findBalanceById(@Param("id") Long id, @Param("userId") Long userId);

    /**
     * 当前用户全部账户的实时余额。
     */
    @Select("""
            SELECT id, uuid, user_id, book_id, name, type, icon,
                   initial_balance, balance, currency, is_default, is_archived,
                   sort_order, note, created_at
            FROM v_account_balance
            WHERE user_id = #{userId}
            ORDER BY is_default DESC, sort_order ASC, id ASC
            """)
    List<AccountBalance> listBalancesByUser(@Param("userId") Long userId);

    // ====== admin 硬删用 —— 绕过 @TableLogic ======

    /** 硬删某用户所有账户(绕过 @TableLogic)。user 删除时 FK CASCADE 也会触发,这里显式调是为统计准确。 */
    @Delete("DELETE FROM accounts WHERE user_id = #{userId}")
    int hardDeleteByUserId(@Param("userId") Long userId);

    /** 统计某用户的账户数(含已被软删的)。供硬删前预览用。 */
    @Select("SELECT COUNT(*) FROM accounts WHERE user_id = #{userId}")
    int countByUserId(@Param("userId") Long userId);
}
