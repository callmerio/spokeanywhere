# PinnedText Zoom Notes

**状态**: Active Reference
**更新时间**: 2026-04-20
**适用范围**: `UI/DesktopText/PinnedText*`

---

## 1. 这份说明解决什么问题

这不是一份产品文案，而是一份给后续开发者看的实现说明，主要记录：

1. 当前 `PinnedText` hover zoom 的真实语义
2. 这轮迭代里已经踩过、不要再反复踩的坑
3. 未来如果继续调“跟手性 / 惯性 / 最小缩放”，应该先看哪里

---

## 2. 当前缩放语义

### 2.1 Preview / Commit

当前 `PinnedText` hover zoom 使用两阶段模型：

```text
[ gesture-time preview ]
    -> 临时 previewZoom
    -> 预览文本按 previewZoom 重渲染
    -> 可见 card 按 proportional viewport geometry 缩放

[ settle-time commit ]
    -> 最终 zoomLevel 写回 item
    -> 当前 frame 作为 committed frame 保留下来
```

关键点：

- preview 与 commit 都不再直接依赖 `preferredWindowSize(text:zoom:)` 作为最终可见 card 几何真相
- preview / commit 统一走 `PinnedTextZoomGeometry`
- commit 不应回跳到旧的 renderer reflow size

### 2.2 Geometry

当前可见 card 的缩放语义是：

```text
base viewport frame
    -> zoomRatio
    -> PinnedTextZoomGeometry.scaledViewportSize(...)
    -> uniform clamp
```

这意味着：

1. 内容稍微 overflow 时，不应该先单独拉高再“看起来等比”
2. 内容极长时，不应该退化成“高度不动、只改宽度”
3. 宽和高始终按同一个比例因子变化，只是在 min/max 边界做统一 clamp

### 2.3 Dynamics

当前缩放手感通过 `PinnedTextZoomDynamics` 控制：

- `ingest(stepDelta:)`：吸收手势期输入
- `nextDecayStep()`：ended 后提供短暂 follow-through

现在的 `precise` 路径不是固定台阶，而是按真实 `deltaY` 幅度映射 step：

```text
deltaY -> preciseSensitivity -> capped step
```

非 `precise` 路径仍走固定小步长。

---

## 3. 已确认的坑位

### 3.1 不要再把 renderer preferred size 当成 card 几何真相

之前的问题：

- 轻度 overflow 会先单独拉高
- 重度 overflow 会退化成 width-only 变化

根因：

- 用文本重排后的 `preferredWindowSize` 直接驱动可见 card 大小

结论：

- `PinnedTextMarkdownRenderer` 继续负责字体、排版、内容测量
- 但 hover zoom 的可见 card 几何应该由 `PinnedTextZoomGeometry` 负责

### 3.2 不要让 `mouseExited` 直接等于“取消 preview”

之前的问题：

- 缩小时，卡片边界可能从静止光标下方移开
- `NSTrackingArea` 发出 `mouseExited`
- 旧逻辑把它当成用户真的移开卡片，导致 preview 回弹

现在的规则：

- 只有当光标屏幕坐标真的离开 card 时，才取消 preview
- 如果只是窗口几何变化让 tracking 区域移开，则保留 preview，直到结束手势

### 3.3 不要把 `precise` 缩放做成只看正负号的固定台阶

之前的问题：

- 过于灵敏
- 台阶感强
- 看起来像“一级一级登台阶”

根因：

- 每次 `precise` 事件都给同一个固定 step
- inertia 继续沿用离散大 step

现在的规则：

- `precise` 路径按真实 `deltaY` 幅度映射 step
- inertia 的速度融合更轻、衰减更快

---

## 4. 目前最重要的调参入口

### 4.1 缩放边界

文件：

- `spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift`

关键常量：

- `minZoomLevel`
- `maxZoomLevel`

目前：

- `minZoomLevel = 0.4`
- `maxZoomLevel = 2.4`

如果用户反馈“最小字体还不够小”，优先从 `minZoomLevel` 调整。

### 4.2 手感参数

文件：

- `spoke/UI/DesktopText/PinnedTextWindow.swift`
- `spoke/UI/DesktopText/PinnedTextZoomDynamics.swift`

关键常量：

- `PreviewZoomTuning.preciseSensitivity`
- `PreviewZoomTuning.preciseMaximumStep`
- `PreviewZoomTuning.nonPreciseStep`
- `PinnedTextZoomDynamics.ingest`
- `PinnedTextZoomDynamics.nextDecayStep`

经验顺序：

1. 先调 `preciseSensitivity`
2. 再调 `preciseMaximumStep`
3. 最后才碰 inertia 衰减

原因：

- 多数“太快 / 太敏感”首先来自输入映射
- 惯性只是放大或延续已有体感

---

## 5. 回归测试入口

如果继续改这个交互，优先跑：

```bash
cd spoke
swift test --filter PinnedTextWindowStateTests
swift test --filter PinnedTextZoomGeometryTests
swift test --filter PinnedTextZoomDynamicsTests
swift test --filter AppPinnedTextRuntimeTests
swift build
```

最关键的几组语义：

1. `PinnedTextWindowStateTests`
   - preview / commit / hover exit / clamp / inertia
2. `PinnedTextZoomGeometryTests`
   - visible card 的统一比例缩放与 clamp
3. `PinnedTextZoomDynamicsTests`
   - 跟手速度与衰减
4. `AppPinnedTextRuntimeTests`
   - frame update 传播

---

## 6. 后续如果还要继续优化

推荐优先级：

```text
1. preciseSensitivity
2. preciseMaximumStep
3. inertia decay / threshold
4. 只有在以上都不够时，再考虑更重的视觉插值
```

不推荐一上来就做的事：

- 重新把 preview 改回单纯 layer scale
- 重新把 commit 改回 `preferredWindowSize` 驱动
- 用更大的 inertia 尾巴掩盖输入映射问题

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-20
