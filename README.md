# CertVault

Apple 开发者证书托管与管理平台，提供 Web 管理后台和 iOS 原生客户端。

## 功能

- **开发者账号管理** — 导入 App Store Connect API Key (.p8)，统一管理多个开发者账号
- **证书管理** — 创建、下载、撤销 iOS/macOS 开发和发布证书，自动生成 P12
- **描述文件管理** — 创建、更新、下载 Provisioning Profile，关联设备和证书
- **设备管理** — 注册 Apple 设备，一键绑定（自动创建证书 + 描述文件 + 全权限）
- **Bundle ID 管理** — 创建和管理应用标识符
- **权限管理** — 可视化开关 App 权限（推送、Sign in with Apple、iCloud 等）
- **推送测试** — 配置 APNs 密钥，在线发送推送通知测试
- **健康检查** — 证书/描述文件有效性和过期检测
- **UDID 获取** — 通过网页引导获取 iOS 设备 UDID
- **用户系统** — 注册登录、邮箱验证、数据隔离、超级管理员

## 技术栈

### 后端

- Node.js + Express
- PostgreSQL
- Apple Developer API (App Store Connect API)
- APNs HTTP/2 推送

### Web 前端

- Vue 3 + Composition API
- Element Plus
- Vite
- Pinia + Vue Router

### iOS 客户端

- SwiftUI (iOS 16+)
- MVVM 架构
- APNs 远程推送
- 日间/夜间模式

## 项目结构

```
├── server/              # Node.js 后端
│   ├── src/
│   │   ├── app.js       # 入口 + Dashboard API
│   │   ├── config/      # 数据库配置
│   │   ├── middleware/   # 认证中间件
│   │   ├── routes/      # API 路由
│   │   └── services/    # Apple API、加密、推送等服务
│   └── package.json
├── client/              # Vue 3 Web 前端
│   ├── src/
│   │   ├── views/       # 页面组件
│   │   ├── api/         # Axios API 封装
│   │   ├── stores/      # Pinia 状态管理
│   │   └── router/      # 路由配置
│   └── package.json
├── ios/                 # iOS SwiftUI 客户端
│   ├── CertVault/
│   │   ├── Models/      # 数据模型
│   │   ├── ViewModels/  # MVVM ViewModel
│   │   ├── Views/       # SwiftUI 视图
│   │   ├── Services/    # API/推送/下载服务
│   │   └── Utils/       # 工具类、扩展
│   └── CertVault.xcodeproj
├── build.sh             # 打包脚本
├── docker-compose.yml   # Docker 部署配置
└── API.md               # API 接口文档
```

## 快速开始

### 环境要求

- Node.js >= 18
- PostgreSQL >= 14
- Xcode >= 15 (iOS 开发)

### 后端

```bash
cd server
cp .env.example .env   # 配置数据库和邮件等参数
npm install
npm start              # 默认端口 3006
```

### Web 前端

```bash
cd client
npm install
npm run dev            # 开发模式
npm run build          # 构建生产版本
```

### iOS 客户端

1. 创建 `ios/CertVault/Config/Secrets.xcconfig`：
```
SERVER_URL = https://your-server.com
```
2. 用 Xcode 打开 `ios/CertVault.xcodeproj`
3. 配置 Signing Team，运行到真机

### 打包部署

```bash
./build.sh patch    # 增量包（后端源码 + 前端构建）
./build.sh lite     # 轻量包（含 package.json，不含 node_modules）
./build.sh full     # 全量包（含 node_modules）
./build.sh server   # 仅后端
./build.sh client   # 仅前端（自动构建）
```

## 默认管理员

首次启动自动创建超级管理员账号：

- 用户名：`zijiu522`
- 密码：`yqq977522`

> 请登录后立即修改密码。

## License

Private — All rights reserved.
