-- EventFlow fresh demo database. Run only against a new database.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS tb_event_ticket,tb_event_session,tb_event,tb_venue_profile;
DROP TABLE IF EXISTS `tb_activity_post`;
CREATE TABLE `tb_activity_post`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `venue_id` bigint(20) NOT NULL COMMENT '场馆id',

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '用户id',

  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标题',

  `images` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '活动的照片，最多9张，多张以\",\"隔开',

  `content` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '活动的文字描述',

  `liked` int(8) UNSIGNED NULL DEFAULT 0 COMMENT '点赞数量',

  `comments` int(8) UNSIGNED NULL DEFAULT NULL COMMENT '评论数量',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_activity_comment`;
CREATE TABLE `tb_activity_comment`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '用户id',

  `activity_post_id` bigint(20) UNSIGNED NOT NULL COMMENT '活动id',

  `parent_id` bigint(20) UNSIGNED NOT NULL COMMENT '关联的1级评论id，如果是一级评论，则值为0',

  `answer_id` bigint(20) UNSIGNED NOT NULL COMMENT '回复的评论id',

  `content` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '回复的内容',

  `liked` int(8) UNSIGNED NULL DEFAULT NULL COMMENT '点赞数',

  `status` tinyint(1) UNSIGNED NULL DEFAULT NULL COMMENT '状态，0：正常，1：被举报，2：禁止查看',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_follow`;
CREATE TABLE `tb_follow`  (

  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '用户id',

  `follow_user_id` bigint(20) UNSIGNED NOT NULL COMMENT '关联的用户id',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_seckill_ticket`;
CREATE TABLE `tb_seckill_ticket`  (

  `ticket_id` bigint(20) UNSIGNED NOT NULL COMMENT '关联的票种的id',

  `stock` int(8) NOT NULL COMMENT '库存',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `begin_time` datetime NOT NULL COMMENT '生效时间',
  `end_time` datetime NOT NULL COMMENT '失效时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`ticket_id`) USING BTREE

) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '秒杀票种表，与票种是一对一关系' ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_venue`;
CREATE TABLE `tb_venue`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '场馆名称',

  `type_id` bigint(20) UNSIGNED NOT NULL COMMENT '场馆分类的id',

  `images` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '场馆图片，多个图片以\',\'隔开',

  `area` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '商圈，例如陆家嘴',

  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '地址',

  `x` double UNSIGNED NOT NULL COMMENT '经度',

  `y` double UNSIGNED NOT NULL COMMENT '维度',

  `avg_price` bigint(10) UNSIGNED NULL DEFAULT NULL COMMENT '均价，取整数',

  `sold` int(10) UNSIGNED ZEROFILL NOT NULL COMMENT '销量',

  `comments` int(10) UNSIGNED ZEROFILL NOT NULL COMMENT '评论数量',

  `score` int(2) UNSIGNED ZEROFILL NOT NULL COMMENT '评分，1~5分，乘10保存，避免小数',

  `open_hours` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '营业时间，例如 10:00-22:00',

  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE,

  INDEX `foreign_key_type`(`type_id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_venue_category`;
CREATE TABLE `tb_venue_category`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '类型名称',

  `icon` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '图标',

  `sort` int(3) UNSIGNED NULL DEFAULT NULL COMMENT '顺序',

  `create_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 11 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_sign`;
CREATE TABLE `tb_sign`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '用户id',

  `year` year NOT NULL COMMENT '签到的年',

  `month` tinyint(2) NOT NULL COMMENT '签到的月',

  `date` date NOT NULL COMMENT '签到的日期',

  `is_backup` tinyint(1) UNSIGNED NULL DEFAULT NULL COMMENT '是否补签',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_user`;
CREATE TABLE `tb_user`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `phone` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '手机号码',

  `password` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '密码，加密存储',

  `nick_name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '昵称，默认是用户id',

  `icon` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '人物头像',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE,

  UNIQUE INDEX `uniqe_key_phone`(`phone`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 1010 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_user_info`;
CREATE TABLE `tb_user_info`  (

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '主键，用户id',

  `city` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '城市名称',

  `introduce` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '个人介绍，不要超过128个字符',

  `fans` int(8) UNSIGNED NULL DEFAULT 0 COMMENT '粉丝数量',

  `followee` int(8) UNSIGNED NULL DEFAULT 0 COMMENT '关注的人的数量',

  `gender` tinyint(1) UNSIGNED NULL DEFAULT 0 COMMENT '性别，0：男，1：女',

  `birthday` date NULL DEFAULT NULL COMMENT '生日',

  `credits` int(8) UNSIGNED NULL DEFAULT 0 COMMENT '积分',

  `level` tinyint(1) UNSIGNED NULL DEFAULT 0 COMMENT '会员级别，0~9级,0代表未开通会员',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`user_id`) USING BTREE

) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_ticket`;
CREATE TABLE `tb_ticket`  (

  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',

  `venue_id` bigint(20) UNSIGNED NULL DEFAULT NULL COMMENT '场馆id',

  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '票档标题',

  `sub_title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '副标题',

  `rules` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '使用规则',

  `pay_value` bigint(10) UNSIGNED NOT NULL COMMENT '支付金额，单位是分。例如200代表2元',

  `actual_value` bigint(10) NOT NULL COMMENT '抵扣金额，单位是分。例如200代表2元',

  `type` tinyint(1) UNSIGNED NOT NULL DEFAULT 0 COMMENT '0,普通券；1,秒杀券',

  `status` tinyint(1) UNSIGNED NOT NULL DEFAULT 1 COMMENT '1,上架; 2,下架; 3,过期',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE

) ENGINE = InnoDB AUTO_INCREMENT = 10 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

DROP TABLE IF EXISTS `tb_ticket_order`;
CREATE TABLE `tb_ticket_order`  (

  `id` bigint(20) NOT NULL COMMENT '主键',

  `user_id` bigint(20) UNSIGNED NOT NULL COMMENT '下单的用户id',

  `ticket_id` bigint(20) UNSIGNED NOT NULL COMMENT '购买的票档id',

  `pay_type` tinyint(1) UNSIGNED NOT NULL DEFAULT 1 COMMENT '支付方式 1：余额支付；2：支付宝；3：微信',

  `status` tinyint(1) UNSIGNED NOT NULL DEFAULT 1 COMMENT '订单状态，1：未支付；2：已支付；3：已核销；4：已取消；5：退款中；6：已退款',

  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下单时间',

  `pay_time` timestamp NULL DEFAULT NULL COMMENT '支付时间',

  `use_time` timestamp NULL DEFAULT NULL COMMENT '核销时间',

  `refund_time` timestamp NULL DEFAULT NULL COMMENT '退款时间',

  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_ticket` (`user_id`, `ticket_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- Additive desktop catalog seed. INSERT IGNORE preserves existing orders and inventory.
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS tb_venue_profile (
 venue_id BIGINT UNSIGNED PRIMARY KEY, city VARCHAR(32) NOT NULL,
 introduction TEXT NOT NULL, transport VARCHAR(512) NOT NULL, capacity VARCHAR(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS tb_event (
 id BIGINT UNSIGNED PRIMARY KEY,title VARCHAR(160) NOT NULL,subtitle VARCHAR(255) NOT NULL,
 category VARCHAR(32) NOT NULL,city VARCHAR(32) NOT NULL,venue_id BIGINT UNSIGNED NOT NULL,
 poster VARCHAR(255) NOT NULL,description TEXT NOT NULL,tag VARCHAR(64) NOT NULL,
 duration_minutes INT NOT NULL,start_time DATETIME NOT NULL,end_time DATETIME NOT NULL,
 sale_start DATETIME NOT NULL,sale_end DATETIME NOT NULL,display_order INT NOT NULL DEFAULT 0,
 INDEX idx_event_city_category(city,category),INDEX idx_event_start(start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS tb_event_session (
 id BIGINT UNSIGNED PRIMARY KEY,event_id BIGINT UNSIGNED NOT NULL,label VARCHAR(100) NOT NULL,
 start_time DATETIME NOT NULL,end_time DATETIME NOT NULL,INDEX idx_session_event(event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS tb_event_ticket (
 ticket_id BIGINT UNSIGNED PRIMARY KEY,event_id BIGINT UNSIGNED NOT NULL,session_id BIGINT UNSIGNED NOT NULL,
 display_order INT NOT NULL DEFAULT 0,INDEX idx_ticket_event(event_id),INDEX idx_ticket_session(session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (1,'音乐现场','/eventflow/mark.svg',1);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (2,'戏剧','/eventflow/mark.svg',2);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (3,'展览','/eventflow/mark.svg',3);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (4,'体育赛事','/eventflow/mark.svg',4);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (5,'亲子','/eventflow/mark.svg',5);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (6,'舞蹈','/eventflow/mark.svg',6);
INSERT IGNORE INTO tb_venue_category (id,name,icon,sort) VALUES (7,'脱口秀','/eventflow/mark.svg',7);
INSERT IGNORE INTO tb_venue (id,name,type_id,images,area,address,x,y,avg_price,sold,comments,score,open_hours) VALUES (1001,'星港滨江音乐公园',1,'/imgs/eventflow/venue-stage.webp','杭州','滨江区星光路 88 号',120.18,30.2,0,0,0,0,'以活动场次时间为准');
INSERT IGNORE INTO tb_venue_profile (venue_id,city,introduction,transport,capacity) VALUES (1001,'杭州','沿江而建的开放式音乐空间。开阔草坪与环形主舞台，让城市的夜色成为演出的一部分。','地铁至滨江文化站，A 口步行约 10 分钟。建议公共交通出行。','户外音乐空间');
INSERT IGNORE INTO tb_venue (id,name,type_id,images,area,address,x,y,avg_price,sold,comments,score,open_hours) VALUES (1002,'运河艺术剧院',1,'/imgs/eventflow/venue-theater.webp','杭州','拱墅区运河文化路 36 号',120.15,30.32,0,0,0,0,'以活动场次时间为准');
INSERT IGNORE INTO tb_venue_profile (venue_id,city,introduction,transport,capacity) VALUES (1002,'杭州','以温暖木质声学墙面与环抱式看台构成的城市剧场，承接戏剧、舞蹈、室内音乐及亲子演出。','地铁至运河广场站，B 口步行约 6 分钟。演出前 45 分钟开放入场。','中型多功能剧场');
INSERT IGNORE INTO tb_venue (id,name,type_id,images,area,address,x,y,avg_price,sold,comments,score,open_hours) VALUES (1003,'白昼当代艺术馆',1,'/imgs/eventflow/venue-gallery.webp','上海','徐汇区艺术滨江路 180 号',121.46,31.17,0,0,0,0,'以活动场次时间为准');
INSERT IGNORE INTO tb_venue_profile (venue_id,city,introduction,transport,capacity) VALUES (1003,'上海','自然光穿过连贯的白色展厅，串联装置、影像与当代艺术。以开放的空间连接作品与每一位观众。','地铁至艺术大道站，C 口步行约 8 分钟。展厅内请勿使用闪光灯。','当代艺术展厅');
INSERT IGNORE INTO tb_venue (id,name,type_id,images,area,address,x,y,avg_price,sold,comments,score,open_hours) VALUES (1004,'城市运动中心',1,'/imgs/eventflow/venue-arena.webp','南京','建邺区新城体育路 16 号',118.73,32.0,0,0,0,0,'以活动场次时间为准');
INSERT IGNORE INTO tb_venue_profile (venue_id,city,introduction,transport,capacity) VALUES (1004,'南京','围绕中央赛场设置的专业观赛空间，提供清晰视野与沉浸式赛事体验。','地铁至体育中心站，D 口步行约 5 分钟。请按票面区域入场。','室内体育场馆');
INSERT IGNORE INTO tb_user (id,phone,nick_name,icon) VALUES (1001,'13800000001','EventFlow 编辑部','/imgs/eventflow/avatar.svg');
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1001,'夜航计划 · 城市音乐节','把日常调成静音，把今晚交给现场。','音乐现场','杭州',1001,'/imgs/eventflow/night-current.webp','沿着江风，走进一场属于城市的夜航。电子、独立流行与现场乐队将在日落后依次登场。\n从第一束舞台灯到最后一次合唱，和朋友一起把这个夜晚留给音乐。\n户外站席，不设固定座位。建议穿着舒适鞋服，提前规划返程。','本月精选',240,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 24 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'20:00:00'),0);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10010,1001,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 24 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 24 DAY),'19:30:00'),INTERVAL 240 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20001,1001,'限量早鸟票','限量发售','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',19900,19900,1,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20001,60,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20001,1001,10010,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20002,1001,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',31900,31900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20002,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20002,1001,10010,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10011,1001,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'19:30:00'),INTERVAL 240 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20011,1001,'限量早鸟票','限量发售','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',19900,19900,1,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20011,60,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20011,1001,10011,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20012,1001,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',31900,31900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20012,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 25 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20012,1001,10011,1);
INSERT IGNORE INTO tb_activity_post (id,venue_id,user_id,title,images,content,liked,comments) VALUES (5001,1001,1001,'夜航计划 · 城市音乐节｜现场灵感','/imgs/eventflow/night-current.webp','沿着江风，走进一场属于城市的夜航。电子、独立流行与现场乐队将在日落后依次登场。\n从第一束舞台灯到最后一次合唱，和朋友一起把这个夜晚留给音乐。\n户外站席，不设固定座位。建议穿着舒适鞋服，提前规划返程。',0,0);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1002,'月亮与六便士之外','一场关于选择、远方与自我的当代戏剧。','戏剧','杭州',1002,'/imgs/eventflow/between-stars.webp','当熟悉的生活出现一条裂缝，我们会选择留下，还是奔向未知？\n以极简舞台、光影与对白，讲述普通人的一次勇敢出走。\n演出约 110 分钟，无中场休息。建议 12 岁以上观众观看。','编辑推荐',110,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'20:00:00'),1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10020,1002,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY),'19:30:00'),INTERVAL 110 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20101,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18000,18000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20101,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20101,1002,10020,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20102,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',24000,24000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20102,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20102,1002,10020,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10021,1002,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'19:30:00'),INTERVAL 110 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20111,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18000,18000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20111,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20111,1002,10021,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20112,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',24000,24000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20112,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 15 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20112,1002,10021,1);
INSERT IGNORE INTO tb_activity_post (id,venue_id,user_id,title,images,content,liked,comments) VALUES (5002,1002,1001,'月亮与六便士之外｜现场灵感','/imgs/eventflow/between-stars.webp','当熟悉的生活出现一条裂缝，我们会选择留下，还是奔向未知？\n以极简舞台、光影与对白，讲述普通人的一次勇敢出走。\n演出约 110 分钟，无中场休息。建议 12 岁以上观众观看。',0,0);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1003,'光的形状 · 沉浸艺术展','在光、尺度与想象之间，重新发现空间。','展览','上海',1003,'/imgs/eventflow/light-field.webp','光不是背景，而是作品本身。以大型装置和镜面结构，带你走入不断变化的空间。\n适合慢慢观看、自由探索。现场可拍照，请尊重其他观众的观展体验。\n按预约场次入馆，建议预留约两小时。','周末去处',120,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'20:00:00'),2);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10030,1003,'日间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY),'14:00:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 3 DAY),'14:00:00'),INTERVAL 120 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20201,1003,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',6800,6800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20201,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20201,1003,10030,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20202,1003,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',12800,12800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20202,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20202,1003,10030,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10031,1003,'日间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'14:00:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'14:00:00'),INTERVAL 120 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20211,1003,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',6800,6800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20211,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20211,1003,10031,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20212,1003,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',12800,12800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20212,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 4 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20212,1003,10031,1);
INSERT IGNORE INTO tb_activity_post (id,venue_id,user_id,title,images,content,liked,comments) VALUES (5003,1003,1001,'光的形状 · 沉浸艺术展｜现场灵感','/imgs/eventflow/light-field.webp','光不是背景，而是作品本身。以大型装置和镜面结构，带你走入不断变化的空间。\n适合慢慢观看、自由探索。现场可拍照，请尊重其他观众的观展体验。\n按预约场次入馆，建议预留约两小时。',0,0);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1004,'爵士不眠夜','一支萨克斯，一段即兴，一座未眠的城市。','音乐现场','杭州',1002,'/imgs/eventflow/city-jazz.webp','从经典标准曲到充满默契的即兴对话，在温暖声场中感受爵士的自由。\n室内音乐现场，小编制乐队演出。请在演出期间将手机静音。\n本活动为虚构演示项目，演出阵容以正式公告为准。','限量早鸟',100,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 10 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'20:00:00'),3);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10040,1004,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 10 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 10 DAY),'19:30:00'),INTERVAL 100 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20301,1002,'限量早鸟票','限量发售','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',12800,12800,1,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20301,60,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20301,1004,10040,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20302,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18800,18800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20302,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20302,1004,10040,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10041,1004,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'19:30:00'),INTERVAL 100 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20311,1002,'限量早鸟票','限量发售','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',12800,12800,1,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20311,60,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20311,1004,10041,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20312,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18800,18800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20312,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20312,1004,10041,1);
INSERT IGNORE INTO tb_activity_post (id,venue_id,user_id,title,images,content,liked,comments) VALUES (5004,1002,1001,'爵士不眠夜｜现场灵感','/imgs/eventflow/city-jazz.webp','从经典标准曲到充满默契的即兴对话，在温暖声场中感受爵士的自由。\n室内音乐现场，小编制乐队演出。请在演出期间将手机静音。\n本活动为虚构演示项目，演出阵容以正式公告为准。',0,0);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1005,'城市篮球邀请赛','为每一次突破与绝杀，坐进现场。','体育赛事','南京',1004,'/imgs/eventflow/court-side.webp','一场关于速度、配合与热爱的城市篮球对决。\n现场提供清晰的看台观赛视野，请按票档所属区域入场。\n请勿携带激光笔、玻璃容器等影响赛事的物品。','全场售罄',150,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 18 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'20:00:00'),4);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10050,1005,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 18 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 18 DAY),'19:30:00'),INTERVAL 150 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20401,1004,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18000,18000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20401,0,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20401,1005,10050,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20402,1004,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',24000,24000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20402,0,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20402,1005,10050,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10051,1005,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'19:30:00'),INTERVAL 150 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20411,1004,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',18000,18000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20411,0,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20411,1005,10051,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20412,1004,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',24000,24000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20412,0,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 19 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20412,1005,10051,1);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1006,'森林来信 · 亲子偶剧','和小狐狸一起，寻找送给春天的那封信。','亲子','杭州',1002,'/imgs/eventflow/forest-letter.webp','手工布偶、层叠森林与温暖音乐，组成孩子们的第一场剧场冒险。\n小狐狸穿过树林，发现每一个小小的善意，都可以成为一封回信。\n建议 3 岁以上儿童观看，成人与儿童均需购票入场。','亲子精选',65,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 12 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'20:00:00'),5);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10060,1006,'日间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 12 DAY),'14:00:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 12 DAY),'14:00:00'),INTERVAL 65 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20501,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',9800,9800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20501,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20501,1006,10060,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20502,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',15800,15800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20502,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20502,1006,10060,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10061,1006,'日间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'14:00:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'14:00:00'),INTERVAL 65 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20511,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',9800,9800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20511,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20511,1006,10061,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20512,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',15800,15800,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20512,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 13 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20512,1006,10061,1);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1007,'蓝色时刻 · 当代舞','让身体成为语言，让片刻成为永恒。','舞蹈','杭州',1002,'/imgs/eventflow/blue-hours.webp','在蓝色舞台上，身体、呼吸与光线共同书写一段流动的诗。\n当代舞作品由多个段落组成，以动作回应城市生活中那些难以言说的感受。\n演出约 90 分钟，无中场休息。','即将开售',90,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 28 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'20:00:00'),6);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10070,1007,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 28 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 28 DAY),'19:30:00'),INTERVAL 90 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20601,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',28000,28000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20601,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20601,1007,10070,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20602,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',34000,34000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20602,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20602,1007,10070,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10071,1007,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'19:30:00'),INTERVAL 90 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20611,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',28000,28000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20611,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20611,1007,10071,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20612,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',34000,34000,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20612,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 29 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20612,1007,10071,1);
INSERT IGNORE INTO tb_event (id,title,subtitle,category,city,venue_id,poster,description,tag,duration_minutes,start_time,end_time,sale_start,sale_end,display_order) VALUES (1008,'今晚有梗 · 脱口秀专场','把烦恼留在门外，今晚一起笑出声。','脱口秀','杭州',1002,'/imgs/eventflow/laugh-club.webp','熟悉的日常，换一个角度就有了笑点。\n近距离喜剧现场，以生活观察和轻松互动，度过一个没有负担的夜晚。\n建议 16 岁以上观众观看，演出期间请勿录音录像。','售票结束',90,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY),'19:30:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 8 DAY),'23:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -1 DAY),'20:00:00'),7);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10080,1008,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY),'19:30:00'),INTERVAL 90 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20701,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',9900,9900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20701,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -1 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20701,1008,10080,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20702,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',15900,15900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20702,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -1 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20702,1008,10080,1);
INSERT IGNORE INTO tb_event_session (id,event_id,label,start_time,end_time) VALUES (10081,1008,'晚间场',TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 8 DAY),'19:30:00'),DATE_ADD(TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 8 DAY),'19:30:00'),INTERVAL 90 MINUTE));
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20711,1002,'标准票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',9900,9900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20711,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -1 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20711,1008,10081,0);
INSERT IGNORE INTO tb_ticket (id,venue_id,title,sub_title,rules,pay_value,actual_value,type,status) VALUES (20712,1002,'优选票','按场次入场','每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。',15900,15900,0,1);
INSERT IGNORE INTO tb_seckill_ticket (ticket_id,stock,begin_time,end_time) VALUES (20712,180,TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -7 DAY),'10:00:00'),TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL -1 DAY),'20:00:00'));
INSERT IGNORE INTO tb_event_ticket (ticket_id,event_id,session_id,display_order) VALUES (20712,1008,10081,1);
SET FOREIGN_KEY_CHECKS=1;
