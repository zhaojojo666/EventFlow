package com.eventflow.controller;


import com.eventflow.dto.Result;
import com.eventflow.entity.Ticket;
import com.eventflow.service.ITicketService;
import org.springframework.web.bind.annotation.*;

import javax.annotation.Resource;

/**
 * <p>
 *  前端控制器
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
@RestController
@RequestMapping("/ticket")
public class TicketController {

    @Resource
    private ITicketService ticketService;

    /**
     * 新增普通券
     * @param ticket 票种信息
     * @return 票种id
     */
    @PostMapping
    public Result addTicket(@RequestBody Ticket ticket) {
        ticketService.save(ticket);
        return Result.ok(ticket.getId());
    }

    /**
     * 新增秒杀券
     * @param ticket 票种信息，包含秒杀信息
     * @return 票种id
     */
    @PostMapping("/seckill")
    public Result addLimitedTicket(@RequestBody Ticket ticket) {
        ticketService.addLimitedTicket(ticket);
        return Result.ok(ticket.getId());
    }

    /**
     * 查询场馆的票种列表
     * @param venueId 场馆id
     * @return 票种列表
     */
    @GetMapping("/list/{venueId}")
    public Result queryTicketOfVenue(@PathVariable("venueId") Long venueId) {
       return ticketService.queryTicketOfVenue(venueId);
    }
}
