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

如需在应用中显示版本，Dockerfile 可加入：

```dockerfile
ARG APP_VERSION=development
ENV APP_VERSION=$APP_VERSION
```

如果 Dockerfile、Compose 文件名或构建目录不是默认值，直接修改 `deploy.yml` 中对应路径。默认同时构建 `amd64` 和 `arm64` 镜像。

Compose 引用了其他本地文件时，把对应文件或顶级目录加入 `Upload deployment files` 的 `scp` 列表。

## 首次配置

服务器需要 Docker、Docker Compose v2、Bash，并在部署目录中准备生产 `.env` 和持久化数据目录。

在 GitHub 仓库的 `production` Environment 或 Actions Secrets 中配置：

- `SERVER_HOST`
- `SERVER_USER`
- `SERVER_PASSWORD`
- `DEPLOY_PATH`，例如 `/opt/my-app`

不需要 GHCR Token。

## 发布

将代码合并到生产分支后推送版本 tag：

```shell
git tag v1.0.0
git push origin v1.0.0
```

工作流会构建并发布 `ghcr.io/<owner>/<repository>:v1.0.0` 和 `latest`，然后按镜像 digest 部署。项目测试仍由项目自己的 CI 工作流负责。
