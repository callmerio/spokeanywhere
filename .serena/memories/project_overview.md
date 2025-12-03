# SpokenAnyWhere 项目概览

## 项目信息
- **项目名称**: SpokenAnyWhere (Mac 版)
- **项目类型**: Swift 桌面应用程序
- **开发平台**: macOS 14.0+ (Intel + Apple Silicon)
- **编程语言**: Swift
- **架构模式**: SwiftUI + SwiftData

## 产品定位
一款面向创作者与知识工作者的 **快捷听写 + 文本智能处理**工具，提供：
- 实时语音转文字（按住快捷键说话）
- AI 文本后处理（去除口头语、格式化等）
- 多模型支持（本地 Apple STT、Whisper、远程 Gemini API）
- 系统级快捷键集成
- 悬浮胶囊状态反馈

## 核心功能模块

### 1. 语音转录 (Transcription)
- **本地模型**: Apple STT、Whisper
- **远程模型**: Gemini Flash/Flash Lite
- **实时听写**: 全局快捷键触发 (⌥+R)
- **文件转录**: 批量音频文件处理

### 2. AI 文本处理 (LLM Pipeline)
- **Provider**: Google Gemini (主要)
- **模型选择**: Gemini 2.5 Flash / Flash Lite
- **思考模式**: 支持深度推理增强
- **自定义提示**: 用户可配置处理规则

### 3. UI 系统
- **主界面**: 系统设置风格多栏结构
- **悬浮胶囊**: Dynamic Island 风格录音状态反馈
- **设置页面**: 8个主要设置模块
- **HUD 组件**: 实时状态显示

### 4. 数据管理
- **历史记录**: SwiftData 本地存储
- **附件系统**: 屏幕截图、文本提取
- **音频管理**: 录音、播放、存储

## 技术栈详情

### 核心框架
- **SwiftUI**: 用户界面构建
- **SwiftData**: 数据持久化
- **Foundation**: 系统服务集成
- **AppKit**: macOS 特定功能

### 依赖管理
- **Swift Package Manager**: 无外部依赖
- **系统框架**: Speech、AVFoundation、CoreGraphics

### 开发工具
- **SwiftLint**: 代码风格检查 (行长度 120/200)
- **Swift 5.9**: 最低版本要求
- **Xcode**: 主要开发环境

## 项目结构

```
spoke/
├── App/                    # 应用入口
│   ├── SpokenlyApp.swift   # SwiftUI App 主入口
│   └── AppDelegate.swift   # 应用代理
├── Core/                   # 核心业务逻辑
│   ├── LLM/               # LLM Provider 实现
│   ├── Transcription/     # 语音转录
│   ├── Attachment/        # 附件处理
│   ├── Audio/             # 音频服务
│   └── DataModels.swift   # SwiftData 模型
├── Services/              # 服务层
├── UI/                    # 用户界面
│   ├── Settings/          # 设置界面
│   ├── HUD/               # 悬浮组件
│   ├── QuickAsk/          # 快速询问
│   └── Components/        # 通用组件
└── Tests/                 # 单元测试
```

## 数据模型

### HistoryItem (历史记录)
- 原始文本 + AI 处理后文本
- 音频文件路径和时长
- 应用上下文 (Bundle ID)
- 关联的 AI Provider 配置

### AppRule (应用规则)
- 按应用定制 Prompt
- 启用/禁用状态

### AIProviderConfig (AI 提供商)
- API Key 安全存储 (Keychain)
- 默认模型配置
- 连接状态管理

## 开发工作流

### 构建命令
```bash
# 开发构建
cd spoke && swift build

# 发布构建
./scripts/build-release.sh

# 运行测试
./spoke/Tests/run-tests.sh
```

### 代码质量
- **SwiftLint**: 严格的代码风格检查
- **行长度**: 警告 120，错误 200
- **函数复杂度**: 警告 15，错误 25
- **命名规范**: camelCase，最小长度 2

### 测试策略
- 单元测试覆盖核心功能
- 手动测试脚本运行
- 重点关注：文本提取、附件处理、TTS 服务

## 产品路线图

### v1.0 (P0 功能)
- 实时听写 + 快捷键
- 本地 Apple STT + Whisper
- 基础设置和 AI 提示配置

### v1.1 (P1 功能)  
- Gemini Provider 集成
- 完整历史记录功能
- AI 提供商管理

### v1.x (P2 功能)
- 文件转录完整功能
- 更多模型支持
- 增强的用户体验

## 权限要求
- **麦克风权限**: 语音录制必需
- **辅助功能权限**: 自动文本插入
- **Keychain 访问**: API Key 安全存储

## 性能指标
- 实时听写延迟: 本地 ≤ 1秒，远程 ≤ 3秒
- 内存占用: 稳定运行状态
- 录音时长限制: 60分钟（实时）
- 崩溃恢复: 音频实时落盘