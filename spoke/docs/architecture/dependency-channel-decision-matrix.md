# SpokenAnyWhere 依赖通道决策矩阵

**版本**: 1.0
**更新时间**: 2026-03-20
**定位**: 统一 direct call、NotificationCenter 与 ServiceContainer 的使用边界

---

## 一、目的

当前仓库同时存在三条依赖通道：

- direct call
- NotificationCenter
- ServiceContainer

本文档的目标，是让新增代码在评审时可以明确回答两个问题：

1. 这条调用为什么走这条通道？
2. 为什么不走另外两条通道？

---

## 二、三种通道的定义

### 2.1 direct call

适用场景：

- 同一功能域内的同步调用
- 一个编排器明确拥有下游协作者
- 调用方需要立刻拿到结果或控制执行顺序

优点：

- 路径直观
- 调试容易
- 适合同步主链路

风险：

- 容易把 UI 直接绑到业务单例
- 改动时耦合面会持续扩大

### 2.2 NotificationCenter

适用场景：

- 广播式事件
- 发布方不应依赖订阅方存在
- 多个订阅者都可能消费同一事件

优点：

- 低耦合
- 发布方不需要知道订阅方

风险：

- userInfo 弱类型
- 触发链不易追踪
- 容易出现重复监听或遗漏清理

### 2.3 ServiceContainer

适用场景：

- SwiftUI 视图或测试替身需要注入依赖
- 想保留现有服务能力，但降低 `*.shared` 直连
- Preview / mock / 轻量替换是明确目标

优点：

- 可测试
- 便于预览和替身
- 适合作为 UI 收敛入口

风险：

- 如果只是套壳而没有真正消费，收益有限
- 若容器接口过大，会退化成另一种全局入口

---

## 三、决策矩阵

| 场景 | 推荐通道 | 原因 | 不推荐 |
|------|----------|------|--------|
| 录音主链路编排 | direct call | 需要严格控制调用顺序与结果流转 | NotificationCenter |
| UI 点击按钮触发业务动作 | ServiceContainer 或 façade | 降低 `*.shared` 直连，利于 Preview / mock | UI 直接 `.shared` |
| 全局状态变化广播 | NotificationCenter | 发布方不依赖具体消费者 | direct call 广播 |
| 多个模块共享同一服务接口 | ServiceContainer | 允许替换与测试注入 | 每处都写 `.shared` |
| 截图域按钮操作 | façade + direct call | UI 只表达动作，façade 负责组合调用 | 视图自己拼多个单例 |
| 词典/生词已存在广播链路 | NotificationCenter | 已有多方监听消费 | 再加一条平行 direct call |

---

## 四、UI shared freeze 规则

### 4.1 规则

自本文档起：

- UI 层**不应新增**新的 `*.shared` 直接依赖
- 允许存量保留
- 新增 UI 行为优先考虑：
  - `ServiceContainer`
  - 功能域 façade
  - 已有 typed 协作者

### 4.2 例外

满足以下条件时可例外：

1. 改动范围极小，抽象层会显著放大复杂度
2. 该依赖只读、无副作用、且不影响测试替换
3. 在 PR 描述或 review 记录中明确说明“为什么这次不收敛”

---

## 五、最小执行规则

评审新增依赖时，按以下顺序判断：

1. 如果调用发生在 UI 视图中，先判断能否走 `ServiceContainer` 或 façade
2. 如果是广播式通知，判断是否应走 `NotificationCenter`
3. 如果是强顺序编排，允许保留 direct call
4. 如果三种都能走，优先选择**测试替换成本最低**的一条

---

## 六、示例

### 6.1 好例子

- `ARCH-010`：截图 UI 改经 `ScreenshotActionFacade`
- `ARCH-020`：`MessagePanelView` 改经 `MessagePanelViewDependencies`
- `ARCH-030`：`QuickAskCapsuleView` 改经 `QuickAskCapsuleDependencies`

### 6.2 坏例子

- 在新 UI 视图里同时新增：
  - `SomeManager.shared.doX()`
  - `AnotherService.shared.doY()`
  - `NotificationCenter.default.post(...)`

这种情况通常意味着调用边界没有被设计清楚。

---

## 七、配套工具

- `scripts/autoresearch/check_ui_shared_freeze.py`
  - 检查 UI 层当前 `*.shared` 分布
  - 可作为 warn 级 review 辅助工具

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-20
