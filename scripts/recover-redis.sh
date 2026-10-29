#!/usr/bin/env bash
# Resume only a first installation that failed before Redis was ready.
set -euo pipefail
payload_dir=$(cd "$(dirname "$0")" && pwd)
target=${EVENTFLOW_DEPLOY_DIR:-/opt/eventflow}
project=${EVENTFLOW_PROJECT_NAME:-eventflow}
[ "$(id -u)" = 0 ] || { echo 'Run this script using sudo bash.' >&2; exit 1; }
test -f "$payload_dir/restore-redis.sh" || { echo 'The fixed restore script is missing.' >&2; exit 1; }
cd "$target"
compose=(docker compose -p "$project" -f compose.yaml)
test -f .deploy-state/bundle || { echo 'No first-install migration state was found.' >&2; exit 1; }
test ! -f .deploy-state/complete && test ! -f .deploy-state/redis-ready || {
  echo 'Redis migration is already marked complete. No data was changed.' >&2; exit 1;
}
expected_bundle=$(sha256sum migration/checksums.sha256 | cut -d ' ' -f 1)
test "$(cat .deploy-state/bundle)" = "$expected_bundle" || {
  echo 'The migration identity does not match; no data was changed.' >&2; exit 1;
}
sha256sum -c migration/checksums.sha256
running=$("${compose[@]}" ps --status running -q app redis)
test -z "$running" || {
  echo 'The app or normal Redis service is running. Stop and inspect before recovery.' >&2; exit 1;
}
umask 077
backup_dir="$PWD/.deploy-state/redis-before-retry-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir "$backup_dir"
cp -p scripts/restore-redis.sh "$backup_dir/restore-redis.sh"
cp -p migration/checksums.sha256 "$backup_dir/checksums.sha256"
cp -p .deploy-state/bundle "$backup_dir/bundle"
# Preserve every file from this failed first restore, instead of deleting the volume.
"${compose[@]}" run --rm --no-deps --user root --entrypoint sh \
  -v "$backup_dir:/recovery" redis -c '
    set -eu
    mkdir /recovery/redis-data
    for item in /data/.[!.]* /data/..?* /data/*; do
      if [ -e "$item" ] || [ -L "$item" ]; then
        mv "$item" /recovery/redis-data/
      fi
    done
  '
install -m 644 "$payload_dir/restore-redis.sh" scripts/restore-redis.sh
new_hash=$(sha256sum scripts/restore-redis.sh | cut -d ' ' -f 1)
awk -v fixed="$new_hash" '{if ($2 == "scripts/restore-redis.sh") $1 = fixed; print $1 "  " $2}' \
  migration/checksums.sha256 > "$backup_dir/checksums.updated"
cp "$backup_dir/checksums.updated" migration/checksums.sha256
sha256sum migration/checksums.sha256 | cut -d ' ' -f 1 > .deploy-state/bundle
printf 'vm.overcommit_memory = 1\n' > /etc/sysctl.d/99-eventflow-redis.conf
sysctl -p /etc/sysctl.d/99-eventflow-redis.conf
echo "Failed-restore files were preserved in: $backup_dir"
bash scripts/deploy-first.sh
