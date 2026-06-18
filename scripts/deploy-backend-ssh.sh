#!/usr/bin/env bash
# 将本地 server 3 后端变更同步到维护文档中的服务器目录并重启 PM2。
# 用法（在项目根目录）:
#   chmod +x scripts/deploy-backend-ssh.sh
#   ./scripts/deploy-backend-ssh.sh
#
# 可选环境变量:
#   SSH_HOST=zhiwen@125.110.207.231
#   SSH_PORT=23

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/server 3/src"
REMOTE_USER_HOST="${SSH_HOST:-zhiwen}"
REMOTE_PORT="${SSH_PORT:-23}"
REMOTE_BASE="/www/wwwroot/cert-manager/deploy/src"
REMOTE_TMP="certvault-deploy-$(date +%s)"

FILES=(
  "routes/account.js"
  "routes/public-tf.js"
  "routes/testflight.js"
  "app.js"
  "config/database.js"
  "services/beta-tester-invite.js"
)

echo "==> 上传至 ${REMOTE_USER_HOST}:${REMOTE_PORT} /tmp/${REMOTE_TMP}/"
ssh -p "$REMOTE_PORT" "$REMOTE_USER_HOST" "mkdir -p /tmp/${REMOTE_TMP}/routes /tmp/${REMOTE_TMP}/config /tmp/${REMOTE_TMP}/services"

for f in "${FILES[@]}"; do
  if [[ ! -f "$SRC/$f" ]]; then
    echo "缺少本地文件: $SRC/$f" >&2
    exit 1
  fi
  dir=$(dirname "$f")
  scp -P "$REMOTE_PORT" "$SRC/$f" "${REMOTE_USER_HOST}:/tmp/${REMOTE_TMP}/${dir}/"
  echo "  OK $f"
done

echo "==> 覆盖到服务器代码目录并重启 PM2（需要 sudo）"
# shellcheck disable=SC2087
ssh -p "$REMOTE_PORT" "$REMOTE_USER_HOST" bash -s <<EOF
set -e
T="/tmp/${REMOTE_TMP}"
B="${REMOTE_BASE}"
sudo cp "\$T/routes/account.js"       "\$B/routes/account.js"
sudo cp "\$T/routes/public-tf.js"      "\$B/routes/public-tf.js"
sudo cp "\$T/routes/testflight.js"     "\$B/routes/testflight.js"
sudo cp "\$T/app.js"                   "\$B/app.js"
sudo cp "\$T/config/database.js"       "\$B/config/database.js"
sudo cp "\$T/services/beta-tester-invite.js" "\$B/services/beta-tester-invite.js"
rm -rf "\$T"
sudo pm2 restart cert-manager --update-env
echo "==> 远程执行完成"
EOF

echo "本地部署脚本结束。"
