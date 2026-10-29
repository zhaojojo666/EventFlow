/* Functional smoke check against the isolated local demo database. */
const assert=require('node:assert/strict');
const fs=require('node:fs');
fs.mkdirSync('output',{recursive:true});
const base=process.env.EVENTFLOW_BASE_URL||'http://127.0.0.1:8082';
const passed=[];
async function request(path,token,method='GET',data){
  const headers={};if(token)headers.authorization=token;
  if(data!==undefined&&!(data instanceof FormData))headers['Content-Type']='application/json';
  const response=await fetch(base+path,{method,headers,body:data===undefined?undefined:data instanceof FormData?data:JSON.stringify(data)});
  const raw=await response.text();const body=raw?JSON.parse(raw):{};return {http:response.status,...body};
}
async function account(phone){
  const code=await request('/user/code?phone='+phone,null,'POST');assert.equal(code.success,true);assert.match(code.data.demoCode,/^\d{6}$/);
  const login=await request('/user/login',null,'POST',{phone,code:code.data.demoCode});assert.equal(login.success,true);assert.equal(typeof login.data,'string');return login.data;
}
async function created(id,token){
  const until=Date.now()+10000;
  while(Date.now()<until){const result=await request('/booking/orders/'+id,token);assert.equal(result.success,true);if(result.data.state==='CREATED')return result.data;if(result.data.state==='FAILED')throw Error('Order compensation reported failure');await new Promise(r=>setTimeout(r,250));}
  throw Error('Order did not persist within ten seconds');
}
(async()=>{
  const config=await request('/events/config');assert.equal(config.data.demoMode,true);
  const catalog=await request('/events');assert.equal(catalog.success,true);assert.equal(catalog.data.total,8);
  const venues=await request('/events/venues');assert.equal(venues.data.length,4);passed.push('活动列表、场馆列表与演示配置');
  const anonymous=await request('/booking/orders');assert.equal(anonymous.http,401);passed.push('未登录禁止查询订单');
  const suffix=String(Date.now()).slice(-8);const token=await account('199'+suffix);
  const me=await request('/user/me',token);assert.equal(me.success,true);passed.push('演示验证码登录与身份查询');
  const standard=await request('/events/1002');const standardTicket=standard.data.sessions[0].tickets[0];
  const standardBooking=await request('/booking/orders',token,'POST',{ticketId:standardTicket.id});assert.equal(standardBooking.success,true);assert.equal(typeof standardBooking.data.orderId,'string');
  const standardOrder=await created(standardBooking.data.orderId,token);assert.equal(standardOrder.title,standard.data.title);assert.equal(standardOrder.orderStatus,1);passed.push('普通票下单、订单落库与详情查询');
  const repeat=await request('/booking/orders',token,'POST',{ticketId:standardTicket.id});assert.equal(repeat.success,false);passed.push('普通票重复购买拦截');
  const limited=await request('/events/1001');const limitedTicket=limited.data.sessions[0].tickets.find(t=>t.type===1);
  const limitedBooking=await request('/booking/orders',token,'POST',{ticketId:limitedTicket.id});assert.equal(limitedBooking.success,true);assert.equal(limitedBooking.data.state,'PROCESSING');
  const limitedOrder=await created(limitedBooking.data.orderId,token);assert.equal(limitedOrder.ticketId,limitedTicket.id);passed.push('限量票提交、Redis Stream 消费与最终订单查询');
  const limitedRepeat=await request('/booking/orders',token,'POST',{ticketId:limitedTicket.id});assert.equal(limitedRepeat.success,false);passed.push('限量票重复购买拦截');
  const orders=await request('/booking/orders',token);assert.equal(orders.data.total,2);assert.ok(orders.data.items.every(o=>typeof o.id==='string'));passed.push('本人订单列表与大整数订单号精度');
  for(const id of [1005,1007,1008]){const event=await request('/events/'+id);const result=await request('/booking/orders',token,'POST',{ticketId:event.data.sessions[0].tickets[0].id});assert.equal(result.success,false);}passed.push('售罄、未开售及售票结束拦截');
  const other=await account('188'+suffix);const forbidden=await request('/booking/orders/'+standardOrder.id,other);assert.equal(forbidden.success,false);passed.push('禁止查询其他用户订单');
  const profile=await request('/user/profile',token,'PUT',{nickName:'本地功能验证',city:'杭州',introduce:'票务流程验证账号'});assert.equal(profile.success,true);
  const updated=await request('/user/me',token);assert.equal(updated.data.nickName,'本地功能验证');passed.push('资料保存与登录信息刷新');
  const image=fs.readFileSync('src/main/resources/static/imgs/eventflow/between-stars.webp');
  const form=new FormData();form.append('file',new Blob([image],{type:'image/webp'}),'backend-check.webp');
  const upload=await request('/upload/activity-post',token,'POST',form);assert.equal(upload.success,true);
  const imageResponse=await fetch(base+'/imgs'+upload.data);assert.equal(imageResponse.status,200);assert.equal((await imageResponse.arrayBuffer()).byteLength,image.length);
  const deleted=await request('/upload/activity-post/delete?name='+encodeURIComponent('/imgs'+upload.data),token);assert.equal(deleted.success,true);passed.push('图片上传、访问与删除');
  await request('/user/logout',token,'POST');const loggedOut=await request('/user/me',token);assert.equal(loggedOut.http,401);passed.push('退出登录与旧令牌失效');
  const report={result:'PASS',checks:passed,limitations:['短信为显式演示模式','未接入真实支付、退款与验票','未进行并发压测']};
  fs.writeFileSync('output/backend-review.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(e=>{console.error(e);process.exitCode=1;});
