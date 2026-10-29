-- Redis Streams可靠秒杀升级脚本
-- 在已存在的 eventflow 数据库中执行一次。

-- 执行前可用以下SQL检查历史重复数据：
-- SELECT user_id, ticket_id, COUNT(*)
-- FROM tb_ticket_order
-- GROUP BY user_id, ticket_id
-- HAVING COUNT(*) > 1;

-- 全量初始化脚本已经包含该索引；下面的写法也支持旧数据库重复执行。
SET @uk_user_ticket_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'tb_ticket_order'
      AND index_name = 'uk_user_ticket'
);
SET @uk_user_ticket_sql = IF(
    @uk_user_ticket_exists = 0,
    'ALTER TABLE tb_ticket_order ADD UNIQUE KEY uk_user_ticket (user_id, ticket_id) USING BTREE',
    'SELECT ''uk_user_ticket already exists'''
);
PREPARE uk_user_ticket_stmt FROM @uk_user_ticket_sql;
EXECUTE uk_user_ticket_stmt;
DEALLOCATE PREPARE uk_user_ticket_stmt;
