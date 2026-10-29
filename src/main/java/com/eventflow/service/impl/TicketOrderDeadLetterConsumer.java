package com.eventflow.service.impl;

import com.eventflow.entity.TicketOrder;
import com.eventflow.service.ITicketOrderService;
import io.lettuce.core.StreamMessage;
import io.lettuce.core.XAutoClaimArgs;
import io.lettuce.core.cluster.api.async.RedisClusterAsyncCommands;
import io.lettuce.core.models.stream.ClaimedMessages;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.connection.RedisStreamCommands;
import org.springframework.data.redis.connection.stream.Consumer;
import org.springframework.data.redis.connection.stream.MapRecord;
import org.springframework.data.redis.connection.stream.ReadOffset;
import org.springframework.data.redis.connection.stream.StreamOffset;
import org.springframework.data.redis.connection.stream.StreamReadOptions;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.serializer.RedisSerializer;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.annotation.Resource;
import java.lang.management.ManagementFactory;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * 死信订单补偿消费者。
 *
 * <p>只有确认MySQL中不存在订单时，才通过Lua原子恢复Redis库存
 * 并移除用户的一人一单标记。</p>
 */
@Component
public class TicketOrderDeadLetterConsumer {

    private static final Logger log = LoggerFactory.getLogger(TicketOrderDeadLetterConsumer.class);

    static final String DEAD_LETTER_STREAM_KEY = "eventflow:stream:ticket-orders:dlq";
    static final String GROUP_NAME = "eventflow-ticket-dlq-group";

    private static final int BATCH_SIZE = 10;
    private static final Duration BLOCK_TIME = Duration.ofSeconds(2);
    private static final Duration MIN_IDLE_TIME = Duration.ofSeconds(30);

    private static final DefaultRedisScript<Long> COMPENSATE_SCRIPT;

    static {
        COMPENSATE_SCRIPT = new DefaultRedisScript<>();
        COMPENSATE_SCRIPT.setLocation(new ClassPathResource("seckill_compensate.lua"));
        COMPENSATE_SCRIPT.setResultType(Long.class);
    }

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Resource
    private ITicketOrderService ticketOrderService;

    private final String consumerName = buildConsumerName();
    private volatile boolean running;
    private ExecutorService consumerExecutor;
    private ScheduledExecutorService recoveryExecutor;

    @PostConstruct
    public void start() {
        createConsumerGroupIfNecessary();
        running = true;
        consumerExecutor = Executors.newSingleThreadExecutor(runnable -> daemonThread(
                runnable, "ticket-order-dlq-consumer"));
        recoveryExecutor = Executors.newSingleThreadScheduledExecutor(runnable -> daemonThread(
                runnable, "ticket-order-dlq-recovery"));

        consumerExecutor.submit(this::consume);
        recoveryExecutor.scheduleWithFixedDelay(
                this::recoverSafely,
                MIN_IDLE_TIME.getSeconds(),
                10L,
                TimeUnit.SECONDS
        );
        log.info("秒杀死信补偿消费者已启动，group={}，consumer={}", GROUP_NAME, consumerName);
    }

    @PreDestroy
    public void stop() {
        running = false;
        if (consumerExecutor != null) {
            consumerExecutor.shutdownNow();
        }
        if (recoveryExecutor != null) {
            recoveryExecutor.shutdownNow();
        }
    }

    private void consume() {
        while (running && !Thread.currentThread().isInterrupted()) {
            try {
                List<MapRecord<String, Object, Object>> records = stringRedisTemplate.opsForStream().read(
                        Consumer.from(GROUP_NAME, consumerName),
                        StreamReadOptions.empty().count(BATCH_SIZE).block(BLOCK_TIME),
                        StreamOffset.create(DEAD_LETTER_STREAM_KEY, ReadOffset.lastConsumed())
                );
                if (records == null) {
                    continue;
                }
                for (MapRecord<String, Object, Object> record : records) {
                    compensate(record.getId().getValue(), record.getValue());
                }
            } catch (Exception e) {
                if (running) {
                    log.error("读取秒杀死信Stream失败，稍后重试", e);
                    sleepQuietly(1000L);
                }
            }
        }
    }

    private void compensate(String messageId, Map<?, ?> values) {
        try {
            long orderId = longValue(values, "id");
            long userId = longValue(values, "userId");
            long ticketId = longValue(values, "ticketId");

            TicketOrder existingOrder = ticketOrderService.getById(orderId);
            if (existingOrder != null) {
                acknowledge(messageId);
                log.warn("死信订单已存在MySQL，不执行库存补偿，orderId={}", orderId);
                return;
            }

            Long result = stringRedisTemplate.execute(
                    COMPENSATE_SCRIPT,
                    java.util.Collections.emptyList(),
                    String.valueOf(ticketId),
                    String.valueOf(userId),
                    String.valueOf(orderId)
            );
            if (result == null) {
                throw new IllegalStateException("补偿Lua脚本无返回值，orderId=" + orderId);
            }

            acknowledge(messageId);
            log.warn("秒杀死信补偿完成，orderId={}，ticketId={}，compensated={}",
                    orderId, ticketId, result == 1L);
        } catch (Exception e) {
            // 不ACK，保留在DLQ的Pending List等待自动接管重试。
            log.error("秒杀死信补偿失败，messageId={}", messageId, e);
        }
    }

    private void acknowledge(String messageId) {
        stringRedisTemplate.opsForStream().acknowledge(DEAD_LETTER_STREAM_KEY, GROUP_NAME, messageId);
    }

    private void recoverSafely() {
        if (!running) {
            return;
        }
        try {
            String startId = "0-0";
            int batches = 0;
            do {
                ClaimedMessages<byte[], byte[]> claimed = autoClaim(startId);
                if (claimed == null) {
                    return;
                }
                for (StreamMessage<byte[], byte[]> message : claimed.getMessages()) {
                    compensate(message.getId(), decodeBody(message.getBody()));
                }
                startId = claimed.getId();
                batches++;
            } while (running && !"0-0".equals(startId) && batches < 100);
        } catch (Exception e) {
            log.error("自动接管秒杀死信Pending消息失败", e);
        }
    }

    @SuppressWarnings("unchecked")
    private ClaimedMessages<byte[], byte[]> autoClaim(String startId) {
        return stringRedisTemplate.execute((RedisCallback<ClaimedMessages<byte[], byte[]>>) connection -> {
            Object nativeConnection = connection.getNativeConnection();
            if (!(nativeConnection instanceof RedisClusterAsyncCommands)) {
                throw new IllegalStateException("当前Redis驱动不支持XAUTOCLAIM");
            }
            RedisClusterAsyncCommands<byte[], byte[]> commands =
                    (RedisClusterAsyncCommands<byte[], byte[]>) nativeConnection;
            XAutoClaimArgs<byte[]> args = new XAutoClaimArgs<byte[]>()
                    .consumer(io.lettuce.core.Consumer.from(bytes(GROUP_NAME), bytes(consumerName)))
                    .minIdleTime(MIN_IDLE_TIME)
                    .startId(startId)
                    .count(BATCH_SIZE);
            try {
                return commands.xautoclaim(bytes(DEAD_LETTER_STREAM_KEY), args).get(5, TimeUnit.SECONDS);
            } catch (Exception e) {
                throw new IllegalStateException("执行DLQ XAUTOCLAIM失败", e);
            }
        });
    }

    private void createConsumerGroupIfNecessary() {
        try {
            stringRedisTemplate.execute((RedisCallback<String>) connection -> {
                RedisSerializer<String> serializer = stringRedisTemplate.getStringSerializer();
                RedisStreamCommands commands = connection.streamCommands();
                return commands.xGroupCreate(
                        serializer.serialize(DEAD_LETTER_STREAM_KEY),
                        GROUP_NAME,
                        ReadOffset.from("0-0"),
                        true
                );
            });
        } catch (DataAccessException e) {
            if (!containsMessage(e, "BUSYGROUP")) {
                throw e;
            }
        }
    }

    private long longValue(Map<?, ?> values, String key) {
        for (Map.Entry<?, ?> entry : values.entrySet()) {
            if (key.equals(String.valueOf(entry.getKey()))) {
                return Long.parseLong(String.valueOf(entry.getValue()));
            }
        }
        throw new IllegalArgumentException("死信消息缺少字段: " + key);
    }

    private Map<String, String> decodeBody(Map<byte[], byte[]> body) {
        Map<String, String> result = new java.util.LinkedHashMap<>();
        for (Map.Entry<byte[], byte[]> entry : body.entrySet()) {
            result.put(new String(entry.getKey(), StandardCharsets.UTF_8),
                    new String(entry.getValue(), StandardCharsets.UTF_8));
        }
        return result;
    }

    private static String buildConsumerName() {
        String process = ManagementFactory.getRuntimeMXBean().getName().replaceAll("[^a-zA-Z0-9_-]", "-");
        return "dlq-" + process + "-" + UUID.randomUUID().toString().substring(0, 8);
    }

    private static Thread daemonThread(Runnable runnable, String name) {
        Thread thread = new Thread(runnable, name);
        thread.setDaemon(true);
        return thread;
    }

    private static byte[] bytes(String value) {
        return value.getBytes(StandardCharsets.UTF_8);
    }

    private static boolean containsMessage(Throwable throwable, String text) {
        Throwable current = throwable;
        while (current != null) {
            if (current.getMessage() != null && current.getMessage().contains(text)) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private static void sleepQuietly(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
