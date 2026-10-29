package com.eventflow.controller;


import cn.hutool.core.util.StrUtil;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.eventflow.dto.Result;
import com.eventflow.entity.Venue;
import com.eventflow.service.IVenueService;
import com.eventflow.utils.SystemConstants;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;

/**
 * <p>
 * 前端控制器
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@RestController
@RequestMapping("/venue")
public class VenueController {

    @Resource
    public IVenueService venueService;

    /**
     * 根据id查询场馆信息
     * @param id 场馆id
     * @return 场馆详情数据
     */
    @GetMapping("/{id}")
    public Result queryVenueById(@PathVariable("id") Long id) {
        //这里是直接查询数据库
        return venueService.queryById(id);
    }

    /**
     * 新增场馆信息
     * @param venue 场馆数据
     * @return 场馆id
     */
    @PostMapping
    public Result saveVenue(@RequestBody Venue venue) {
        // 写入数据库
        venueService.save(venue);
        // 返回场馆id
        return Result.ok(venue.getId());
    }

    /**
     * 更新场馆信息
     * @param venue 场馆数据
     * @return 无
     */
    @PutMapping
    public Result updateVenue(@RequestBody Venue venue) {
        // 写入数据库
        return venueService.update(venue);
    }

    /**
     * 根据场馆分类分页查询场馆信息
     * @param typeId 场馆分类
     * @param current 页码
     * @return 场馆列表
     */
    @GetMapping("/of/type")
    public Result queryVenueByType(
            @RequestParam("typeId") Integer typeId,
            @RequestParam(value = "current", defaultValue = "1") Integer current,
            @RequestParam(value = "x", required = false) Double x,
            @RequestParam(value = "y", required = false) Double y
    ) {
        return venueService.queryVenueByType(typeId, current, x, y);
    }

    /**
     * 根据场馆名称关键字分页查询场馆信息
     * @param name 场馆名称关键字
     * @param current 页码
     * @return 场馆列表
     */
    @GetMapping("/of/name")
    public Result queryVenueByName(
            @RequestParam(value = "name", required = false) String name,
            @RequestParam(value = "current", defaultValue = "1") Integer current
    ) {
        // 根据类型分页查询
        Page<Venue> page = venueService.query()
                .like(StrUtil.isNotBlank(name), "name", name)
                .page(new Page<>(current, SystemConstants.MAX_PAGE_SIZE));
        // 返回数据
        return Result.ok(page.getRecords());
    }
}
