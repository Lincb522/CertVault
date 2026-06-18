# CertVault

CertVault 是一套 Apple 开发者资源管理平台，包含 Web 管理后台、Node.js API 服务和 iOS 客户端。它用于统一管理开发者账号、设备、证书、描述文件、Bundle ID、TestFlight 与 APNs 推送。

## 工程结构

```text
p12/
├── client/                 # Vue 3 Web 前端源码
├── server/                 # Node.js + Express 后端源码
├── ios/                    # SwiftUI App 与 Widget
├── scripts/                # 部署及辅助脚本
├── docs/                   # API、部署说明与项目规划
├── build.sh                # 生成标准部署包
└── docker-compose.yml      # 本地或容器化部署
```

目录约定：

- `client/src` 是唯一 Web 前端源码。
- `server/src` 是唯一后端源码，入口为 `server/src/app.js`。
- `client/dist`、`server/client`、`releases` 都是生成物，不提交到 Git。
- 运行时数据只允许放在 `server/data` 或服务器持久化目录，不提交到 Git。

## 技术栈

- Web：Vue 3、Vite、Element Plus、Pinia、Axios
- API：Node.js、Express、PostgreSQL
- iOS：SwiftUI、MVVM、App Groups、WidgetKit
- 外部能力：Apple Developer API、App Store Connect API、APNs、SMTP、S3/MinIO

## 本地开发

环境要求：Node.js 20+、PostgreSQL 14+、Xcode 15+。

```bash
# 后端
cp server/.env.example server/.env
npm --prefix server install
npm --prefix server run dev

# 前端（另开终端）
npm --prefix client install
npm --prefix client run dev
```

- 后端默认地址：`http://localhost:3006`
- 前端开发地址：`http://localhost:5173/admin/`
- 前端开发服务器会把 `/api` 代理到后端。

请在运行前填写 `server/.env`。任何数据库密码、加密密钥、P8、P12、SSL 私钥都不能提交到仓库。

首次启动会根据 `ADMIN_USERNAME` 和 `ADMIN_PASSWORD` 创建超级管理员；出售版配置中的 `CHANGE_ME` 必须先替换，否则服务会拒绝启动。

## iOS 配置

```bash
cp ios/CertVault/Config/Secrets.xcconfig.example ios/CertVault/Config/Secrets.xcconfig
```

把 `Secrets.xcconfig` 中的域名换成自己的 HTTPS 地址，再在 Xcode 中修改开发团队、App/Widget Bundle ID 和 App Group。出售包不包含签名证书、描述文件或开发者账号信息。

## 构建

```bash
./build.sh release  # 完整部署包
./build.sh patch    # src + Web 构建产物
./build.sh server   # 仅后端 src
./build.sh client   # 仅 Web 构建产物
```

输出统一写入 `releases/`。完整部署包解压后就是服务器需要的结构：`src/`、`public/`、`client/`、`package.json`。

## 文档

- [项目规划](docs/PROJECT_PLAN.md)
- [部署与运维](docs/DEPLOYMENT.md)
- [API 文档](docs/API.md)

## 当前约束

- 生产环境更新前必须备份 `.env` 与 `data/`。
- 数据库结构变更必须通过可重复执行的迁移完成。
- 新功能需要同时明确 Web、iOS 和 API 的影响范围。
- 不再复制整套工程作为“新版本”；版本管理统一使用 Git 标签和发布包。
