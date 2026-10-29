from pathlib import Path
root=Path(__file__).resolve().parents[1]/'src/main/resources/static'
pages={
 'index.html':('home','发现现场'), 'events.html':('events','全部活动'), 'venue-list.html':('events','全部活动'),
 'event-detail.html':('detail','活动详情'), 'checkout.html':('checkout','确认订单'), 'orders.html':('orders','我的订单'),
 'order-detail.html':('order-detail','订单详情'), 'info.html':('profile','我的账户'), 'info-edit.html':('profile-edit','编辑资料'),
 'login.html':('login','登录'), 'login2.html':('login','登录'), 'venues.html':('venues','精选场馆'),
 'venue-detail.html':('venue','场馆详情'), 'community.html':('community','现场灵感'),
 'activity-detail.html':('story','分享详情'), 'activity-edit.html':('publish','分享现场'),
 'other-info.html':('public-profile','现场爱好者'), 'help.html':('help','平台使用说明')
}
for file,(page,title) in pages.items():
 (root/file).write_text(f'''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="EventFlow 现场见，发现音乐、戏剧、展览与值得出发的精彩活动。">
  <title>{title} · EventFlow 现场见</title>
  <link rel="icon" type="image/svg+xml" href="/imgs/eventflow/mark.svg">
  <link rel="stylesheet" href="/css/desktop.css">
  <link rel="stylesheet" href="/css/mobile.css">
</head>
<body data-page="{page}">
  <div id="app" v-cloak></div>
  <noscript>请启用 JavaScript 以浏览活动和查询订单。</noscript>
  <script src="/js/vue.js"></script>
  <script src="/js/axios.min.js"></script>
  <script src="/js/desktop.js"></script>
</body>
</html>
''',encoding='utf-8')
assets=root/'imgs/eventflow'
assets.mkdir(parents=True,exist_ok=True)
(assets/'mark.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect x="1" y="1" width="38" height="38" rx="11" fill="#159c84"/><path d="M11 11h18v6a3 3 0 0 0 0 6v6H11v-6a3 3 0 0 0 0-6v-6Z" fill="none" stroke="white" stroke-width="2"/><path d="M23 12v4m0 3v3m0 3v3" stroke="white" stroke-width="2"/></svg>''',encoding='utf-8')
(assets/'avatar.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80"><rect width="80" height="80" rx="40" fill="#fff0e9"/><path d="M25 24h30v10a6 6 0 0 0 0 12v10H25V46a6 6 0 0 0 0-12V24Z" stroke="#159c84" stroke-width="3" fill="none"/></svg>''',encoding='utf-8')
for kind,symbol in [('orders','<path d="M54 39h72v22a9 9 0 0 0 0 18v22H54V79a9 9 0 0 0 0-18V39Z"/><path d="M102 42v12m0 8v12m0 8v12"/>'),('search','<circle cx="81" cy="63" r="26"/><path d="m100 83 23 23M69 63h24"/>'),('error','<path d="m90 30 45 74H45l45-74Z"/><path d="M90 54v24m0 10v2"/>')]:
 svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 130"><ellipse cx="90" cy="112" rx="52" ry="7" fill="#ecece6"/><circle cx="90" cy="64" r="53" fill="#f2f0e8"/><g fill="none" stroke="#c5ba9f" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round">'+symbol+'</g><circle cx="143" cy="34" r="4" fill="#159c84"/><path d="M31 57h8m-4-4v8" stroke="#efb89a" stroke-width="2"/></svg>'
 (assets/('empty-'+kind+'.svg')).write_text(svg,encoding='utf-8')
print('Built',len(pages),'desktop page entry points')
