<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2016+-blue?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Backend-Node.js-339933?style=flat-square&logo=nodedotjs&logoColor=white" />
  <img src="https://img.shields.io/badge/Frontend-Vue%203-4FC08D?style=flat-square&logo=vuedotjs&logoColor=white" />
  <img src="https://img.shields.io/badge/Database-PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/License-Private-red?style=flat-square" />
</p>

<h1 align="center">CertVault</h1>

<p align="center">
  <strong>Apple 开发者证书托管与管理平台</strong><br/>
  <sub>Web 管理后台 · iOS 原生客户端 · Apple Developer API 深度集成</sub>
</p>

---

## 核心功能

<table>
<tr>
<td width="50%">

### 证书与描述文件
- 创建、下载、撤销 iOS / macOS 证书
- 自动生成 P12 + 密码文件
- 创建和管理 Provisioning Profile
- 证书 / 描述文件有效性检测与到期提醒

</td>
<td width="50%">

### 设备管理
- Apple 设备注册与管理
- **一键绑定** — 自动创建证书 + 描述文件 + 全权限
- 支持 iOS / macOS / tvOS 多平台
- 网页引导获取设备 UDID

</td>
</tr>
<tr>
<td>

### 账号与权限
- App Store Connect API Key 导入 (.p8)
- 多开发者账号统一管理
- 可视化权限开关（推送、iCloud、Sign in with Apple 等）
- 用户系统 — 注册、邮箱验证、数据隔离

</td>
<td>

### 推送服务
- APNs 推送密钥管理
- 在线推送测试（沙盒 / 生产）
- 操作完成自动推送通知
- iOS 端远程推送接收

</td>
</tr>
</table>

---

## 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                       CertVault                         │
├──────────────┬──────────────────┬───────────────────────┤
│  iOS 客户端   │   Web 管理后台    │      后端服务          │
│              │                  │                       │
│  SwiftUI     │  Vue 3           │  Node.js + Express    │
│  iOS 16+     │  Element Plus    │  PostgreSQL           │
│  MVVM        │  Vite + Pinia    │  Apple Developer API  │
│  APNs Push   │  Axios           │  APNs HTTP/2          │
└──────────────┴──────────────────┴───────────────────────┘
```

---

## 项目结构

```
CertVault/
│
├── server/                    # Node.js 后端
│   ├── src/
│   │   ├── app.js             # 入口文件
│   │   ├── config/            # 数据库配置
│   │   ├── middleware/        # 认证中间件
│   │   ├── routes/            # API 路由
│   │   │   ├── account.js     #   账号管理
│   │   │   ├── certificate.js #   证书管理
│   │   │   ├── device.js      #   设备管理 + 一键绑定
│   │   │   ├── profile.js     #   描述文件
│   │   │   ├── capability.js  #   权限管理
│   │   │   ├── push.js        #   推送发送 + Token 注册
│   │   │   └── ...
│   │   └── services/          # 业务服务
│   │       ├── apple-api.js   #   Apple API 封装
│   │       ├── crypto.js      #   证书加密 / P12 生成
│   │       └── push-helper.js #   推送通知辅助
│   └── package.json
│
├── client/                    # Vue 3 Web 前端
│   ├── src/
│   │   ├── views/             # 14 个业务页面
│   │   ├── api/               # Axios API 封装
│   │   ├── stores/            # Pinia 状态管理
│   │   └── router/            # 路由配置
│   └── package.json
│
├── ios/                       # iOS SwiftUI 客户端
│   ├── CertVault/
│   │   ├── Models/            # 数据模型 (Codable)
│   │   ├── ViewModels/        # MVVM ViewModel
│   │   ├── Views/             # SwiftUI 视图
│   │   │   ├── Dashboard/     #   仪表盘
│   │   │   ├── Auth/          #   登录 / 注册
│   │   │   ├── Devices/       #   设备管理
│   │   │   ├── Certificates/  #   证书管理
│   │   │   ├── Profiles/      #   描述文件
│   │   │   ├── Push/          #   推送测试
│   │   │   └── Settings/      #   设置
│   │   ├── Services/          # API / 推送 / 下载服务
│   │   └── Utils/             # 工具类、图标
│   └── CertVault.xcodeproj
│
├── build.sh                   # 打包脚本
├── docker-compose.yml         # Docker 部署
└── API.md                     # 接口文档
```

---

## 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| Node.js | >= 18 |
| PostgreSQL | >= 14 |
| Xcode | >= 15 (iOS 开发) |

### 后端

```bash
cd server
cp .env.example .env    # 编辑配置：数据库、SMTP 等
npm install
npm start               # http://localhost:3006
```

### Web 前端

```bash
cd client
npm install
npm run dev             # 开发模式
npm run build           # 生产构建
```

### iOS 客户端

```bash
# 1. 创建配置文件
cat > ios/CertVault/Config/Secrets.xcconfig << EOF
SERVER_URL = https://your-server.com
EOF

# 2. Xcode 打开项目
open ios/CertVault.xcodeproj

# 3. 配置 Signing Team，运行到真机
```

---

## 打包部署

```bash
./build.sh patch    # 增量包 — 后端源码 + 前端构建（默认）
./build.sh lite     # 轻量包 — 含 package.json
./build.sh full     # 全量包 — 含 node_modules
./build.sh server   # 仅后端
./build.sh client   # 仅前端（自动构建）
```

### Docker 部署

```bash
docker-compose up -d
```

---

## 初始化配置

首次启动会自动创建超级管理员账号，用户名和密码在 `.env` 中配置：

```env
ADMIN_USERNAME=your_admin
ADMIN_PASSWORD=your_password
```

> 如未配置，将使用代码中的默认值，请登录后立即修改密码。

---

## API 文档

详见 [API.md](./API.md)，涵盖所有接口：

- 认证 (`/api/auth/*`)
- 账号 (`/api/accounts/*`)
- 证书 (`/api/certificates/*`)
- 设备 (`/api/devices/*`)
- 描述文件 (`/api/profiles/*`)
- 权限 (`/api/capabilities/*`)
- 推送 (`/api/push/*`)
- 健康检查 (`/api/healthcheck/*`)

---

## License

**Private** — All rights reserved.
