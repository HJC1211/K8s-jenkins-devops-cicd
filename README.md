# 基于 K8s+Jenkins 的 CICD DevOps 平台

## 项目简介

Kubernetes 与 Jenkins 构建的自动化交付平台，旨在实现 SpringBoot 应用从代码提交到 Kubernetes 集群部署的全链路自动化。项目集成了 GitLab 代码托管、Harbor 镜像仓库、SonarQube 代码审计等核心组件，通过 Jenkins Kubernetes 插件实现动态构建节点，结合声明式 Pipeline 脚本与 Webhook 触发机制，打造了一套CI/CD解决方案。

技术栈：Linux、Jenkins  Pipeline、Kubernetes 、GitLab、Maven、SonarQube、Harbor 私有镜像仓库、Docker、YAML

## 组件信息

| 组件      | 地址                                                         | 说明                                                       |
| --------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| GitLab    | [http://192.168.142.152:28080](https://link.wtturl.cn/?target=http%3A%2F%2F192.168.142.152%3A28080&scene=im&aid=497858&lang=zh) | 业务代码仓库，配置 Webhook 回调 Jenkins                    |
| Jenkins   | http://192.168.142.152:31783                                 | 执行流水线任务                                             |
| SonarQube | [http://192.168.142.152:32267](https://link.wtturl.cn/?target=http%3A%2F%2F192.168.142.152%3A32267&scene=im&aid=497858&lang=zh) | 代码质量扫描，配置质量门禁                                 |
| Harbor    | http://192.168.142.156:8858                                  | 私有镜像仓库                                               |
| K8s 集群  | 内网 K8s集群                                                 | 运行 Jenkins 、动态 Agent Pod 及业务应用 (dev、production) |

## 流水线架构

开发者提交代码至 GitLab，通过 Webhook 触发 Jenkins 流水线，由 K8s 动态创建 Maven Agent Pod 执行全流程任务：

1. 检出代码：支持页面下拉选择指定构建分支
2. 单元测试：Maven 执行测试
3. 代码质量扫描：对接 SonarQube 执行扫描，质量门禁不通过直接终止流水线
4. 构建推送：Maven 打包，构建镜像推送至 Harbor
5. 镜像更新：给当前构建镜像打 `latest` 标签并覆盖推送
6. 开发部署：人工确认后，kubectl自动部署至 dev 环境
7. 版本发布：仅当输入 TAG_NAME 以 `v` 开头时触发，人工确认发布后，创建新版标签并推送至 GitLab
8. 生产部署：人工确认后，kubectl自动部署至 production 生产环境

## CI/CD 流水线流程

```
[代码提交]
    |
    v
[Webhook 触发 Jenkins]
    |
    v
[Checkout SCM] --> [Unit Test] --> [SonarQube 分析 & 质量门禁]
                                          |
                                          v
                                   [Build & Push SNAPSHOT]
                                          |
                                          v
                                   [Push Latest Tag]
                                          |
                                          v
                                   [手动审批: Deploy to Dev?]
                                          |
                                          v
                                   [Deploy to Dev ]
                                          |
                                          v
                                   [手动审批: Release Image with Tag?]
                                          |
                                          v
                                   [Git Tag & Push with Tag]
                                          |
                                          v
                                   [手动审批: Deploy to Production?]
                                          |
                                          v
                                   [Deploy to Production ]
```

## 核心功能

1. **Kubernetes 动态 Pod 构建**：流水线启动临时 Pod 执行任务，执行完毕自动销毁，不污染 Jenkins Master 节点，资源按需调度。
2. **参数化构建**：集成 gitParameter 插件，页面下拉选择构建分支；支持输入版本 TAG 控制发布流程。
3. **SonarQube 质量门禁**：代码扫描不达标通过 `abortPipeline` 直接终止流水线，阻断缺陷代码进入发布环节。
4. **镜像版本管理**：每次构建生成 SNAPSHOT 构建号镜像；输入 v 开头版本号可生成正式版本镜像，同步归档 Git Tag 与 Harbor 镜像。
5. **多环境隔离发布**：dev 环境每次构建支持人工确认部署；生产环境必须输入 v 开头版本 TAG，人工确认后方可发布。

## 部署前置条件

### Jenkins 需安装插件

- Build Authorization Token Root
- Gitlab
- SonarQube Scanner
- Node and Label parameter
- Kubernetes
- Config File Provider
- Git Parameter

### Jenkins 凭证配置

| 凭证 ID                              | 凭证类型               | 作用                                                      |
| ------------------------------------ | ---------------------- | --------------------------------------------------------- |
| harbor-user-pass                     | Username with password | Harbor 镜像仓库登录账号密码                               |
| gitlab-token                         | GitLab API token       | GitLab API 令牌,用于 Jenkins 与 GitLab 的全局双向通信连接 |
| git-user-pass                        | Username with password | GitLab 代码仓库访问账号密码                               |
| 9615b7f8-8237-45b5-a7aa-4ef1f209711c | Kubeconfig             | 访问目标 K8s 集群执行部署                                 |
| sonarqube-token                      | Secret text            | SonarQube 服务访问认证令牌                                |

### Jenkins 系统配置

- 系统配置 SonarQube 服务，服务名称：`sonarqube`
- 配置 Kubernetes 云，Pod 模板标签设置为 `maven`
- GitLab 项目配置 Webhook，触发 Jenkins 构建任务

## 目录说明

```
k8s-jenkins-devops-cicd
├── jenkinsfile             # 流水线脚本
├── src/                    # SpringBoot 业务源码
├── deploy/                 # SpringBoot业务应用双环境部署模板
├── pom.xml                 # Maven 项目配置
├── manifests/              # 平台全组件K8s部署资源
│   ├── sonarqube/          # SonarQube服务端部署资源
│   ├── jenkins/            # Jenkins构建平台部署资源    
│   └── storage/            # 集群通用存储资源
└── Dockerfile              # SpringBoot 业务应用的运行镜像
```