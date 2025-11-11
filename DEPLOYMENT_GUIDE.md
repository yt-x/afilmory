# Afilmory 阿里云 ECS 部署完整指南

本指南提供在阿里云 ECS 服务器上使用 Docker 部署 Afilmory 画廊的完整步骤。

## 📋 前置要求

### 已完成项
- ✅ 阿里云 ECS 服务器 (Ubuntu/Debian)
- ✅ 阿里云 OSS 存储桶 (已创建并上传图片)
- ✅ OSS AccessKey ID 和 AccessKey Secret

### 需要准备的信息
请准备好以下信息,稍后会用到:

1. **OSS 配置**
   - `Bucket 名称`: 例如 `my-gallery-photos`
   - `Region`: 例如 `oss-cn-hangzhou`
   - `Endpoint`: 例如 `https://oss-cn-hangzhou.aliyuncs.com`
   - `AccessKey ID`: 你的访问密钥 ID
   - `AccessKey Secret`: 你的访问密钥
   - `Prefix` (可选): OSS 中图片的路径前缀,例如 `photos/`

2. **ECS 服务器**
   - 公网 IP 地址
   - SSH 登录信息

3. **域名配置** (可选,暂时用不到)
   - 域名备案完成后再配置

## 🚀 部署步骤

### 第一步: 连接到 ECS 服务器

使用 SSH 连接到你的 ECS 服务器:

```bash
ssh root@your-ecs-ip
```

### 第二步: 安装必要软件

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 安装 Docker Compose
apt install docker-compose -y

# 安装 Nginx (用于反向代理)
apt install nginx -y

# 安装 Git
apt install git -y

# 验证安装
docker --version
docker-compose --version
nginx -v
```

### 第三步: 克隆项目到服务器

```bash
# 进入工作目录
cd /opt

# 克隆项目
git clone https://github.com/Afilmory/afilmory.git
cd afilmory

# 如果网络慢,可以使用国内镜像
# git clone https://gitee.com/mirrors/afilmory.git
```

### 第四步: 配置环境变量

创建 `.env` 文件:

```bash
# 复制模板文件
cp .env.template .env

# 编辑配置文件
nano .env
```

在 `.env` 文件中填入以下内容 (请替换成你的真实信息):

```env
# 阿里云 OSS 配置
S3_ACCESS_KEY_ID=你的AccessKey_ID
S3_SECRET_ACCESS_KEY=你的AccessKey_Secret
S3_BUCKET_NAME=你的Bucket名称
S3_REGION=oss-cn-hangzhou
S3_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
S3_PREFIX=
S3_CUSTOM_DOMAIN=
S3_EXCLUDE_REGEX=

# 可选: Git Token (用于缓存构建结果到 GitHub)
# GIT_TOKEN=

# 可选: PostgreSQL 数据库
# PG_CONNECTION_STRING=
```

**重要提示:**
- 确保没有多余的空格
- Region 和 Endpoint 要匹配你的 Bucket 所在地域
- 保存后按 `Ctrl+X`, 然后按 `Y`, 再按 `Enter`

### 第五步: 配置站点信息

创建 `config.json` 文件:

```bash
nano config.json
```

填入以下内容 (替换成你的个人信息):

```json
{
  "name": "我的摄影画廊",
  "title": "我的摄影作品集",
  "description": "记录生活中的美好瞬间",
  "url": "http://你的ECS公网IP:3000",
  "accentColor": "#007bff",
  "author": {
    "name": "你的名字",
    "url": "https://你的网站.com",
    "avatar": "https://你的头像链接.jpg"
  },
  "social": {
    "github": "你的GitHub用户名",
    "rss": true
  }
}
```

### 第六步: 创建 Docker 配置

创建 `docker-compose.yml` 文件:

```bash
nano docker-compose.yml
```

使用本项目提供的 `docker-compose.production.yml` 内容。

### 第七步: 构建和启动服务

```bash
# 使用 Docker Compose 构建和启动
docker-compose -f docker-compose.production.yml up -d

# 查看日志
docker-compose -f docker-compose.production.yml logs -f

# 等待构建完成 (首次构建需要较长时间,约 10-30 分钟)
```

**构建过程说明:**
1. 首次运行会从 OSS 下载所有图片
2. 生成缩略图和 EXIF 信息
3. 创建 manifest.json 索引文件
4. 构建前端应用

### 第八步: 配置 Nginx 反向代理

创建 Nginx 配置文件:

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
# 创建软链接
ln -s /etc/nginx/sites-available/afilmory /etc/nginx/sites-enabled/

# 测试配置
nginx -t

# 重启 Nginx
systemctl restart nginx
```

### 第九步: 配置防火墙

```bash
# 开放 HTTP 端口
ufw allow 80

# 开放 HTTPS 端口 (为将来准备)
ufw allow 443

# 重载防火墙
ufw reload
```

### 第十步: 访问你的画廊

在浏览器中访问:

```
http://你的ECS公网IP
```

## 🔧 常用管理命令

### 查看运行状态

```bash
cd /opt/afilmory
docker-compose -f docker-compose.production.yml ps
```

### 查看日志

```bash
# 查看所有日志
docker-compose -f docker-compose.production.yml logs

# 实时查看日志
docker-compose -f docker-compose.production.yml logs -f

# 查看最近 100 行
docker-compose -f docker-compose.production.yml logs --tail=100
```

### 重启服务

```bash
docker-compose -f docker-compose.production.yml restart
```

### 停止服务

```bash
docker-compose -f docker-compose.production.yml down
```

### 更新内容

当 OSS 中添加了新图片后:

```bash
# 进入容器
docker-compose -f docker-compose.production.yml exec app sh

# 在容器内运行增量更新
pnpm run build:manifest

# 退出容器
exit

# 重启服务使更改生效
docker-compose -f docker-compose.production.yml restart
```

### 完全重新构建

```bash
cd /opt/afilmory
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d --build
```

## 🌐 配置 HTTPS (域名备案完成后)

### 第一步: 安装 Certbot

```bash
apt install certbot python3-certbot-nginx -y
```

### 第二步: 修改 Nginx 配置

```bash
nano /etc/nginx/sites-available/afilmory
```

将 `server_name` 改为你的域名:

```nginx
server_name 你的域名.com;
```

### 第三步: 申请 SSL 证书

```bash
certbot --nginx -d 你的域名.com
```

按照提示完成配置,Certbot 会自动修改 Nginx 配置并申请证书。

### 第四步: 更新 config.json

```bash
nano /opt/afilmory/config.json
```

将 `url` 改为:

```json
{
  "url": "https://你的域名.com"
}
```

然后重启服务:

```bash
docker-compose -f docker-compose.production.yml restart
```

## ❓ 故障排查

### 1. 容器无法启动

```bash
# 查看详细日志
docker-compose -f docker-compose.production.yml logs app

# 检查环境变量是否正确加载
docker-compose -f docker-compose.production.yml exec app env | grep S3
```

### 2. 无法连接 OSS

检查:
- `.env` 文件中的 AccessKey 是否正确
- Region 和 Endpoint 是否匹配
- ECS 安全组是否允许出站访问
- OSS Bucket 权限是否正确配置

### 3. 构建失败

```bash
# 进入容器检查
docker-compose -f docker-compose.production.yml exec app sh

# 手动运行构建
pnpm run build:manifest -- --force

# 查看错误信息
```

### 4. Nginx 502 错误

```bash
# 检查应用是否在运行
docker-compose -f docker-compose.production.yml ps

# 检查端口是否被占用
netstat -tlnp | grep 3000

# 查看 Nginx 错误日志
tail -f /var/log/nginx/error.log
```

### 5. 环境变量未生效

这是之前遇到的主要问题。确保:
- `.env` 文件在项目根目录
- `.env` 文件格式正确,没有多余空格
- Docker Compose 配置正确引用了 `.env` 文件
- 重启容器后环境变量才会生效

## 📊 性能优化建议

1. **ECS 规格**: 建议至少 2核4GB 内存
2. **OSS 配置**: 开启 OSS CDN 加速图片访问
3. **图片优化**: 大图建议在上传前先压缩
4. **缓存策略**: Nginx 可以配置静态资源缓存

## 🔄 更新项目

```bash
cd /opt/afilmory

# 拉取最新代码
git pull

# 重新构建
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d --build
```

## 📝 备份数据

重要数据:
- `/opt/afilmory/.env` - 环境配置
- `/opt/afilmory/config.json` - 站点配置
- OSS 中的原始图片

建议定期备份这些文件。

## 🆘 需要帮助?

- GitHub Issues: https://github.com/Afilmory/afilmory/issues
- 项目文档: https://github.com/Afilmory/afilmory

---

**祝部署顺利!** 🎉
