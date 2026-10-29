package com.eventflow.controller;

import com.eventflow.dto.Result;
import com.eventflow.service.impl.DesktopTicketingService;
import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Value;
import javax.annotation.Resource;
import java.util.*;

@RestController
public class DesktopTicketingController {
    @Resource private DesktopTicketingService desktop;
    @Value("${eventflow.demo-mode:false}") private boolean demoMode;
    @GetMapping("/events/config")
    public Result config(){Map<String,Object> data=new LinkedHashMap<>();data.put("demoMode",demoMode);data.put("smsAvailable",false);return Result.ok(data);}
    @GetMapping("/events")
    public Result catalog(@RequestParam(defaultValue="") String keyword,@RequestParam(defaultValue="") String category,
                          @RequestParam(defaultValue="") String city,@RequestParam(defaultValue="") String state,
                          @RequestParam(defaultValue="") String sort,@RequestParam(defaultValue="") String from,
                          @RequestParam(defaultValue="") String to,@RequestParam(defaultValue="1") int page,
                          @RequestParam(defaultValue="12") int size){
        return desktop.catalog(keyword.trim(),category,city,state,sort,from,to,Math.min(10000,Math.max(1,page)),Math.max(1,Math.min(24,size)));
    }
    @GetMapping("/events/{id}") public Result event(@PathVariable Long id){return desktop.event(id);}
    @GetMapping("/events/venues") public Result venues(){return desktop.venues();}
    @GetMapping("/events/venues/{id}") public Result venue(@PathVariable Long id){return desktop.venue(id);}
    @PostMapping("/booking/orders")
    public Result book(@RequestBody Map<String,Object> body){
        try{return desktop.book(Long.valueOf(String.valueOf(body.get("ticketId"))));}
        catch(NumberFormatException ex){return Result.fail("请选择有效票档");}
    }
    @GetMapping("/booking/orders") public Result myOrders(@RequestParam(required=false) Integer status,@RequestParam(defaultValue="1") int page){return desktop.myOrders(status,Math.min(10000,Math.max(1,page)));}
    @GetMapping("/booking/orders/{id}") public Result order(@PathVariable Long id){return desktop.order(id);}
}
