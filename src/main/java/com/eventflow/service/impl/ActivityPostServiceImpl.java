package com.eventflow.service.impl;

import cn.hutool.core.bean.BeanUtil;
import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.eventflow.entity.ActivityPost;
import com.eventflow.dto.Result;
import com.eventflow.dto.ScrollResult;
import com.eventflow.dto.UserDTO;
import com.eventflow.entity.Follow;
import com.eventflow.entity.User;
import com.eventflow.mapper.ActivityPostMapper;
import com.eventflow.service.IActivityPostService;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.eventflow.service.IFollowService;
import com.eventflow.service.IUserService;
import com.eventflow.utils.SystemConstants;
import com.eventflow.utils.UserHolder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static com.eventflow.utils.RedisConstants.POST_LIKED_KEY;
import static com.eventflow.utils.RedisConstants.FEED_KEY;

/**
 * <p>
 *  服务实现类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@Service
public class ActivityPostServiceImpl extends ServiceImpl<ActivityPostMapper, ActivityPost> implements IActivityPostService {

    @Resource
    private IUserService userService;

    @Resource
    private IFollowService followService;

    @Resource
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public Result queryHotActivityPost(Integer current) {
        Page<ActivityPost> page = query()
                .orderByDesc("liked")
                .page(new Page<>(current, SystemConstants.MAX_PAGE_SIZE));
        List<ActivityPost> records = page.getRecords();
        records.forEach(activityPost -> {
            queryActivityPostUser(activityPost);
            isActivityPostLiked(activityPost);
        });
        return Result.ok(records);
    }

    @Override
    public Result queryActivityPostById(Long id) {
        ActivityPost activityPost = getById(id);
        if (activityPost == null) {
            return Result.fail("笔记不存在！");
        }
        queryActivityPostUser(activityPost);
        isActivityPostLiked(activityPost);
        return Result.ok(activityPost);
    }

    @Override
    public Result likeActivityPost(Long id) {
        Long userId = UserHolder.getUser().getId();
        String key = POST_LIKED_KEY + id;
        Double score = stringRedisTemplate.opsForZSet().score(key, userId.toString());
        if (score == null) {
            boolean success = update().setSql("liked = liked + 1").eq("id", id).update();
            if (!success) {
                return Result.fail("笔记不存在！");
            }
            stringRedisTemplate.opsForZSet().add(key, userId.toString(), System.currentTimeMillis());
        } else {
            boolean success = update()
                    .setSql("liked = liked - 1")
                    .eq("id", id)
                    .gt("liked", 0)
                    .update();
            if (success) {
                stringRedisTemplate.opsForZSet().remove(key, userId.toString());
            }
        }
        return Result.ok();
    }

    @Override
    public Result queryActivityPostLikes(Long id) {
        Set<String> top5 = stringRedisTemplate.opsForZSet().range(POST_LIKED_KEY + id, 0, 4);
        if (top5 == null || top5.isEmpty()) {
            return Result.ok(Collections.emptyList());
        }
        List<Long> ids = top5.stream().map(Long::valueOf).collect(Collectors.toList());
        String idStr = StrUtil.join(",", ids);
        List<UserDTO> users = userService.query()
                .in("id", ids)
                .last("ORDER BY FIELD(id," + idStr + ")")
                .list()
                .stream()
                .map(user -> BeanUtil.copyProperties(user, UserDTO.class))
                .collect(Collectors.toList());
        return Result.ok(users);
    }

    @Override
    public Result saveActivityPost(ActivityPost activityPost) {
        UserDTO user = UserHolder.getUser();
        activityPost.setUserId(user.getId());
        if (!save(activityPost)) {
            return Result.fail("新增笔记失败！");
        }
        List<Follow> follows = followService.query()
                .eq("follow_user_id", user.getId())
                .list();
        long now = System.currentTimeMillis();
        for (Follow follow : follows) {
            stringRedisTemplate.opsForZSet().add(
                    FEED_KEY + follow.getUserId(), activityPost.getId().toString(), now);
        }
        return Result.ok(activityPost.getId());
    }

    @Override
    public Result queryActivityPostOfFollow(Long max, Integer offset) {
        Long userId = UserHolder.getUser().getId();
        Set<ZSetOperations.TypedTuple<String>> tuples = stringRedisTemplate.opsForZSet()
                .reverseRangeByScoreWithScores(FEED_KEY + userId, 0, max, offset, 2);
        if (tuples == null || tuples.isEmpty()) {
            ScrollResult empty = new ScrollResult();
            empty.setList(Collections.emptyList());
            empty.setMinTime(max);
            empty.setOffset(offset);
            return Result.ok(empty);
        }

        List<Long> ids = new ArrayList<>(tuples.size());
        long minTime = 0L;
        int sameTimeCount = 0;
        for (ZSetOperations.TypedTuple<String> tuple : tuples) {
            if (tuple.getValue() == null || tuple.getScore() == null) {
                continue;
            }
            ids.add(Long.valueOf(tuple.getValue()));
            long time = tuple.getScore().longValue();
            if (time == minTime) {
                sameTimeCount++;
            } else {
                minTime = time;
                sameTimeCount = 1;
            }
        }
        if (ids.isEmpty()) {
            return Result.ok();
        }
        int nextOffset = minTime == max ? offset + sameTimeCount : sameTimeCount;
        String idStr = StrUtil.join(",", ids);
        List<ActivityPost> activityPosts = query()
                .in("id", ids)
                .last("ORDER BY FIELD(id," + idStr + ")")
                .list();
        activityPosts.forEach(activityPost -> {
            queryActivityPostUser(activityPost);
            isActivityPostLiked(activityPost);
        });

        ScrollResult result = new ScrollResult();
        result.setList(activityPosts);
        result.setMinTime(minTime);
        result.setOffset(nextOffset);
        return Result.ok(result);
    }

    private void queryActivityPostUser(ActivityPost activityPost) {
        User user = userService.getById(activityPost.getUserId());
        if (user != null) {
            activityPost.setName(user.getNickName());
            activityPost.setIcon(user.getIcon());
        }
    }

    private void isActivityPostLiked(ActivityPost activityPost) {
        UserDTO user = UserHolder.getUser();
        if (user == null) {
            return;
        }
        Double score = stringRedisTemplate.opsForZSet()
                .score(POST_LIKED_KEY + activityPost.getId(), user.getId().toString());
        activityPost.setIsLike(score != null);
    }
}
