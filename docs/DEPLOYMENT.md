# CertVault 部署说明

本文提供两种部署方式：宝塔面板和普通 Ubuntu/Debian 服务器。两种方式都使用同一套结构，后端监听 `3006`，Nginx 负责域名和 HTTPS。

## 一、部署前准备

服务器建议配置：2 核 CPU、2 GB 内存、20 GB 磁盘。

需要安装：

- Node.js 20 或更高版本
- PostgreSQL 14 或更高版本
- PM2
- Nginx

源码目录说明：

```text
client/       Vue Web 前端源码
server/       Node.js 后端源码
ios/          iOS 客户端源码
docs/         文档
```

出售版 ZIP 还附带 `deploy-ready.tar.gz`。它是已经构建好的 Web 前端与后端部署目录，适合不改源码直接上线；完整源码仍以 `client`、`server`、`ios` 为准。

生产环境不要上传 `.git`、`node_modules`、证书、数据库备份或个人 `.env`。

## 二、创建 PostgreSQL 数据库

进入 PostgreSQL：

```bash
sudo -u postgres psql
```

执行下面的 SQL。请把密码替换成自己的强密码：

```sql
CREATE USER certvault WITH PASSWORD '替换为数据库强密码';
CREATE DATABASE certvault OWNER certvault;
GRANT ALL PRIVILEGES ON DATABASE certvault TO certvault;
\q
```

数据库表会在后端第一次启动时自动创建。

## 三、填写配置

在源码根目录执行：

```bash
cp server/.env.example server/.env
```

编辑 `server/.env`，至少修改这些项目：

```env
SERVER_URL=https://你的域名
PG_HOST=127.0.0.1
PG_PORT=5432
PG_DATABASE=certvault
PG_USER=certvault
PG_PASSWORD=你的数据库强密码
ADMIN_USERNAME=admin
ADMIN_PASSWORD=你的管理员强密码
```

注意：

- `SERVER_URL` 不要以 `/` 结尾。
- `PG_PASSWORD` 和 `ADMIN_PASSWORD` 不能保留 `CHANGE_ME`。
- 邮件注册需要填写 SMTP；不需要邮件功能可以暂时留空。
- Token 服务是可选功能，不使用时保持默认或留空。

## 四、宝塔面板部署

### 1. 安装软件

在宝塔“软件商店”安装：

- Nginx
- PostgreSQL
- Node.js 版本管理器，并安装 Node.js 20+
- PM2 管理器

### 2. 上传源码

把出售版 ZIP 上传到：

```text
/www/wwwroot/certvault
```

解压后确认能看到 `client`、`server`、`docs` 三个目录。如果 ZIP 外层还有一个 `CertVault-Source`，请进入该目录执行后续命令。

如果只想直接部署，可解压包内的 `deploy-ready.tar.gz` 到网站目录，然后跳过 Web 构建；在该目录复制 `.env.example` 为 `.env`、安装后端依赖并用 PM2 启动即可。

### 3. 安装依赖并构建

在宝塔终端执行：

```bash
cd /www/wwwroot/certvault

npm --prefix client ci
npm --prefix client run build

rm -rf server/client
cp -R client/dist server/client

npm --prefix server ci --omit=dev
mkdir -p server/data/certificates server/data/profiles server/data/p8keys server/data/uploads
```

然后按照“第三节”创建并填写 `server/.env`。

### 4. 启动后端

```bash
cd /www/wwwroot/certvault/server
pm2 start ecosystem.config.js
pm2 save
pm2 status
```

看到 `cert-manager` 状态为 `online` 即启动成功。

### 5. 添加网站和反向代理

1. 宝塔 → 网站 → 添加站点，填写你的域名。
2. 站点设置 → 反向代理 → 添加反向代理。
3. 目标 URL 填写 `http://127.0.0.1:3006`。
4. 开启“保留 Host”并保存。
5. SSL 页面申请证书并开启强制 HTTPS。

浏览器打开：

```text
https://你的域名/admin/
```

使用 `.env` 中的 `ADMIN_USERNAME` 和 `ADMIN_PASSWORD` 登录。

## 五、普通 Ubuntu/Debian 服务器部署

### 1. 安装基础软件

确保 Node.js 版本不低于 20：

```bash
node -v
```

安装 PostgreSQL、Nginx、编译工具和 PM2：

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib nginx build-essential python3 unzip
sudo npm install -g pm2
```

如果系统 Node.js 版本过低，请先通过 NodeSource 或 nvm 安装 Node.js 20+。

### 2. 上传和构建

将 ZIP 上传到服务器后执行：

```bash
sudo mkdir -p /opt/certvault
sudo unzip CertVault-Source-*.zip -d /opt/certvault
cd /opt/certvault/CertVault-Source

npm --prefix client ci
npm --prefix client run build

rm -rf server/client
cp -R client/dist server/client

npm --prefix server ci --omit=dev
mkdir -p server/data/certificates server/data/profiles server/data/p8keys server/data/uploads
cp server/.env.example server/.env
nano server/.env
```

数据库按“第二节”创建，环境变量按“第三节”填写。

如果使用 `deploy-ready.tar.gz`，不需要执行前端构建和复制步骤；解压后执行 `npm ci --omit=dev`，再创建 `.env` 与数据目录即可。

### 3. 使用 PM2 启动

```bash
cd /opt/certvault/CertVault-Source/server
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

`pm2 startup` 会输出一条带 `sudo` 的命令，请复制执行一次，再运行 `pm2 save`。

### 4. 配置 Nginx

创建 `/etc/nginx/sites-available/certvault`：

```nginx
server {
    listen 80;
    server_name 你的域名;

    client_max_body_size 250m;

    location / {
        proxy_pass http://127.0.0.1:3006;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 180s;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/certvault /etc/nginx/sites-enabled/certvault
sudo nginx -t
sudo systemctl reload nginx
```

配置好域名解析后，用 Certbot 或其他方式申请 HTTPS 证书。UDID 描述文件和 Apple 回调功能建议必须使用 HTTPS。

## 六、更新与备份

更新前先备份：

```bash
cd 你的项目目录/server
tar -czf ~/certvault-backup-$(date +%Y%m%d).tar.gz .env data
```

更新源码后重新执行：

```bash
npm --prefix client ci
npm --prefix client run build
rm -rf server/client
cp -R client/dist server/client
npm --prefix server ci --omit=dev
pm2 restart cert-manager --update-env
```

重要数据包括：PostgreSQL 数据库、`server/.env` 和 `server/data`。三者都需要单独备份。

## 七、常用排查命令

```bash
pm2 status
pm2 logs cert-manager --lines 100
curl http://127.0.0.1:3006/
sudo nginx -t
```

常见问题：

- `PG_PASSWORD is required`：没有创建 `.env`，或数据库密码仍是占位值。
- 管理员配置错误：检查 `ADMIN_USERNAME`、`ADMIN_PASSWORD` 是否已修改。
- 页面 404：确认已经把 `client/dist` 复制到 `server/client`。
- 数据库连接失败：检查 PostgreSQL 是否启动、用户密码和数据库名是否一致。
- Apple API 失败：检查导入的 Issuer ID、Key ID 和 P8 文件，不要把这些凭据写进 `.env.example`。
