# GHCR Deploy

把本仓库的 `.github/workflows/deploy.yml` 和 `scripts/deploy-ghcr.sh` 复制到项目的相同位置即可使用。

## 项目需要修改

目标服务名默认为 `app`。如果不同，修改工作流顶部：

```yaml
env:
  COMPOSE_SERVICE: app
```

Compose 中目标服务必须使用 `APP_IMAGE_REF`：

```yaml
services:
  app:
    image: ${APP_IMAGE_REF:-my-app:local}
```

部署脚本把服务器上的 `.env` 用作 Compose 插值文件。如果应用容器也需要其中的变量，必须在 Compose 服务中显式引用：

```yaml
services:
  app:
    env_file: .env
```

脚本只拉取、更新并检查 `COMPOSE_SERVICE` 指定的服务；Compose 声明的依赖仍会按需启动，其他服务不会被批量重建或删除。

如需在应用中显示版本，Dockerfile 可加入：

```dockerfile
ARG APP_VERSION=development
ENV APP_VERSION=$APP_VERSION
```

如果 Dockerfile、Compose 文件名或构建目录不是默认值，直接修改 `deploy.yml` 中对应路径。默认只构建 `linux/amd64` 镜像。

Compose 引用了其他本地文件时，把对应文件或顶级目录加入 `Upload deployment files` 的 `source` 列表，用逗号分隔。上传会保留源文件的相对目录结构。

## 首次配置

服务器需要 Docker、支持 `--wait` 的 Docker Compose v2、Bash、tar 和支持密钥认证的 SSH 服务，并在部署目录中准备生产 `.env` 和持久化数据目录。目标服务应配置 `healthcheck`，否则部署只能确认容器已经运行，不能确认应用已经就绪。

为 GitHub Actions 创建一个无密码短语的专用 SSH 密钥。密钥只用于部署，不要提交到仓库：

```shell
ssh-keygen -t ed25519 -C "github-actions-deploy" -f github-actions-deploy
```

把生成的 `github-actions-deploy.pub` 公钥内容加入部署用户在服务器上的 `~/.ssh/authorized_keys`。

在服务器控制台或可信 SSH 会话中查看服务器 SSH 主机公钥的 SHA256 指纹。例如，使用 ED25519 主机密钥的服务器：

```shell
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

将输出中的 `SHA256:...` 部分保存到 GitHub Secret，使用服务器实际提供的主机密钥指纹，而不是部署用户的公钥指纹。不要只依赖未经核对的 `ssh-keyscan` 结果判断服务器身份。

在 GitHub 仓库的 `production` Environment 或 Actions Secrets 中配置：

- `SERVER_HOST`
- `SERVER_USER`
- `SERVER_SSH_PRIVATE_KEY`，内容为 `github-actions-deploy` 私钥的完整文本
- `SERVER_FINGERPRINT`，内容为已核对的服务器 SSH 主机公钥指纹，格式为 `SHA256:...`
- `DEPLOY_PATH`，例如 `/opt/my-app`，必须为绝对路径且不能是 `/`

工作流通过 `appleboy/ssh-action` 执行远程命令、`appleboy/scp-action` 上传文件，使用该私钥认证，并在每次连接时通过 `SERVER_FINGERPRINT` 校验服务器身份。指纹未配置时，工作流会在构建前失败。不需要 `SERVER_PASSWORD`，也不需要单独配置 GHCR Token，工作流使用 GitHub 自动提供的 `GITHUB_TOKEN`。

从旧版工作流迁移时，需要新增 `SERVER_FINGERPRINT`；原来的 `SERVER_KNOWN_HOSTS` 不再使用。

## 部署后的服务器目录

假设 `DEPLOY_PATH=/opt/my-app`，部署完成后的最小目录结构如下：

```text
/opt/my-app/
├── .env                 # 服务器预先准备，工作流不会覆盖
├── docker-compose.yml   # 工作流从仓库根目录上传
└── scripts/
    └── deploy-ghcr.sh   # 工作流保留 scripts/ 相对路径
```

Compose 使用的持久化目录和其他本地文件也应放在该目录下。例如：

```text
/opt/my-app/
├── .env
├── docker-compose.yml
├── scripts/
│   └── deploy-ghcr.sh
├── data/                # 示例：应用持久化数据
└── config/              # 示例：额外配置文件
```

`data/`、`config/` 等目录名称由项目自己的 Compose 配置决定。需要从仓库同步的目录必须加入工作流 `Upload deployment files` 步骤的 `source` 列表；只存在于生产服务器上的持久化目录不应加入上传列表。

## 发布

将代码合并到生产分支后推送版本 tag：

```shell
git tag v1.0.0
git push origin v1.0.0
```

工作流会构建并发布 `ghcr.io/<owner>/<repository>:v1.0.0` 和 `latest`，然后按镜像 digest 部署。项目测试仍由项目自己的 CI 工作流负责。
