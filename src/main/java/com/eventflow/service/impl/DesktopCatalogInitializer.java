package com.eventflow.service.impl;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.data.redis.core.StringRedisTemplate;
import javax.annotation.Resource;
import java.util.Map;

/** Restore missing Redis data for the desktop demo catalog without resetting live inventory. */
@Component
public class DesktopCatalogInitializer implements ApplicationRunner {
    @Resource private JdbcTemplate jdbc;
    @Resource private StringRedisTemplate redis;
    @Override public void run(ApplicationArguments args) {
        // Legacy databases can start before the additive catalog migration is applied.
        Integer installed=jdbc.queryForObject("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='tb_event_ticket'",Integer.class);
        if(installed==null||installed==0)return;
        for(Map<String,Object> row:jdbc.queryForList("SELECT t.id,i.stock FROM tb_event_ticket et JOIN tb_ticket t ON t.id=et.ticket_id JOIN tb_seckill_ticket i ON i.ticket_id=t.id WHERE t.type=1")) {
            String id=row.get("id").toString();
            redis.opsForValue().setIfAbsent("eventflow:ticket:stock:"+id,row.get("stock").toString());
            for(Map<String,Object> order:jdbc.queryForList("SELECT user_id FROM tb_ticket_order WHERE ticket_id=?",row.get("id"))) {
                redis.opsForSet().add("eventflow:ticket:order:"+id,order.get("user_id").toString());
            }
        }
    }
}
