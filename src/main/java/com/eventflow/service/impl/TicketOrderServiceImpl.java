package com.eventflow.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.eventflow.dto.Result;
import com.eventflow.entity.TicketOrder;
import com.eventflow.mapper.TicketOrderMapper;
import com.eventflow.service.ILimitedTicketService;
import com.eventflow.service.ITicketOrderService;
import com.eventflow.utils.RedisIdWorker;
import com.eventflow.utils.UserHolder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.Collections;

/**
 * 秒杀票务订单服务。
 *
 * <p>Lua只负责Redis内的原子校验、预扣库存和写入Stream；
 * 真正的数据库事务由独立的Stream消费者异步调用。</p>
 */
@Service
public class TicketOrderServiceImpl extends ServiceImpl<TicketOrderMapper, TicketOrder>
        implements ITicketOrderService {

    private static final Logger log = LoggerFactory.getLogger(TicketOrderServiceImpl.class);

    private static final DefaultRedisScript<Long> SECKILL_SCRIPT;

    static {
        SECKILL_SCRIPT = new DefaultRedisScript<>();
        SECKILL_SCRIPT.setLocation(new ClassPathResource("seckill.lua"));
        SECKILL_SCRIPT.setResultType(Long.class);
    }

    @Resource
    private ILimitedTicketService limitedTicketService;

    @Resource
    private RedisIdWorker redisIdWorker;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public Result limitedTicket(Long ticketId) {
        Long userId = UserHolder.getUser().getId();
        long orderId = redisIdWorker.nextId("order");

        Long result = stringRedisTemplate.execute(
                SECKILL_SCRIPT,
                Collections.emptyList(),
                ticketId.toString(),
                userId.toString(),
                String.valueOf(orderId)
        );

        if (result == null) {
            log.error("执行秒杀Lua脚本无返回值，ticketId={}，userId={}", ticketId, userId);
            return Result.fail("秒杀服务异常，请稍后重试");
        }

        int code = result.intValue();
        if (code != 0) {
            return Result.fail(code == 1 ? "库存不足" : "不能重复下单");
        }

        // Lua已将订单写入Redis Stream，接口可立即返回。
        return Result.ok(orderId);
    }

    /**
     * Stream消费者调用的订单落库事务。
     * 相同消息可能被至少一次投递，因此必须幂等。
     */
    @Override
    @Transactional
    public void createTicketOrder(TicketOrder ticketOrder) {
        Long userId = ticketOrder.getUserId();
        Long ticketId = ticketOrder.getTicketId();

        // 相同Stream消息重复投递时，订单ID不变。
        if (getById(ticketOrder.getId()) != null) {
            log.info("秒杀订单已存在，幂等返回，orderId={}", ticketOrder.getId());
            return;
        }

        // Redis做前置拦截，数据库再做一次最终兜底。
        int count = query().eq("user_id", userId).eq("ticket_id", ticketId).count();
        if (count > 0) {
            log.warn("用户该票务订单已存在，幂等返回，userId={}，ticketId={}", userId, ticketId);
            return;
        }

        boolean stockUpdated = limitedTicketService.update()
                .setSql("stock = stock - 1")
                .eq("ticket_id", ticketId)
                .gt("stock", 0)
                .update();

        if (!stockUpdated) {
            // 保留消息在Pending List，由自动恢复线程重试或转入死信Stream。
            throw new IllegalStateException("扣减数据库库存失败，ticketId=" + ticketId);
        }

        if (!save(ticketOrder)) {
            throw new IllegalStateException("秒杀订单落库失败，orderId=" + ticketOrder.getId());
        }
    }

    /**
     * 保留的同步入口，便于普通下单场景复用。
     */
    @Override
    @Transactional
    public Result createTicketOrder(Long ticketId) {
        Long userId = UserHolder.getUser().getId();

        int count = query().eq("user_id", userId).eq("ticket_id", ticketId).count();
        if (count > 0) {
            return Result.fail("用户已经购买过一次！");
        }

        boolean success = limitedTicketService.update()
                .setSql("stock = stock - 1")
                .eq("ticket_id", ticketId)
                .gt("stock", 0)
                .update();
        if (!success) {
            return Result.fail("库存不足！");
        }

        TicketOrder ticketOrder = new TicketOrder();
        ticketOrder.setId(redisIdWorker.nextId("order"));
        ticketOrder.setUserId(userId);
        ticketOrder.setTicketId(ticketId);
        save(ticketOrder);
        return Result.ok(ticketOrder.getId());
    }
}
