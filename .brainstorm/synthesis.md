# Brainstorm Synthesis

## Aligned Decisions
- **一致同意 P0: App Store 合规与沙盒化**。
  - PM 认为这是发布的必要条件。
  - 架构师认为这是架构安全的基础，越晚做成本越高。
- **一致同意 P0: 体验/Bug 修复**。
  - 特别是翻译截断问题，不仅影响体验，也可能隐含架构缺陷。
- **一致同意 P1: 权限引导 (Onboarding)**。
  - PM 关注转化率，架构师关注统一的权限管理模块。
- **暂缓本地模型**。
  - 双方都认为目前优先级低于合规和体验修复。

## Conflicts Identified
- **冲突 1**: 自定义快捷键 (PM P1) vs 架构重构 (Architect P0)。
  - **Resolution**: 优先完成沙盒化和权限模块重构（因为 Onboarding 依赖它），之后再做自定义快捷键（作为易用性提升）。

## Unified Proposal (Roadmap)

### Phase 1: Foundation & Compliance (The "Must-Haves")
1.  **App Sandbox 迁移**: 
    - 配置 Entitlements。
    - 修复文件访问（Security Scoped Bookmarks）。
    - 验证所有核心功能在沙盒下正常工作（截图、录音、日志）。
2.  **权限引导 (Onboarding)**:
    - 设计并实现首次启动向导。
    - 统一 `PermissionManager`。
    - 引导用户授予辅助功能、录音等必要权限。

### Phase 2: Core Experience Polish (The "Quality of Life")
1.  **翻译系统优化**: 彻底修复翻译截断问题，优化高频更新时的 UI 性能。
2.  **自定义快捷键**: 让用户根据习惯配置 ⌥+R, ⌥+A 等。

### Phase 3: Visual & Delight (The "Nice-to-Haves")
1.  **深色/浅色主题**: 完善 Design Token，支持系统切换。
2.  **本地字典/生词本面板**: 继续打磨交互细节。
