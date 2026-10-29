#!/bin/sh
# Run once in an isolated Redis container, with the destination volume at /data.
set -eu
if [ -n "$(ls -A /data)" ]; then
  echo 'Redis data volume is not empty; refusing to replace it.' >&2
  exit 1
fi
cp /backup/redis.rdb /data/dump.rdb
redis-check-rdb /data/dump.rdb
# RDB must be loaded before enabling AOF. Starting with AOF enabled can ignore it.
redis-server --bind 127.0.0.1 --dir /data --dbfilename dump.rdb \
  --appendonly no --daemonize no > /tmp/redis-restore.log 2>&1 &
redis_pid=$!
cleanup() {
  result=$?
  trap - EXIT
  if kill -0 "$redis_pid" 2>/dev/null; then
    redis-cli shutdown save >/dev/null 2>&1 || kill "$redis_pid" 2>/dev/null || true
  fi
  wait "$redis_pid" 2>/dev/null || true
  if [ "$result" -ne 0 ]; then cat /tmp/redis-restore.log >&2; fi
  exit "$result"
}
trap cleanup EXIT
started=0
for attempt in $(seq 1 60); do
  if [ "$(redis-cli ping 2>/dev/null || true)" = PONG ]; then
    started=1
    break
  fi
  if ! kill -0 "$redis_pid" 2>/dev/null; then break; fi
  sleep 1
done
[ "$started" = 1 ] || { echo 'Redis did not become ready; startup log follows.' >&2; exit 1; }
redis-cli -e config set appendonly yes
ready=0
for attempt in $(seq 1 120); do
  info=$(redis-cli info persistence | tr -d '\r')
  if echo "$info" | grep -q '^aof_rewrite_in_progress:0$' && \
     echo "$info" | grep -q '^aof_rewrite_scheduled:0$' && \
     echo "$info" | grep -q '^aof_last_bgrewrite_status:ok$' && \
     [ -f /data/appendonlydir/appendonly.aof.manifest ]; then
    ready=1
    break
  fi
  sleep 1
done
[ "$ready" = 1 ] || { echo 'Redis AOF conversion did not finish.' >&2; exit 1; }
redis-cli shutdown save
wait "$redis_pid"
trap - EXIT
chown -R redis:redis /data
echo 'Redis snapshot restored and converted to persistent AOF.'
