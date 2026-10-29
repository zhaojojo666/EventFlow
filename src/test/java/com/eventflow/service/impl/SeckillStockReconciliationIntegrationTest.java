package com.eventflow.service.impl;

import com.eventflow.entity.LimitedTicket;
import com.eventflow.service.ILimitedTicketService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;

import javax.annotation.Resource;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class SeckillStockReconciliationIntegrationTest {

    @Resource
    private SeckillStockReconciliationService reconciliationService;

    @Resource
    private ILimitedTicketService limitedTicketService;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Test
    void shouldInitializeMissingStockAndReportMismatchWithoutOverwriting() {
        long ticketId = 300_000_000L + System.currentTimeMillis() % 100_000_000L;
        String stockKey = "eventflow:ticket:stock:" + ticketId;

        LimitedTicket ticket = new LimitedTicket();
        ticket.setTicketId(ticketId);
        ticket.setStock(7);
        ticket.setBeginTime(LocalDateTime.now().minusMinutes(1));
        ticket.setEndTime(LocalDateTime.now().plusMinutes(10));

        try {
            limitedTicketService.save(ticket);

            reconciliationService.reconcile();
            assertEquals("7", stringRedisTemplate.opsForValue().get(stockKey));

            stringRedisTemplate.opsForValue().set(stockKey, "5");
            reconciliationService.reconcile();
            String issue = (String) stringRedisTemplate.opsForHash().get(
                    SeckillStockReconciliationService.ISSUE_HASH_KEY,
                    String.valueOf(ticketId));
            assertNotNull(issue);
            assertEquals("5", stringRedisTemplate.opsForValue().get(stockKey),
                    "对账任务不应在并发环境中盲目覆盖Redis库存");

            stringRedisTemplate.opsForValue().set(stockKey, "7");
            reconciliationService.reconcile();
            assertNull(stringRedisTemplate.opsForHash().get(
                    SeckillStockReconciliationService.ISSUE_HASH_KEY,
                    String.valueOf(ticketId)));
        } finally {
            limitedTicketService.removeById(ticketId);
            stringRedisTemplate.delete(stockKey);
            stringRedisTemplate.opsForHash().delete(
                    SeckillStockReconciliationService.ISSUE_HASH_KEY,
                    String.valueOf(ticketId));
        }
    }
}
