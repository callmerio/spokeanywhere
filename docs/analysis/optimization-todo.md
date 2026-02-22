# SpokenAnyWhere 优化 TODO 清单

**生成日期**: 2026-02-22
**优先级**: P0 (关键) > P1 (重要) > P2 (优化) > P3 (增强)

---

## 🔴 P0 - 关键任务（必须完成）

### 架构改进

#### ✅ TODO-001: ServiceContainer 依赖注入迁移
**目标**: 减少单例依赖，提升可测试性
**当前**: 512 处 `.shared` 调用
**目标**: < 100 处

**步骤**:
1. [ ] 审计所有 `.shared` 使用（已统计：98 个文件）
2. [ ] 优先迁移核心服务
   - [ ] `LLMPipeline` → `services.llm`
   - [ ] `TranscriptionManager` → `services.transcription`
   - [ ] `AudioRecorderService` → `services.audioCapture`
   - [ ] `AppSettings` → `services.appSettings`
   - [ ] `HistoryManager` → `services.historyManager`
3. [ ] 更新所有 UI 视图使用 `@Environment(\.services)`
4. [ ] 更新测试使用 mock 服务
5. [ ] 验证构建通过
6. [ ] 运行完整测试套件

**预计工作量**: 3-5 天
**风险**: 高（影响面大）
**验收标准**:
- 核心服务 100% 通过 ServiceContainer 访问
- 所有测试通过
- 无性能回归

---

#### ✅ TODO-002: 并发安全审计与加固
**目标**: 消除数据竞争，通过 Swift 6 strict concurrency

**步骤**:
1. [ ] 启用 strict concurrency 检查
   ```bash
   cd spoke
   swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
   ```
2. [ ] 修复所有并发警告（按优先级）
   - [ ] `LocalDictionaryService` - 移除手动 NSLock，使用 actor
   - [ ] `AudioCallbackRouter` - 确保回调线程安全
   - [ ] `LiveCaptionManager` - 音频处理线程隔离
   - [ ] `UnifiedDictionaryService` - 缓存并发访问
3. [ ] 为关键服务添加 actor 隔离
4. [ ] 运行 Thread Sanitizer 测试
   ```bash
   swift test --sanitize=thread --parallel
   ```
5. [ ] 文档化并发边界

**预计工作量**: 5-7 天
**风险**: 高（可能引入新 bug）
**验收标准**:
- 0 个并发警告
- Thread Sanitizer 通过
- 所有测试通过

---

#### ✅ TODO-003: 错误处理统一
**目标**: 统一错误处理模式，提升用户体验

**步骤**:
1. [ ] 定义统一错误类型
   ```swift
   enum SpokenAnyWhereError: LocalizedError {
       case audio(AudioError)
       case transcription(TranscriptionError)
       case llm(LLMError)
       case dictionary(DictionaryError)
       // ...
   }
   ```
2. [ ] 迁移核心服务到 `async throws`
   - [ ] `LLMPipeline.chat()` - 已使用 Result，改为 throws
   - [ ] `TranscriptionManager` - 统一错误类型
   - [ ] `DictionaryService` - 从 Optional 改为 throws
3. [ ] 添加用户友好的错误消息
4. [ ] 实现错误恢复策略
5. [ ] 添加错误日志记录

**预计工作量**: 2-3 天
**风险**: 中
**验收标准**:
- 所有公共 API 使用统一错误处理
- 用户看到清晰的错误提示
- 错误日志完整

---

### 测试覆盖

#### ✅ TODO-004: 核心模块单元测试
**目标**: 测试覆盖率从 8.9% 提升到 40%+

**优先级模块**:
1. [ ] `LLMPipeline` (当前: 0 测试)
   - [ ] 测试 chat() 成功场景
   - [ ] 测试 chat() 错误处理
   - [ ] 测试 refine() 流程
   - [ ] 测试 provider 切换
   - [ ] 目标: 80% 覆盖率

2. [ ] `TranscriptionManager` (当前: 19 测试)
   - [ ] 测试引擎切换
   - [ ] 测试词典注入
   - [ ] 测试错误恢复
   - [ ] 目标: 70% 覆盖率

3. [ ] `UnifiedDictionaryService` (当前: 0 测试)
   - [ ] 测试本地查询
   - [ ] 测试在线查询
   - [ ] 测试缓存机制
   - [ ] 测试降级策略
   - [ ] 目标: 80% 覆盖率

4. [ ] `AudioRecorderService` (当前: 1 测试)
   - [ ] 测试录音启动/停止
   - [ ] 测试权限处理
   - [ ] 测试设备切换
   - [ ] 测试错误恢复
   - [ ] 目标: 60% 覆盖率

5. [ ] `HotKeyService` (当前: 0 测试)
   - [ ] 测试快捷键注册
   - [ ] 测试快捷键冲突
   - [ ] 测试快捷键触发
   - [ ] 目标: 70% 覆盖率

**预计工作量**: 5-7 天
**风险**: 低
**验收标准**:
- 核心模块测试覆盖率 > 60%
- 所有测试通过
- CI 集成测试覆盖率检查

---

## 🟡 P1 - 重要任务（应该完成）

### 性能优化

#### ✅ TODO-005: 音频处理管道优化
**目标**: 降低音频延迟，提升实时转录体验

**步骤**:
1. [ ] 性能基准测试
   - [ ] 测量当前延迟（录音开始 → 转录显示）
   - [ ] 测量 CPU 使用率
   - [ ] 测量内存占用
2. [ ] 优化音频缓冲
   - [ ] 调整缓冲区大小（实验最优值）
   - [ ] 使用 Accelerate 框架优化 PCM 转换
3. [ ] 异步音频写入
   - [ ] 音频文件写入不阻塞主线程
   - [ ] 使用后台队列处理
4. [ ] 验证优化效果
   - [ ] 延迟降低 > 20%
   - [ ] CPU 使用率降低 > 15%

**预计工作量**: 3-4 天
**风险**: 中
**验收标准**:
- 音频延迟 < 500ms
- CPU 使用率 < 30%
- 无音频丢失

---

#### ✅ TODO-006: 智能缓存层实现
**目标**: 减少重复计算，提升响应速度

**步骤**:
1. [ ] 设计缓存策略
   ```swift
   protocol CacheStrategy {
       func cache<T>(_ key: String, value: T, ttl: TimeInterval)
       func retrieve<T>(_ key: String) -> T?
       func invalidate(_ key: String)
   }
   ```
2. [ ] 实现 LRU 缓存
3. [ ] 添加缓存到关键服务
   - [ ] LLM 响应缓存（相同 prompt）
   - [ ] OCR 结果缓存（相同窗口内容）
   - [ ] 转录模型缓存（避免重复加载）
4. [ ] 添加缓存监控
5. [ ] 性能测试

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- 缓存命中率 > 30%
- 响应时间降低 > 40%
- 内存占用增加 < 50MB

---

#### ✅ TODO-007: 内存管理优化
**目标**: 降低内存占用，防止内存泄漏

**步骤**:
1. [ ] 内存分析
   - [ ] 使用 Instruments 分析内存占用
   - [ ] 识别内存泄漏
   - [ ] 识别大对象
2. [ ] 优化单例生命周期
   - [ ] 实现懒加载单例
   - [ ] 添加资源释放机制
3. [ ] 历史记录管理
   - [ ] 实现自动归档（> 30 天）
   - [ ] 限制内存中记录数量（< 100 条）
4. [ ] 临时文件清理
   - [ ] 录音完成后自动清理
   - [ ] 应用退出时清理临时目录
5. [ ] 验证优化效果

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- 空闲内存 < 200MB
- 工作内存 < 500MB
- 0 个内存泄漏

---

### 代码质量

#### ✅ TODO-008: 高复杂度代码重构
**目标**: 降低代码复杂度，提升可维护性

**重点文件**:
1. [ ] `QuickAskService.swift` (400+ 行)
   - [ ] 提取 `PromptBuilder` 服务
   - [ ] 提取 `ContextCollector` 服务
   - [ ] 简化状态管理
   - [ ] 目标: < 300 行

2. [ ] `RecordingController.swift` (复杂状态机)
   - [ ] 使用状态模式重构
   - [ ] 提取 `RecordingStateMachine`
   - [ ] 简化回调处理
   - [ ] 目标: 圈复杂度 < 15

3. [ ] `LiveCaptionManager.swift` (多线程协调)
   - [ ] 使用协调器模式
   - [ ] 提取 `AudioCoordinator`
   - [ ] 简化线程同步
   - [ ] 目标: 圈复杂度 < 12

**预计工作量**: 4-5 天
**风险**: 中
**验收标准**:
- 所有文件 < 400 行
- 圈复杂度 < 15
- 测试覆盖率不降低

---

#### ✅ TODO-009: API 文档完善
**目标**: 为所有公共 API 添加文档注释

**步骤**:
1. [ ] 审计缺少文档的 API
2. [ ] 添加文档注释（按模块）
   - [ ] Core/Audio
   - [ ] Core/Transcription
   - [ ] Core/LLM
   - [ ] Core/Dictionary
   - [ ] Services
3. [ ] 生成 API 文档
   ```bash
   swift doc generate --module SpokenAnyWhere --output docs/api
   ```
4. [ ] 添加使用示例

**预计工作量**: 3-4 天
**风险**: 低
**验收标准**:
- 所有 public API 有文档注释
- 文档包含参数说明和返回值
- 文档包含使用示例

---

#### ✅ TODO-010: 技术债务清理
**目标**: 清理已弃用代码和 TODO 标记

**步骤**:
1. [ ] 删除 `.deprecated/` 目录
2. [ ] 清理注释掉的代码
3. [ ] 处理 TODO/FIXME 标记（10 个）
   - [ ] 为每个创建 GitHub Issue
   - [ ] 设置优先级
   - [ ] 分配责任人
4. [ ] 更新依赖
   - [ ] 检查 Swift Package 更新
   - [ ] 测试兼容性
   - [ ] 更新 Package.swift

**预计工作量**: 1-2 天
**风险**: 低
**验收标准**:
- 0 个已弃用文件
- 0 个注释代码块
- 所有 TODO 有对应 Issue

---

## 🟢 P2 - 优化任务（建议完成）

### UI/UX 优化

#### ✅ TODO-011: DesignTokens 全面审计
**目标**: 确保所有 UI 使用 DesignTokens

**步骤**:
1. [ ] 审计所有 UI 文件
   ```bash
   grep -r "Color\." spoke/UI --include="*.swift" | grep -v "DesignTokens"
   grep -r "\.padding(" spoke/UI --include="*.swift" | grep -v "DesignTokens"
   ```
2. [ ] 修复硬编码值
3. [ ] 验证暗色模式
4. [ ] 添加 SwiftLint 规则防止硬编码

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- 0 个硬编码颜色/间距
- 暗色模式完整支持
- SwiftLint 检查通过

---

#### ✅ TODO-012: 可访问性支持
**目标**: 支持 VoiceOver 和辅助功能

**步骤**:
1. [ ] 为所有交互元素添加 accessibility labels
2. [ ] 测试 VoiceOver 完整流程
3. [ ] 支持键盘导航
4. [ ] 支持高对比度模式
5. [ ] 添加可访问性测试

**预计工作量**: 3-4 天
**风险**: 低
**验收标准**:
- VoiceOver 可完整使用
- 键盘可完成所有操作
- 通过 Accessibility Inspector 检查

---

#### ✅ TODO-013: 性能监控集成
**目标**: 集成 MetricKit 监控生产环境性能

**步骤**:
1. [ ] 集成 MetricKit
   ```swift
   import MetricKit

   class PerformanceMonitor: MXMetricManagerSubscriber {
       func didReceive(_ payloads: [MXMetricPayload]) {
           // 分析指标
       }
   }
   ```
2. [ ] 定义关键指标
   - CPU 使用率
   - 内存占用
   - 磁盘 I/O
   - 网络延迟
3. [ ] 实现指标上报
4. [ ] 添加性能仪表板

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- MetricKit 正常工作
- 关键指标可监控
- 性能异常可告警

---

### 测试增强

#### ✅ TODO-014: 集成测试套件
**目标**: 添加端到端集成测试

**测试场景**:
1. [ ] 语音录制完整流程
   - 启动录音 → 转录 → LLM 处理 → 剪贴板
2. [ ] Quick Ask 完整流程
   - 打开面板 → 输入问题 → 获取回答
3. [ ] 实时字幕流程
   - 启动字幕 → 捕获音频 → 显示文本
4. [ ] 词典查询流程
   - 选择单词 → 查询 → 显示结果
5. [ ] 截图 OCR 流程
   - 截图 → OCR → 文本提取

**预计工作量**: 4-5 天
**风险**: 中
**验收标准**:
- 5 个核心流程有集成测试
- 测试可在 CI 运行
- 测试稳定（无 flaky）

---

#### ✅ TODO-015: 性能基准测试
**目标**: 建立性能基准，防止性能回归

**步骤**:
1. [ ] 定义性能指标
   - 音频延迟 < 500ms
   - LLM 首字节 < 2s
   - UI 响应 < 100ms
   - 启动时间 < 2s
2. [ ] 实现性能测试
   ```swift
   func testAudioLatency() {
       measure {
           // 测试音频延迟
       }
   }
   ```
3. [ ] 集成到 CI
4. [ ] 设置性能阈值

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- 所有关键指标有基准
- CI 检查性能回归
- 性能报告可视化

---

## 🔵 P3 - 增强任务（可选）

### 功能增强

#### ✅ TODO-016: 多模型支持
**目标**: 支持多个 LLM 提供商

**步骤**:
1. [ ] 抽象 LLM Provider 接口
2. [ ] 实现 GPT-4 Provider
3. [ ] 实现 Gemini Provider
4. [ ] 实现 Claude Provider
5. [ ] 添加模型切换 UI
6. [ ] 添加模型性能对比

**预计工作量**: 5-7 天
**风险**: 中
**验收标准**:
- 支持 3+ LLM 提供商
- 可动态切换
- 性能无明显差异

---

#### ✅ TODO-017: 本地 LLM 集成
**目标**: 支持本地 LLM（隐私保护）

**步骤**:
1. [ ] 集成 llama.cpp
2. [ ] 下载 Llama 3 模型
3. [ ] 实现本地推理
4. [ ] 优化推理性能
5. [ ] 添加模型管理 UI

**预计工作量**: 7-10 天
**风险**: 高
**验收标准**:
- 本地 LLM 可用
- 推理速度可接受
- 内存占用 < 2GB

---

#### ✅ TODO-018: 自定义工作流
**目标**: 允许用户自定义处理流程

**步骤**:
1. [ ] 设计工作流 DSL
2. [ ] 实现工作流引擎
3. [ ] 添加工作流编辑器
4. [ ] 提供预设工作流
5. [ ] 添加工作流分享

**预计工作量**: 10-15 天
**风险**: 高
**验收标准**:
- 用户可创建工作流
- 工作流可保存/分享
- 提供 10+ 预设工作流

---

### 生态集成

#### ✅ TODO-019: Raycast 插件
**目标**: 开发 Raycast 插件

**步骤**:
1. [ ] 学习 Raycast API
2. [ ] 实现基础命令
   - 语音转文本
   - Quick Ask
   - 词典查询
3. [ ] 发布到 Raycast Store

**预计工作量**: 3-5 天
**风险**: 低
**验收标准**:
- 插件可用
- 发布到 Store
- 用户评分 > 4.0

---

#### ✅ TODO-020: Alfred Workflow
**目标**: 开发 Alfred Workflow

**步骤**:
1. [ ] 学习 Alfred API
2. [ ] 实现基础功能
3. [ ] 发布到 Alfred Gallery

**预计工作量**: 2-3 天
**风险**: 低
**验收标准**:
- Workflow 可用
- 发布到 Gallery
- 下载量 > 100

---

## 📊 进度跟踪

### 完成统计
- P0 任务: 0/4 (0%)
- P1 任务: 0/6 (0%)
- P2 任务: 0/5 (0%)
- P3 任务: 0/5 (0%)
- **总计**: 0/20 (0%)

### 时间估算
- P0 任务: 13-19 天
- P1 任务: 18-24 天
- P2 任务: 13-18 天
- P3 任务: 27-40 天
- **总计**: 71-101 天（约 3-4 个月）

### 建议执行顺序
1. **Week 1-2**: TODO-001, TODO-004 (依赖注入 + 测试)
2. **Week 3-4**: TODO-002, TODO-003 (并发 + 错误处理)
3. **Week 5-6**: TODO-005, TODO-006, TODO-007 (性能优化)
4. **Week 7-8**: TODO-008, TODO-009, TODO-010 (代码质量)
5. **Week 9+**: P2/P3 任务（根据优先级）

---

## 🎯 成功指标

### 技术指标
- [ ] 测试覆盖率: 8.9% → 40%+
- [ ] 单例依赖: 512 → < 100
- [ ] 并发安全: 100% 通过 strict concurrency
- [ ] 构建时间: 保持 < 30s
- [ ] 代码复杂度: 所有文件 < 400 行

### 质量指标
- [ ] Crash 率: < 0.1%
- [ ] 性能回归: 0 个
- [ ] 安全漏洞: 0 个
- [ ] 用户反馈: 4.5+ 星

### 性能指标
- [ ] 音频延迟: < 500ms
- [ ] LLM 首字节: < 2s
- [ ] UI 响应: < 100ms
- [ ] 内存占用: 空闲 < 200MB, 工作 < 500MB
- [ ] 启动时间: < 2s

---

## 📝 注意事项

### 风险管理
1. **并发重构**: 充分测试，使用 Thread Sanitizer
2. **依赖注入迁移**: 分阶段进行，保持向后兼容
3. **性能优化**: 建立基准，防止过度优化

### 质量保证
1. 每个 TODO 完成后运行完整测试套件
2. 使用 feature flags 控制新功能发布
3. 充分的 code review
4. Beta 测试验证

### 文档更新
1. 更新 CHANGELOG.md
2. 更新 README.md
3. 更新 API 文档
4. 记录架构决策（ADR）

---

**生成工具**: Claude Code (Opus 4.6)
**相关文档**: `optimization-report-2026-02-22.md`
**下一步**: 选择优先级最高的任务开始执行
