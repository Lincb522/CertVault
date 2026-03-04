# Apple 证书托管工具 — 部署教程

## 一、Docker 部署（推荐）

### 1. 环境要求

- Docker 20+
- Docker Compose 2+

```bash
# 检查版本
docker --version
docker compose version
```

### 2. 一键启动

```bash
cd p12
docker compose up -d --build
```

启动完成后：
- 前端：http://你的IP:9090
- 后端 API：http://你的IP:3001
- 默认账号：admin / admin123

### 3. 查看日志

```bash
# 查看所有日志
docker compose logs -f

# 只看后端
docker compose logs -f server

# 只看前端
docker compose logs -f client
```

### 4. 停止 / 重启

```bash
# 停止
docker compose down

# 重启
docker compose restart

# 重新构建并启动（代码更新后）
docker compose up -d --build
```

### 5. 数据持久化

后端数据（数据库、证书、P12、描述文件）存储在 Docker Volume `server-data` 中，容器删除后数据不会丢失。

```bash
# 查看数据卷
docker volume ls | grep server-data

# 备份数据
docker cp cert-server:/app/data ./backup-data

# 恢复数据
docker cp ./backup-data/. cert-server:/app/data
docker compose restart server
```

### 6. 修改端口

编辑 `docker-compose.yml`：

```yaml
services:
  server:
    ports:
      - "你想要的后端端口:3001"
  client:
    ports:
      - "你想要的前端端口:80"
```

---

## 二、宝塔面板部署

### 1. 环境要求

- 宝塔面板 7.x+
- Node.js 18+（宝塔软件商店安装）
- PM2 管理器（宝塔软件商店安装）

### 2. 上传项目

将 `cert-manager-deploy.zip` 上传到服务器，解压：

```bash
cd /www/wwwroot
unzip cert-manager-deploy.zip
mv deploy cert-manager
cd cert-manager
```

### 3. 安装依赖

```bash
cd /www/wwwroot/cert-manager
npm install --production
```

> 如果 `better-sqlite3` 编译失败，先安装编译工具：
> ```bash
> yum install -y python3 make gcc gcc-c++   # CentOS
> apt install -y python3 make g++            # Ubuntu
> ```

### 4. 方式 A：PM2 启动（推荐）

```bash
cd /www/wwwroot/cert-manager

# 启动
pm2 start ecosystem.config.js

# 设置开机自启
pm2 save
pm2 startup
```

PM2 常用命令：

```bash
pm2 list                 # 查看进程
pm2 logs cert-manager    # 查看日志
pm2 restart cert-manager # 重启
pm2 stop cert-manager    # 停止
pm2 delete cert-manager  # 删除
```

### 5. 方式 B：宝塔 Node 项目管理器

1. 宝塔面板 → 网站 → Node 项目
2. 添加 Node 项目：
   - 项目目录：`/www/wwwroot/cert-manager`
   - 启动文件：`src/app.js`
   - 项目端口：`3001`
   - 勾选「开机启动」

### 6. 配置域名访问（可选）

#### 方式 1：宝塔反向代理

1. 宝塔 → 网站 → 添加站点 → 输入域名
2. 站点设置 → 反向代理 → 添加反向代理
   - 代理名称：cert-manager
   - 目标 URL：`http://127.0.0.1:3001`
   - 发送域名：`$host`

#### 方式 2：Nginx 配置

宝塔 → 网站 → 站点设置 → 配置文件，添加：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        client_max_body_size 20m;
    }
}
```

### 7. 配置 HTTPS（推荐）

1. 宝塔 → 网站 → 站点设置 → SSL
2. 申请 Let's Encrypt 免费证书
3. 开启强制 HTTPS

### 8. 防火墙

```bash
# 宝塔面板 → 安全 → 放行端口 3001
# 或命令行：
firewall-cmd --add-port=3001/tcp --permanent
firewall-cmd --reload
```

---

## 三、直接部署（无 Docker / 无宝塔）

```bash
cd /opt/cert-manager   # 或任意目录
unzip cert-manager-deploy.zip
mv deploy/* .
npm install --production
mkdir -p data/certificates data/profiles data/p8keys data/uploads

# 前台运行（测试）
PORT=3001 node src/app.js

# 后台运行
nohup PORT=3001 node src/app.js > app.log 2>&1 &

# 或用 PM2
npm install -g pm2
pm2 start ecosystem.config.js
pm2 save && pm2 startup
```

---

## 四、访问和初始化

1. 浏览器打开 `http://你的IP:3001`（或配置的域名）
2. 默认登录账号：`admin` / `admin123`
3. 登录后请立即修改密码
4. 添加 Apple API Key（需要 .p8 文件、Issuer ID、Key ID）

---

## 五、备份和恢复

### 备份

```bash
# 备份整个 data 目录（包含数据库、证书、描述文件）
cd /www/wwwroot/cert-manager
tar -czf backup-$(date +%Y%m%d).tar.gz data/
```

### 恢复

```bash
cd /www/wwwroot/cert-manager
tar -xzf backup-20260303.tar.gz
pm2 restart cert-manager
```

### 定时备份（宝塔计划任务）

宝塔 → 计划任务 → Shell 脚本：

```bash
cd /www/wwwroot/cert-manager
tar -czf /www/backup/cert-manager-$(date +%Y%m%d).tar.gz data/
find /www/backup -name "cert-manager-*.tar.gz" -mtime +30 -delete
```

---

## 六、常见问题

**Q: better-sqlite3 安装失败**
A: 安装编译工具后重试：
```bash
yum install -y python3 make gcc gcc-c++
npm rebuild better-sqlite3
```

**Q: 端口被占用**
A: 修改 `ecosystem.config.js` 中的 PORT，或 `docker-compose.yml` 中的端口映射。

**Q: 忘记密码**
A: 删除数据库文件重新初始化（会丢失所有数据）：
```bash
rm data/cert-manager.db
pm2 restart cert-manager
# 默认账号恢复为 admin / admin123
```

**Q: Docker 镜像太大**
A: 使用 Alpine 基础镜像（已默认配置），首次构建需下载依赖。

**Q: iOS 端连接不上**
A: 确保服务器防火墙放行了 3001 端口，且使用 `http://服务器IP:3001/api` 访问。
