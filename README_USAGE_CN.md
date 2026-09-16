# OFA 代码与 NN 资源分离方案——使用教程

> 适用仓库：
>
> - 代码仓库（repA）：<https://github.com/abLiuMing/code_rep>
> - 资源配置仓库（repB）：<https://github.com/abLiuMing/res_rep>

## 1. 开始之前

本方案包含四个部分：

| 部分 | 用途 |
| --- | --- |
| repA | 保存 OFA/算法代码，选择并锁定资源版本 |
| repB | 保存 JSON、效果参数、manifest 和资源构建脚本 |
| 制品库 | 保存 NN、权重和大型二进制资源 |
| 本地缓存 | 保存当前机器已经下载过的 NN，避免重复下载 |

repB 通过 Git submodule 放在 repA 的 `deps/resource_config` 目录中。大型 NN 不放进 repA 或 repB Git，而是由 manifest 指向制品库，使用时按需下载。

## 2. 环境要求

基础 PoC 需要：

- Git；
- POSIX Shell（macOS/Linux 自带）；
- `curl`（使用 HTTP/HTTPS 制品库时）；
- `shasum`（用于 SHA-256 校验）。

正式接入后，还需要具备：

- repA 的 Git 访问权限；
- repB 的 Git 读取权限；
- 制品库下载权限；
- 修改资源时需要 repB 写权限和制品上传权限。

## 3. 第一次克隆

推荐同时克隆 repA 和 submodule：

```bash
git clone --recurse-submodules git@github.com:abLiuMing/code_rep.git
cd code_rep
```

检查 submodule：

```bash
git submodule status
```

正常情况下会看到：

```text
<commit> deps/resource_config
```

如果已经执行过普通 clone，可以补充初始化：

```bash
git submodule update --init --recursive
```

也可以使用项目封装命令：

```bash
./tools/ofa sync
```

## 4. 配置制品库地址

脚本通过 `RESOURCE_BASE_URL` 获取大型 NN 文件。

正式环境示例：

```bash
export RESOURCE_BASE_URL=https://artifact.example.com/ofa-nn
```

后续可以直接执行：

```bash
./tools/ofa prepare
./tools/ofa build
./tools/ofa run
```

也可以只为一条命令设置：

```bash
RESOURCE_BASE_URL=https://artifact.example.com/ofa-nn ./tools/ofa run
```

凭证不要写进 Git。用户名、Token 等应由开发环境、系统凭证服务或 CI Secret 提供。

### 4.1 当前 PoC 使用 GitHub 在线模拟制品库

当前 PoC 将两个小型演示 NN 放在 `res_rep` 的独立 `demo-artifacts` 分支，脚本默认通过 GitHub Raw 下载，因此全新 clone 后不设置环境变量也可以运行：

```bash
./tools/ofa run
```

该分支只包含 1MiB/2MiB 测试文件，用于验证线上按需下载流程；正式15GB资源不能采用这种方式，应接入专业制品库。

也可以覆盖默认地址，继续使用本地模拟制品库。PoC 的本地 NN 位于实验电脑：

```text
/Users/lm/Desktop/rep_by_rep/artifact-store
```

在实验电脑上运行：

```bash
cd /Users/lm/Desktop/rep_by_rep/repA-code

RESOURCE_BASE_URL=/Users/lm/Desktop/rep_by_rep/artifact-store \
./tools/ofa run
```

还可以临时启动 HTTP 文件服务：

```bash
cd /Users/lm/Desktop/rep_by_rep/artifact-store
python3 -m http.server 9000
```

另一个终端执行：

```bash
cd code_rep
RESOURCE_BASE_URL=http://127.0.0.1:9000 ./tools/ofa run
```

局域网其他电脑可以把 `127.0.0.1` 替换为提供资源机器的 IP。GitHub Raw 和该临时 HTTP 服务都只用于 PoC，不作为正式制品库。

## 5. 日常开发命令

### 5.1 查看状态

```bash
./tools/ofa status
```

也可以分别查看两个仓库：

```bash
git status
git -C deps/resource_config status
git submodule status
```

### 5.2 更新代码与资源配置

```bash
git pull --ff-only
./tools/ofa sync
```

`sync` 会把 repB 恢复到当前 repA commit 锁定的版本，不会自动追踪 repB 远端最新版本。

### 5.3 切换分支

推荐执行：

```bash
./tools/ofa switch main
```

或者：

```bash
./tools/ofa switch project-q3-8870
```

该命令会：

1. 切换 repA 分支；
2. 将 repB 恢复到该分支锁定的 commit。

如果直接执行 `git switch`，需要手动补充：

```bash
git switch <branch>
git submodule update --init --recursive
```

### 5.4 准备资源

```bash
./tools/ofa prepare
```

该命令会：

1. 初始化并同步 repB；
2. 读取 repA 的 `resource.lock`；
3. 找到 repB 中对应的 manifest；
4. 检查 `.resource-cache`；
5. 缓存未命中时下载 NN；
6. 校验文件 SHA-256；
7. 缓存命中时跳过下载。

### 5.5 构建资源

```bash
./tools/ofa build
```

生成内容位于：

```text
build/generated_resources/
```

该目录是生成物，不提交 Git。接入真实 OFA 工程后，`build` 命令还应调用项目实际的 CMake、Gradle、Make 或其他构建过程。

### 5.6 运行

```bash
./tools/ofa run
```

该命令先准备和生成资源，再启动当前 PoC 程序。正式接入后，应替换为 OFA 的实际运行命令。

## 6. 当前分支与资源对应关系

PoC 包含两套配置：

| repA 分支 | repB commit/配置 | 项目/平台 | NN |
| --- | --- | --- | --- |
| `main` | `Q2-8850.tsv` | Q2/8850 | srainr 2.33 |
| `project-q3-8870` | `Q3-8870.tsv` | Q3/8870 | srainr 3.00 |

例如：

```bash
./tools/ofa switch main
./tools/ofa run
```

会使用 Q2/8850 和 srainr 2.33。

```bash
./tools/ofa switch project-q3-8870
./tools/ofa run
```

会使用 Q3/8870 和 srainr 3.00。

第二次使用相同 NN 时会显示：

```text
cache hit: srainr <version>
```

## 7. repA 如何选择资源

repA 使用 `resource.lock` 指定 manifest。当前 PoC 示例：

```text
manifest=Q2-8850.tsv
```

它对应 repB 中：

```text
deps/resource_config/manifests/Q2-8850.tsv
```

当前 manifest 格式：

```text
# name version artifact sha256
srainr 2.33 srainr/Q2/8850/2.33/model.bin <sha256>
```

字段含义：

| 字段 | 含义 |
| --- | --- |
| `name` | 算法/资源名称 |
| `version` | NN 或资源版本 |
| `artifact` | 相对于制品库根地址的文件路径 |
| `sha256` | 文件完整性校验值 |

PoC 使用 TSV 是为了避免增加 YAML 解析依赖。正式项目可根据字段复杂度升级为 YAML 或 JSON。

## 8. 修改 JSON 或效果参数

repB 在 clone 后通常处于 detached HEAD，因此不要直接修改并提交。先创建 repB 开发分支：

```bash
cd code_rep/deps/resource_config
git fetch origin
git switch -c feature/tune-srainr origin/main
```

修改配置，例如：

```text
configs/effect.json
```

本地验证：

```bash
cd ../..
./tools/ofa build
./tools/ofa run
```

提交到 repB：

```bash
cd deps/resource_config
git add configs/effect.json
git commit -m "Tune srainr effect parameters"
git push -u origin feature/tune-srainr
```

然后在 GitHub 的 `res_rep` 中创建 Pull Request。repB 合入后，再更新 repA 的 submodule 指针，参见第 10 节。

## 9. 上传或更新 NN

不要把大型 NN 直接提交到 repA 或 repB：

```bash
# 不推荐
git add model.bin
```

正确流程：

1. 生成并验证新 NN；
2. 使用制品库上传命令发布新版本；
3. 获取文件大小和 SHA-256；
4. 更新 repB manifest；
5. 在 repB 创建 Pull Request；
6. repB 合入后更新 repA 锁定指针。

计算文件大小和 SHA-256：

```bash
wc -c model.bin
shasum -a 256 model.bin
```

版本路径示例：

```text
旧版本：srainr/Q2/8850/2.33/model.bin
新版本：srainr/Q2/8850/2.34/model.bin
```

已经发布的 `2.33` 不允许覆盖。NN 发生变化后必须发布 `2.34` 或其他新版本。

修改 repB manifest：

```text
# name version artifact sha256
srainr 2.34 srainr/Q2/8850/2.34/model.bin <new-sha256>
```

在 repB 分支中测试：

```bash
cd code_rep
./tools/ofa prepare
./tools/ofa build
./tools/ofa run
```

## 10. repA 更新到新的 repB 版本

repB Pull Request 合入后，在 repA 的目标分支执行：

```bash
cd code_rep
git switch <repA目标分支>

git -C deps/resource_config fetch origin
git -C deps/resource_config checkout origin/main
```

确认资源：

```bash
./tools/ofa status
./tools/ofa build
./tools/ofa run
```

然后将新的 repB commit 指针提交到 repA：

```bash
git add deps/resource_config
git commit -m "Update resource configuration"
git push
```

如果同时切换 manifest：

```bash
git add resource.lock deps/resource_config
git commit -m "Use Q4 8890 resources"
git push
```

必须先合入 repB，再更新和提交 repA；否则其他开发者 clone repA 时可能找不到 repB 对应 commit。

## 11. 增加新项目或平台

假设新增：

```text
项目：Q4
平台：8890
算法：srainr
NN：4.00
```

操作步骤：

1. 上传 NN：

   ```text
   srainr/Q4/8890/4.00/model.bin
   ```

2. 在 repB 创建开发分支：

   ```bash
   cd code_rep/deps/resource_config
   git fetch origin
   git switch -c feature/q4-8890 origin/main
   ```

3. 添加 JSON/效果参数：

   ```text
   configs/srainr/Q4/8890/effect.json
   ```

4. 添加 manifest：

   ```text
   manifests/Q4-8890.tsv
   ```

5. 测试、提交并合入 repB；
6. 在 repA 创建 `project-q4-8890` 分支；
7. 将 `resource.lock` 修改为：

   ```text
   manifest=Q4-8890.tsv
   ```

8. 更新 repB submodule 指针；
9. Build/Run 验证；
10. 提交 repA。

## 12. CI/CD 使用方式

CI checkout 时需要包含 submodule：

```bash
git submodule update --init --recursive
```

配置制品地址和凭证后执行：

```bash
./tools/ofa prepare
./tools/ofa build
```

推荐缓存：

```text
.resource-cache/
```

缓存键建议包含：

```text
操作系统
+ 平台
+ repB commit
+ manifest hash
+ 资源构建工具版本
```

构建凭证应放在 CI Secret，不得写入 `resource.lock`、manifest、脚本或 Git 历史。

## 13. 文件应该放在哪里

| 文件 | 存放位置 |
| --- | --- |
| OFA/CV/算法代码 | repA |
| `resource.lock` | repA |
| `tools/ofa` | repA |
| JSON、效果参数 | repB |
| manifest、Schema | repB |
| 资源校验和生成脚本 | repB |
| NN、权重、大型二进制 | 制品库 |
| `.resource-cache` | 本地缓存，不提交 |
| `build/generated_resources` | 本地生成，不提交 |
| Token、密码和上传凭证 | 环境变量或 Secret，不提交 |

## 14. 常见问题

### 14.1 `deps/resource_config` 是空目录

执行：

```bash
git submodule update --init --recursive
```

### 14.2 repB 显示 detached HEAD

正常使用时这是预期状态，表示 repA 锁定了 repB 的准确 commit。

需要修改 repB 时创建开发分支：

```bash
git -C deps/resource_config fetch origin
git -C deps/resource_config switch -c feature/my-change origin/main
```

### 14.3 `missing resource`

检查：

```bash
echo "$RESOURCE_BASE_URL"
./tools/ofa prepare
```

确认 manifest 中的相对路径与制品库中的实际路径一致。

### 14.4 `checksum mismatch`

表示下载文件的 SHA-256 与 manifest 不一致。可能原因：

- 文件上传不完整；
- 制品被错误覆盖；
- manifest 填错 SHA-256；
- 本地缓存损坏；
- 下载被代理或登录页面替代。

不能跳过校验继续构建。应检查制品和 manifest，修复后重新准备资源。

### 14.5 切分支后 repB 状态显示改变

使用：

```bash
./tools/ofa switch <branch>
```

或者手动同步：

```bash
git submodule update --init --recursive
```

### 14.6 是否可以删除本地缓存

可以。`.resource-cache` 是可恢复缓存，删除后会重新从制品库下载。

### 14.7 为什么 Build 不自动获取 repB 最新 main

因为 Build 必须使用 repA 锁定的资源版本。同一个 repA commit 应始终产生相同结果。升级 repB 必须通过明确提交和评审完成。

## 15. 日常命令速查

```bash
# 首次克隆
git clone --recurse-submodules git@github.com:abLiuMing/code_rep.git
cd code_rep

# 同步当前锁定资源配置
./tools/ofa sync

# 切换项目分支
./tools/ofa switch main
./tools/ofa switch project-q3-8870

# 准备、构建、运行
./tools/ofa prepare
./tools/ofa build
./tools/ofa run

# 查看状态
./tools/ofa status
git status
git -C deps/resource_config status
```

## 16. 当前 PoC 与正式接入的差异

当前已经完成：

- repA/repB 两个 GitHub 仓库；
- repB submodule 精确锁定；
- Q2/8850 和 Q3/8870 分支切换；
- NN 按需准备和 SHA-256 校验；
- 本地缓存；
- Build/Run；
- 防止不同平台生成物残留。
- 从 GitHub `demo-artifacts` 分支在线按需下载小型演示 NN。

正式使用前还需要：

1. 确定公司正式制品库；
2. 将 NN 上传到制品库；
3. 接入制品库鉴权及上传命令；
4. 将 TSV manifest 升级为最终约定格式；
5. 增加 JSON Schema 和参数依赖校验；
6. 接入 OFA 真实构建系统；
7. 配置 CI 缓存和 Secret；
8. 制定旧资源和历史 tag 的迁移方案。

## 17. 使用原则

1. repA 决定使用哪套资源；
2. repB 描述资源由哪些 JSON、效果参数和 NN 组成；
3. 制品库保存大型 NN 文件；
4. 本地缓存只做加速，不作为版本依据；
5. repA 通过 submodule commit 精确锁定 repB；
6. repB 通过 manifest 版本、大小和 SHA-256 精确锁定 NN；
7. Build 只使用锁定版本，不自动追踪远端最新版本；
8. 已发布 NN 不覆盖，发生变化时发布新版本。
