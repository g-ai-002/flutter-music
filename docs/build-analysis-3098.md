# 构建耗时分析报告

> 基于 CI 日志 `build-Build Android APK-3098.log`（2026-07-12）

## 优化效果对比

| 指标 | 优化前 (#3090) | 优化后 (#3098) |
|------|---------------|---------------|
| 总耗时 | 13m 30s | **6m 0s** |
| 降幅 | -- | **-55%** |
| 国内镜像下载 | 41.4% | **100%** |
| 境外源下载 | 58.6% | **0%** |
| Resource missing | 938 次 | **399 次** (-57%) |

## 耗时分布

| 阶段 | 耗时 | 占比 | 说明 |
|------|------|------|------|
| CI 准备 | ~12s | 3% | checkout + pub get + env check |
| Gradle Wrapper 下载 | ~23s | 6% | 每次从华为云下载 Gradle 9.5.1 |
| **Configuration + 下载** | **~2m 39s** | **44%** | 依赖解析 + 下载 1,797 个文件 |
| **编译 (Kotlin/Java/Dart)** | **~1m 47s** | **30%** | 10 个插件模块 + app |
| **Lint** | **~43s** | **12%** | lintVitalAnalyzeRelease |
| Dex/打包/签名 | ~30s | 8% | dexBuilder + mergeDex + package |

## 关键阶段时间线

| 时间 | 阶段 |
|------|------|
| `14:44:18` | CI Job 收到任务 |
| `14:44:26` | Git checkout 完成 (~8s) |
| `14:44:26` | flutter pub get (107 deps, ~2s) |
| `14:44:30` | 部署 Aliyun init 脚本 |
| `14:44:31` | 下载 Gradle Wrapper zip |
| `14:44:53` | Gradle Wrapper 解压完成 (~23s) |
| `14:44:55` | Gradle Daemon 启动 (single-use, 0.362s) |
| `14:45:12` | Configure project :gradle 开始 |
| `14:46:03` | Configuration 阶段开始 (12 个子项目) |
| `14:47:32` | App tasks 开始 (preBuild, CMake) |
| `14:47:34` | compileFlutterBuildRelease (Dart->kernel, ~18s) |
| `14:47:56` | mergeReleaseNativeLibs (~19s) |
| `14:48:18` | 插件 Kotlin/Java 编译 (10 个模块, ~59s) |
| `14:49:17` | :app:compileReleaseKotlin |
| `14:49:20` | :app:processReleaseResources |
| `14:49:25` | :app:dexBuilderRelease (~21s) |
| `14:49:47` | lintVitalAnalyzeRelease (~35s) |
| `14:50:30` | BUILD SUCCESSFUL |

## 下载统计

**总下载文件数**: 1,797 个

| 域名 | 下载次数 | 占比 | 类型 |
|------|---------|------|------|
| maven.aliyun.com | 1,792 | 99.72% | 国内镜像 |
| storage.flutter-io.cn | 4 | 0.22% | Flutter 国内 |
| mirrors.huaweicloud.com | 1 | 0.06% | Gradle Wrapper (国内) |
| repo.maven.apache.org | 0 | 0% | -- |
| dl.google.com | 0 | 0% | -- |
| plugins.gradle.org | 0 | 0% | -- |

**国内镜像 vs 境外源**: 1,797 / 1,797 = **100% 国内镜像**，0% 境外直连。

## Resource Missing 统计

**总 miss 次数**: 399

| 域名 | miss 次数 | 占比 |
|------|----------|------|
| maven.aliyun.com | 395 | 98.99% |
| repo.maven.apache.org | 2 | 0.50% |
| dl.google.com | 2 | 0.50% |

miss 率: 399 / (1,797 + 399) = **18.2%**。Aliyun 镜像 miss 来自 Gradle 在多个子仓库 (public, google, gradle-plugin) 间的正常轮询。

## 缓存命中情况

| 指标 | 数量 |
|------|------|
| 总 actionable tasks | 464 |
| 实际执行 (executed) | 463 |
| UP-TO-DATE | 1 |
| FROM-CACHE | 0 |
| "Caching disabled" 日志行 | 7,051 |

**缓存命中率**: 1 / 464 = **0.22%** (几乎为零)

## Gradle Daemon 和配置缓存

| 项目 | 详情 |
|------|------|
| Gradle 版本 | 9.5.1 |
| Daemon 模式 | Single-use (单次使用) |
| 单次使用原因 | JVM 参数不匹配 (instrumentation agent) |
| Configuration Cache | 未启用 |
| Kotlin Daemon 版本 | 5 个 (2.3.20, 2.3.21, 2.1.10, 1.8.22, 2.3.0) |
| JVM 内存 | -Xmx8096m (8GB) |

## R8/ProGuard

| 检查项 | 结果 |
|--------|------|
| minifyReleaseWithR8 | 未启用 |
| shrinkReleaseResources | 未启用 |

Release 构建未启用代码/资源压缩。

## 可优化项（按预期收益排序）

### 1. CI 缓存 Gradle 依赖（预期 -2~3 分钟）

当前每次 CI 从零下载 1,797 个文件。`GRADLE_USER_HOME` 未持久化，构建缓存完全禁用（日志中 7,051 条 `Caching disabled`）。在 Gitea Actions 中缓存 `~/.gradle/caches/modules-2` 可跳过大部分下载。

### 2. 启用 Gradle Build Cache（预期 -30~60s）

`gradle.properties` 中添加 `org.gradle.caching=true`。当前 464 个 task 全量执行，0 个从缓存恢复。

### 3. 禁用 CI 中的 lintVital（预期 -35s）

`lintVitalAnalyzeRelease` 耗时 ~35s。在 `android/app/build.gradle` 中添加 `lint.checkReleaseBuilds false` 或在 CI 中传递 `-Plint=false`。

### 4. 修复 Gradle Daemon 单次使用问题（预期 -5~10s）

当前 daemon 是 single-use，原因是 instrumentation agent 参数不匹配。统一 `gradle.properties` 中的 JVM 参数可复用 daemon。

### 5. 减少 Kotlin 版本碎片化（预期 -10~20s）

日志显示加载了 5 个不同版本的 Kotlin daemon（2.3.20, 2.3.21, 2.1.10, 1.8.22, 2.3.0）。在 `android/settings.gradle` 的 `plugins` 块或 `android/build.gradle` 中强制统一 Kotlin 版本可减少重复编译器加载。
