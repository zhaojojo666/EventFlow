-- 1.参数列表
-- 1.1.票种id
local ticketId = ARGV[1]
-- 1.2.用户id
local userId = ARGV[2]
-- 1.3.订单id
local orderId = ARGV[3]

-- 2.数据key
-- 2.1.库存key
local stockKey = 'eventflow:ticket:stock:' .. ticketId
-- 2.2.订单key
local orderKey = 'eventflow:ticket:order:' .. ticketId

-- 3.脚本业务
-- 3.1.先判断用户是否已下单，保证即使库存已售罄也能返回准确的重复下单结果
if(redis.call('sismember', orderKey, userId) == 1) then
    return 2
end
-- 3.2.判断库存是否存在且充足
local stock = tonumber(redis.call('get', stockKey))
if(not stock or stock <= 0) then
    return 1
end
-- 3.3.扣库存 incrby stockKey -1
redis.call('incrby', stockKey, -1)
-- 3.4.下单（保存用户）sadd orderKey userId
redis.call('sadd', orderKey, userId)
-- 3.5.订单事件与库存预扣、一人一单校验在同一Lua中原子完成
-- MAXLEN ~ 使用近似裁剪，避免Stream无上限增长
redis.call('xadd', 'eventflow:stream:ticket-orders', 'MAXLEN', '~', 100000, '*',
        'userId', userId, 'ticketId', ticketId, 'id', orderId)
return 0
