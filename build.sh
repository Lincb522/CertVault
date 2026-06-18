#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-release}"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BUILD_DIR="$ROOT/.build"
RELEASE_DIR="$ROOT/releases"

usage() {
  echo "用法: ./build.sh [release|patch|server|client]"
  echo "  release  完整部署包：后端、依赖清单、public、前端构建产物"
  echo "  patch    增量部署包：后端 src 与前端构建产物"
  echo "  server   仅后端 src"
  echo "  client   仅前端构建产物"
}

build_client() {
  echo "[build] 构建 Web 前端"
  npm --prefix "$ROOT/client" run build
}

prepare() {
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR" "$RELEASE_DIR"
}

pack() {
  local name="$1"
  tar -czf "$RELEASE_DIR/$name" -C "$BUILD_DIR" .
  echo "[build] 已生成 $RELEASE_DIR/$name"
}

prepare

case "$MODE" in
  release)
    build_client
    cp "$ROOT/server/package.json" "$ROOT/server/package-lock.json" "$BUILD_DIR/"
    cp -R "$ROOT/server/src" "$BUILD_DIR/src"
    cp -R "$ROOT/server/public" "$BUILD_DIR/public"
    cp -R "$ROOT/client/dist" "$BUILD_DIR/client"
    [ ! -f "$ROOT/server/.env.example" ] || cp "$ROOT/server/.env.example" "$BUILD_DIR/.env.example"
    [ ! -f "$ROOT/server/ecosystem.config.js" ] || cp "$ROOT/server/ecosystem.config.js" "$BUILD_DIR/ecosystem.config.js"
    [ ! -f "$ROOT/server/start.sh" ] || cp "$ROOT/server/start.sh" "$BUILD_DIR/start.sh"
    pack "certvault-release-$TIMESTAMP.tar.gz"
    ;;
  patch)
    build_client
    cp -R "$ROOT/server/src" "$BUILD_DIR/src"
    cp -R "$ROOT/client/dist" "$BUILD_DIR/client"
    pack "certvault-patch-$TIMESTAMP.tar.gz"
    ;;
  server)
    cp -R "$ROOT/server/src" "$BUILD_DIR/src"
    pack "certvault-server-$TIMESTAMP.tar.gz"
    ;;
  client)
    build_client
    cp -R "$ROOT/client/dist" "$BUILD_DIR/client"
    pack "certvault-client-$TIMESTAMP.tar.gz"
    ;;
  *)
    usage
    rm -rf "$BUILD_DIR"
    exit 1
    ;;
esac

rm -rf "$BUILD_DIR"
