package com.eventflow.service.impl;

import com.eventflow.entity.TicketOrder;
import com.eventflow.service.ITicketOrderService;
import io.lettuce.core.StreamMessage;
import io.lettuce.core.XAutoClaimArgs;
import io.lettuce.core.cluster.api.async.RedisClusterAsyncCommands;
import io.lettuce.core.models.stream.ClaimedMessages;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.connection.RedisStreamCommands;
import org.springframework.data.redis.connection.stream.Consumer;
import org.springframework.data.redis.connection.stream.MapRecord;
import org.springframework.data.redis.connection.stream.ReadOffset;
import org.springframework.data.redis.connection.stream.StreamOffset;
import org.springframework.data.redis.connection.stream.StreamReadOptions;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.serializer.RedisSerializer;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.annotation.Resource;
import java.lang.management.ManagementFactory;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Redis Streams秒杀订单消费者。
 *
 * <p>正常消息通过XREADGROUP消费，事务成功后才XACK。
 * 宕机或处理失败留下的Pending消息由XAUTOCLAIM自动接管，
 * 超过重试上限后转入死信Stream。</p>
 */
@Component
public class TicketOrderStreamConsumer {

    private static final Logger log = LoggerFactory.getLogger(TicketOrderStreamConsumer.class);

    static final String STREAM_KEY = "eventflow:stream:ticket-orders";
    static final String GROUP_NAME = "eventflow-ticket-order-group";
    static final String DEAD_LETTER_STREAM_KEY = "eventflow:stream:ticket-orders:dlq";
    static final String RETRY_HASH_KEY = "eventflow:stream:ticket-orders:retry";

    private static final int BATCH_SIZE = 10;
    private static final int MAX_RETRY_COUNT = 3;
    private static final Duration READ_BLOCK_TIME = Duration.ofSeconds(2);
    private static final Duration MIN_IDLE_TIME = Duration.ofSeconds(30);
    private static final long RECOVERY_INTERVAL_SECONDS = 10L;

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

        consumerExecutor = Executors.newSingleThreadExecutor(runnable -> {
            Thread thread = new Thread(runnable, "ticket-order-stream-consumer");
            thread.setDaemon(true);
            return thread;
        });
        recoveryExecutor = Executors.newSingleThreadScheduledExecutor(runnable -> {
            Thread thread = new Thread(runnable, "ticket-order-stream-recovery");
            thread.setDaemon(true);
            return thread;
        });

        consumerExecutor.submit(this::consumeNewMessages);
        recoveryExecutor.scheduleWithFixedDelay(
                this::recoverPendingMessagesSafely,
                MIN_IDLE_TIME.getSeconds(),
                RECOVERY_INTERVAL_SECONDS,
                TimeUnit.SECONDS
        );
        log.info("Redis Stream订单消费者已启动，group={}，consumer={}", GROUP_NAME, consumerName);
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

    private void consumeNewMessages() {
        while (running && !Thread.currentThread().isInterrupted()) {
            try {
                List<MapRecord<String, Object, Object>> records = stringRedisTemplate.opsForStream().read(
                        Consumer.from(GROUP_NAME, consumerName),
                        StreamReadOptions.empty().count(BATCH_SIZE).block(READ_BLOCK_TIME),
                        StreamOffset.create(STREAM_KEY, ReadOffset.lastConsumed())
                );
                if (records == null || records.isEmpty()) {
                    continue;
                }
                for (MapRecord<String, Object, Object> record : records) {
                    processMessage(record.getId().getValue(), record.getValue());
                }
            } catch (Exception e) {
                if (running) {
                    log.error("读取Redis Stream秒杀订单失败，稍后重试", e);
                    sleepQuietly(1000L);
                }
            }
        }
    }

    private void processMessage(String messageId, Map<?, ?> values) {
        try {
            TicketOrder order = toTicketOrder(values);
            ticketOrderService.createTicketOrder(order);
            acknowledge(messageId);
            stringRedisTemplate.opsForHash().delete(RETRY_HASH_KEY, messageId);
            log.debug("秒杀订单消费成功，messageId={}，orderId={}", messageId, order.getId());
        } catch (Exception e) {
            handleFailure(messageId, values, e);
        }
    }

    private void handleFailure(String messageId, Map<?, ?> values, Exception cause) {
        Long retryCount = stringRedisTemplate.opsForHash().increment(RETRY_HASH_KEY, messageId, 1L);
        long attempts = retryCount == null ? 1L : retryCount;

        if (attempts < MAX_RETRY_COUNT) {
            log.warn("秒杀订单消费失败，保留在Pending List等待重试，messageId={}，attempt={}",
                    messageId, attempts, cause);
            return;
        }

        Map<String, String> deadLetter = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : values.entrySet()) {
            deadLetter.put(String.valueOf(entry.getKey()), String.valueOf(entry.getValue()));
        }
        deadLetter.put("originalMessageId", messageId);
        deadLetter.put("failedConsumer", consumerName);
        deadLetter.put("retryCount", String.valueOf(attempts));
        deadLetter.put("failedAt", Instant.now().toString());
        deadLetter.put("error", abbreviate(cause.getMessage(), 500));

        // 先写死信再ACK原消息，避免死信写入失败时丢单。
        stringRedisTemplate.opsForStream().add(DEAD_LETTER_STREAM_KEY, deadLetter);
        acknowledge(messageId);
        stringRedisTemplate.opsForHash().delete(RETRY_HASH_KEY, messageId);
        log.error("秒杀订单超过重试上限，已转入死信Stream，messageId={}", messageId, cause);
    }

    private void acknowledge(String messageId) {
        stringRedisTemplate.opsForStream().acknowledge(STREAM_KEY, GROUP_NAME, messageId);
    }

    private void recoverPendingMessagesSafely() {
        if (!running) {
            return;
        }
        try {
            recoverPendingMessages();
        } catch (Exception e) {
            log.error("自动接管Pending秒杀订单失败", e);
        }
    }

    private void recoverPendingMessages() {
        String startId = "0-0";
        int scannedBatches = 0;
        do {
            ClaimedMessages<byte[], byte[]> claimed = autoClaim(startId);
            if (claimed == null) {
                return;
            }
            for (StreamMessage<byte[], byte[]> message : claimed.getMessages()) {
                processMessage(message.getId(), decodeBody(message.getBody()));
            }
            startId = claimed.getId();
            scannedBatches++;
        } while (running && !"0-0".equals(startId) && scannedBatches < 100);
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
                return commands.xautoclaim(bytes(STREAM_KEY), args).get(5, TimeUnit.SECONDS);
            } catch (Exception e) {
                throw new IllegalStateException("执行XAUTOCLAIM失败", e);
            }
        });
    }

    private void createConsumerGroupIfNecessary() {
        try {
            stringRedisTemplate.execute((RedisCallback<String>) connection -> {
                RedisSerializer<String> serializer = stringRedisTemplate.getStringSerializer();
                byte[] streamKey = serializer.serialize(STREAM_KEY);
                RedisStreamCommands commands = connection.streamCommands();
                return commands.xGroupCreate(streamKey, GROUP_NAME, ReadOffset.from("0-0"), true);
            });
        } catch (DataAccessException e) {
            if (!containsMessage(e, "BUSYGROUP")) {
                throw e;
            }
        }
    }

    private TicketOrder toTicketOrder(Map<?, ?> values) {
        TicketOrder order = new TicketOrder();
        order.setId(Long.valueOf(requiredValue(values, "id")));
        order.setUserId(Long.valueOf(requiredValue(values, "userId")));
        order.setTicketId(Long.valueOf(requiredValue(values, "ticketId")));
        return order;
    }

    private String requiredValue(Map<?, ?> values, String key) {
        for (Map.Entry<?, ?> entry : values.entrySet()) {
            if (key.equals(String.valueOf(entry.getKey()))) {
                return String.valueOf(entry.getValue());
            }
        }
        throw new IllegalArgumentException("Stream消息缺少字段: " + key);
    }

    private Map<String, String> decodeBody(Map<byte[], byte[]> body) {
        Map<String, String> result = new LinkedHashMap<>();
        for (Map.Entry<byte[], byte[]> entry : body.entrySet()) {
            result.put(new String(entry.getKey(), StandardCharsets.UTF_8),
                    new String(entry.getValue(), StandardCharsets.UTF_8));
        }
        return result;
    }

    private static String buildConsumerName() {
        String process = ManagementFactory.getRuntimeMXBean().getName().replaceAll("[^a-zA-Z0-9_-]", "-");
        return process + "-" + UUID.randomUUID().toString().substring(0, 8);
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

    private static String abbreviate(String value, int maxLength) {
        if (value == null) {
            return "unknown";
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }

    private static void sleepQuietly(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
