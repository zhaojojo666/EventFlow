package com.eventflow.service.impl;

import com.eventflow.entity.LimitedTicket;
import com.eventflow.service.ILimitedTicketService;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.DependsOn;
import org.springframework.data.redis.connection.stream.PendingMessagesSummary;
import org.springframework.data.redis.connection.stream.StreamInfo;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.annotation.Resource;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import static com.eventflow.utils.RedisConstants.SECKILL_STOCK_KEY;

/**
 * Redis与MySQL秒杀库存对账。
 *
 * <p>对账任务只自动初始化缺失的Redis库存Key。
 * 已存在Key的数值不一致时只记录告警，不盲目覆盖，
 * 避免与正在进行的秒杀请求竞争造成超卖。</p>
 */
@Component
@DependsOn({"ticketOrderStreamConsumer", "ticketOrderDeadLetterConsumer"})
public class SeckillStockReconciliationService {

    private static final Logger log = LoggerFactory.getLogger(SeckillStockReconciliationService.class);

    public static final String ISSUE_HASH_KEY = "eventflow:ticket:reconcile:issues";
    private static final String LOCK_KEY = "eventflow:lock:ticket:reconcile";
    private static final long INITIAL_DELAY_SECONDS = 15L;
    private static final long INTERVAL_SECONDS = 60L;

    @Resource
    private ILimitedTicketService limitedTicketService;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Resource
    private RedissonClient redissonClient;

    private ScheduledExecutorService executor;

    @PostConstruct
    public void start() {
        executor = Executors.newSingleThreadScheduledExecutor(runnable -> {
            Thread thread = new Thread(runnable, "seckill-stock-reconciliation");
            thread.setDaemon(true);
            return thread;
        });
        executor.scheduleWithFixedDelay(
                this::reconcileSafely,
                INITIAL_DELAY_SECONDS,
                INTERVAL_SECONDS,
                TimeUnit.SECONDS
        );
    }

    @PreDestroy
    public void stop() {
        if (executor != null) {
            executor.shutdownNow();
        }
    }

    private void reconcileSafely() {
        RLock lock = redissonClient.getLock(LOCK_KEY);
        boolean locked = false;
        try {
            locked = lock.tryLock(0, 55, TimeUnit.SECONDS);
            if (!locked) {
                return;
            }
            reconcile();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            log.error("秒杀库存对账任务执行失败", e);
        } finally {
            if (locked && lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    void reconcile() {
        if (hasUnfinishedMessages(TicketOrderStreamConsumer.STREAM_KEY,
                TicketOrderStreamConsumer.GROUP_NAME)
                || hasUnfinishedMessages(TicketOrderDeadLetterConsumer.DEAD_LETTER_STREAM_KEY,
                TicketOrderDeadLetterConsumer.GROUP_NAME)) {
            log.debug("秒杀Stream存在未处理或Pending消息，本轮跳过库存对账");
            return;
        }

        List<LimitedTicket> tickets = limitedTicketService.list(
                new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<LimitedTicket>()
                        .notInSql("ticket_id", "SELECT id FROM tb_ticket WHERE type = 0"));
        for (LimitedTicket ticket : tickets) {
            Long ticketId = ticket.getTicketId();
            int databaseStock = ticket.getStock();
            String stockKey = SECKILL_STOCK_KEY + ticketId;
            String redisValue = stringRedisTemplate.opsForValue().get(stockKey);

            if (redisValue == null) {
                Boolean initialized = stringRedisTemplate.opsForValue()
                        .setIfAbsent(stockKey, String.valueOf(databaseStock));
                if (Boolean.TRUE.equals(initialized)) {
                    log.info("初始化缺失的秒杀Redis库存，ticketId={}，stock={}", ticketId, databaseStock);
                }
                stringRedisTemplate.opsForHash().delete(ISSUE_HASH_KEY, ticketId.toString());
                continue;
            }

            try {
                int redisStock = Integer.parseInt(redisValue);
                if (redisStock == databaseStock) {
                    stringRedisTemplate.opsForHash().delete(ISSUE_HASH_KEY, ticketId.toString());
                    continue;
                }
                recordIssue(ticketId, databaseStock, redisStock);
            } catch (NumberFormatException e) {
                String issue = "invalidRedisStock=" + redisValue + ",detectedAt=" + Instant.now();
                stringRedisTemplate.opsForHash().put(ISSUE_HASH_KEY, ticketId.toString(), issue);
                log.error("秒杀Redis库存不是有效整数，ticketId={}，value={}", ticketId, redisValue);
            }
        }
        stringRedisTemplate.expire(ISSUE_HASH_KEY, 7, TimeUnit.DAYS);
    }

    private void recordIssue(Long ticketId, int databaseStock, int redisStock) {
        String issue = "databaseStock=" + databaseStock
                + ",redisStock=" + redisStock
                + ",detectedAt=" + Instant.now();
        stringRedisTemplate.opsForHash().put(ISSUE_HASH_KEY, ticketId.toString(), issue);
        log.warn("秒杀库存对账不一致，ticketId={}，databaseStock={}，redisStock={}",
                ticketId, databaseStock, redisStock);
    }

    private boolean hasUnfinishedMessages(String streamKey, String groupName) {
        PendingMessagesSummary pending = stringRedisTemplate.opsForStream().pending(streamKey, groupName);
        if (pending.getTotalPendingMessages() > 0) {
            return true;
        }

        StreamInfo.XInfoStream streamInfo = stringRedisTemplate.opsForStream().info(streamKey);
        StreamInfo.XInfoGroups groups = stringRedisTemplate.opsForStream().groups(streamKey);
        for (int i = 0; i < groups.size(); i++) {
            StreamInfo.XInfoGroup group = groups.get(i);
            if (groupName.equals(group.groupName())) {
                return !streamInfo.lastGeneratedId().equals(group.lastDeliveredId());
            }
        }
        return true;
    }
}
