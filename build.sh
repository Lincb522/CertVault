#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[打包]${NC} $1"; }
ok()  { echo -e "${GREEN}[完成]${NC} $1"; }
warn(){ echo -e "${YELLOW}[提示]${NC} $1"; }

usage() {
  echo "用法: ./build.sh [选项]"
  echo ""
  echo "  full       全量打包（后端 + 前端，含 node_modules）"
  echo "  lite       轻量打包（后端 + 前端，不含 node_modules）"
  echo "  patch      增量包（仅后端 src + 前端 dist）"
  echo "  server     仅后端 src"
  echo "  client     仅前端（自动构建 dist）"
  echo ""
  echo "示例: ./build.sh patch"
  exit 1
}

MODE=${1:-patch}

build_client() {
  if [ -f "$PROJECT_DIR/client/package.json" ]; then
    log "构建前端..."
    cd "$PROJECT_DIR/client"
    npm run build
    cd "$PROJECT_DIR"
    ok "前端构建完成"
  fi
}

DIST_DIR="$PROJECT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

case "$MODE" in
  full)
    log "全量打包模式"
    build_client
    OUTFILE="certvault-full-${TIMESTAMP}.tar.gz"
    tar czf "$PROJECT_DIR/$OUTFILE" \
      -C "$PROJECT_DIR" \
      server/package.json \
      server/package-lock.json \
      server/src \
      server/node_modules \
      -C "$PROJECT_DIR" \
      client/dist
    ok "全量包: $OUTFILE ($(du -h "$PROJECT_DIR/$OUTFILE" | cut -f1))"
    warn "部署: 解压后 cd server && node src/app.js"
    ;;

  lite)
    log "轻量打包模式（不含 node_modules）"
    build_client
    OUTFILE="certvault-lite-${TIMESTAMP}.tar.gz"
    tar czf "$PROJECT_DIR/$OUTFILE" \
      -C "$PROJECT_DIR" \
      server/package.json \
      server/package-lock.json \
      server/src \
      -C "$PROJECT_DIR" \
      client/dist
    ok "轻量包: $OUTFILE ($(du -h "$PROJECT_DIR/$OUTFILE" | cut -f1))"
    warn "部署: 解压后 cd server && npm install --production && node src/app.js"
    ;;

  patch)
    log "增量打包模式（仅源码）"
    OUTFILE="certvault-patch-${TIMESTAMP}.tar.gz"
    mkdir -p "$DIST_DIR/src" "$DIST_DIR/client"
    cp -r "$PROJECT_DIR/server/src/"* "$DIST_DIR/src/"
    if [ -d "$PROJECT_DIR/client/dist" ]; then
      cp -r "$PROJECT_DIR/client/dist/"* "$DIST_DIR/client/"
    fi
    tar czf "$PROJECT_DIR/$OUTFILE" -C "$DIST_DIR" .
    ok "增量包: $OUTFILE ($(du -h "$PROJECT_DIR/$OUTFILE" | cut -f1))"
    warn "部署: 在服务器项目根目录解压覆盖，重启服务"
    ;;

  server)
    log "仅后端打包"
    OUTFILE="certvault-server-${TIMESTAMP}.tar.gz"
    mkdir -p "$DIST_DIR/src"
    cp -r "$PROJECT_DIR/server/src/"* "$DIST_DIR/src/"
    tar czf "$PROJECT_DIR/$OUTFILE" -C "$DIST_DIR" .
    ok "后端包: $OUTFILE ($(du -h "$PROJECT_DIR/$OUTFILE" | cut -f1))"
    warn "部署: 覆盖服务器 src/ 目录，重启服务"
    ;;

  client)
    log "仅前端打包"
    build_client
    OUTFILE="certvault-client-${TIMESTAMP}.tar.gz"
    mkdir -p "$DIST_DIR/client"
    cp -r "$PROJECT_DIR/client/dist/"* "$DIST_DIR/client/"
    tar czf "$PROJECT_DIR/$OUTFILE" -C "$DIST_DIR" .
    ok "前端包: $OUTFILE ($(du -h "$PROJECT_DIR/$OUTFILE" | cut -f1))"
    warn "部署: 覆盖服务器 client/ 目录"
    ;;

  *)
    usage
    ;;
esac

rm -rf "$DIST_DIR"
echo ""
ok "打包完成 → $OUTFILE"
