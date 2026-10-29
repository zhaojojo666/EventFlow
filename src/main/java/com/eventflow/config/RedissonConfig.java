package com.eventflow.config;

import org.redisson.Redisson;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import cn.hutool.core.util.StrUtil;

@Configuration
public class RedissonConfig {

    @Value("${spring.redis.host}")
    private String host;

    @Value("${spring.redis.port}")
    private int port;

    @Value("${spring.redis.password:}")
    private String password;

    @Bean
    public RedissonClient redissonClient(){
        Config config = new Config();
        org.redisson.config.SingleServerConfig singleServer = config.useSingleServer()
                .setAddress("redis://" + host + ":" + port);
        if (StrUtil.isNotBlank(password)) {
            singleServer.setPassword(password);
        }
        return Redisson.create(config);
    }
}
