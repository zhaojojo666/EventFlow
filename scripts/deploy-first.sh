#!/usr/bin/env bash
# Fresh installation with a verified local data snapshot. Never removes volumes.
set -euo pipefail
cd "$(dirname "$0")/.."
project=${EVENTFLOW_PROJECT_NAME:-eventflow}
compose=(docker compose -p "$project" -f compose.yaml)
for required in docker openssl curl sha256sum; do
  command -v "$required" >/dev/null || { echo "Missing command: $required" >&2; exit 1; }
done
docker info >/dev/null
test -f migration/checksums.sha256 || { echo 'A migration package is required.' >&2; exit 1; }
sha256sum -c migration/checksums.sha256
bundle=$(sha256sum migration/checksums.sha256 | cut -d ' ' -f 1)
if [ -f .deploy-state/bundle ]; then
  test "$(cat .deploy-state/bundle)" = "$bundle" || {
    echo 'This directory has a different migration in progress. Stop and inspect existing data.' >&2; exit 1;
  }
else
  for volume in mysql-data redis-data uploads; do
    if docker volume inspect "${project}_${volume}" >/dev/null 2>&1; then
      echo "Existing data volume found: ${project}_${volume}. No data was overwritten." >&2
      exit 1
    fi
  done
  mkdir -p .deploy-state
  printf '%s\n' "$bundle" > .deploy-state/bundle
fi
if [ ! -f .env ]; then
  umask 077
  printf 'COMPOSE_PROJECT_NAME=%s\nMYSQL_ROOT_PASSWORD=%s\nMYSQL_PASSWORD=%s\nREDIS_PASSWORD=%s\nAPP_BIND_IP=0.0.0.0\nAPP_PORT=80\nMYSQL_INIT_SQL=./migration/mysql.sql\n' \
    "$project" "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > .env
fi
# Verify the snapshot is used, rather than silently starting with example data.
grep -qx 'MYSQL_INIT_SQL=./migration/mysql.sql' .env || {
  echo 'The .env file must select migration/mysql.sql for this first installation.' >&2; exit 1;
}
chmod 600 .env
app_port=$(sed -n 's/^APP_PORT=//p' .env | tail -n 1)
app_port=${app_port:-8082}
[[ "$app_port" =~ ^[0-9]+$ ]] || { echo 'Invalid APP_PORT' >&2; exit 1; }
"${compose[@]}" config --quiet
"${compose[@]}" build app
"${compose[@]}" up -d mysql
mysql_ready=0
for attempt in $(seq 1 180); do
  if "${compose[@]}" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h127.0.0.1 -uroot eventflow -N -e "SELECT 1 FROM tb_event LIMIT 1"' >/dev/null 2>&1; then
    mysql_ready=1; break
  fi
  sleep 2
done
[ "$mysql_ready" = 1 ] || { "${compose[@]}" logs --tail=80 mysql; exit 1; }
while IFS=$'\t' read -r table expected; do
  [[ "$table" =~ ^tb_[a-z_]+$ ]] && [[ "$expected" =~ ^[0-9]+$ ]] || exit 1
  actual=$("${compose[@]}" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -h127.0.0.1 -uroot eventflow -N -e "$1"' sh "SELECT COUNT(*) FROM \`$table\`" | tr -d '\r')
  [ "$actual" = "$expected" ] || { echo "Row count mismatch: $table ($actual != $expected)" >&2; exit 1; }
done < migration/counts.tsv
echo 'All MySQL table counts match the local snapshot.'
if [ ! -f .deploy-state/redis-ready ]; then
  "${compose[@]}" run --rm --no-deps --user root --entrypoint sh \
    -v "$PWD/migration/redis.rdb:/backup/redis.rdb:ro" \
    -v "$PWD/scripts/restore-redis.sh:/backup/restore-redis.sh:ro" \
    redis /backup/restore-redis.sh
  touch .deploy-state/redis-ready
fi
if [ ! -f .deploy-state/uploads-ready ]; then
  "${compose[@]}" run --rm --no-deps --entrypoint sh \
    -v "$PWD/migration/uploads.tar:/backup/uploads.tar:ro" \
    app -c 'tar -xf /backup/uploads.tar -C /app/uploads'
  touch .deploy-state/uploads-ready
fi
"${compose[@]}" up -d
app_ready=0
for attempt in $(seq 1 120); do
  if response=$(curl -fsS --max-time 3 "http://127.0.0.1:$app_port/events" 2>/dev/null); then
    if [[ "$response" == *'"success":true'* ]]; then app_ready=1; break; fi
  fi
  sleep 2
done
"${compose[@]}" ps
[ "$app_ready" = 1 ] || { "${compose[@]}" logs --tail=100 app; exit 1; }
touch .deploy-state/complete
echo "EventFlow and migrated data are ready on HTTP port $app_port."
echo 'Allow this TCP port in the Alibaba Cloud firewall before opening the public site.'
