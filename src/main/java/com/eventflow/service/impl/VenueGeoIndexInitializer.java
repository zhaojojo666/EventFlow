package com.eventflow.service.impl;

import com.eventflow.entity.Venue;
import com.eventflow.service.IVenueService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static com.eventflow.utils.RedisConstants.VENUE_GEO_KEY;

/**
 * 启动时从 MySQL 恢复场馆 GEO 索引。
 *
 * <p>GEO 数据属于可重建的 Redis 派生数据。Redis 使用新容器、清空数据或迁移后，
 * 如果不恢复该索引，携带经纬度的场馆列表查询会得到空结果。GEOADD 本身具备幂等
 * 更新语义，因此每次启动同步一次既能补全空 Redis，也能刷新已有场馆坐标。</p>
 */
@Slf4j
@Component
public class VenueGeoIndexInitializer implements ApplicationRunner {

    @Resource
    private IVenueService venueService;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public void run(ApplicationArguments args) {
        List<Venue> venues = venueService.list();
        Map<Long, List<Venue>> venuesByType = venues.stream()
                .filter(venue -> venue.getTypeId() != null
                        && venue.getId() != null
                        && venue.getX() != null
                        && venue.getY() != null)
                .collect(Collectors.groupingBy(Venue::getTypeId));

        int indexed = 0;
        for (Map.Entry<Long, List<Venue>> entry : venuesByType.entrySet()) {
            List<RedisGeoCommands.GeoLocation<String>> locations = new ArrayList<>();
            for (Venue venue : entry.getValue()) {
                locations.add(new RedisGeoCommands.GeoLocation<>(
                        venue.getId().toString(),
                        new Point(venue.getX(), venue.getY())
                ));
            }
            if (!locations.isEmpty()) {
                stringRedisTemplate.opsForGeo().add(VENUE_GEO_KEY + entry.getKey(), locations);
                indexed += locations.size();
            }
        }
        log.info("场馆GEO索引初始化完成，typeCount={}，venueCount={}", venuesByType.size(), indexed);
    }
}
