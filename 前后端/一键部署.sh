#!/bin/bash
#
# CertVault 一键部署脚本
# 适用于: 宝塔面板 + CentOS 7/8/9 / Ubuntu 20.04/22.04/24.04
# 用法:   bash deploy.sh
#
# 执行前请确保:
#   1. 已安装宝塔面板
#   2. 宝塔中已安装 Nginx
#   3. 域名已解析到本机 IP
#   4. 部署包已上传到服务器（或使用脚本内置上传功能）
#
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        全 局 配 置                               ║
# ╚══════════════════════════════════════════════════════════════════╝

DEPLOY_DIR="/www/wwwroot/cert-manager"
APP_DIR="$DEPLOY_DIR/deploy"
DATA_DIR="$APP_DIR/data"
LOG_FILE="/tmp/certvault-deploy-$(date +%Y%m%d_%H%M%S).log"
NODE_MIN_VERSION=18
PG_MIN_VERSION=10

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        工 具 函 数                               ║
# ╚══════════════════════════════════════════════════════════════════╝

log() { echo -e "${DIM}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}ℹ${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}✓${NC}  $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}✗${NC}  $*" | tee -a "$LOG_FILE"; }
fatal() { error "$*"; echo -e "\n${RED}部署中止。日志文件: $LOG_FILE${NC}"; exit 1; }

step_header() {
    local num=$1; shift
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}  步骤 $num: $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

ask() {
    local prompt=$1 default=$2 var=$3
    echo -en "${BOLD}  $prompt${NC}"
    if [ -n "$default" ]; then
        echo -en " ${DIM}[$default]${NC}"
    fi
    echo -en ": "
    read -r input
    eval "$var='${input:-$default}'"
}

ask_password() {
    local prompt=$1 var=$2
    echo -en "${BOLD}  $prompt${NC}: "
    read -rs input
    echo ""
    eval "$var='$input'"
}

ask_yn() {
    local prompt=$1 default=$2
    local yn_hint="[y/N]"
    [ "$default" = "y" ] && yn_hint="[Y/n]"
    echo -en "${BOLD}  $prompt${NC} $yn_hint: "
    read -r input
    input=${input:-$default}
    [[ "$input" =~ ^[Yy] ]]
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fatal "请使用 root 用户运行此脚本: sudo bash deploy.sh"
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_ID="centos"
        OS_VERSION=$(grep -oP '\d+' /etc/redhat-release | head -1)
    else
        OS_ID="unknown"
        OS_VERSION="0"
    fi
    log "检测到操作系统: $OS_ID $OS_VERSION"
}

get_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

get_ip() {
    curl -s4 ifconfig.me 2>/dev/null || curl -s4 ip.sb 2>/dev/null || hostname -I | awk '{print $1}'
}

gen_random_key() {
    local len=${1:-32}
    openssl rand -hex $((len / 2)) 2>/dev/null || head -c $len /dev/urandom | xxd -p | head -c "$len"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        欢 迎 界 面                               ║
# ╚══════════════════════════════════════════════════════════════════╝

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
   ╔═══════════════════════════════════════════════════╗
   ║                                                   ║
   ║          CertVault 一键部署脚本 v1.0              ║
   ║                                                   ║
   ║   Apple Developer Certificate Management Tool     ║
   ║                                                   ║
   ╚═══════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}部署日志: $LOG_FILE${NC}"
    echo -e "  ${DIM}服务器 IP: $(get_ip)${NC}"
    echo ""
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                     步骤 1: 环境检查                             ║
# ╚══════════════════════════════════════════════════════════════════╝

check_environment() {
    step_header 1 "环境检查"

    check_root
    detect_os

    local PKG=$(get_pkg_manager)
    if [ "$PKG" = "unknown" ]; then
        fatal "不支持的包管理器，请使用 CentOS/Ubuntu 系统"
    fi
    success "操作系统: $OS_ID $OS_VERSION (包管理: $PKG)"

    # 检查宝塔面板
    if [ -f /www/server/panel/BT-Panel ]; then
        success "宝塔面板: 已安装"
    else
        warn "未检测到宝塔面板，Nginx 配置需手动操作"
    fi

    # 检查 Nginx
    if command -v nginx &>/dev/null; then
        local nginx_ver=$(nginx -v 2>&1 | grep -oP '[\d.]+')
        success "Nginx: $nginx_ver"
    else
        fatal "Nginx 未安装，请在宝塔面板中安装 Nginx"
    fi

    # 检查磁盘空间
    local free_mb=$(df -m /www 2>/dev/null | awk 'NR==2{print $4}' || df -m / | awk 'NR==2{print $4}')
    if [ "$free_mb" -lt 1024 ]; then
        warn "磁盘剩余空间不足 1GB ($free_mb MB)，建议清理"
    else
        success "磁盘空间: ${free_mb}MB 可用"
    fi

    # 检查内存
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 512 ]; then
        warn "内存不足 512MB ($total_mem MB)，可能影响性能"
    else
        success "内存: ${total_mem}MB"
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 2: 收集配置信息                           ║
# ╚══════════════════════════════════════════════════════════════════╝

collect_config() {
    step_header 2 "收集配置信息"

    echo -e "\n  ${DIM}请填写以下部署信息（回车使用默认值）${NC}\n"

    # 域名
    ask "域名" "" CFG_DOMAIN
    while [ -z "$CFG_DOMAIN" ]; do
        warn "域名不能为空"
        ask "域名" "" CFG_DOMAIN
    done

    # 端口
    ask "后端端口" "3006" CFG_PORT

    # 数据库
    echo ""
    info "数据库配置"
    ask "PostgreSQL 主机" "127.0.0.1" CFG_PG_HOST
    ask "PostgreSQL 端口" "5432" CFG_PG_PORT
    ask "数据库名" "CertManager" CFG_PG_DB
    ask "数据库用户名" "CertManager" CFG_PG_USER
    ask_password "数据库密码（留空自动生成）" CFG_PG_PASS
    if [ -z "$CFG_PG_PASS" ]; then
        CFG_PG_PASS=$(gen_random_key 16)
        success "已自动生成数据库密码: $CFG_PG_PASS"
    fi

    # 加密密钥
    echo ""
    CFG_ENCRYPTION_KEY=$(gen_random_key 32)
    success "已自动生成加密密钥 (32 位)"

    # 邮件
    echo ""
    CFG_SMTP_CONFIGURED="false"
    if ask_yn "是否配置邮件服务？（用于发送验证码）" "n"; then
        CFG_SMTP_CONFIGURED="true"
        ask "SMTP 服务器" "smtp.qq.com" CFG_SMTP_HOST
        ask "SMTP 端口" "465" CFG_SMTP_PORT
        ask "SMTP 加密 (true/false)" "true" CFG_SMTP_SECURE
        ask "SMTP 用户名（邮箱地址）" "" CFG_SMTP_USER
        ask_password "SMTP 密码/授权码" CFG_SMTP_PASS
        ask "发件人名称" "CertVault" CFG_SMTP_FROM_NAME
    fi

    # 确认
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━ 配置确认 ━━━━━━━━━━━━━━━━${NC}"
    echo -e "  域名:        ${BOLD}$CFG_DOMAIN${NC}"
    echo -e "  端口:        ${BOLD}$CFG_PORT${NC}"
    echo -e "  数据库:      ${BOLD}$CFG_PG_USER@$CFG_PG_HOST:$CFG_PG_PORT/$CFG_PG_DB${NC}"
    echo -e "  邮件服务:    ${BOLD}$([ "$CFG_SMTP_CONFIGURED" = "true" ] && echo "已配置 ($CFG_SMTP_HOST)" || echo "未配置")${NC}"
    echo -e "  部署目录:    ${BOLD}$APP_DIR${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! ask_yn "确认以上配置？" "y"; then
        fatal "用户取消部署"
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 3: 安装 Node.js                          ║
# ╚══════════════════════════════════════════════════════════════════╝

install_nodejs() {
    step_header 3 "安装 Node.js"

    if command -v node &>/dev/null; then
        local node_ver=$(node -v | tr -d 'v')
        local node_major=$(echo "$node_ver" | cut -d. -f1)
        if [ "$node_major" -ge "$NODE_MIN_VERSION" ]; then
            success "Node.js 已安装: v$node_ver (满足要求 >= v$NODE_MIN_VERSION)"
            return
        else
            warn "Node.js 版本过低: v$node_ver (需要 >= v$NODE_MIN_VERSION)"
        fi
    fi

    info "正在安装 Node.js LTS..."

    # 优先检查宝塔的 Node.js
    if [ -d /www/server/nodejs ]; then
        local bt_node=$(ls /www/server/nodejs/ 2>/dev/null | sort -V | tail -1)
        if [ -n "$bt_node" ]; then
            local bt_major=$(echo "$bt_node" | grep -oP '^\d+')
            if [ -n "$bt_major" ] && [ "$bt_major" -ge "$NODE_MIN_VERSION" ]; then
                local bt_node_path="/www/server/nodejs/$bt_node/bin"
                if [ -f "$bt_node_path/node" ]; then
                    export PATH="$bt_node_path:$PATH"
                    # 写入 profile 使其持久化
                    echo "export PATH=$bt_node_path:\$PATH" > /etc/profile.d/nodejs.sh
                    source /etc/profile.d/nodejs.sh
                    success "使用宝塔 Node.js: $(node -v)"
                    return
                fi
            fi
        fi
    fi

    # 使用 NodeSource 安装
    local PKG=$(get_pkg_manager)
    if [ "$PKG" = "apt" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$LOG_FILE" 2>&1
        apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    else
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >> "$LOG_FILE" 2>&1
        $PKG install -y nodejs >> "$LOG_FILE" 2>&1
    fi

    if ! command -v node &>/dev/null; then
        fatal "Node.js 安装失败，请手动安装后重试"
    fi

    success "Node.js 安装完成: $(node -v)"
}

install_pm2() {
    if command -v pm2 &>/dev/null; then
        success "PM2 已安装: $(pm2 -v 2>/dev/null)"
        return
    fi

    info "正在安装 PM2..."
    npm install -g pm2 >> "$LOG_FILE" 2>&1

    if ! command -v pm2 &>/dev/null; then
        warn "PM2 安装失败，将使用 nohup 方式启动"
        USE_NOHUP=true
    else
        success "PM2 安装完成: $(pm2 -v)"
        USE_NOHUP=false
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                  步骤 4: 安装 PostgreSQL                        ║
# ╚══════════════════════════════════════════════════════════════════╝

install_postgresql() {
    step_header 4 "安装 PostgreSQL"

    if command -v psql &>/dev/null; then
        local pg_ver=$(psql --version | grep -oP '[\d]+' | head -1)
        if [ "$pg_ver" -ge "$PG_MIN_VERSION" ]; then
            success "PostgreSQL 已安装: $(psql --version | head -1)"
        else
            warn "PostgreSQL 版本过低: $pg_ver (需要 >= $PG_MIN_VERSION)"
        fi
    else
        info "正在安装 PostgreSQL..."
        local PKG=$(get_pkg_manager)

        if [ "$PKG" = "apt" ]; then
            apt-get update >> "$LOG_FILE" 2>&1
            apt-get install -y postgresql postgresql-contrib >> "$LOG_FILE" 2>&1
        else
            $PKG install -y postgresql-server postgresql >> "$LOG_FILE" 2>&1

            # CentOS 需要初始化
            if [ -f /usr/bin/postgresql-setup ]; then
                postgresql-setup --initdb >> "$LOG_FILE" 2>&1 || true
            elif [ -f /usr/pgsql-15/bin/postgresql-15-setup ]; then
                /usr/pgsql-15/bin/postgresql-15-setup initdb >> "$LOG_FILE" 2>&1 || true
            fi
        fi

        if ! command -v psql &>/dev/null; then
            fatal "PostgreSQL 安装失败，请手动安装后重试"
        fi
        success "PostgreSQL 安装完成: $(psql --version | head -1)"
    fi

    # 确保 PostgreSQL 已启动
    local pg_service="postgresql"
    if systemctl list-unit-files | grep -q "postgresql-15"; then
        pg_service="postgresql-15"
    elif systemctl list-unit-files | grep -q "postgresql-14"; then
        pg_service="postgresql-14"
    fi

    if ! systemctl is-active --quiet "$pg_service" 2>/dev/null; then
        info "启动 PostgreSQL..."
        systemctl start "$pg_service" >> "$LOG_FILE" 2>&1
        systemctl enable "$pg_service" >> "$LOG_FILE" 2>&1
    fi
    success "PostgreSQL 服务: 运行中"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                  步骤 5: 配置数据库                              ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_database() {
    step_header 5 "配置数据库"

    # 检查数据库是否已存在
    if sudo -u postgres psql -lqt 2>/dev/null | cut -d\| -f1 | grep -qw "$CFG_PG_DB"; then
        success "数据库 '$CFG_PG_DB' 已存在"
    else
        info "创建数据库用户和数据库..."

        sudo -u postgres psql << EOSQL >> "$LOG_FILE" 2>&1
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$CFG_PG_USER') THEN
        CREATE USER "$CFG_PG_USER" WITH PASSWORD '$CFG_PG_PASS';
    ELSE
        ALTER USER "$CFG_PG_USER" WITH PASSWORD '$CFG_PG_PASS';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE "$CFG_PG_DB" OWNER "$CFG_PG_USER"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$CFG_PG_DB')\gexec

GRANT ALL PRIVILEGES ON DATABASE "$CFG_PG_DB" TO "$CFG_PG_USER";
EOSQL

        success "数据库用户和数据库创建完成"
    fi

    # 配置 pg_hba.conf 允许密码认证
    local PG_HBA=$(sudo -u postgres psql -t -c "SHOW hba_file;" 2>/dev/null | tr -d ' ')
    if [ -n "$PG_HBA" ] && [ -f "$PG_HBA" ]; then
        # 检查是否已配置 md5 认证
        if ! grep -q "^host.*all.*all.*127.0.0.1/32.*md5" "$PG_HBA" && \
           ! grep -q "^host.*all.*all.*127.0.0.1/32.*scram-sha-256" "$PG_HBA"; then
            info "配置 PostgreSQL 密码认证..."

            # 备份
            cp "$PG_HBA" "${PG_HBA}.bak.$(date +%Y%m%d)"

            # 在文件开头（注释后）插入规则
            local TEMP_HBA=$(mktemp)
            {
                echo "# Added by CertVault deploy script"
                echo "local   all             $CFG_PG_USER                                md5"
                echo "host    all             $CFG_PG_USER        127.0.0.1/32            md5"
                echo "host    all             $CFG_PG_USER        ::1/128                 md5"
                cat "$PG_HBA"
            } > "$TEMP_HBA"
            mv "$TEMP_HBA" "$PG_HBA"
            chown postgres:postgres "$PG_HBA"

            # 重载配置
            systemctl reload postgresql* >> "$LOG_FILE" 2>&1 || sudo -u postgres pg_ctl reload >> "$LOG_FILE" 2>&1 || true
            success "PostgreSQL 认证配置已更新"
        else
            success "PostgreSQL 密码认证: 已配置"
        fi
    else
        warn "无法自动配置 pg_hba.conf，请手动确认密码认证已启用"
    fi

    # 测试连接
    info "测试数据库连接..."
    if PGPASSWORD="$CFG_PG_PASS" psql -U "$CFG_PG_USER" -h "$CFG_PG_HOST" -d "$CFG_PG_DB" -c "SELECT 1;" &>/dev/null; then
        success "数据库连接测试通过"
    else
        # 可能需要等待 reload 生效
        sleep 2
        if PGPASSWORD="$CFG_PG_PASS" psql -U "$CFG_PG_USER" -h "$CFG_PG_HOST" -d "$CFG_PG_DB" -c "SELECT 1;" &>/dev/null; then
            success "数据库连接测试通过"
        else
            warn "数据库连接测试失败，请检查 pg_hba.conf 配置"
            warn "可能需要手动将认证方式改为 md5 并执行: systemctl reload postgresql"
        fi
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                  步骤 6: 部署应用代码                            ║
# ╚══════════════════════════════════════════════════════════════════╝

deploy_code() {
    step_header 6 "部署应用代码"

    # 创建目录结构
    mkdir -p "$DEPLOY_DIR" "$APP_DIR"

    if [ -f "$APP_DIR/app.js" ]; then
        success "应用代码已存在于 $APP_DIR"
        if ask_yn "是否覆盖现有代码？" "n"; then
            info "将保留 .env 和 data/ 目录，覆盖其他文件"
        else
            info "跳过代码部署，使用现有代码"
            return
        fi
    fi

    # 检查是否有部署包
    local FOUND_ARCHIVE=""
    for f in "$DEPLOY_DIR"/cert-deploy.tar.gz "$DEPLOY_DIR"/deploy.tar.gz /tmp/cert-deploy.tar.gz /root/cert-deploy.tar.gz; do
        if [ -f "$f" ]; then
            FOUND_ARCHIVE="$f"
            break
        fi
    done

    if [ -n "$FOUND_ARCHIVE" ]; then
        info "检测到部署包: $FOUND_ARCHIVE"
        info "正在解压..."
        tar -xzf "$FOUND_ARCHIVE" -C "$APP_DIR" >> "$LOG_FILE" 2>&1
        success "代码解压完成"
    elif [ -f "$APP_DIR/package.json" ]; then
        success "使用现有代码"
    else
        echo ""
        echo -e "  ${YELLOW}未找到部署包。请按以下步骤操作:${NC}"
        echo ""
        echo -e "  ${DIM}在本地开发机执行:${NC}"
        echo -e "    cd /path/to/server\\ 3"
        echo -e "    tar --exclude='node_modules' --exclude='.env' -czf /tmp/cert-deploy.tar.gz ."
        echo -e "    scp /tmp/cert-deploy.tar.gz root@$(get_ip):$DEPLOY_DIR/"
        echo ""
        echo -e "  ${DIM}然后重新运行此脚本。${NC}"
        echo ""

        if ! ask_yn "是否已上传部署包？按回车检查..." "n"; then
            fatal "请先上传部署包后重试"
        fi

        # 再次检查
        for f in "$DEPLOY_DIR"/cert-deploy.tar.gz "$DEPLOY_DIR"/deploy.tar.gz; do
            if [ -f "$f" ]; then
                FOUND_ARCHIVE="$f"
                break
            fi
        done

        if [ -z "$FOUND_ARCHIVE" ]; then
            fatal "仍未找到部署包，请上传到 $DEPLOY_DIR/ 后重试"
        fi

        tar -xzf "$FOUND_ARCHIVE" -C "$APP_DIR" >> "$LOG_FILE" 2>&1
        success "代码解压完成"
    fi

    # 创建数据目录
    info "创建数据目录..."
    mkdir -p "$DATA_DIR"/{certificates,profiles,p8keys,uploads,downloads,tmp,ssl}
    success "数据目录创建完成"

    # 设置权限
    chown -R www:www "$DEPLOY_DIR" 2>/dev/null || true
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 7: 写入环境变量                           ║
# ╚══════════════════════════════════════════════════════════════════╝

write_env() {
    step_header 7 "写入环境变量"

    local ENV_FILE="$APP_DIR/.env"

    # 如果已存在，备份
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "已备份旧 .env 文件"
    fi

    cat > "$ENV_FILE" << ENVEOF
# CertVault 环境配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 由部署脚本自动生成

# ====== 服务端口 ======
PORT=$CFG_PORT
SERVER_URL=https://$CFG_DOMAIN

# ====== PostgreSQL ======
PG_HOST=$CFG_PG_HOST
PG_PORT=$CFG_PG_PORT
PG_DATABASE=$CFG_PG_DB
PG_USER=$CFG_PG_USER
PG_PASSWORD=$CFG_PG_PASS

# ====== 数据加密密钥（首次生成后不可更改） ======
ENCRYPTION_KEY=$CFG_ENCRYPTION_KEY

# ====== 应用名称 ======
APP_NAME=CertVault
ENVEOF

    # 邮件配置
    if [ "$CFG_SMTP_CONFIGURED" = "true" ]; then
        cat >> "$ENV_FILE" << SMTPEOF

# ====== 邮件服务 ======
SMTP_HOST=$CFG_SMTP_HOST
SMTP_PORT=$CFG_SMTP_PORT
SMTP_SECURE=$CFG_SMTP_SECURE
SMTP_USER=$CFG_SMTP_USER
SMTP_PASS=$CFG_SMTP_PASS
SMTP_FROM=$CFG_SMTP_USER
SMTP_FROM_NAME=$CFG_SMTP_FROM_NAME
SMTPEOF
    fi

    # 同时在 DEPLOY_DIR 根目录放一份（dotenv 从 cwd 读取）
    cp "$ENV_FILE" "$DEPLOY_DIR/.env"

    chmod 600 "$ENV_FILE" "$DEPLOY_DIR/.env"
    success ".env 配置文件已写入"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                 步骤 8: 安装依赖并构建                           ║
# ╚══════════════════════════════════════════════════════════════════╝

install_dependencies() {
    step_header 8 "安装依赖"

    cd "$APP_DIR"

    if [ ! -f "package.json" ]; then
        fatal "package.json 不存在，请检查代码是否正确部署"
    fi

    info "正在安装 Node.js 依赖..."
    npm install --production >> "$LOG_FILE" 2>&1

    if [ ! -d "node_modules" ]; then
        fatal "npm install 失败，请检查日志: $LOG_FILE"
    fi

    local dep_count=$(ls node_modules/ | wc -l)
    success "依赖安装完成 ($dep_count 个包)"

    # 检查前端
    echo ""
    if [ -f "$APP_DIR/client/index.html" ]; then
        success "前端文件: 已就绪 (client/index.html)"
    else
        warn "前端文件不存在 (client/index.html)"
        echo ""
        echo -e "  ${DIM}前端需要在本地构建后上传:${NC}"
        echo -e "    cd /path/to/p12/client"
        echo -e "    npm install && npm run build"
        echo -e "    scp -r dist/* root@$(get_ip):$APP_DIR/client/"
        echo ""
        warn "管理面板 (/admin/) 将暂时不可用，但 API 可正常运行"
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                 步骤 9: 配置 Nginx                              ║
# ╚══════════════════════════════════════════════════════════════════╝

configure_nginx() {
    step_header 9 "配置 Nginx"

    local NGINX_CONF_DIR="/www/server/panel/vhost/nginx"
    local CONF_NAME="cert-manager"
    local CONF_FILE="$NGINX_CONF_DIR/${CONF_NAME}.conf"

    # 如果宝塔 Nginx 配置目录不存在，尝试标准路径
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        CONF_FILE="$NGINX_CONF_DIR/cert-manager.conf"
        mkdir -p "$NGINX_CONF_DIR"
    fi

    # 备份旧配置
    if [ -f "$CONF_FILE" ]; then
        cp "$CONF_FILE" "${CONF_FILE}.bak.$(date +%Y%m%d)"
        info "已备份旧 Nginx 配置"
    fi

    info "写入 Nginx 配置..."

    cat > "$CONF_FILE" << NGINXEOF
# CertVault Nginx 配置
# 由部署脚本自动生成: $(date '+%Y-%m-%d %H:%M:%S')
# 域名: $CFG_DOMAIN → 127.0.0.1:$CFG_PORT

server {
    listen 80;
    server_name $CFG_DOMAIN;

    # SSL 证书申请验证
    location /.well-known/ {
        root $APP_DIR;
        allow all;
    }

    # HTTP → HTTPS 重定向（配置 SSL 后启用）
    # location / {
    #     return 301 https://\$host\$request_uri;
    # }

    # 暂时直接代理（未配 SSL 前使用）
    location / {
        proxy_pass http://127.0.0.1:$CFG_PORT;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header REMOTE-HOST \$remote_addr;
        proxy_connect_timeout 30s;
        proxy_read_timeout 86400s;
        proxy_send_timeout 30s;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 200m;
    }

    # 禁止访问敏感文件
    location ~ ^/(\.env|\.git|\.htaccess|package\.json|package-lock\.json) {
        return 404;
    }

    access_log /www/wwwlogs/cert-manager.log;
    error_log /www/wwwlogs/cert-manager.error.log;
}
NGINXEOF

    # 创建日志目录
    mkdir -p /www/wwwlogs 2>/dev/null || true

    # 宝塔需要的额外目录
    mkdir -p "$NGINX_CONF_DIR/well-known" 2>/dev/null || true
    mkdir -p "$NGINX_CONF_DIR/extension/cert-manager" 2>/dev/null || true

    # well-known 配置（宝塔 SSL 申请需要）
    if [ -d "$NGINX_CONF_DIR/well-known" ]; then
        cat > "$NGINX_CONF_DIR/well-known/cert-manager.conf" << 'WKEOF'
location /.well-known/ {
    allow all;
}
WKEOF
    fi

    # 测试配置
    if nginx -t >> "$LOG_FILE" 2>&1; then
        nginx -s reload >> "$LOG_FILE" 2>&1
        success "Nginx 配置已生效"
    else
        error "Nginx 配置测试失败"
        nginx -t 2>&1 | tee -a "$LOG_FILE"
        fatal "请检查 Nginx 配置"
    fi

    echo ""
    info "SSL 证书配置:"
    echo -e "  ${DIM}方式一 (推荐): 宝塔面板 → 网站 → 站点设置 → SSL → Let's Encrypt${NC}"
    echo -e "  ${DIM}方式二: certbot --nginx -d $CFG_DOMAIN${NC}"
    echo ""
    echo -e "  ${DIM}配置 SSL 后需要更新 Nginx 配置以启用 HTTPS 重定向。${NC}"
    echo -e "  ${DIM}完整的 HTTPS Nginx 配置模板见 DEPLOY_BAOTA.md 第 9 节。${NC}"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║               步骤 10: 配置 SSL 证书（自动）                      ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_ssl() {
    step_header 10 "SSL 证书"

    local CERT_DIR="/www/server/panel/vhost/cert/cert-manager"

    if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
        success "SSL 证书已存在"
        update_nginx_ssl
        return
    fi

    # 尝试使用 certbot
    if command -v certbot &>/dev/null; then
        if ask_yn "是否使用 certbot 自动申请 SSL 证书？" "y"; then
            info "正在申请 SSL 证书..."
            if certbot certonly --webroot -w "$APP_DIR" -d "$CFG_DOMAIN" --non-interactive --agree-tos --email "admin@$CFG_DOMAIN" >> "$LOG_FILE" 2>&1; then
                # 复制到宝塔目录
                mkdir -p "$CERT_DIR"
                cp "/etc/letsencrypt/live/$CFG_DOMAIN/fullchain.pem" "$CERT_DIR/"
                cp "/etc/letsencrypt/live/$CFG_DOMAIN/privkey.pem" "$CERT_DIR/"
                success "SSL 证书申请成功"
                update_nginx_ssl
                return
            else
                warn "certbot 申请失败，请在宝塔面板中手动申请"
            fi
        fi
    fi

    warn "SSL 证书未配置，请在宝塔面板中手动申请"
    echo -e "  ${DIM}宝塔面板 → 网站 → $CFG_DOMAIN → 设置 → SSL → Let's Encrypt${NC}"
}

update_nginx_ssl() {
    local NGINX_CONF_DIR="/www/server/panel/vhost/nginx"
    local CONF_FILE="$NGINX_CONF_DIR/cert-manager.conf"
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        CONF_FILE="/etc/nginx/conf.d/cert-manager.conf"
    fi

    local CERT_DIR="/www/server/panel/vhost/cert/cert-manager"
    if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
        # 尝试 letsencrypt 目录
        if [ -f "/etc/letsencrypt/live/$CFG_DOMAIN/fullchain.pem" ]; then
            CERT_DIR="/etc/letsencrypt/live/$CFG_DOMAIN"
        else
            return
        fi
    fi

    info "更新 Nginx 配置以启用 HTTPS..."

    cat > "$CONF_FILE" << SSLEOF
# CertVault Nginx 配置 (HTTPS)
# 由部署脚本自动生成: $(date '+%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name $CFG_DOMAIN;

    location /.well-known/ {
        root $APP_DIR;
        allow all;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $CFG_DOMAIN;

    ssl_certificate    $CERT_DIR/fullchain.pem;
    ssl_certificate_key    $CERT_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    add_header Strict-Transport-Security "max-age=31536000";

    # 禁止缓存管理面板入口
    location = /admin/ {
        proxy_pass http://127.0.0.1:$CFG_PORT;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # 反向代理
    location / {
        proxy_pass http://127.0.0.1:$CFG_PORT;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header REMOTE-HOST \$remote_addr;
        proxy_connect_timeout 30s;
        proxy_read_timeout 86400s;
        proxy_send_timeout 30s;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 200m;
    }

    # 安全
    location ~ ^/(\.env|\.git|\.htaccess|package\.json|package-lock\.json) {
        return 404;
    }

    access_log /www/wwwlogs/cert-manager.log;
    error_log /www/wwwlogs/cert-manager.error.log;
}
SSLEOF

    if nginx -t >> "$LOG_FILE" 2>&1; then
        nginx -s reload >> "$LOG_FILE" 2>&1
        success "Nginx HTTPS 配置已生效"
    else
        warn "Nginx SSL 配置测试失败，已保留 HTTP 配置"
    fi

    # 复制证书到 data/ssl（UDID 签名用）
    if [ -d "$DATA_DIR/ssl" ]; then
        cp "$CERT_DIR/fullchain.pem" "$DATA_DIR/ssl/fullchain.pem" 2>/dev/null || true
        cp "$CERT_DIR/privkey.pem" "$DATA_DIR/ssl/privkey.key" 2>/dev/null || true
        # 提取中间证书链
        awk 'BEGIN{c=0} /-----BEGIN CERTIFICATE-----/{c++} c>1' \
            "$CERT_DIR/fullchain.pem" > "$DATA_DIR/ssl/chain.pem" 2>/dev/null || true
        success "SSL 证书已复制到 data/ssl/（UDID 签名用）"
    fi
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 11: 启动应用                              ║
# ╚══════════════════════════════════════════════════════════════════╝

start_application() {
    step_header 11 "启动应用"

    cd "$APP_DIR"

    # 先尝试停止旧进程
    pm2 delete cert-manager >> "$LOG_FILE" 2>&1 || true
    local old_pid=$(pgrep -f "$APP_DIR/app.js" | head -1)
    if [ -n "$old_pid" ]; then
        kill -9 "$old_pid" >> "$LOG_FILE" 2>&1 || true
        sleep 1
    fi

    if [ "${USE_NOHUP:-false}" = "true" ]; then
        # nohup 方式
        info "使用 nohup 启动..."
        cd "$APP_DIR"
        nohup node app.js > /tmp/cert-manager.log 2>&1 &
        echo $! > /tmp/cert-manager.pid
        sleep 3
    else
        # PM2 方式
        info "使用 PM2 启动..."

        # 生成 PM2 配置
        cat > "$APP_DIR/ecosystem.config.js" << PMEOF
module.exports = {
  apps: [{
    name: 'cert-manager',
    script: 'app.js',
    cwd: '$APP_DIR',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production'
    }
  }]
};
PMEOF

        cd "$APP_DIR"
        pm2 start ecosystem.config.js >> "$LOG_FILE" 2>&1
        sleep 3

        # 设置开机自启
        pm2 save >> "$LOG_FILE" 2>&1 || true
        pm2 startup >> "$LOG_FILE" 2>&1 || true
    fi

    # 验证启动
    info "验证应用启动..."
    local retry=0
    while [ $retry -lt 10 ]; do
        if curl -s "http://127.0.0.1:$CFG_PORT/api/health" | grep -q "ok" 2>/dev/null; then
            success "应用启动成功！"

            # 显示进程信息
            if [ "${USE_NOHUP:-false}" != "true" ]; then
                echo ""
                pm2 list | tee -a "$LOG_FILE"
            fi
            return
        fi
        retry=$((retry + 1))
        sleep 2
    done

    error "应用启动验证失败"
    echo ""
    echo -e "  ${DIM}查看日志排查:${NC}"
    if [ "${USE_NOHUP:-false}" = "true" ]; then
        echo -e "    tail -50 /tmp/cert-manager.log"
    else
        echo -e "    pm2 logs cert-manager --lines 50"
    fi
    warn "请排查错误后手动重启"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 12: 配置防火墙                            ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_firewall() {
    step_header 12 "防火墙配置"

    # 宝塔防火墙
    if [ -f /www/server/panel/BT-Panel ]; then
        info "宝塔面板防火墙请在面板中配置:"
        echo -e "  ${DIM}安全 → 防火墙 → 确保 80 和 443 端口已放行${NC}"
    fi

    # 系统防火墙
    if command -v firewall-cmd &>/dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1 || true
            firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1 || true
            firewall-cmd --reload >> "$LOG_FILE" 2>&1 || true
            success "firewalld: 已放行 80/443"
        fi
    elif command -v ufw &>/dev/null; then
        if ufw status | grep -q "active"; then
            ufw allow 80/tcp >> "$LOG_FILE" 2>&1 || true
            ufw allow 443/tcp >> "$LOG_FILE" 2>&1 || true
            success "ufw: 已放行 80/443"
        fi
    fi

    success "防火墙配置完成"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                   步骤 13: 配置定时任务                          ║
# ╚══════════════════════════════════════════════════════════════════╝

setup_crontab() {
    step_header 13 "定时任务"

    # 数据库自动备份
    local BACKUP_DIR="/backup/certvault"
    mkdir -p "$BACKUP_DIR"

    # 检查是否已有备份任务
    if crontab -l 2>/dev/null | grep -q "certmanager_backup"; then
        success "数据库备份任务: 已存在"
    else
        info "添加每日数据库备份任务（凌晨 3 点）..."
        local BACKUP_SCRIPT="$DEPLOY_DIR/backup.sh"
        cat > "$BACKUP_SCRIPT" << BKEOF
#!/bin/bash
# CertVault 自动备份脚本
BACKUP_DIR="$BACKUP_DIR"
mkdir -p "\$BACKUP_DIR"
PGPASSWORD="$CFG_PG_PASS" pg_dump -U "$CFG_PG_USER" -h "$CFG_PG_HOST" "$CFG_PG_DB" | gzip > "\$BACKUP_DIR/certmanager_\$(date +\%Y\%m\%d).sql.gz"
# 保留最近 30 天
find "\$BACKUP_DIR" -name "certmanager_*.sql.gz" -mtime +30 -delete
echo "[\$(date)] Backup completed" >> /var/log/certvault-backup.log
BKEOF
        chmod +x "$BACKUP_SCRIPT"

        (crontab -l 2>/dev/null; echo "0 3 * * * $BACKUP_SCRIPT # certmanager_backup") | crontab -
        success "每日 03:00 自动备份已配置"
    fi

    success "定时任务配置完成"
    echo -e "  ${DIM}备份目录: $BACKUP_DIR${NC}"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                    最终验证与报告                                 ║
# ╚══════════════════════════════════════════════════════════════════╝

final_report() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}${BOLD}              CertVault 部署完成！${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # 最终健康检查
    local api_ok=false
    local admin_ok=false

    if curl -s "http://127.0.0.1:$CFG_PORT/api/health" | grep -q "ok" 2>/dev/null; then
        api_ok=true
    fi
    if curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$CFG_PORT/admin/" 2>/dev/null | grep -q "200"; then
        admin_ok=true
    fi

    echo -e "  ${BOLD}访问地址${NC}" | tee -a "$LOG_FILE"
    echo -e "  ├─ 管理面板:  https://$CFG_DOMAIN/admin/" | tee -a "$LOG_FILE"
    echo -e "  ├─ API 地址:  https://$CFG_DOMAIN/api/" | tee -a "$LOG_FILE"
    echo -e "  └─ 健康检查:  https://$CFG_DOMAIN/api/health" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "  ${BOLD}默认管理员${NC}" | tee -a "$LOG_FILE"
    echo -e "  ├─ 用户名:  admin" | tee -a "$LOG_FILE"
    echo -e "  └─ 密码:    admin123  ${RED}（请立即修改！）${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "  ${BOLD}服务状态${NC}" | tee -a "$LOG_FILE"
    echo -e "  ├─ API 接口:     $([ "$api_ok" = true ] && echo -e "${GREEN}✓ 正常${NC}" || echo -e "${RED}✗ 异常${NC}")" | tee -a "$LOG_FILE"
    echo -e "  ├─ 管理面板:     $([ "$admin_ok" = true ] && echo -e "${GREEN}✓ 正常${NC}" || echo -e "${YELLOW}⚠ 未就绪（需上传前端）${NC}")" | tee -a "$LOG_FILE"
    echo -e "  ├─ Node.js:      $(node -v)" | tee -a "$LOG_FILE"
    echo -e "  ├─ PostgreSQL:   $(psql --version 2>/dev/null | head -1 || echo '未知')" | tee -a "$LOG_FILE"
    echo -e "  └─ 进程管理:     $([ "${USE_NOHUP:-false}" = "true" ] && echo "nohup" || echo "PM2")" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "  ${BOLD}重要路径${NC}" | tee -a "$LOG_FILE"
    echo -e "  ├─ 应用目录:  $APP_DIR" | tee -a "$LOG_FILE"
    echo -e "  ├─ 数据目录:  $DATA_DIR" | tee -a "$LOG_FILE"
    echo -e "  ├─ 环境配置:  $APP_DIR/.env" | tee -a "$LOG_FILE"
    echo -e "  ├─ 备份目录:  /backup/certvault" | tee -a "$LOG_FILE"
    echo -e "  └─ 部署日志:  $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "  ${BOLD}常用命令${NC}" | tee -a "$LOG_FILE"
    if [ "${USE_NOHUP:-false}" != "true" ]; then
        echo -e "  ├─ 查看状态:  pm2 list" | tee -a "$LOG_FILE"
        echo -e "  ├─ 查看日志:  pm2 logs cert-manager" | tee -a "$LOG_FILE"
        echo -e "  ├─ 重启服务:  pm2 restart cert-manager" | tee -a "$LOG_FILE"
        echo -e "  └─ 停止服务:  pm2 stop cert-manager" | tee -a "$LOG_FILE"
    else
        echo -e "  ├─ 查看日志:  tail -f /tmp/cert-manager.log" | tee -a "$LOG_FILE"
        echo -e "  └─ 重启服务:  kill \$(cat /tmp/cert-manager.pid); cd $DEPLOY_DIR && nohup node deploy/src/app.js > /tmp/cert-manager.log 2>&1 &" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"

    if [ "$CFG_SMTP_CONFIGURED" != "true" ]; then
        echo -e "  ${YELLOW}提示: 邮件服务未配置，注册验证码功能不可用。${NC}" | tee -a "$LOG_FILE"
        echo -e "  ${DIM}编辑 $APP_DIR/.env 添加 SMTP 配置后重启即可。${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi

    echo -e "  ${BOLD}数据库连接信息（请妥善保管）${NC}" | tee -a "$LOG_FILE"
    echo -e "  ├─ 主机:  $CFG_PG_HOST:$CFG_PG_PORT" | tee -a "$LOG_FILE"
    echo -e "  ├─ 库名:  $CFG_PG_DB" | tee -a "$LOG_FILE"
    echo -e "  ├─ 用户:  $CFG_PG_USER" | tee -a "$LOG_FILE"
    echo -e "  └─ 密码:  $CFG_PG_PASS" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "  ${BOLD}加密密钥（请妥善备份，丢失将无法恢复数据）${NC}" | tee -a "$LOG_FILE"
    echo -e "  └─ $CFG_ENCRYPTION_KEY" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ╔══════════════════════════════════════════════════════════════════╗
# ║                         主 流 程                                 ║
# ╚══════════════════════════════════════════════════════════════════╝

main() {
    show_banner

    echo -e "  即将执行以下步骤:"
    echo -e "  ${DIM} 1. 环境检查        7. 写入环境变量${NC}"
    echo -e "  ${DIM} 2. 收集配置信息    8. 安装依赖${NC}"
    echo -e "  ${DIM} 3. 安装 Node.js    9. 配置 Nginx${NC}"
    echo -e "  ${DIM} 4. 安装 PostgreSQL  10. 配置 SSL${NC}"
    echo -e "  ${DIM} 5. 配置数据库      11. 启动应用${NC}"
    echo -e "  ${DIM} 6. 部署应用代码    12. 防火墙设置${NC}"
    echo -e "  ${DIM}                    13. 定时任务${NC}"
    echo ""

    if ! ask_yn "开始部署？" "y"; then
        echo "已取消"
        exit 0
    fi

    check_environment        # 1
    collect_config           # 2
    install_nodejs           # 3
    install_pm2              # 3.5
    install_postgresql       # 4
    setup_database           # 5
    deploy_code              # 6
    write_env                # 7
    install_dependencies     # 8
    configure_nginx          # 9
    setup_ssl                # 10
    start_application        # 11
    setup_firewall           # 12
    setup_crontab            # 13
    final_report             # 完成
}

main "$@"
