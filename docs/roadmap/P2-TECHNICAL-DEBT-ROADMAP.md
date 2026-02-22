# P2 Technical Debt Roadmap

> 基于 4 专家评审结果的技术债务清理计划
> 创建日期: 2026-02-09
> 状态: 已规划

---

## 📊 概览

| 优先级 | 任务 | 预估工时 | 影响范围 | 风险等级 |
|--------|------|----------|----------|----------|
| P2-1 | 依赖注入重构 | 5-7 天 | 全局 | 中 |
| P2-2 | HotKeyService 拆分 | 2-3 天 | 热键系统 | 低 |
| P2-3 | 测试覆盖率提升 | 持续 | 全局 | 低 |
| P2-4 | async/await 迁移 | 3-4 天 | 异步代码 | 中 |
| P2-5 | Dictionary 服务合并 | 2-3 天 | 词典功能 | 低 |
| P2-6 | 文档完善 | 2 天 | 文档 | 低 |

**总预估工时**: 14-21 天（分阶段执行）

---

## 🎯 Phase 1: 基础设施优化 (Week 1-2)

### P2-1: 依赖注入重构

**现状问题**:
- 590+ 处 `.shared` 单例调用分布在 73 个文件
- 测试时难以 mock 依赖
- 服务间耦合度高

**目标**:
- 引入轻量级 DI 容器或 SwiftUI Environment 注入
- 核心服务可测试、可替换

**实施步骤**:

```swift
// Step 1: 定义服务协议 (Day 1-2)
protocol AudioCaptureServiceProtocol {
    func startCapture() async throws
    func stopCapture()
    var isCapturing: Bool { get }
}

// Step 2: 创建 DI 容器 (Day 2-3)
@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    lazy var audioCapture: AudioCaptureServiceProtocol = AudioCaptureService()
    lazy var transcription: TranscriptionServiceProtocol = TranscriptionService()
    // ... 其他服务

    // 测试时可替换
    func register<T>(_ service: T, for type: T.Type) { ... }
}

// Step 3: SwiftUI Environment 集成 (Day 3-4)
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// Step 4: 逐步迁移 (Day 4-7)
// 优先迁移: AudioCaptureService, TranscriptionService, LLMService
// 后续迁移: 其余 70+ 个服务
```

**迁移顺序** (按依赖层级):
1. 基础服务: `AppSettings`, `HistoryService`
2. 核心服务: `AudioCaptureService`, `TranscriptionService`
3. AI 服务: `LLMService`, `GeminiLiveService`
4. UI 服务: `HotKeyService`, `QuickAskService`
5. 辅助服务: 剩余服务

**验收标准**:
- [ ] ServiceContainer 实现完成
- [ ] 7 个核心服务迁移完成
- [ ] 单元测试可 mock 核心服务
- [ ] 无运行时回归

---

### P2-2: HotKeyService 拆分

**现状问题**:
- 单文件 800+ 行，职责过重
- 混合了注册、监听、执行逻辑
- 难以扩展新热键

**目标架构**:

```
HotKeyService/
├── HotKeyRegistry.swift      # 热键注册表
├── HotKeyListener.swift      # 全局监听器
├── Handlers/
│   ├── QuickAskHandler.swift
│   ├── CaptionHandler.swift
│   ├── ScreenshotHandler.swift
│   └── VoiceHandler.swift
└── HotKeyBinding.swift       # 统一绑定模式
```

**实施步骤**:

```swift
// Step 1: 定义 Handler 协议 (Day 1)
protocol HotKeyHandler {
    var identifier: String { get }
    var defaultBinding: HotKeyBinding { get }
    func execute() async
}

// Step 2: 拆分各 Handler (Day 1-2)
struct QuickAskHandler: HotKeyHandler {
    let identifier = "quickAsk"
    let defaultBinding = HotKeyBinding(key: .space, modifiers: [.option])

    func execute() async {
        await QuickAskService.shared.toggle()
    }
}

// Step 3: 统一注册 (Day 2-3)
final class HotKeyRegistry {
    private var handlers: [String: HotKeyHandler] = [:]

    func register(_ handler: HotKeyHandler) {
        handlers[handler.identifier] = handler
    }

    func handler(for identifier: String) -> HotKeyHandler? {
        handlers[identifier]
    }
}
```

**验收标准**:
- [ ] HotKeyService 拆分为 4+ 个文件
- [ ] 每个 Handler 独立可测试
- [ ] 现有热键功能无回归
- [ ] 新增热键只需创建 Handler

---

## 🎯 Phase 2: 代码质量提升 (Week 3-4)

### P2-3: 测试覆盖率提升

**现状**: 0% 覆盖率（Package.swift 刚添加 testTarget）

**目标**: 50%+ 核心服务覆盖率

**优先测试列表**:

| 服务 | 测试类型 | 优先级 |
|------|----------|--------|
| AppSettings | Unit | P0 |
| HistoryService | Unit + Integration | P0 |
| VocabularyService | Unit | P0 |
| TagLibrary | Unit | P1 |
| DictionaryAPIService | Unit + Mock | P1 |
| TranscriptionService | Integration | P2 |
| QuickAskService | Integration | P2 |

**测试框架选择**:
```swift
// 使用 Swift Testing (Swift 5.10+)
import Testing

@Suite("VocabularyService Tests")
struct VocabularyServiceTests {
    @Test("添加生词")
    func addWord() async {
        let service = VocabularyService()
        service.add("serendipity")
        #expect(service.contains("serendipity"))
    }

    @Test("高亮范围计算")
    func highlightRanges() {
        let service = VocabularyService()
        service.add("test")
        let ranges = service.highlightRanges(in: "This is a test.")
        #expect(ranges.count == 1)
    }
}
```

**持续集成**:
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: cd spoke && swift test
```

---

### P2-4: async/await 迁移

**现状问题**:
- 混合使用 callback 和 async/await
- 部分代码使用 DispatchQueue 手动调度
- Task { } 包装过多

**迁移目标**:

```swift
// Before: Callback 风格
func fetchTranscription(completion: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.global().async {
        // ...
        DispatchQueue.main.async {
            completion(.success(text))
        }
    }
}

// After: async/await
func fetchTranscription() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        // 桥接旧 API
    }
}

// 或使用 AsyncStream
var transcriptionStream: AsyncStream<TranscriptionResult> {
    AsyncStream { continuation in
        // 流式输出
    }
}
```

**迁移顺序**:
1. `TranscriptionService` - 核心转录流
2. `LLMService` - AI 调用
3. `AudioCaptureService` - 音频捕获
4. `GeminiLiveService` - 实时对话

---

### P2-5: Dictionary 服务合并

**现状问题**:
- 6 个相关服务：`DictionaryAPIService`, `DictionaryData`, `DictionaryManager`, `UnifiedDictionaryService`, `DictionaryPopupManager`, `DictionaryModels`
- 职责重叠，调用链复杂

**目标架构**:

```
Dictionary/
├── DictionaryService.swift       # 统一入口
├── Models/
│   └── DictionaryModels.swift    # 数据模型
├── Providers/
│   ├── YoudaoProvider.swift      # 有道 API
│   └── LocalProvider.swift       # 本地词典
└── UI/
    └── DictionaryPopup.swift     # 弹窗 UI
```

**合并策略**:
1. `UnifiedDictionaryService` 作为统一入口
2. `DictionaryAPIService` → `YoudaoProvider`
3. `DictionaryManager` 职责合并到 Service
4. `DictionaryPopupManager` → UI 层

---

## 🎯 Phase 3: 文档与维护 (Week 5)

### P2-6: 文档完善

**需要补充的文档**:

| 文档 | 内容 | 位置 |
|------|------|------|
| 架构图 | 服务依赖关系图 | `spoke/docs/architecture/` |
| API 文档 | 核心服务 API | `docs/api/` |
| 贡献指南 | 开发规范 | `CONTRIBUTING.md` |
| 变更日志 | 版本历史 | `CHANGELOG.md` |

---

## 📅 执行时间线

```
Week 1-2: Phase 1 - 基础设施优化
├── Day 1-3: DI 容器设计与实现
├── Day 4-7: 核心服务迁移
├── Day 8-10: HotKeyService 拆分
└── Day 11-14: 验证与修复

Week 3-4: Phase 2 - 代码质量提升
├── Day 15-18: 测试框架搭建 + 核心测试
├── Day 19-21: async/await 迁移
└── Day 22-25: Dictionary 服务合并

Week 5: Phase 3 - 文档与收尾
├── Day 26-28: 文档补充
└── Day 29-30: 最终验证
```

---

## ✅ 验收清单

### Phase 1 验收
- [ ] ServiceContainer 实现并集成
- [ ] 7 个核心服务支持 DI
- [ ] HotKeyService 拆分为 4+ 个模块
- [ ] 所有热键功能正常

### Phase 2 验收
- [ ] 测试覆盖率达到 50%+
- [ ] CI/CD 集成测试
- [ ] async/await 迁移完成 4 个服务
- [ ] Dictionary 服务合并为统一架构

### Phase 3 验收
- [ ] 架构文档完成
- [ ] API 文档完成
- [ ] CHANGELOG 更新

---

## 🚨 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| DI 迁移引入 bug | 高 | 分批迁移，每批验证 |
| 测试覆盖拖慢开发 | 中 | 优先核心路径，渐进式 |
| async 迁移兼容性 | 中 | 保留 callback API 作为桥接 |
| 文档过时 | 低 | 与代码变更同步更新 |

---

## 📝 备注

- 本路线图基于 2026-02-09 的 4 专家评审结果
- P0/P1 问题已在 `design/hig-unify` 分支修复并合并到 `main`
- 执行时应参考 `CLAUDE.md` 中的编码规范
- 建议每周 Review 进度，按需调整优先级

---

*Generated by Claude Code Review System*
