package com.eventflow.controller;


import com.eventflow.dto.Result;
import com.eventflow.entity.VenueCategory;
import com.eventflow.service.IVenueCategoryService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
@RequestMapping("/venue-category")
public class VenueCategoryController {
    @Resource
    private IVenueCategoryService typeService;

    @GetMapping("list")
    public Result queryTypeList() {
        List<VenueCategory> typeList = typeService
                .query().orderByAsc("sort").list();
        return Result.ok(typeList);
    }
}
