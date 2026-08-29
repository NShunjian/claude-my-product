package com.qingzhang.books.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.books.entity.Book;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface BookMapper extends BaseMapper<Book> {
}
