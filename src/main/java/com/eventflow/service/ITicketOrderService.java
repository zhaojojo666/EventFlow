package com.eventflow.service;

import com.eventflow.dto.Result;
import com.eventflow.entity.TicketOrder;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * <p>
 *  服务类
 * </p>
 *
 * @author 虎哥
 * @since 2021-12-22
 */
public interface ITicketOrderService extends IService<TicketOrder> {

    Result limitedTicket(Long ticketId);

    /**
     * 同步创建订单（旧版入口，参数为票种ID）
     */
    Result createTicketOrder(Long ticketId);

    /**
     * 异步创建订单（秒杀队列消费入口，参数为订单实体）
     */
    void createTicketOrder(TicketOrder ticketOrder);
}
