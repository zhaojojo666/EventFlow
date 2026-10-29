package com.eventflow;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

@MapperScan("com.eventflow.mapper")
@SpringBootApplication
@EnableAspectJAutoProxy(exposeProxy = true)
public class EventFlowApplication {

    public static void main(String[] args) {
        SpringApplication.run(EventFlowApplication.class, args);
    }

}
