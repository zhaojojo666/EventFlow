package com.eventflow.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.eventflow.dto.Result;
import com.eventflow.entity.Ticket;
import com.eventflow.mapper.TicketMapper;
import com.eventflow.entity.LimitedTicket;
import com.eventflow.service.ILimitedTicketService;
import com.eventflow.service.ITicketService;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.List;

import static com.eventflow.utils.RedisConstants.SECKILL_STOCK_KEY;

/**
 * <p>
 *  服务实现类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@Service
public class TicketServiceImpl extends ServiceImpl<TicketMapper, Ticket> implements ITicketService {

    @Resource
    private ILimitedTicketService limitedTicketService;
    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public Result queryTicketOfVenue(Long venueId) {
        // 查询票种信息
        List<Ticket> tickets = getBaseMapper().queryTicketOfVenue(venueId);
        // 返回结果
        return Result.ok(tickets);
    }

    @Override
    @Transactional
    public void addLimitedTicket(Ticket ticket) {
        // 保存票种
        save(ticket);
        // 保存秒杀信息
        LimitedTicket limitedTicket = new LimitedTicket();
        limitedTicket.setTicketId(ticket.getId());
        limitedTicket.setStock(ticket.getStock());
        limitedTicket.setBeginTime(ticket.getBeginTime());
        limitedTicket.setEndTime(ticket.getEndTime());
        limitedTicketService.save(limitedTicket);
        //保存秒杀库存信息到redis
        stringRedisTemplate.opsForValue().set(SECKILL_STOCK_KEY+ticket.getId(),ticket.getStock().toString());

    }
}
