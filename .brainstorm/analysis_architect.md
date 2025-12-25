# Role Analysis: System Architect

## Architecture Overview
System needs to be secure (Sandboxed), robust (Error handling), and performant (Low latency).

## Analysis of Questions

1. **里程碑优先级 (App Sandbox)**:
   - **观点**: 沙盒化不仅仅是开关，它限制了文件访问（Open/Save Panels, Security Scoped Bookmarks）、IPC（XPC Services）和硬件访问。这是一个**架构级的重构**。必须现在做，因为所有文件 I/O 逻辑可能都需要修改。
   - **风险**: 现有的自动保存、日志记录、截图保存路径可能全部失效。
   - **建议**: **立即启动沙盒化迁移**，作为技术债务清偿的第一优先级。

2. **核心痛点 (翻译截断)**:
   - **观点**: 截断通常是由于 UI 布局计算（NSTextView/Label）与异步数据流的不匹配，或者是 API 返回数据的处理逻辑问题。这属于 Bug Fix。
   - **建议**: 分配专门的 Debug 资源解决。

3. **技术偏好 (本地模型)**:
   - **观点**: 引入本地模型（CoreML/Whisper.cpp）会引入复杂的依赖管理和性能调优（内存占用、热管理）。
   - **建议**: 目前架构支持多引擎，可以先保持架构的灵活性，待 App 稳定后再通过插件化或可选下载的方式引入本地模型，避免主包过大。

4. **交互体验 (Onboarding)**:
   - **观点**: 权限检测逻辑目前分散在各 Service 中。
   - **架构建议**: 统一 `PermissionManager` 模块，集中管理状态和请求逻辑，为 UI 提供统一的 State。

## Proposal
1. **Technical Foundation (P0)**: **App Sandbox Migration**. 彻底梳理文件访问权限，引入 `SecurityScopedBookmark` 机制。
2. **Refactoring**: 统一权限管理模块 `PermissionManager`，支持响应式状态更新。
3. **Maintenance**: 修复翻译/UI布局的 Bug。
