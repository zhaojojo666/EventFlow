"""Apply the mobile-first review layout to the shared application template."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
path=root/'src/main/resources/static/js/desktop.js'
s=path.read_text(encoding='utf-8')
s=s.replace('/* EventFlow desktop application.', '/* EventFlow responsive ticketing application.')
s=s.replace('const layout=`<div>', 'const layout=`<div class="app-frame">')
s=re.sub(r'<nav class="bottom-nav".*?</nav>', '', s, flags=re.S)
s=re.sub(r"(?:homeCategory:'',)+page:document", "homeCategory:'',page:document", s)
start=s.index('    <header class="site-header">') if '<header class="site-header">' in s else s.index('    <header class="app-header">')
end=s.index('</header>',start)+len('</header>')
s=s[:start]+'''    <header class="app-header"><div class="header-wrap"><a v-if="page!=='home'" class="header-leading" href="/" aria-label="返回首页"><ef-icon name="back"></ef-icon></a><span v-else class="header-leading live-dot" aria-hidden="true"><span></span> LIVE</span><a href="/" class="app-brand"><img src="/imgs/eventflow/mark.svg" alt=""><strong>EventFlow</strong><span>现场见</span></a><a :href="user?'/info.html':'/login.html'" class="header-member">{{user?'我的账户':'登录 / 注册'}}</a></div></header>'''+s[end:]
start=s.index('      <template v-if="page===\'home\'">')
end=s.index('      <template v-if="page===\'events\'">',start)
home='''      <template v-if="page==='home'">
        <div class="home-welcome"><span>生活需要一点<span class="mint-word">现场感。</span></span><a href="/help.html">购票指南 <ef-icon name="arrow"></ef-icon></a></div>
        <div class="home-location"><div class="location-choice"><ef-icon name="pin"></ef-icon><select v-model="filters.city" @change="loadHome" aria-label="选择活动城市"><option value="">全国</option><option v-for="city in cities" :key="city">{{city}}</option></select></div><span>为热爱，奔赴下一场</span><a href="/events.html?sort=date"><ef-icon name="calendar"></ef-icon> 演出日历</a></div>
        <nav class="mobile-categories" aria-label="活动分类"><a v-for="c in categories.slice(1)" :key="c.name" :href="'/events.html?category='+encodeURIComponent(c.name)"><ef-icon :name="c.icon"></ef-icon>{{c.name}}</a></nav>
        <a class="service-ribbon" href="/help.html#booking"><div class="service-ribbon-main"><span class="ribbon-symbol"><ef-icon name="ticket"></ef-icon></span><strong>每一次心动，都有迹可循</strong><span class="ribbon-divider">|</span><span>场次清晰 · 订单可查</span><ef-icon class="ribbon-arrow" name="arrow"></ef-icon></div><p>选一场喜欢的演出，让下一次见面发生在现场。</p></a>
        <section class="home-section hot-section"><div class="home-section-head"><div><h2>热门演出 <em>HOT!</em></h2><p>那些不想错过的精彩</p></div><a href="/events.html" aria-label="查看全部热门演出"><ef-icon name="arrow"></ef-icon></a></div><div v-if="loading" class="hot-loading"><div class="skeleton" v-for="n in 4" :key="n"></div></div><ef-empty v-else-if="error" type="error" title="活动暂时没有加载出来" :message="error"><button class="button secondary small" @click="loadHome">重新加载</button></ef-empty><div v-else-if="events.length" class="hot-rail"><a v-for="e in events" :key="e.id" class="hot-card" :href="'/event-detail.html?id='+e.id"><div class="hot-cover"><img :src="e.poster" :alt="e.title+'海报'" loading="lazy"><div class="hot-cover-title"><small>{{english[e.id]}}</small><b>{{e.title.split(' · ')[0]}}</b></div><span class="hot-cover-status" :class="statusOf(e)"><span class="tiny-dot"></span>{{labels[statusOf(e)]}} <span>{{e.city}}</span></span></div><h3>{{e.title}}</h3></a></div><ef-empty v-else title="下一场精彩正在准备中" message="试试切换城市，发现更多现场。"></ef-empty></section>
        <div class="section-divider"></div>
        <section class="home-section ticket-section"><div class="home-section-head"><div><h2>精选票务 <span class="section-count">{{events.length}}<small> 场精彩等你发现</small></span></h2></div><a href="/events.html" aria-label="查看全部票务"><ef-icon name="arrow"></ef-icon></a></div><div class="home-tags"><button v-for="c in categories" :key="c.name" :class="{active:homeCategory===(c.name==='全部活动'?'':c.name)}" @click="homeCategory=c.name==='全部活动'?'':c.name">{{c.name==='全部活动'?'全部':'#'+c.name}}</button></div><div class="ticket-feed"><a class="ticket-feed-item" v-for="e in homeEvents" :key="e.id" :href="'/event-detail.html?id='+e.id"><div class="feed-poster"><img :src="e.poster" :alt="e.title+'海报'" loading="lazy"><span>{{e.category}}</span></div><div class="feed-info"><h3><span class="feed-city">{{e.city}}</span>{{e.title}}</h3><p class="feed-date">{{date(e.startTime)}} <span>起</span></p><p class="feed-venue"><ef-icon name="pin"></ef-icon>{{e.venueName}}</p><div class="feed-bottom"><div><span class="feed-price"><small>¥</small>{{money(e.price)}}<em>起</em></span><span class="feed-tag" v-if="e.tag==='限量早鸟'">限量早鸟</span></div><span class="feed-action" :class="{muted:statusOf(e)!=='SELLING'}">{{statusOf(e)==='SELLING'?'去选票':labels[statusOf(e)]}}<ef-icon name="arrow"></ef-icon></span></div></div></a></div><ef-empty v-if="!loading&&!error&&!homeEvents.length" title="这个分类暂时还没有活动" message="换个分类看看，新的精彩还在路上。"><button class="button secondary small" @click="homeCategory=''">查看全部</button></ef-empty></section>
        <div class="home-end-note"><span></span> 把日子过成值得期待的样子 <span></span></div>
      </template>
'''
s=s[:start]+home+s[end:]
s=s.replace("{{filters.keyword?'搜索：'+filters.keyword:'找到你的下一场心动'}}",'找到你的下一场心动')
s=s.replace("keyword:searchParams.get('keyword')||'',",'')
s=s.replace("keyword:'',",'')
s=re.sub(r"searchText:searchParams\.get\('keyword'\)\|\|'',",'',s)
s=re.sub(r"      search\(\)\{location.href='/events.html\?keyword='\+encodeURIComponent\(this.searchText.trim\(\)\);\},\n",'',s)
s=s.replace("this.searchText='';",'')
s=s.replace("const [catalog,venues]=await Promise.all([api('/events?size=8'),api('/events/venues')]);", "const [catalog,venues]=await Promise.all([api('/events?size=12'+(this.filters.city?'&city='+encodeURIComponent(this.filters.city):'')),api('/events/venues')]);")
if "homeCategory:''" not in s:
 s=s.replace("page:document.body.dataset.page||'home',", "homeCategory:'',page:document.body.dataset.page||'home',")
s=s.replace("computed:{heroEvent()", "computed:{homeEvents(){return this.events.filter(e=>!this.homeCategory||e.category===this.homeCategory);},heroEvent()")
footer_start=s.index('    <footer class="site-footer">')
footer_end=s.index('</footer>',footer_start)+len('</footer>')
s=s[:footer_start]+'''    <footer class="site-footer"><div class="wrap"><a href="/help.html">EventFlow · 让热爱在现场发生</a><p>演示活动与 AI 素材 · 暂未接入真实支付</p></div></footer><nav class="bottom-nav" aria-label="底部导航"><a href="/" :class="{active:page==='home'}"><span><ef-icon name="ticket"></ef-icon></span><b>推荐</b></a><a href="/events.html" :class="{active:['events','detail','checkout','venues','venue'].includes(page)}"><span><ef-icon name="grid"></ef-icon></span><b>分类</b></a><a href="/orders.html" :class="{active:['orders','order-detail'].includes(page)}"><span><ef-icon name="calendar"></ef-icon></span><b>订单</b></a><a :href="user?'/info.html':'/login.html'" :class="{active:['profile','profile-edit','login'].includes(page)}"><span><ef-icon name="user"></ef-icon></span><b>我的</b></a></nav>'''+s[footer_end:]
path.write_text(s,encoding='utf-8')
# Keep generated entry points aligned with the preview stylesheet.
generator=root/'scripts/build_desktop_pages.py'
g=generator.read_text(encoding='utf-8')
if '/css/mobile.css' not in g:
 g=g.replace('  <link rel="stylesheet" href="/css/desktop.css">','  <link rel="stylesheet" href="/css/desktop.css">\n  <link rel="stylesheet" href="/css/mobile.css">')
 generator.write_text(g,encoding='utf-8')
generator.write_text(g.replace('#ef5a35','#159c84'),encoding='utf-8')
mark=root/'src/main/resources/static/imgs/eventflow/mark.svg'
mark.write_text(mark.read_text(encoding='utf-8').replace('#ef5a35','#159c84'),encoding='utf-8')
print('Applied mobile reference layout; removed UI search')
