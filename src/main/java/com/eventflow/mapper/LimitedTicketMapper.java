package com.eventflow.mapper;

import com.eventflow.entity.LimitedTicket;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;

/**
 * <p>
 * 秒杀票种表，与票种是一对一关系 Mapper 接口
 * </p>
 *
 * @author 虎哥
 * @since 2022-01-04
 */
public interface LimitedTicketMapper extends BaseMapper<LimitedTicket> {

}
