package com.eventflow;

import com.eventflow.entity.Venue;
import com.eventflow.service.IVenueService;
import com.eventflow.service.impl.VenueServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import static com.eventflow.utils.RedisConstants.VENUE_GEO_KEY;

@SpringBootTest
class EventFlowApplicationTests {
    @Resource
    private VenueServiceImpl venueService;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Test
    void testSaveVenue(){
        Venue venue = venueService.query().last("LIMIT 1").one();
        assertNotNull(venue, "请先初始化演示数据库");
        venueService.saveVenue2Redis(venue.getId(),10L);
    }

    @Test
    void loadVenueData() {
        List<Venue> venues = venueService.list();
        Map<Long, List<Venue>> venuesByType = venues.stream()
                .collect(Collectors.groupingBy(Venue::getTypeId));
        for (Map.Entry<Long, List<Venue>> entry : venuesByType.entrySet()) {
            List<RedisGeoCommands.GeoLocation<String>> locations =
                    new ArrayList<>(entry.getValue().size());
            for (Venue venue : entry.getValue()) {
                locations.add(new RedisGeoCommands.GeoLocation<>(
                        venue.getId().toString(), new Point(venue.getX(), venue.getY())));
            }
            stringRedisTemplate.opsForGeo().add(VENUE_GEO_KEY + entry.getKey(), locations);
        }
    }


}
