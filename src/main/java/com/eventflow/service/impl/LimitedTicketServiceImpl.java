package com.eventflow.service.impl;

import com.eventflow.entity.LimitedTicket;
import com.eventflow.mapper.LimitedTicketMapper;
import com.eventflow.service.ILimitedTicketService;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import org.springframework.stereotype.Service;

/**
 * <p>
 * 秒杀票种表，与票种是一对一关系 服务实现类
 * </p>
 *
 * @author 虎哥
 * @since 2022-01-04
 */
@Service
public class LimitedTicketServiceImpl extends ServiceImpl<LimitedTicketMapper, LimitedTicket> implements ILimitedTicketService {

}
