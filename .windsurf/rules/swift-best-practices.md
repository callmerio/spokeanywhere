---
trigger: manual
---

# Swift Best Practices Rule

当编写或审查 Swift 代码时，遵循以下核心规则。详细内容查阅索引文件。

---

## 📚 文件索引

### 主文档
| 文件 | 用途 |
|------|------|
| `.windsurf/swift-best-practices/SKILL.md` | 核心规则总览 |
| `.windsurf/swift-best-practices/references/concurrency.md` | 并发模式详解 |
| `.windsurf/swift-best-practices/references/swift6-features.md` | Swift 6/6.2 新特性 |
| `.windsurf/swift-best-practices/references/api-design.md` | API 设计规范 |
| `.windsurf/swift-best-practices/references/availability-patterns.md` | 平台可用性标注 |

### 官方语言参考 (Swift 6.2.1)
| 文件 | 用途 |
|------|------|
| `.windsurf/swift-best-practices/programming-swift/LanguageGuide/Concurrency.md` | 并发官方文档 |
| `.windsurf/swift-best-practices/programming-swift/LanguageGuide/Macros.md` | 宏语法 |
| `.windsurf/swift-best-practices/programming-swift/LanguageGuide/ErrorHandling.md` | 错误处理 (Typed Throws) |
| `.windsurf/swift-best-practices/programming-swift/LanguageGuide/Protocols.md` | 协议设计 |
| `.windsurf/swift-best-practices/programming-swift/LanguageGuide/Generics.md` | 泛型 |
| `.windsurf/swift-best-practices/programming-swift/ReferenceManual/Attributes.md` | 所有属性参考 |

---

## 🎯 核心规则速查

### 1. 并发 (Concurrency)

```swift
// ✅ MainActor 显式标注 UI 类型 (SE-0401)
@MainActor
class ViewModel: ObservableObject { }

// ✅ Actor 保护可变共享状态
actor DataCache {
    private var cache: [String: Data] = [:]
}

// ✅ 全局变量必须并发安全 (SE-0412)
static let config = Config()  // 常量 OK
@MainActor static var state = State()  // Actor 隔离 OK

// ❌ 避免不必要的 async
func syncWork() { }  // 不要标 async 如果不需要

// ❌ 永远不要用 DispatchSemaphore 等待 async
// await doAsyncWork()  // 正确方式
```

**详见**: `references/concurrency.md`

### 2. Sendable

```swift
// ✅ 信任编译器流分析，不滥加 Sendable
// Swift 6 Region-based isolation (SE-0414) 会自动推断

// ✅ @MainActor 类型自动 Sendable
@MainActor class SomeClass { }  // 无需再加 Sendable

// ⚠️ @unchecked Sendable 仅在确定安全时使用
final class ThreadSafeClass: @unchecked Sendable { }
```

### 3. Typed Throws (SE-0413)

```swift
enum NetworkError: Error {
    case timeout, invalidResponse
}

// ✅ 指定具体错误类型
func fetch() throws(NetworkError) -> Data {
    throw .timeout  // 可用简写
}
```

**详见**: `programming-swift/LanguageGuide/ErrorHandling.md`

### 4. API 命名

| 场景 | 规则 | 示例 |
|------|------|------|
| 类型/协议 | UpperCamelCase | `DataManager`, `Equatable` |
| 函数/变量 | lowerCamelCase | `fetchData()`, `userName` |
| 能力协议 | -able/-ible/-ing | `Sendable`, `ProgressReporting` |
| 工厂方法 | make 开头 | `makeIterator()` |
| 变异方法对 | 命令式 vs 过去分词 | `sort()` / `sorted()` |

**详见**: `references/api-design.md`

### 5. Swift 6 Breaking Changes

| 变更 | 解决方案 |
|------|----------|
| Property wrapper 不再推断 @MainActor | 显式添加 `@MainActor` 到类型 |
| 全局变量必须并发安全 | 改为常量 / @MainActor / nonisolated(unsafe) |
| `@NSApplicationMain` 废弃 | 使用 `@main` |
| 存在类型需要 `any` | `any Protocol` 代替 `Protocol` |

**详见**: `references/swift6-features.md`

### 6. 可用性标注

```swift
@available(macOS 15, iOS 18, *)
func modernAPI() { }

@available(*, deprecated, message: "Use newMethod()")
func oldMethod() { }

if #available(macOS 15, *) {
    // macOS 15+ code
}
```

**详见**: `references/availability-patterns.md`

---

## 🔍 查阅策略

1. **写代码时** → 先查本文件核心规则
2. **需要细节** → 查 `references/` 下对应文档
3. **语法疑问** → 查 `programming-swift/LanguageGuide/`
4. **正式规范** → 查 `programming-swift/ReferenceManual/`

---

## ⚠️ 常见 Pitfalls

1. **async ≠ 后台线程** - async 只意味着可挂起，不自动切线程
2. **不要创建无状态 Actor** - 用普通 async 函数代替
3. **检查 Task 取消** - 长操作中调用 `try Task.checkCancellation()`
4. **避免 split isolation** - 同一类型不要混合隔离域
5. **减少 context switching** - 在同一隔离域内批量操作
