#!/bin/bash
# Afilmory 快速部署脚本
# 适用于阿里云 ECS (Ubuntu/Debian)

set -e

echo "================================================"
echo "Afilmory 快速部署脚本"
echo "================================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 用户运行此脚本${NC}"
    echo "使用: sudo bash quick-deploy.sh"
    exit 1
fi

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo -e "${RED}错误: 未找到 .env 文件${NC}"
    echo ""
    echo "请先创建 .env 文件并配置阿里云 OSS 信息:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

echo -e "${GREEN}✓ 找到 .env 文件${NC}"

# 检查 .env 文件中的必要变量
echo "检查环境变量配置..."
REQUIRED_VARS=("S3_ACCESS_KEY_ID" "S3_SECRET_ACCESS_KEY" "S3_BUCKET_NAME" "S3_REGION" "S3_ENDPOINT")
for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${var}=" .env || grep -q "^${var}=$" .env || grep -q "^${var}=your_" .env; then
        echo -e "${RED}错误: .env 文件中 ${var} 未配置或使用了默认值${NC}"
        echo "请编辑 .env 文件并填入真实的配置"
        exit 1
    fi
done
echo -e "${GREEN}✓ 环境变量配置检查通过${NC}"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装,正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}✓ Docker 安装完成${NC}"
else
    echo -e "${GREEN}✓ Docker 已安装${NC}"
fi

# 检查 Nginx 是否安装
if ! command -v nginx &> /dev/null; then
    echo "Nginx 未安装,正在安装..."
    apt update
    apt install -y nginx
    echo -e "${GREEN}✓ Nginx 安装完成${NC}"
else
    echo -e "${GREEN}✓ Nginx 已安装${NC}"
fi

echo ""
echo "================================================"
echo "开始构建 Docker 镜像"
echo "================================================"
echo "⚠️  首次构建需要 10-30 分钟,请耐心等待..."
echo ""

# 停止并删除旧容器
if docker ps -a | grep -q afilmory; then
    echo "停止并删除旧容器..."
    docker stop afilmory 2>/dev/null || true
    docker rm afilmory 2>/dev/null || true
fi

# 构建镜像
echo "构建 Docker 镜像 (这可能需要较长时间)..."
docker build -t afilmory -f Dockerfile .

echo -e "${GREEN}✓ Docker 镜像构建完成${NC}"
echo ""

# 运行容器
echo "启动容器..."
docker run -d \
  --name afilmory \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env \
  afilmory

echo -e "${GREEN}✓ 容器启动成功${NC}"
echo ""

# 等待服务启动
echo "等待服务启动 (最多等待 120 秒)..."
for i in {1..120}; do
    if docker logs afilmory 2>&1 | grep -q "ready\|started\|listening"; then
        echo -e "${GREEN}✓ 服务已启动${NC}"
        break
    fi
    if [ $i -eq 120 ]; then
        echo -e "${YELLOW}⚠ 服务启动时间较长,请手动查看日志: docker logs -f afilmory${NC}"
    fi
    sleep 1
done

echo ""
echo "================================================"
echo "配置 Nginx 反向代理"
echo "================================================"

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me || echo "请手动输入")

# 创建 Nginx 配置
cat > /etc/nginx/sites-available/afilmory <<EOF
server {
    listen 80;
    server_name ${SERVER_IP};

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# 启用配置
ln -sf /etc/nginx/sites-available/afilmory /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

echo -e "${GREEN}✓ Nginx 配置完成${NC}"
echo ""

# 配置防火墙
if command -v ufw &> /dev/null; then
    echo "配置防火墙..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo -e "${GREEN}✓ 防火墙规则已添加${NC}"
else
    echo -e "${YELLOW}⚠ 未检测到 ufw,请手动配置防火墙${NC}"
fi

echo ""
echo "================================================"
echo "🎉 部署完成!"
echo "================================================"
echo ""
echo "访问地址: http://${SERVER_IP}"
echo ""
echo "常用命令:"
echo "  查看日志: docker logs -f afilmory"
echo "  重启服务: docker restart afilmory"
echo "  停止服务: docker stop afilmory"
echo ""
echo -e "${YELLOW}⚠️  重要提示:${NC}"
echo "1. 请确保阿里云安全组已开放 80 和 443 端口"
echo "2. 首次运行需要从 OSS 下载图片并生成缩略图,请查看日志了解进度"
echo "3. 域名备案完成后,可以配置 HTTPS (参考 DEPLOYMENT.md)"
echo ""
echo "查看实时日志:"
echo "  docker logs -f afilmory"
echo ""
