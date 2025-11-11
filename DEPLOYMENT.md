# Afilmory 阿里云 ECS Docker 部署指南

本指南提供在阿里云 ECS 上使用 Docker 部署 Afilmory 的**最小改动方案**。

## 📋 部署方案说明

### 使用的文件
- ✅ **已存在的 `Dockerfile`** - 项目自带,无需修改
- ✅ **已存在的 `Dockerfile.core`** - 后端服务,本次不使用
- ✅ **已存在的 `scripts/preinstall.sh`** - 自动创建配置文件
- ✅ **模板文件** - `config.example.json` 和 `builder.config.default.ts`

### 需要创建的文件
- 📝 `.env` - 阿里云 OSS 配置 (必须)
- 📝 `config.json` - 站点配置 (可选,有默认值)
- 📝 `builder.config.ts` - 构建配置 (可选,有默认值)

## 🚀 完整部署步骤

### 第一步: 连接 ECS 服务器

```bash
ssh root@你的ECS公网IP
```

### 第二步: 安装 Docker

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 验证安装
docker --version
```

### 第三步: 克隆项目

```bash
cd /opt
git clone https://github.com/Afilmory/afilmory.git
cd afilmory
```

### 第四步: 配置环境变量 ⚠️ 重要

创建 `.env` 文件 (这是之前环境变量没有生效的原因):

```bash
nano .env
```

填入以下内容 (替换成你的真实配置):

```env
# 阿里云 OSS 配置 - 必须填写
S3_ACCESS_KEY_ID=你的AccessKeyID
S3_SECRET_ACCESS_KEY=你的AccessKeySecret
S3_BUCKET_NAME=你的Bucket名称
S3_REGION=你的Region
S3_ENDPOINT=你的Endpoint
S3_PREFIX=
S3_CUSTOM_DOMAIN=

# 可选配置
GIT_TOKEN=
PG_CONNECTION_STRING=
```

**重要说明:**
- 等号两边不要有空格
- 不要有多余的引号
- `S3_REGION` 示例: `oss-cn-hangzhou`
- `S3_ENDPOINT` 示例: `https://oss-cn-hangzhou.aliyuncs.com`

保存: `Ctrl+X` → `Y` → `Enter`

### 第五步: 配置站点信息 (可选)

如果要自定义站点信息,创建 `config.json`:

```bash
cp config.example.json config.json
nano config.json
```

修改以下字段:

```json
{
  "name": "我的摄影画廊",
  "title": "我的摄影作品",
  "description": "记录生活美好瞬间",
  "url": "http://你的ECS_IP:3000",
  "author": {
    "name": "你的名字",
    "url": "https://你的网站.com"
  }
}
```

> **注意**: 如果不创建此文件,`preinstall.sh` 会自动复制 `config.example.json`

### 第六步: 构建 Docker 镜像

```bash
# 从项目根目录构建
docker build -t afilmory -f Dockerfile .
```

**构建说明:**
- 使用项目自带的 `Dockerfile`
- 构建时会自动运行 `scripts/preinstall.sh`
- 如果没有 `config.json` 和 `builder.config.ts`,会自动创建
- 构建时间约 10-30 分钟,取决于网络和服务器性能

### 第七步: 运行容器

```bash
docker run -d \
  --name afilmory \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env \
  afilmory
```

**参数说明:**
- `-d`: 后台运行
- `--name afilmory`: 容器名称
- `--restart unless-stopped`: 自动重启
- `-p 3000:3000`: 端口映射
- `--env-file .env`: 从 `.env` 文件加载环境变量

### 第八步: 查看日志

```bash
# 查看实时日志
docker logs -f afilmory

# 查看最近 100 行
docker logs --tail=100 afilmory
```

**等待构建完成:**
- 首次运行会从 OSS 下载图片
- 生成缩略图和 EXIF 信息
- 完成后会显示 "Server running on port 3000"

### 第九步: 配置 Nginx 反向代理

安装 Nginx:

```bash
apt install nginx -y
```

创建配置文件:

```bash
nano /etc/nginx/sites-available/afilmory
```

填入以下内容:

```nginx
server {
    listen 80;
    server_name 你的ECS公网IP;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

启用配置:

```bash
ln -s /etc/nginx/sites-available/afilmory /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

### 第十步: 配置防火墙

```bash
# 开放 HTTP 端口
ufw allow 80
ufw allow 443

# 如果防火墙未启用,先启用
ufw enable
```

**同时检查阿里云安全组:**
- 在 ECS 控制台添加入站规则
- 开放 80 和 443 端口

### 第十一步: 访问画廊

在浏览器中访问:

```
http://你的ECS公网IP
```

## 🔧 常用管理命令

### 容器管理

```bash
# 查看容器状态
docker ps

# 停止容器
docker stop afilmory

# 启动容器
docker start afilmory

# 重启容器
docker restart afilmory

# 删除容器
docker rm -f afilmory
```

### 更新图片内容

当 OSS 中添加新图片后:

```bash
# 进入运行中的容器
docker exec -it afilmory sh

# 运行增量更新
cd /app
sh ./scripts/preinstall.sh
pnpm install --frozen-lockfile
pnpm run build:manifest

# 退出容器
exit

# 重启容器
docker restart afilmory
```

### 完全重新构建

```bash
cd /opt/afilmory

# 拉取最新代码 (可选)
git pull

# 停止并删除旧容器
docker stop afilmory
docker rm afilmory

# 删除旧镜像
docker rmi afilmory

# 重新构建和运行
docker build -t afilmory -f Dockerfile .
docker run -d --name afilmory --restart unless-stopped -p 3000:3000 --env-file .env afilmory
```

## 🌐 配置 HTTPS (域名备案完成后)

### 方法一: 使用 Certbot

```bash
# 安装 Certbot
apt install certbot python3-certbot-nginx -y

# 修改 Nginx 配置,将 server_name 改为域名
nano /etc/nginx/sites-available/afilmory
# 将 "你的ECS公网IP" 改为 "你的域名.com"

# 重启 Nginx
systemctl restart nginx

# 申请证书
certbot --nginx -d 你的域名.com

# 按提示完成配置
```

### 方法二: 使用阿里云 SSL 证书

1. 在阿里云控制台申请免费 SSL 证书
2. 下载 Nginx 格式证书
3. 上传到服务器 `/etc/nginx/ssl/`
4. 修改 Nginx 配置:

```nginx
server {
    listen 443 ssl http2;
    server_name 你的域名.com;

    ssl_certificate /etc/nginx/ssl/your-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/your-cert.key;

    # ... 其他配置
}

server {
    listen 80;
    server_name 你的域名.com;
    return 301 https://$server_name$request_uri;
}
```

更新 `config.json` 中的 URL:

```bash
docker exec -it afilmory sh
nano /app/config.json
# 将 url 改为 https://你的域名.com
exit
docker restart afilmory
```

## ❓ 故障排查

### 问题 1: 容器无法启动

```bash
# 查看详细日志
docker logs afilmory

# 检查环境变量
docker exec afilmory env | grep S3
```

**常见原因:**
- `.env` 文件格式错误
- OSS 配置信息不正确
- 端口被占用

### 问题 2: 环境变量未生效 ⚠️

这是你之前遇到的问题。确保:

1. `.env` 文件在项目根目录
2. 使用 `--env-file .env` 参数运行容器
3. `.env` 文件格式正确,无多余空格

验证环境变量:

```bash
docker exec afilmory env | grep S3_
```

应该能看到你配置的值。

### 问题 3: 无法连接 OSS

```bash
# 进入容器测试连接
docker exec -it afilmory sh

# 测试网络
ping oss-cn-hangzhou.aliyuncs.com

# 检查环境变量
echo $S3_ENDPOINT
echo $S3_BUCKET_NAME
```

**检查项:**
- ECS 安全组允许出站访问
- AccessKey 权限正确
- Bucket 名称和 Region 匹配

### 问题 4: 构建时间过长

正常情况下首次构建需要 10-30 分钟:
- 下载依赖包
- 从 OSS 下载图片
- 生成缩略图
- 编译前端代码

可以通过日志查看进度:

```bash
docker logs -f afilmory
```

### 问题 5: Nginx 502 错误

```bash
# 检查容器是否运行
docker ps | grep afilmory

# 检查应用是否监听 3000 端口
docker exec afilmory netstat -tlnp | grep 3000

# 检查 Nginx 配置
nginx -t

# 查看 Nginx 错误日志
tail -f /var/log/nginx/error.log
```

## 📊 性能优化建议

1. **ECS 规格**: 建议至少 2核4GB 内存
2. **OSS CDN**: 开启 OSS CDN 加速图片访问
3. **图片优化**: 上传前压缩大图
4. **缓存配置**: 在 Nginx 中配置静态资源缓存

## 🔄 自动化部署脚本

创建一键部署脚本 (可选):

```bash
nano /opt/afilmory/deploy.sh
```

内容:

```bash
#!/bin/bash
set -e

cd /opt/afilmory

echo "拉取最新代码..."
git pull

echo "停止旧容器..."
docker stop afilmory || true
docker rm afilmory || true

echo "构建新镜像..."
docker build -t afilmory -f Dockerfile .

echo "启动新容器..."
docker run -d \
  --name afilmory \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env \
  afilmory

echo "查看日志..."
docker logs -f afilmory
```

使其可执行:

```bash
chmod +x /opt/afilmory/deploy.sh
```

使用:

```bash
/opt/afilmory/deploy.sh
```

## 📝 重要提示

1. **环境变量**: 必须通过 `.env` 文件或 `--env-file` 参数传入
2. **配置文件**: `config.json` 和 `builder.config.ts` 会自动创建默认版本
3. **Docker 构建**: 使用项目自带的 `Dockerfile`,无需修改
4. **端口映射**: 默认 3000,可根据需要修改
5. **数据持久化**: 图片存储在 OSS,无需本地持久化

## 🆘 获取帮助

- GitHub Issues: https://github.com/Afilmory/afilmory/issues
- 官方 Docker 仓库: https://github.com/Afilmory/docker

---

**部署愉快!** 🎉
