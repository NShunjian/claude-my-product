package com.qingzhang.books.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.books.entity.BookMember;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface BookMemberMapper extends BaseMapper<BookMember> {
}
