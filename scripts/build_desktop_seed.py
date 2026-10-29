"""Build fresh installation and additive desktop catalog SQL from one fixture definition."""
import json, re, tarfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
db = root / 'src/main/resources/db'
base = db / 'base_schema.sql'
if not base.exists() or base.stat().st_size < 1000:
    with tarfile.open(root / 'output/pre-desktop-redesign.tar.gz') as archive:
        original = archive.extractfile('src/main/resources/db/eventflow.sql').read().decode('utf-8-sig')
    definitions = re.findall(r'CREATE TABLE `([^`]+)`.*?\) ENGINE[^;]+;', original, re.S)
    chunks = []
    for name in definitions:
        ddl = re.search(r'CREATE TABLE `' + name + r'`.*?\) ENGINE[^;]+;', original, re.S).group(0)
        ddl = ddl.replace('代金券', '票档').replace('商户id', '场馆id').replace('ROW_FORMAT = Compact', 'ROW_FORMAT = Dynamic')
        chunks.append('DROP TABLE IF EXISTS `' + name + '`;\n' + ddl)
    base.write_text('\n\n'.join(chunks) + '\n', encoding='utf-8')

schema = '''
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
'''
def q(value):
    if isinstance(value, int): return str(value)
    return "'" + str(value).replace('\\','\\\\').replace("'", "''").replace('\n','\\n') + "'"
def insert(table, columns, values):
    return 'INSERT IGNORE INTO ' + table + ' (' + ','.join(columns) + ') VALUES (' + ','.join(values) + ');'
def day(offset, hour='19:30:00'):
    return "TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL %d DAY),'%s')" % (offset,hour)

venues = [
 (1001,'星港滨江音乐公园','杭州','滨江区星光路 88 号','venue-stage','沿江而建的开放式音乐空间。开阔草坪与环形主舞台，让城市的夜色成为演出的一部分。','地铁至滨江文化站，A 口步行约 10 分钟。建议公共交通出行。','户外音乐空间',120.18,30.20),
 (1002,'运河艺术剧院','杭州','拱墅区运河文化路 36 号','venue-theater','以温暖木质声学墙面与环抱式看台构成的城市剧场，承接戏剧、舞蹈、室内音乐及亲子演出。','地铁至运河广场站，B 口步行约 6 分钟。演出前 45 分钟开放入场。','中型多功能剧场',120.15,30.32),
 (1003,'白昼当代艺术馆','上海','徐汇区艺术滨江路 180 号','venue-gallery','自然光穿过连贯的白色展厅，串联装置、影像与当代艺术。以开放的空间连接作品与每一位观众。','地铁至艺术大道站，C 口步行约 8 分钟。展厅内请勿使用闪光灯。','当代艺术展厅',121.46,31.17),
 (1004,'城市运动中心','南京','建邺区新城体育路 16 号','venue-arena','围绕中央赛场设置的专业观赛空间，提供清晰视野与沉浸式赛事体验。','地铁至体育中心站，D 口步行约 5 分钟。请按票面区域入场。','室内体育场馆',118.73,32.00)
]
events = [
 dict(id=1001,title='夜航计划 · 城市音乐节',en='NIGHT CURRENT',subtitle='把日常调成静音，把今晚交给现场。',category='音乐现场',venue=1001,asset='night-current',tag='本月精选',offset=24,price=19900,duration=240,description='沿着江风，走进一场属于城市的夜航。电子、独立流行与现场乐队将在日落后依次登场。\n从第一束舞台灯到最后一次合唱，和朋友一起把这个夜晚留给音乐。\n户外站席，不设固定座位。建议穿着舒适鞋服，提前规划返程。'),
 dict(id=1002,title='月亮与六便士之外',en='BETWEEN THE STARS',subtitle='一场关于选择、远方与自我的当代戏剧。',category='戏剧',venue=1002,asset='between-stars',tag='编辑推荐',offset=14,price=18000,duration=110,description='当熟悉的生活出现一条裂缝，我们会选择留下，还是奔向未知？\n以极简舞台、光影与对白，讲述普通人的一次勇敢出走。\n演出约 110 分钟，无中场休息。建议 12 岁以上观众观看。'),
 dict(id=1003,title='光的形状 · 沉浸艺术展',en='THE SHAPE OF LIGHT',subtitle='在光、尺度与想象之间，重新发现空间。',category='展览',venue=1003,asset='light-field',tag='周末去处',offset=3,price=6800,duration=120,description='光不是背景，而是作品本身。以大型装置和镜面结构，带你走入不断变化的空间。\n适合慢慢观看、自由探索。现场可拍照，请尊重其他观众的观展体验。\n按预约场次入馆，建议预留约两小时。'),
 dict(id=1004,title='爵士不眠夜',en='CITY JAZZ SESSION',subtitle='一支萨克斯，一段即兴，一座未眠的城市。',category='音乐现场',venue=1002,asset='city-jazz',tag='限量早鸟',offset=10,price=12800,duration=100,description='从经典标准曲到充满默契的即兴对话，在温暖声场中感受爵士的自由。\n室内音乐现场，小编制乐队演出。请在演出期间将手机静音。\n本活动为虚构演示项目，演出阵容以正式公告为准。'),
 dict(id=1005,title='城市篮球邀请赛',en='COURTSIDE WEEKEND',subtitle='为每一次突破与绝杀，坐进现场。',category='体育赛事',venue=1004,asset='court-side',tag='全场售罄',offset=18,price=18000,duration=150,description='一场关于速度、配合与热爱的城市篮球对决。\n现场提供清晰的看台观赛视野，请按票档所属区域入场。\n请勿携带激光笔、玻璃容器等影响赛事的物品。'),
 dict(id=1006,title='森林来信 · 亲子偶剧',en='A LETTER FROM THE FOREST',subtitle='和小狐狸一起，寻找送给春天的那封信。',category='亲子',venue=1002,asset='forest-letter',tag='亲子精选',offset=12,price=9800,duration=65,description='手工布偶、层叠森林与温暖音乐，组成孩子们的第一场剧场冒险。\n小狐狸穿过树林，发现每一个小小的善意，都可以成为一封回信。\n建议 3 岁以上儿童观看，成人与儿童均需购票入场。'),
 dict(id=1007,title='蓝色时刻 · 当代舞',en='BLUE HOURS',subtitle='让身体成为语言，让片刻成为永恒。',category='舞蹈',venue=1002,asset='blue-hours',tag='即将开售',offset=28,price=28000,duration=90,description='在蓝色舞台上，身体、呼吸与光线共同书写一段流动的诗。\n当代舞作品由多个段落组成，以动作回应城市生活中那些难以言说的感受。\n演出约 90 分钟，无中场休息。'),
 dict(id=1008,title='今晚有梗 · 脱口秀专场',en='A GOOD NIGHT TO LAUGH',subtitle='把烦恼留在门外，今晚一起笑出声。',category='脱口秀',venue=1002,asset='laugh-club',tag='售票结束',offset=7,price=9900,duration=90,description='熟悉的日常，换一个角度就有了笑点。\n近距离喜剧现场，以生活观察和轻松互动，度过一个没有负担的夜晚。\n建议 16 岁以上观众观看，演出期间请勿录音录像。')
]
parts = [schema]
for i,name in enumerate(['音乐现场','戏剧','展览','体育赛事','亲子','舞蹈','脱口秀'],1):
    parts.append(insert('tb_venue_category',['id','name','icon','sort'],[q(i),q(name),q('/eventflow/mark.svg'),q(i)]))
for v in venues:
    id,name,city,address,asset,intro,transport,capacity,x,y=v
    parts.append(insert('tb_venue',['id','name','type_id','images','area','address','x','y','avg_price','sold','comments','score','open_hours'],[q(id),q(name),'1',q('/imgs/eventflow/'+asset+'.webp'),q(city),q(address),str(x),str(y),'0','0','0','0',q('以活动场次时间为准')]))
    parts.append(insert('tb_venue_profile',['venue_id','city','introduction','transport','capacity'],[q(id),q(city),q(intro),q(transport),q(capacity)]))
parts.append(insert('tb_user',['id','phone','nick_name','icon'],['1001',q('13800000001'),q('EventFlow 编辑部'),q('/imgs/eventflow/avatar.svg')]))
for idx,e in enumerate(events):
    city=next(v[2] for v in venues if v[0]==e['venue'])
    sale_start=day(2 if e['id']==1007 else -7,'10:00:00')
    sale_end=day(-1 if e['id']==1008 else e['offset']+1,'20:00:00')
    parts.append(insert('tb_event',['id','title','subtitle','category','city','venue_id','poster','description','tag','duration_minutes','start_time','end_time','sale_start','sale_end','display_order'],[q(e['id']),q(e['title']),q(e['subtitle']),q(e['category']),q(city),q(e['venue']),q('/imgs/eventflow/'+e['asset']+'.webp'),q(e['description']),q(e['tag']),q(e['duration']),day(e['offset']),day(e['offset']+1,'23:00:00'),sale_start,sale_end,q(idx)]))
    for s in range(2):
        sid=e['id']*10+s
        hour='14:00:00' if e['id'] in (1003,1006) else '19:30:00'
        parts.append(insert('tb_event_session',['id','event_id','label','start_time','end_time'],[q(sid),q(e['id']),q('日间场' if hour=='14:00:00' else '晚间场'),day(e['offset']+s,hour),"DATE_ADD(%s,INTERVAL %d MINUTE)"%(day(e['offset']+s,hour),e['duration'])]))
        for tier in range(2):
            tid=20001+idx*100+s*10+tier
            limited=tier==0 and e['id'] in (1001,1004)
            label='限量早鸟票' if limited else ('标准票' if tier==0 else '优选票')
            price=e['price']+(0 if tier==0 else (12000 if e['id']==1001 else 6000))
            stock=0 if e['id']==1005 else (60 if limited else 180)
            rules='每个账号每票档限购 1 张；一人一票；请按所选场次入场。演示环境未接入真实支付与验票。'
            parts.append(insert('tb_ticket',['id','venue_id','title','sub_title','rules','pay_value','actual_value','type','status'],[q(tid),q(e['venue']),q(label),q('限量发售' if limited else '按场次入场'),q(rules),q(price),q(price),'1' if limited else '0','1']))
            parts.append(insert('tb_seckill_ticket',['ticket_id','stock','begin_time','end_time'],[q(tid),q(stock),sale_start,sale_end]))
            parts.append(insert('tb_event_ticket',['ticket_id','event_id','session_id','display_order'],[q(tid),q(e['id']),q(sid),q(tier)]))
    if idx<4:
        parts.append(insert('tb_activity_post',['id','venue_id','user_id','title','images','content','liked','comments'],[q(5001+idx),q(e['venue']),'1001',q(e['title']+'｜现场灵感'),q('/imgs/eventflow/'+e['asset']+'.webp'),q(e['description']), '0','0']))

upgrade='-- Additive desktop catalog seed. INSERT IGNORE preserves existing orders and inventory.\nSET NAMES utf8mb4;\n'+'\n'.join(parts)+'\n'
(db/'upgrade_desktop_ticketing.sql').write_text(upgrade,encoding='utf-8')
full='-- EventFlow fresh demo database. Run only against a new database.\nSET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS=0;\n'
full+='DROP TABLE IF EXISTS tb_event_ticket,tb_event_session,tb_event,tb_venue_profile;\n'+base.read_text(encoding='utf-8')+'\n'+upgrade+'SET FOREIGN_KEY_CHECKS=1;\n'
(db/'eventflow.sql').write_text(full,encoding='utf-8')
(root/'design/event-fixtures.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
print('Built clean database seed with',len(events),'events and',len(venues),'venues')
