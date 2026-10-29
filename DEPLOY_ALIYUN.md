# 部署 EventFlow

Docker Compose 运行 Spring Boot、MySQL 8.0 和 Redis 7.2。前端静态文件包含在 JAR 中，服务器无需单独安装 Node.js 或 Maven。

当前 Dockerfile 使用预编译 JAR，不在镜像内编译源码。首次执行 `docker compose up -d --build` 前，必须先完成下面的 JAR 编译和 `.env` 配置；直接在刚下载的源码目录执行该命令会缺少构建产物或环境变量。

## 使用初始演示数据

1. 在开发机使用 JDK 8 编译：

   ```bash
   mvn -DskipTests package
   ```

2. 将 `Dockerfile`、`.dockerignore`、`compose.yaml`、`.env.example`、`target/eventflow-ticketing-0.0.1-SNAPSHOT.jar` 和 `src/main/resources/db/eventflow.sql` 上传到服务器，保持目录结构。

3. 在服务器项目目录生成配置并启动：

   ```bash
   umask 077
   printf 'MYSQL_ROOT_PASSWORD=%s\nMYSQL_PASSWORD=%s\nREDIS_PASSWORD=%s\nAPP_BIND_IP=127.0.0.1\nAPP_PORT=8082\n' \
     "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > .env
   docker compose up -d --build
   docker compose ps
   curl -f http://127.0.0.1:8082/events
   ```

   该配置先将网站绑定到服务器本机。MySQL 和 Redis 不发布公网端口。首次启动空数据卷时导入演示数据；重启已有卷不会重新导入。

4. 配置反向代理、域名与 HTTPS 后对外提供服务。也可按需调整 `APP_BIND_IP` 和 `APP_PORT`，在所用云服务器的防火墙或安全组中放行网站端口。

Compose 使用 `production` Profile，不加载本地演示配置。当前 `EVENTFLOW_DEMO_MODE=true` 用于体验验证码流程；真实短信、支付和验票尚未实现，关闭演示模式也不会自动接入这些服务。

## 迁移已有本地数据

迁移工具默认面向 `compose.local.yaml` 创建的独立开发环境。

1. 停止本机后端，保留 MySQL 和 Redis 运行，避免导出时产生跨库状态变化。
2. 编译后运行 `python scripts/package-deploy.py --with-local-data`。
3. 生成的 `EventFlow-deploy.tar.gz` 包含数据库、Redis 快照和上传文件，属于私有备份，不上传 GitHub。
4. 将包解压到新服务器的空项目目录，执行 `sudo bash scripts/deploy-first.sh`。脚本默认使用 Compose 项目名 `eventflow`，生成随机密码、迁移数据并发布 HTTP 80 端口。

脚本会校验文件、核对全部 MySQL 表行数，再将 Redis RDB 转为 AOF。发现已有数据卷而没有本次迁移状态时会停止。首次 Redis 恢复失败时，`recover-redis.sh` 可配合同目录的修复版 `restore-redis.sh`，备份失败现场后重试；它不用于覆盖已经运行的网站。

## 维护

```bash
docker compose logs --tail=100 app mysql redis
docker stats --no-stream
docker compose stop
docker compose up -d
```

更新 JAR 后执行 `docker compose up -d --build app`。结构升级前先备份，再使用增量 SQL；不要将旧的本机快照覆盖线上新增订单。

`docker compose down -v` 会删除数据卷。正常停止服务使用 `stop`，排错时保留日志和数据备份。

Java 堆上限和 MySQL 缓冲池已在 Compose 中设置，实际资源需求取决于数据量与请求负载。部署后应观察内存、磁盘和容器状态，开发机验证结果不能代替生产环境压测。
