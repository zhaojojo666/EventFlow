package com.eventflow.controller;


import com.eventflow.dto.Result;
import com.eventflow.service.ITicketOrderService;
import com.eventflow.service.ITicketService;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
@RequestMapping("/ticket-order")
public class TicketOrderController {

    @Resource
    private ITicketOrderService ticketOrderService;

    @PostMapping("seckill/{id}")
    public Result limitedTicket(@PathVariable("id") Long ticketId) {

         return ticketOrderService.limitedTicket(ticketId);
    }
}
