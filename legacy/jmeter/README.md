# 历史 JMeter 压测资料

本目录来自旧版点评工程，包含旧接口、旧表名和 Redis 键名，尚未适配当前 EventFlow。仅保留作迁移参考，不可直接用于当前业务库，也不构成本项目的性能测试结果。当前验证入口见仓库根目录 README 与 src/test。

以下是历史版本使用记录：

# 黑马点评秒杀压测

测试包包含三个场景：

1. `seckill-one-token.jmx`：同一 Token 并发请求，验证一人一单。
2. `seckill-multi-token.jmx`：每个线程使用独立 Token，验证有限库存不超卖。
3. 一键脚本额外制造 MySQL 库存不足，验证 Stream Pending 重试、死信和 Lua 补偿。

## 一键执行

先启动 MySQL、`hmdp-redis7` 和 `HmDianPingApplication`，然后在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\jmeter\run-seckill-load-test.ps1 -Cleanup
```

默认参数：

- 同一 Token：100 个并发线程；
- 多用户：100 个并发线程；
- 多用户场景库存：30；
- Ramp-Up：1 秒；
- 每个线程请求一次。

调整并发量：

```powershell
powershell -ExecutionPolicy Bypass -File .\jmeter\run-seckill-load-test.ps1 `
  -OneUserThreads 200 `
  -MultiUserThreads 200 `
  -MultiUserStock 50 `
  -Cleanup
```

结果保存在 `jmeter/results/<时间>/`：

- `summary.json`：业务验证汇总；
- `one-token/results.jtl`：单用户原始结果；
- `multi-token/results.jtl`：多用户原始结果；
- `failure-recovery/results.jtl`：故障补偿原始结果；
- 每个场景的 `html/index.html`：JMeter HTML 报告。

`-Cleanup` 只清理由本次脚本创建并精确记录的测试用户、优惠券、订单和登录 Key，不清理业务数据。

正式压测应使用 CLI 模式；JMeter GUI 只用于查看和编辑 `.jmx`。
