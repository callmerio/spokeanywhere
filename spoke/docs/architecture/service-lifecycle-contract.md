# Service Lifecycle Contract

版本：v1  
日期：2026-03-19  
状态：active

## 1. 目标

本合同用于把 App 层顶层服务的启动 / 终止边界从“分散的隐式行为”收敛为“可审计的显式约定”。

当前合同聚焦 `AppDelegate` 与 `RecordingController` 相关的顶层服务，不要求一次性去单例化，也不覆盖所有 observer / callback 清理细节。

## 2. Owner 与基本约束

- `AppDelegate` 是顶层服务生命周期合同的 owner。
- `applicationDidFinishLaunching(_:)` 只通过显式 contract 启动受管服务。
- `applicationWillTerminate(_:)` 只通过显式 contract 终止受管服务。
- 运行期副作用应优先放在 `start()` / `stop()`，而不是 `init()`。

## 3. 合同覆盖范围

- `RecordingController`
- `TrackpadSwipeService`
- `ResourceMonitor`
- `SelectionToolbarManager`

## 4. 启动合同

1. `AppDelegate -> RecordingController.start()`
   - 注册 `RecordingController` 拥有的 hotkey / HUD / audio callback 运行期绑定
   - 允许重复调用，但实现必须具备幂等保护

2. `AppDelegate -> setupTrackpadGesture() -> TrackpadSwipeService.start()`
   - `AppDelegate` 负责手势回调 wiring
   - `TrackpadSwipeService` 负责全局手势监听的实际启停

3. `AppDelegate -> setupResourceMonitor() -> ResourceMonitor.start(interval:onOverload:)`
   - `AppDelegate` 负责阈值配置与 overload 降级策略
   - `ResourceMonitor` 负责定时采样与超限通知

4. `AppDelegate -> setupSelectionToolbar() -> SelectionToolbarManager.start()`
   - `AppDelegate` 负责读取设置并决定是否启动
   - `SelectionToolbarManager` 负责选择监听与工具栏显示

## 5. 终止合同

1. `AppDelegate -> RecordingController.stop()`
   - 注销自身拥有的 hotkey 回调
   - 取消当前录音会话
   - 释放 HUD 回调绑定
   - 移除自身 audio callback session

2. `AppDelegate -> TrackpadSwipeService.stop()`
   - 停止全局 scrollWheel 监听

3. `AppDelegate -> SelectionToolbarManager.stop()`
   - 停止选择监听并隐藏工具栏窗口

4. `AppDelegate -> ResourceMonitor.stop()`
   - 停止定时器采样，结束 overload 监控

## 6. 可审计规则

- 新增顶层服务前，必须先明确 owner、启动边界、终止边界，再接入 `AppDelegate`。
- 如果服务没有 `start()` / `stop()`，也必须给出等效的显式边界方法，并在本合同中登记。
- `RecordingController` 的 `init()` 不应再承担运行期回调注册或音频 session 创建等副作用。

## 7. 当前非目标

- 不在本轮一次性去除 `*.shared`
- 不在本轮覆盖所有 singleton 服务
- 不在本轮解决全部 observer / callback inventory；该部分继续由 `APP-020` 收敛
