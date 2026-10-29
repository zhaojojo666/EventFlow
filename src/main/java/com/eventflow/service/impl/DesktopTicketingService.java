package com.eventflow.service.impl;

import com.eventflow.dto.Result;
import com.eventflow.service.ITicketOrderService;
import com.eventflow.utils.UserHolder;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.dao.DuplicateKeyException;
import javax.annotation.Resource;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

/** Desktop catalog and booking views. Existing Stream consumers remain the order writer. */
@Service
public class DesktopTicketingService {
    @Resource private JdbcTemplate jdbc;
    @Resource private ITicketOrderService orders;
    @Resource private StringRedisTemplate redis;

    private static final String CATALOG = "SELECT e.id,e.title,e.subtitle,e.category,e.city,e.venue_id AS venueId," +
            "e.poster,e.description,e.tag,e.duration_minutes AS durationMinutes,e.start_time AS startTime," +
            "e.end_time AS endTime,e.sale_start AS saleStart,e.sale_end AS saleEnd,e.display_order AS displayOrder," +
            "v.name AS venueName,v.address,v.images AS venueImage,COALESCE(p.price,0) AS price," +
            "COALESCE(p.stock,0) AS stock FROM tb_event e JOIN tb_venue v ON v.id=e.venue_id LEFT JOIN " +
            "(SELECT et.event_id,MIN(t.pay_value) AS price,SUM(i.stock) AS stock FROM tb_event_ticket et " +
            "JOIN tb_ticket t ON t.id=et.ticket_id JOIN tb_seckill_ticket i ON i.ticket_id=t.id " +
            "GROUP BY et.event_id) p ON p.event_id=e.id";
    private static final String ORDER_VIEW = "SELECT o.id,o.user_id AS userId,o.status AS orderStatus,o.create_time AS createTime," +
            "o.ticket_id AS ticketId,t.title AS ticketName,t.pay_value AS price,e.id AS eventId,e.title,e.poster,e.city," +
            "v.name AS venueName,v.address,s.start_time AS startTime,s.label AS sessionLabel " +
            "FROM tb_ticket_order o JOIN tb_ticket t ON t.id=o.ticket_id JOIN tb_event_ticket et ON et.ticket_id=t.id " +
            "JOIN tb_event e ON e.id=et.event_id JOIN tb_event_session s ON s.id=et.session_id JOIN tb_venue v ON v.id=e.venue_id";

    private List<Map<String,Object>> rows(String sql, Object... args) {
        List<Map<String,Object>> result = jdbc.queryForList(sql,args);
        for (Map<String,Object> row : result) {
            for (Map.Entry<String,Object> entry : row.entrySet()) {
                if (entry.getValue() instanceof Timestamp) entry.setValue(((Timestamp)entry.getValue()).toLocalDateTime().toString());
                else if (entry.getValue() instanceof LocalDateTime) entry.setValue(entry.getValue().toString());
            }
        }
        return result;
    }
    private LocalDateTime time(Map<String,Object> row,String key) { return LocalDateTime.parse(row.get(key).toString()); }
    private long number(Map<String,Object> row,String key) { return ((Number)row.get(key)).longValue(); }
    private Map<String,Object> status(Map<String,Object> event) {
        LocalDateTime now=LocalDateTime.now();
        String value=now.isAfter(time(event,"saleEnd"))?"ENDED":now.isBefore(time(event,"saleStart"))?"UPCOMING":number(event,"stock")<=0?"SOLD_OUT":"SELLING";
        event.put("saleStatus",value);
        return event;
    }
    public Result catalog(String keyword,String category,String city,String state,String sort,String from,String to,int page,int size) {
        List<Map<String,Object>> all=rows(CATALOG+" ORDER BY e.display_order,e.id");
        all.forEach(this::status);
        List<String> cities=all.stream().map(e->e.get("city").toString()).distinct().collect(Collectors.toList());
        List<Map<String,Object>> filtered=all.stream().filter(e->
                (keyword.isEmpty()||(e.get("title")+" "+e.get("venueName")+" "+e.get("subtitle")).toLowerCase(Locale.ROOT).contains(keyword.toLowerCase(Locale.ROOT))) &&
                (category.isEmpty()||category.equals(e.get("category"))) && (city.isEmpty()||city.equals(e.get("city"))) &&
                (state.isEmpty()||state.equals(e.get("saleStatus"))) &&
                (from.isEmpty()||e.get("startTime").toString().substring(0,10).compareTo(from)>=0) &&
                (to.isEmpty()||e.get("startTime").toString().substring(0,10).compareTo(to)<=0)
        ).collect(Collectors.toList());
        if("price".equals(sort)) filtered.sort(Comparator.comparingLong(e->number(e,"price")));
        if("date".equals(sort)) filtered.sort(Comparator.comparing(e->e.get("startTime").toString()));
        int offset=Math.min(filtered.size(),(page-1)*size);
        Map<String,Object> data=new LinkedHashMap<>();
        data.put("items",filtered.subList(offset,Math.min(filtered.size(),offset+size)));
        data.put("total",filtered.size()); data.put("page",page); data.put("pageSize",size); data.put("cities",cities);
        return Result.ok(data);
    }
    public Result event(Long id) {
        List<Map<String,Object>> found=rows(CATALOG+" WHERE e.id=?",id);
        if(found.isEmpty()) return Result.fail("活动不存在或已下架");
        Map<String,Object> data=status(found.get(0));
        List<Map<String,Object>> sessions=rows("SELECT id,label,start_time AS startTime,end_time AS endTime FROM tb_event_session WHERE event_id=? ORDER BY start_time",id);
        for(Map<String,Object> session:sessions) {
            session.put("tickets",rows("SELECT t.id,t.title,t.sub_title AS subTitle,t.rules,t.pay_value AS price,t.type,i.stock,i.begin_time AS saleStart,i.end_time AS saleEnd " +
                    "FROM tb_event_ticket et JOIN tb_ticket t ON t.id=et.ticket_id JOIN tb_seckill_ticket i ON i.ticket_id=t.id WHERE et.session_id=? AND t.status=1 ORDER BY et.display_order",session.get("id")));
        }
        data.put("sessions",sessions);
        return Result.ok(data);
    }
    public Result venues() {
        return Result.ok(rows("SELECT v.id,v.name,v.images AS image,v.address,p.city,p.introduction,p.transport,p.capacity FROM tb_venue_profile p JOIN tb_venue v ON v.id=p.venue_id ORDER BY v.id"));
    }
    public Result venue(Long id) {
        List<Map<String,Object>> found=rows("SELECT v.id,v.name,v.images AS image,v.address,v.open_hours AS openHours,p.city,p.introduction,p.transport,p.capacity FROM tb_venue_profile p JOIN tb_venue v ON v.id=p.venue_id WHERE v.id=?",id);
        if(found.isEmpty()) return Result.fail("场馆不存在");
        Map<String,Object> data=found.get(0);
        List<Map<String,Object>> events=rows(CATALOG+" WHERE e.venue_id=? ORDER BY e.start_time",id); events.forEach(this::status);
        data.put("events",events); return Result.ok(data);
    }
    public Result book(Long ticketId) {
        List<Map<String,Object>> found=rows("SELECT t.id,t.type,t.status,i.stock,i.begin_time AS saleStart,i.end_time AS saleEnd,s.start_time AS startTime " +
                "FROM tb_event_ticket et JOIN tb_ticket t ON t.id=et.ticket_id JOIN tb_seckill_ticket i ON i.ticket_id=t.id JOIN tb_event_session s ON s.id=et.session_id WHERE t.id=?",ticketId);
        if(found.isEmpty()) return Result.fail("票档不存在");
        Map<String,Object> ticket=found.get(0); LocalDateTime now=LocalDateTime.now();
        if(number(ticket,"status")!=1||now.isAfter(time(ticket,"saleEnd"))||now.isAfter(time(ticket,"startTime"))) return Result.fail("本场次已停止售票");
        if(now.isBefore(time(ticket,"saleStart"))) return Result.fail("尚未开售，请留意开售时间");
        if(number(ticket,"stock")<=0) return Result.fail("该票档已售罄");
        Result result;
        try { result=number(ticket,"type")==1?orders.limitedTicket(ticketId):orders.createTicketOrder(ticketId); }
        catch(DuplicateKeyException ex) { return Result.fail("你已购买过该票档，请在我的订单中查看"); }
        if(!Boolean.TRUE.equals(result.getSuccess())) return result;
        String id=result.getData().toString();
        redis.opsForValue().set("eventflow:booking:request:"+id,UserHolder.getUser().getId().toString(),Duration.ofHours(24));
        Map<String,Object> data=new LinkedHashMap<>();data.put("orderId",id);data.put("state",number(ticket,"type")==1?"PROCESSING":"CREATED");
        return Result.ok(data);
    }
    private Map<String,Object> normalizeOrder(Map<String,Object> row) {
        row.put("id",row.get("id").toString());row.remove("userId");row.put("state","CREATED");return row;
    }
    public Result myOrders(Integer state,int page) {
        String where=" WHERE o.user_id=?";List<Object> args=new ArrayList<>();args.add(UserHolder.getUser().getId());
        if(state!=null){where+=" AND o.status=?";args.add(state);}
        List<Map<String,Object>> list=rows(ORDER_VIEW+where+" ORDER BY o.create_time DESC,o.id DESC",args.toArray());
        list.forEach(this::normalizeOrder);
        int offset=Math.min(list.size(),(page-1)*10);
        Map<String,Object> data=new LinkedHashMap<>();data.put("total",list.size());data.put("items",list.subList(offset,Math.min(list.size(),offset+10)));return Result.ok(data);
    }
    public Result order(Long id) {
        Long user=UserHolder.getUser().getId();
        List<Map<String,Object>> found=rows(ORDER_VIEW+" WHERE o.id=? AND o.user_id=?",id,user);
        if(!found.isEmpty()) return Result.ok(normalizeOrder(found.get(0)));
        if(!user.toString().equals(redis.opsForValue().get("eventflow:booking:request:"+id))) return Result.fail("订单不存在或无权访问");
        Map<String,Object> data=new LinkedHashMap<>();data.put("id",id.toString());
        data.put("state",Boolean.TRUE.equals(redis.hasKey("eventflow:ticket:compensated:"+id))?"FAILED":"PROCESSING");return Result.ok(data);
    }
}
