package com.eventflow.controller;


import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.eventflow.dto.Result;
import com.eventflow.dto.UserDTO;
import com.eventflow.entity.ActivityPost;
import com.eventflow.service.IActivityPostService;
import com.eventflow.utils.SystemConstants;
import com.eventflow.utils.UserHolder;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;
import java.util.List;

/**
 * <p>
 * 前端控制器
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@RestController
@RequestMapping("/activity-post")
public class ActivityPostController {

    @Resource
    private IActivityPostService activityPostService;
    @PostMapping
    public Result saveActivityPost(@RequestBody ActivityPost activityPost) {
        return activityPostService.saveActivityPost(activityPost);
    }

    @PutMapping("/like/{id}")
    public Result likeActivityPost(@PathVariable("id") Long id) {
        return activityPostService.likeActivityPost(id);
    }

    @GetMapping("/of/me")
    public Result queryMyActivityPost(@RequestParam(value = "current", defaultValue = "1") Integer current) {
        // 获取登录用户
        UserDTO user = UserHolder.getUser();
        // 根据用户查询
        Page<ActivityPost> page = activityPostService.query()
                .eq("user_id", user.getId()).page(new Page<>(current, SystemConstants.MAX_PAGE_SIZE));
        // 获取当前页数据
        List<ActivityPost> records = page.getRecords();
        return Result.ok(records);
    }

    @GetMapping("/hot")
    public Result queryHotActivityPost(@RequestParam(value = "current", defaultValue = "1") Integer current) {
        return activityPostService.queryHotActivityPost(current);
    }

    @GetMapping("/{id}")
    public Result queryActivityPostById(@PathVariable("id") Long id) {
        return activityPostService.queryActivityPostById(id);
    }

    @GetMapping("/likes/{id}")
    public Result queryActivityPostLikes(@PathVariable("id") Long id) {
        return activityPostService.queryActivityPostLikes(id);
    }

    @GetMapping("/of/user")
    public Result queryActivityPostByUserId(
            @RequestParam(value = "current", defaultValue = "1") Integer current,
            @RequestParam("id") Long id) {
        Page<ActivityPost> page = activityPostService.query()
                .eq("user_id", id)
                .page(new Page<>(current, SystemConstants.MAX_PAGE_SIZE));
        return Result.ok(page.getRecords());
    }

    @GetMapping("/of/follow")
    public Result queryActivityPostOfFollow(
            @RequestParam("lastId") Long max,
            @RequestParam(value = "offset", defaultValue = "0") Integer offset) {
        return activityPostService.queryActivityPostOfFollow(max, offset);
    }
}
