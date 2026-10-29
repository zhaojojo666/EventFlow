package com.eventflow.service;

import com.eventflow.dto.Result;
import com.eventflow.entity.Venue;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * <p>
 *  服务类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
public interface IVenueService extends IService<Venue> {

    Result queryById(Long id);

    Result update(Venue venue);

    Result queryVenueByType(Integer typeId, Integer current, Double x, Double y);
}
