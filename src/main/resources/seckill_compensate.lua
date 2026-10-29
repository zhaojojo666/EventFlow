-- 死信订单幂等补偿脚本
-- ARGV[1] ticketId
-- ARGV[2] userId
-- ARGV[3] orderId

local ticketId = ARGV[1]
local userId = ARGV[2]
local orderId = ARGV[3]

local stockKey = 'eventflow:ticket:stock:' .. ticketId
local orderKey = 'eventflow:ticket:order:' .. ticketId
local compensationKey = 'eventflow:ticket:compensated:' .. orderId

-- 防止死信重复投递时反复回补库存
if (redis.call('set', compensationKey, '1', 'NX', 'EX', 604800) == false) then
    return 0
end

redis.call('incrby', stockKey, 1)
redis.call('srem', orderKey, userId)

-- 保留补偿审计记录，便于对账和排查
redis.call('xadd', 'eventflow:stream:ticket-orders:compensated', 'MAXLEN', '~', 10000, '*',
        'orderId', orderId, 'userId', userId, 'ticketId', ticketId)

return 1
