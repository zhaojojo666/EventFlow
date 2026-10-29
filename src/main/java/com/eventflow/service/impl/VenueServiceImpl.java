package com.eventflow.service.impl;

import cn.hutool.core.util.BooleanUtil;
import cn.hutool.core.util.StrUtil;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.eventflow.dto.Result;
import com.eventflow.entity.Venue;
import com.eventflow.mapper.VenueMapper;
import com.eventflow.service.IVenueService;
import com.eventflow.utils.CacheClient;
import com.eventflow.utils.RedisData;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.eventflow.utils.SystemConstants;
import org.springframework.data.geo.Circle;
import org.springframework.data.geo.Distance;
import org.springframework.data.geo.GeoResult;
import org.springframework.data.geo.GeoResults;
import org.springframework.data.geo.Metrics;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static com.eventflow.utils.RedisConstants.*;

/**
 * <p>
 *  服务实现类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@Service
public class VenueServiceImpl extends ServiceImpl<VenueMapper, Venue> implements IVenueService {
    @Resource
    private StringRedisTemplate stringRedisTemplate;
    @Resource
    private CacheClient cacheClient;

    @Override
    public Result queryById(Long id) {
        // 解决缓存穿透
        Venue venue = cacheClient
                .queryWithPassThrough(CACHE_VENUE_KEY, id, Venue.class, this::getById, CACHE_VENUE_TTL, TimeUnit.MINUTES);

        // 互斥锁解决缓存击穿
        // Venue venue = cacheClient
        //         .queryWithMutex(CACHE_VENUE_KEY, id, Venue.class, this::getById, CACHE_VENUE_TTL, TimeUnit.MINUTES);

        // 逻辑过期解决缓存击穿
        // Venue venue = cacheClient
        //         .queryWithLogicalExpire(CACHE_VENUE_KEY, id, Venue.class, this::getById, 20L, TimeUnit.SECONDS);

        if (venue == null) {
            return Result.fail("场馆不存在！");
        }
        // 7.返回
        return Result.ok(venue);
    }

    public Venue queryWithMutex(Long id){
        String key=CACHE_VENUE_KEY+id;
        //1.从redis查询场馆缓存
        String venueJson=stringRedisTemplate.opsForValue().get(key);
        //2.判断redis中是否有缓存，如果有直接返回
        if (StrUtil.isNotBlank(venueJson)){
            //3.存在则返回
            return JSONUtil.toBean(venueJson,Venue.class);
        }
        //判断是否为空值
        if ("".equals(venueJson)){
            return null;
        }
        //4.实现缓存重建
        //4.1 ,获取互斥锁
        String lockkey=LOCK_VENUE_KEY+id;
        Venue venue= null;
        try {
            boolean isLock = tryLock(lockkey);
            //4.2，判断是否成功
            if (!isLock){
                //4.3.失败，则休眠重试
                Thread.sleep(50);
                return queryWithMutex(id);
            }


            //4.4,成功，根据id查询数据库
            venue = getById(id);
            //5.不存在则返回错误
            if (venue==null){
                //将空值写入redis防止缓存穿透
                stringRedisTemplate.opsForValue().set(key,"",CACHE_NULL_TTL,TimeUnit.MINUTES);
                return null;
            }
            //6.存在，写入redis
            stringRedisTemplate.opsForValue().set(key,JSONUtil.toJsonStr(venue),CACHE_VENUE_TTL, TimeUnit.MINUTES);
        } catch (Exception e) {
            throw new RuntimeException(e);
        } finally {
            //7,释放互斥锁
            unlock(lockkey) ;
        }

        return venue;
    }

    private static final ExecutorService CACHE_REBUILD_EXECUTOR= Executors.newFixedThreadPool(10);
    public Venue queryWithLogicalExpire(Long id){
        String key=CACHE_VENUE_KEY+id;
        //1.从redis查询场馆缓存
        String venueJson=stringRedisTemplate.opsForValue().get(key);
        //2.判断redis中是否有缓存，如果有直接返回
        if (StrUtil.isNotBlank(venueJson)){
            //3.不存在则返回
            return null;
        }
        //4.命中则先把json反序列化为对象
        RedisData redisData=JSONUtil.toBean(venueJson,RedisData.class);
        Venue venue = JSONUtil.toBean((JSONObject) redisData.getData(), Venue.class);
        LocalDateTime expireTime=redisData.getExpireTime();
        //5.判断是否过期
        if (expireTime.isAfter(LocalDateTime.now())){
            //5.1未过期直接返回场馆信息
            return venue;
        }
        //5.2已过期则需要缓存重建
        //6.缓存重建

        //6.1获取互斥锁
        String lockkey=LOCK_VENUE_KEY+id;
        boolean isLock=tryLock(lockkey);
        //6.2判断是否获取锁成功
        //6.3成功，开启独立线程实现缓存重建
        if (isLock){
            CACHE_REBUILD_EXECUTOR.submit( ()->{

                try{
                    //重建缓存
                    this.saveVenue2Redis(id,20L);
                }catch (Exception e){
                    throw new RuntimeException(e);
                }finally {
                    unlock(lockkey);
                }
            });
        }
        //6.4失败则返回旧数据
        return venue;
    }

    public Venue queryWithPassThrough(Long id){
        String key=CACHE_VENUE_KEY+id;
        //1.从redis查询场馆缓存
        String venueJson=stringRedisTemplate.opsForValue().get(key);
        //2.判断redis中是否有缓存，如果有直接返回
        if (StrUtil.isNotBlank(venueJson)){
            //3.存在则返回
            return JSONUtil.toBean(venueJson,Venue.class);
        }
        //判断是否为空值
        if ("".equals(venueJson)){
            return null;
        }
        Venue venue=getById(id);
        if (venue==null){
            //将空值写入redis防止缓存穿透
            stringRedisTemplate.opsForValue().set(key,"",CACHE_NULL_TTL,TimeUnit.MINUTES);
            return null;
        }
        stringRedisTemplate.opsForValue().set(key,JSONUtil.toJsonStr(venue),CACHE_VENUE_TTL, TimeUnit.MINUTES);
        return venue;
    }

    public void saveVenue2Redis(Long id, Long expireSeconds){
        Venue venue=getById(id);
        RedisData redisData=new RedisData();
        redisData.setData(venue);
        redisData.setExpireTime(LocalDateTime.now().plusSeconds(expireSeconds));
        stringRedisTemplate.opsForValue().set(CACHE_VENUE_KEY+id,JSONUtil.toJsonStr(redisData));

    }



    @Override
    @Transactional
    public Result update(Venue venue){
        Long id=venue.getId();
        if (id==null){
            return Result.fail("场馆id不能为空");
        }
        //1.更新数据库
        updateById(venue);
        //2.删除缓存
        stringRedisTemplate.delete(CACHE_VENUE_KEY+id);
        return Result.ok();
    }

    @Override
    public Result queryVenueByType(Integer typeId, Integer current, Double x, Double y) {
        if (x == null || y == null) {
            return Result.ok(query()
                    .eq("type_id", typeId)
                    .page(new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(
                            current, SystemConstants.DEFAULT_PAGE_SIZE))
                    .getRecords());
        }

        int from = (current - 1) * SystemConstants.DEFAULT_PAGE_SIZE;
        int end = current * SystemConstants.DEFAULT_PAGE_SIZE;
        GeoResults<RedisGeoCommands.GeoLocation<String>> results = stringRedisTemplate.opsForGeo().radius(
                VENUE_GEO_KEY + typeId,
                new Circle(new Point(x, y), new Distance(5, Metrics.KILOMETERS)),
                RedisGeoCommands.GeoRadiusCommandArgs.newGeoRadiusArgs()
                        .includeDistance()
                        .sortAscending()
                        .limit(end)
        );
        if (results == null || results.getContent().size() <= from) {
            return Result.ok(Collections.emptyList());
        }

        List<GeoResult<RedisGeoCommands.GeoLocation<String>>> geoList = results.getContent();
        List<Long> ids = new ArrayList<>(Math.min(geoList.size() - from, SystemConstants.DEFAULT_PAGE_SIZE));
        Map<String, Distance> distanceMap = new HashMap<>();
        geoList.stream().skip(from).forEach(result -> {
            String venueId = result.getContent().getName();
            ids.add(Long.valueOf(venueId));
            distanceMap.put(venueId, result.getDistance());
        });

        String idStr = StrUtil.join(",", ids);
        List<Venue> venues = query().in("id", ids)
                .last("ORDER BY FIELD(id," + idStr + ")")
                .list();
        venues.forEach(venue -> {
            Distance distance = distanceMap.get(venue.getId().toString());
            if (distance != null) {
                venue.setDistance(distance.getValue());
            }
        });
        return Result.ok(venues);
    }

    private boolean tryLock(String key){
        Boolean flag = stringRedisTemplate.opsForValue().setIfAbsent(key, "1", 10, TimeUnit.SECONDS);
        return BooleanUtil.isTrue(flag);
    }
    private void unlock(String key){
        stringRedisTemplate.delete(key);
    }



}
