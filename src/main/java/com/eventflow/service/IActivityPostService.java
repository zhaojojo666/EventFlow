package com.eventflow.service;

import com.eventflow.dto.Result;
import com.eventflow.entity.ActivityPost;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * <p>
 *  服务类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
public interface IActivityPostService extends IService<ActivityPost> {

    Result queryHotActivityPost(Integer current);

    Result queryActivityPostById(Long id);

    Result likeActivityPost(Long id);

    Result queryActivityPostLikes(Long id);

    Result saveActivityPost(ActivityPost activityPost);

    Result queryActivityPostOfFollow(Long max, Integer offset);
}
