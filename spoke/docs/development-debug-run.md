# 本地稳定调试运行指南

本文档定义 SpokenAnyWhere 在本机上的**稳定调试运行**方式。

目标：

- 不再直接把 `.build/bundler/SpokenAnyWhere.app` 当作长期运行入口
- 用固定安装路径 + 开发证书签名，稳定 TCC/辅助功能/麦克风/屏幕录制权限
- 把日常调试收敛为一条命令

---

## 1. 推荐入口

日常开发统一使用：

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
./dev.sh
```

`dev.sh` 现在会转发到：

- `scripts/dev-run.sh`

---

## 2. 脚本做了什么

稳定调试脚本会自动完成以下步骤：

1. 停止旧实例
2. 使用 Swift Bundler 打包 `.app`
3. 将应用复制到固定路径
4. 用 `Apple Development` 证书重签
5. 启动日志采集
6. 启动应用

固定开发版路径：

```text
~/Applications/SpokenAnyWhere Dev.app
```

固定 bundle id：

```text
app.spokenly
```

---

## 3. 为什么不能直接运行 .build/bundler

`.build/bundler/SpokenAnyWhere.app` 是构建中间产物。

问题：

- 路径不稳定
- 重建后内容会被覆盖
- 如果只用 adhoc 签名，TCC/辅助功能权限容易漂移
- 系统可能反复请求辅助功能权限，或者在权限列表里难以稳定识别

因此：

- **中间产物只用于生成**
- **固定安装路径才用于调试运行**

---

## 4. 首次授权

第一次使用稳定调试流程时，请在系统中授权这个固定路径：

```text
~/Applications/SpokenAnyWhere Dev.app
```

路径位置：

- `系统设置 -> 隐私与安全性 -> 辅助功能`

如有需要，也应对同一路径补齐以下权限：

- 麦克风
- 屏幕与系统音频录制
- 语音识别

如果辅助功能权限状态混乱，可先重置：

```bash
tccutil reset Accessibility app.spokenly
```

然后重新运行：

```bash
./dev.sh
```

再去系统设置中给固定路径授权。

---

## 5. 调试模式

### 5.1 默认模式

默认使用 `open` 启动：

```bash
./dev.sh
```

适用场景：

- 日常手动调试
- 权限稳定验证
- UI 交互检查

### 5.2 传入环境变量

如果需要把 `SPOKE_*` 环境变量直接传给应用进程，请用 `exec` 模式：

```bash
APP_LAUNCH_MODE=exec \
SPOKE_DEBUG_AUTOMATION=1 \
SPOKE_SKIP_ACCESSIBILITY_ALERTS=1 \
SPOKE_AUDIO_WARMUP=0 \
SPOKE_STARTUP_LOG=1 \
SPOKE_PERF_LOG=1 \
./dev.sh
```

适用场景：

- Debug automation
- 启动日志分析
- 启动性能复算
- 避免权限弹窗打断自动化

---

## 6. 日志

运行 `./dev.sh` 后，会打印当前日志文件路径。

默认日志目录：

```text
../.tmp_frames/
```

查看日志：

```bash
tail -f ../.tmp_frames/dev-*.log
```

脚本内部采集的是：

- `process == "SpokenAnyWhere"`
- `subsystem BEGINSWITH "com.spokeanywhere"`
- `subsystem == "app.spokenly"`
- `error` / `fault`

---

## 7. 常用命令

### 7.1 仅演练脚本，不真实执行

```bash
DRY_RUN=1 ./dev.sh
```

### 7.2 手动重置辅助功能权限

```bash
tccutil reset Accessibility app.spokenly
```

### 7.3 手动查看签名信息

```bash
codesign -dv --verbose=2 ~/Applications/SpokenAnyWhere\ Dev.app
```

### 7.4 手动启动固定安装路径应用

```bash
open ~/Applications/SpokenAnyWhere\ Dev.app
```

### 7.5 直接运行固定安装路径中的可执行文件

```bash
~/Applications/SpokenAnyWhere\ Dev.app/Contents/MacOS/SpokenAnyWhere
```

---

## 8. 排障建议

### 症状：应用程序“已不能再打开”

优先检查：

1. 是否重新 bundle 后没有重签
2. 是否仍然从 `.build/bundler/...` 直接启动
3. 固定路径的开发版 App 是否被覆盖或删除

### 症状：每次都请求辅助功能权限

优先检查：

1. 是否从固定路径启动
2. 是否使用开发证书签名
3. 辅助功能授权是否授给了 `~/Applications/SpokenAnyWhere Dev.app`

### 症状：脚本运行成功，但应用没有起来

优先检查：

1. `../.tmp_frames/dev-*.log`
2. `pgrep -fal SpokenAnyWhere`
3. `codesign -dv --verbose=2 ~/Applications/SpokenAnyWhere\ Dev.app`

---

## 9. 相关文件

- [dev.sh](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/dev.sh)
- [dev-run.sh](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/scripts/dev-run.sh)
- [Bundler.toml](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/Bundler.toml)
- [startup-log-interpretation.md](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/docs/diagnostics/startup-log-interpretation.md)
