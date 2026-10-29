package com.eventflow.config;

import com.eventflow.utils.LoginInterceptor;
import com.eventflow.utils.RefreshTokenInterceptor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import javax.annotation.Resource;
import java.nio.file.Paths;

@Configuration
public class MvcConfig implements WebMvcConfigurer {
    @Value("${eventflow.upload-dir}")
    private String uploadDir;


    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 登录拦截器
        registry.addInterceptor(new LoginInterceptor(stringRedisTemplate))
                .excludePathPatterns(
                        "/",
                        "/*.html",
                        "/favicon.ico",
                        "/css/**",
                        "/js/**",
                        "/imgs/**",
                        "/events",
                        "/events/**",
                        "/activity-post/*",
                        "/venue/**",
                        "/ticket/**",
                        "/venue-category/**",
                        "/activity-post/hot",
                        "/user/code",
                        "/user/login"
                ).order(1);
        // token刷新的拦截器
        registry.addInterceptor(new RefreshTokenInterceptor(stringRedisTemplate)).addPathPatterns("/**").order(0);
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String uploadLocation = Paths.get(uploadDir).toAbsolutePath().normalize()
                .resolve("activity-posts").toUri().toString();
        if (!uploadLocation.endsWith("/")) {
            uploadLocation += "/";
        }
        registry.addResourceHandler("/imgs/activity-posts/**")
                .addResourceLocations(uploadLocation, "classpath:/static/imgs/activity-posts/");
    }
}
