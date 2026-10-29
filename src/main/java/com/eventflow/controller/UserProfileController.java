package com.eventflow.controller;

import com.eventflow.dto.Result;
import com.eventflow.entity.User;
import com.eventflow.entity.UserInfo;
import com.eventflow.service.IUserService;
import com.eventflow.service.IUserInfoService;
import com.eventflow.utils.UserHolder;
import com.eventflow.utils.RedisConstants;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import javax.annotation.Resource;
import java.util.Map;

@RestController
public class UserProfileController {
    @Resource private IUserService users;
    @Resource private IUserInfoService infoService;
    @Resource private StringRedisTemplate redis;
    @PutMapping("/user/profile")
    @Transactional
    public Result update(@RequestBody Map<String,String> body,@RequestHeader("authorization") String token) {
        String name=body.getOrDefault("nickName","").trim();
        String city=body.getOrDefault("city","").trim();
        String introduction=body.getOrDefault("introduce","").trim();
        if(name.isEmpty()||name.length()>32||city.length()>32||introduction.length()>128) return Result.fail("请检查昵称、城市和简介的长度");
        Long id=UserHolder.getUser().getId();
        User user=new User();user.setId(id);user.setNickName(name);
        users.updateById(user);
        UserInfo info=infoService.getById(id);
        if(info==null) { info=new UserInfo();info.setUserId(id); }
        info.setCity(city);info.setIntroduce(introduction);infoService.saveOrUpdate(info);
        redis.opsForHash().put(RedisConstants.LOGIN_USER_KEY+token,"nickName",name);
        return Result.ok();
    }
}
