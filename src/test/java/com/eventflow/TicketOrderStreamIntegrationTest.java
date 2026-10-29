package com.eventflow;

import com.eventflow.entity.LimitedTicket;
import com.eventflow.entity.TicketOrder;
import com.eventflow.service.ILimitedTicketService;
import com.eventflow.service.ITicketOrderService;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.domain.Range;
import org.springframework.data.redis.connection.stream.MapRecord;
import org.springframework.data.redis.connection.stream.RecordId;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.boot.test.context.SpringBootTest;

import javax.annotation.Resource;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * 需要本地MySQL和Redis 7。测试数据使用独立ID，并在finally中清理。
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class TicketOrderStreamIntegrationTest {

    private static final String STREAM_KEY = "eventflow:stream:ticket-orders";
    private static final String DEAD_LETTER_STREAM_KEY = "eventflow:stream:ticket-orders:dlq";
    private static final String COMPENSATED_STREAM_KEY = "eventflow:stream:ticket-orders:compensated";
    private static final String RETRY_HASH_KEY = "eventflow:stream:ticket-orders:retry";

    private static final DefaultRedisScript<Long> SECKILL_SCRIPT;

    static {
        SECKILL_SCRIPT = new DefaultRedisScript<>();
        SECKILL_SCRIPT.setLocation(new ClassPathResource("seckill.lua"));
        SECKILL_SCRIPT.setResultType(Long.class);
    }

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Resource
    private ILimitedTicketService limitedTicketService;

    @Resource
    private ITicketOrderService ticketOrderService;

    @Test
    void luaShouldWriteStreamAndConsumerShouldPersistExactlyOnce() throws Exception {
        long suffix = System.currentTimeMillis() % 100_000_000L;
        long ticketId = 900_000_000L + suffix;
        long userId = 800_000_000L + suffix;
        long orderId = 700_000_000L + suffix;
        String stockKey = "eventflow:ticket:stock:" + ticketId;
        String orderKey = "eventflow:ticket:order:" + ticketId;

        LimitedTicket ticket = new LimitedTicket();
        ticket.setTicketId(ticketId);
        ticket.setStock(1);
        ticket.setBeginTime(LocalDateTime.now().minusMinutes(1));
        ticket.setEndTime(LocalDateTime.now().plusMinutes(10));

        try {
            limitedTicketService.save(ticket);
            stringRedisTemplate.opsForValue().set(stockKey, "1");

            Long firstResult = executeSeckill(ticketId, userId, orderId);
            assertEquals(0L, firstResult);

            TicketOrder savedOrder = waitForOrder(orderId, 10_000L);
            assertNotNull(savedOrder, "Stream订单应在10秒内落库");
            assertEquals(userId, savedOrder.getUserId());
            assertEquals(ticketId, savedOrder.getTicketId());

            Long duplicateResult = executeSeckill(ticketId, userId, orderId + 1);
            assertEquals(2L, duplicateResult, "同一用户不应重复购买同一优惠券");
        } finally {
            ticketOrderService.removeById(orderId);
            limitedTicketService.removeById(ticketId);
            stringRedisTemplate.delete(stockKey);
            stringRedisTemplate.delete(orderKey);
            removeTestMessages(orderId);
        }
    }

    @Test
    void deadLetterConsumerShouldCompensateStockExactlyOnce() throws Exception {
        long suffix = System.currentTimeMillis() % 100_000_000L;
        long ticketId = 600_000_000L + suffix;
        long userId = 500_000_000L + suffix;
        long orderId = 400_000_000L + suffix;
        String stockKey = "eventflow:ticket:stock:" + ticketId;
        String orderKey = "eventflow:ticket:order:" + ticketId;
        String compensatedKey = "eventflow:ticket:compensated:" + orderId;

        Map<String, String> deadLetter = new LinkedHashMap<>();
        deadLetter.put("id", String.valueOf(orderId));
        deadLetter.put("userId", String.valueOf(userId));
        deadLetter.put("ticketId", String.valueOf(ticketId));
        deadLetter.put("originalMessageId", "test-0");
        deadLetter.put("retryCount", "3");

        RecordId firstMessage = null;
        RecordId duplicateMessage = null;
        try {
            stringRedisTemplate.opsForValue().set(stockKey, "0");
            stringRedisTemplate.opsForSet().add(orderKey, String.valueOf(userId));

            firstMessage = stringRedisTemplate.opsForStream().add(DEAD_LETTER_STREAM_KEY, deadLetter);
            waitForRedisValue(stockKey, "1", 10_000L);

            assertEquals("1", stringRedisTemplate.opsForValue().get(stockKey));
            assertEquals(Boolean.FALSE,
                    stringRedisTemplate.opsForSet().isMember(orderKey, String.valueOf(userId)));
            assertEquals("1", stringRedisTemplate.opsForValue().get(compensatedKey));

            // 同一订单死信再次投递，补偿标记应防止重复恢复库存。
            duplicateMessage = stringRedisTemplate.opsForStream().add(DEAD_LETTER_STREAM_KEY, deadLetter);
            Thread.sleep(1000L);
            assertEquals("1", stringRedisTemplate.opsForValue().get(stockKey));
        } finally {
            stringRedisTemplate.delete(stockKey);
            stringRedisTemplate.delete(orderKey);
            stringRedisTemplate.delete(compensatedKey);
            if (firstMessage != null) {
                stringRedisTemplate.opsForStream().delete(DEAD_LETTER_STREAM_KEY, firstMessage);
            }
            if (duplicateMessage != null) {
                stringRedisTemplate.opsForStream().delete(DEAD_LETTER_STREAM_KEY, duplicateMessage);
            }
            removeMessagesByOrderId(COMPENSATED_STREAM_KEY, orderId);
        }
    }

    private Long executeSeckill(long ticketId, long userId, long orderId) {
        return stringRedisTemplate.execute(
                SECKILL_SCRIPT,
                Collections.emptyList(),
                String.valueOf(ticketId),
                String.valueOf(userId),
                String.valueOf(orderId)
        );
    }

    private TicketOrder waitForOrder(long orderId, long timeoutMillis) throws InterruptedException {
        long deadline = System.currentTimeMillis() + timeoutMillis;
        TicketOrder order;
        do {
            order = ticketOrderService.getById(orderId);
            if (order != null) {
                return order;
            }
            Thread.sleep(100L);
        } while (System.currentTimeMillis() < deadline);
        return null;
    }

    private void waitForRedisValue(String key, String expected, long timeoutMillis) throws InterruptedException {
        long deadline = System.currentTimeMillis() + timeoutMillis;
        do {
            if (expected.equals(stringRedisTemplate.opsForValue().get(key))) {
                return;
            }
            Thread.sleep(100L);
        } while (System.currentTimeMillis() < deadline);
    }

    private void removeTestMessages(long orderId) {
        removeMessagesByOrderId(STREAM_KEY, orderId);
    }

    private void removeMessagesByOrderId(String streamKey, long orderId) {
        List<MapRecord<String, Object, Object>> records =
                stringRedisTemplate.opsForStream().range(streamKey, Range.unbounded());
        if (records == null) {
            return;
        }
        for (MapRecord<String, Object, Object> record : records) {
            Object value = record.getValue().get("id");
            if (value == null) {
                value = record.getValue().get("orderId");
            }
            if (value != null && String.valueOf(orderId).equals(String.valueOf(value))) {
                stringRedisTemplate.opsForStream().delete(streamKey, record.getId());
                stringRedisTemplate.opsForHash().delete(RETRY_HASH_KEY, record.getId().getValue());
            }
        }
    }
}
