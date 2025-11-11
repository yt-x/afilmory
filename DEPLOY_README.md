# 🚀 快速部署指南

## 方案说明

本方案基于项目自带的 `Dockerfile`,**零修改**现有文件,通过环境变量配置阿里云 OSS。

## ✅ 最小改动清单

### 无需修改的文件
- ✅ `Dockerfile` - 使用现有文件
- ✅ `Dockerfile.core` - 不使用
- ✅ `scripts/preinstall.sh` - 现有脚本会自动创建配置文件
- ✅ 所有源代码文件

### 需要创建的文件
- 📝 `.env` - **必须创建** (配置 OSS)
- 📝 `config.json` - 可选 (不创建会用默认值)
- 📝 `builder.config.ts` - 可选 (不创建会用默认值)

## 🎯 核心问题解决

**你之前遇到的问题: `.env` 中的 S3 密码等信息没有读进去**

**原因:** Docker 容器运行时未正确加载环境变量

**解决方案:** 使用 `--env-file .env` 参数

## ⚡ 三步快速部署

### 方法一: 自动化脚本 (推荐)

```bash
# 1. 在 ECS 上克隆项目
cd /opt
git clone https://github.com/Afilmory/afilmory.git
cd afilmory

# 2. 配置环境变量
cp .env.example .env
nano .env  # 填入你的 OSS 配置

# 3. 运行一键部署脚本
chmod +x quick-deploy.sh
./quick-deploy.sh
```

### 方法二: 手动部署

```bash
# 1. 创建 .env 文件
cat > .env <<EOF
S3_ACCESS_KEY_ID=你的AccessKeyID
S3_SECRET_ACCESS_KEY=你的AccessKeySecret
S3_BUCKET_NAME=你的Bucket名称
S3_REGION=oss-cn-hangzhou
S3_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
EOF

# 2. 构建镜像
docker build -t afilmory -f Dockerfile .

# 3. 运行容器
docker run -d \
  --name afilmory \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env \
  afilmory
```

## 📋 环境变量配置模板

创建 `.env` 文件:

```env
# 阿里云 OSS 配置 (必填)
S3_ACCESS_KEY_ID=你的AccessKeyID
S3_SECRET_ACCESS_KEY=你的AccessKeySecret
S3_BUCKET_NAME=你的Bucket名称
S3_REGION=oss-cn-hangzhou
S3_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com

# 可选配置
S3_PREFIX=
S3_CUSTOM_DOMAIN=
GIT_TOKEN=
PG_CONNECTION_STRING=
```

**重要提示:**
- 等号两边不要有空格
- 不要添加引号
- 确保 Region 和 Endpoint 匹配

## 🔍 验证环境变量

```bash
# 检查环境变量是否正确加载
docker exec afilmory env | grep S3_

# 应该能看到你配置的值
```

## 📊 查看日志

```bash
# 实时查看日志
docker logs -f afilmory

# 查看最近 100 行
docker logs --tail=100 afilmory
```

## 🌐 访问画廊

```
http://你的ECS公网IP:3000
```

或配置 Nginx 后访问:

```
http://你的ECS公网IP
```

## 📚 详细文档

- **完整部署指南**: `DEPLOYMENT.md` - 包含详细步骤和故障排查
- **部署文档**: `DEPLOYMENT_GUIDE.md` - 原始完整文档
- **环境变量示例**: `.env.example` - 配置模板

## ❓ 常见问题

### Q1: 环境变量没有生效?

**检查步骤:**
1. 确认 `.env` 文件在项目根目录
2. 运行容器时使用了 `--env-file .env` 参数
3. 文件格式正确,无多余空格

**验证:**
```bash
docker exec afilmory env | grep S3_
```

### Q2: 无法连接 OSS?

**检查项:**
- AccessKey 是否正确
- Region 和 Endpoint 是否匹配
- ECS 安全组允许出站访问
- Bucket 权限配置

### Q3: 构建时间很长?

正常情况,首次构建需要 10-30 分钟:
- 安装依赖
- 从 OSS 下载图片
- 生成缩略图
- 提取 EXIF 信息

### Q4: 如何更新内容?

当 OSS 添加新图片后:

```bash
# 进入容器
docker exec -it afilmory sh

# 增量更新
pnpm run build:manifest

# 退出并重启
exit
docker restart afilmory
```

## 🔧 管理命令速查

```bash
# 容器管理
docker ps                    # 查看运行状态
docker logs -f afilmory      # 查看日志
docker restart afilmory      # 重启
docker stop afilmory         # 停止
docker start afilmory        # 启动

# 完全重建
docker stop afilmory && docker rm afilmory
docker rmi afilmory
docker build -t afilmory -f Dockerfile .
docker run -d --name afilmory --restart unless-stopped -p 3000:3000 --env-file .env afilmory
```

## 🎁 项目文件说明

```
afilmory/
├── Dockerfile                    # ✅ 现有文件,使用此文件构建
├── .env                          # 📝 需要创建 (必须)
├── .env.example                  # 📄 新增: 配置模板
├── config.json                   # 📝 可选创建 (有默认值)
├── config.example.json           # ✅ 现有模板
├── builder.config.ts             # 📝 可选创建 (有默认值)
├── builder.config.default.ts     # ✅ 现有模板
├── scripts/preinstall.sh         # ✅ 自动创建配置文件
├── DEPLOYMENT.md                 # 📄 新增: 完整部署指南
├── DEPLOY_README.md              # 📄 新增: 快速参考
└── quick-deploy.sh               # 📄 新增: 一键部署脚本
```

## 🆘 获取帮助

- GitHub Issues: https://github.com/Afilmory/afilmory/issues
- 官方文档: https://github.com/Afilmory/afilmory

---

**祝部署顺利!** 🎉

如遇问题请查看 `DEPLOYMENT.md` 中的故障排查章节。
