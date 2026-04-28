# Overlay Unified Contract Design

Date: 2026-04-20
Status: Approved in conversation, pending written-spec review
Scope: `PinnedText` + `Screenshot` 前台浮层的交互与外观统一化

## 1. Context

当前 SpokenAnyWhere 里有两套非常接近、但实现与体感并不完全一致的前台浮层：

1. `PinnedText`
   - 文本来源的贴屏卡片
   - 支持 hover、缩放、编辑、复制文本、复制图片
2. `Screenshot`
   - 图片来源的贴屏卡片
   - 支持 hover、缩放、OCR / Live Text、Quick Ask、复制图片

用户当前提出的真实诉求不是单点改一个参数，而是希望这两类浮层在“看起来像同一类贴图”的前提下，尽量共享一套交互和外观规则：

- `上下滑` 都是缩放
- `左右滑` 都是透明度
- 最低透明度统一
- 阴影 / 光晕尽量统一
- 右键菜单骨架尽量统一

同时用户也明确要求：

- 不同来源的内容可以保留不同的底层处理方式
- 不要为了统一而把“文本缩放”和“图片缩放”的内部实现强行揉成一套
- 视觉风格更倾向于当前 `PinnedText` 这种更自然的浮层，而不是让 `PinnedText` 去长出更重的 screenshot 黑边感

## 2. Primary Goals

1. 让 `PinnedText` 与 `Screenshot` 在用户可感知的交互规则上尽量一致。
2. 把最低透明度统一到更轻的存在感级别。
3. 让两类贴图的右键菜单和视觉语言更像同一套系统。
4. 在统一体验的同时，保留各自内容域的专有能力与实现路径。

## 3. Non-Goals

1. 这一轮不把 `PinnedTextWindow` 和 `ScreenshotWindow` 合并成一个大 window 类。
2. 不强行统一文本内容处理与图片内容处理的内部算法。
3. 不借这轮顺手重构 OCR、Quick Ask、编辑器、图片增强或注释系统。
4. 不要求两个菜单项完全一字不差；允许保留来源特有项。

## 4. Locked Decisions

### 4.1 统一最低透明度

两类前台浮层统一采用：

```text
minimum overlay opacity = 0.05
maximum overlay opacity = 1.0
```

这里的“统一”只作用于浮层本身：

- `PinnedText` 整体卡片透明度
- `Screenshot` 整体贴图透明度

不在本轮一并改动：

- screenshot annotation 文本 opacity clamp
- OCR / Live Text 选区内部透明度
- 其他独立子系统中的 opacity 规则

### 4.2 统一交互语义

两类前台浮层统一为：

```text
vertical dominant scroll   -> 缩放
horizontal dominant scroll -> 透明度
```

说明：

- 这里统一的是**用户语义**
- 不是要求底层必须走同一段缩放实现

也就是说：

- `PinnedText` 继续使用当前文本专属的 zoom / preview / commit 语义
- `Screenshot` 继续使用图片专属的缩放路径
- 但入口规则和最低透明度应一致

### 4.3 统一菜单骨架，保留来源特有项

右键菜单统一到一套共享骨架：

```text
[ Common Core ]
1. Copy Image
2. Pin / Unpin
3. Mark / Unmark
4. Close

[ Source Specific ]
- PinnedText: Copy Text, Edit
- Screenshot: OCR / Live Text, Quick Ask, Copy Enhanced Image
```

目标不是“完全一样”，而是：

1. 共有项的命名尽量统一
2. 共有项的顺序尽量统一
3. 分组逻辑尽量统一
4. 特有项在统一骨架里自然挂接

### 4.4 统一视觉契约，但允许内容层差异

用户希望两类贴图“看起来像同一类贴图”，而不是明显属于两套系统。

因此本轮视觉方向锁定为：

- screenshot 的边缘黑感 / 厚重感向 `PinnedText` 当前更自然的风格靠拢
- 不是让 `PinnedText` 去变得更像现在 screenshot 那种更重的边缘

但“统一视觉契约”并不等于“完全相同像素输出”：

- 两类内容尺寸不同
- 文本卡片与图片卡片的内容密度不同
- 可允许在同一套 token 结构下有轻微 surface-specific 数值差异

## 5. Recommended Architecture

### Recommendation

推荐做法是引入一个共享的 `overlay interaction / appearance contract`，而不是直接合并两个 window 类。

推荐结构：

```text
[ Overlay Contract ]
├─ Interaction Config
│  ├─ horizontal scroll -> opacity
│  ├─ vertical scroll -> zoom
│  └─ min/max opacity
├─ Menu Contract
│  ├─ common groups
│  └─ source-specific item slots
└─ Appearance Contract
   ├─ glow token set
   ├─ shadow token set
   └─ hover / mark / idle state mapping
```

然后：

```text
PinnedTextWindow     -> 接共享 contract + 自己的文本缩放实现
ScreenshotWindow     -> 接共享 contract + 自己的图片缩放实现
```

### Why this is preferred

1. 统一体验规则而不破坏内容域实现。
2. 风险明显低于“窗口类大合并”。
3. 以后继续统一时，可围绕 contract 迭代，而不是重复对比两套散落逻辑。
4. 更适合 TDD：先锁 contract 语义，再分别接入。

## 6. Detailed Design

### 6.1 Opacity Contract

共享 contract 至少要提供：

- `minimumOpacity = 0.05`
- `maximumOpacity = 1.0`
- `horizontalOpacitySensitivity`
- optional: `isOpacityScrollLocked` 之类的滚动生命周期规则

目标：

- `PinnedTextWindow.handleOpacityChange(...)`
- `ScreenshotWindow.handleOpacityChange(...)`

都不再各自硬编码下限。

它们可以仍然保留自己的函数，但下限、上限和 sensitivity 来源应统一。

### 6.2 Menu Contract

共有菜单项建议统一为一组共享 builder 或共享 descriptors：

- `Copy Image`
- `Pin to Space` / `Unpin`
- `Mark` / `Unmark`
- `Close`

`PinnedText` 额外项：

- `Copy Text`
- `Edit` 或进入编辑相关入口

`Screenshot` 额外项：

- `Copy Text`（如果 OCR / Live Text 可得）
- `Quick Ask`
- `Copy Enhanced Image`
- `OCR`（若仍保留独立入口）

### 6.3 Appearance Contract

这部分不要求一步到位共用同一份像素常量，但至少应共用同一套字段结构：

- idle glow
- hover glow
- mark glow
- card edge / stroke visibility
- shadow radius / opacity / color family

预期方向：

- 当前 screenshot 比 text 更重的边缘黑感要先被识别并收敛
- 若最终发现数值不能完全一致，也应在同一配置模型里表达，而不是两个 surface 各自散落写死

### 6.4 Zoom Implementation Boundary

尽管用户体验上“上下滑都是缩放”，但底层仍分开：

```text
PinnedText  -> 文本 zoom pipeline
Screenshot  -> 图片 zoom pipeline
```

允许差异：

- preview / commit 机制
- 几何计算方式
- 内容重绘方式

需要统一的是：

- 入口手势语义
- 菜单与外观 contract
- 透明度 contract

## 7. Testing Strategy

本轮推荐测试顺序：

### Phase A — Contract red tests

1. `PinnedText` 和 `Screenshot` 的最小透明度统一到 `0.05`
2. 两边 horizontal scroll 都仍然调透明度
3. 共有菜单项顺序 / 命名 / 分组符合统一骨架
4. glow / shadow contract 的共有字段存在且被双方消费

### Phase B — Integration tests

1. `PinnedTextWindowStateTests`
   - horizontal opacity floor 变更
   - 菜单骨架断言更新
2. `ScreenshotWindowInteractionTests`
   - opacity floor / hover visual / context menu 骨架
3. 如有需要，补新的 shared contract 单测

### Phase C — Manual UAT

手工检查：

1. 两类浮层都能淡到“几乎只是一个提示”
2. 两类浮层横向滑动的透明度感受一致
3. 右键菜单的共有项位置、命名、分组更统一
4. screenshot 不再有明显比 text 更“脏”或更重的黑边感

## 8. Risk Notes

### Risk 1 — 过度统一导致内容域能力退化

避免方式：

- 统一 contract，不统一内容实现

### Risk 2 — 视觉“统一”变成视觉“平均”

避免方式：

- 目标不是两者完全复制彼此
- 目标是“看起来属于同一系统”
- screenshot 视觉应向当前 text 的自然感靠拢

### Risk 3 — 菜单统一破坏已有用户肌肉记忆

避免方式：

- 只统一共有骨架
- 特有项保留，但挂在稳定位置

## 9. Recommended Execution Strategy

推荐分两步，而不是一步把所有实现揉进去：

```text
Step 1
  -> 先 research / diff 两条链
  -> 明确 opacity / menu / appearance contract
  -> 补红灯测试

Step 2
  -> 先落 opacity contract
  -> 再落 menu skeleton
  -> 最后收 appearance token / config
```

这比“直接一步到位改完”更稳，也更符合你刚才说的担心：

- 不丢方法
- 不丢实现
- 能逐步验证统一是否真的更自然

## 10. Current User-Approved Inputs

为避免后续跑偏，当前已锁定的用户输入如下：

1. 统一最低透明度先用 `0.05`
2. `上下滑` 继续各自做缩放，但规则层面统一为“纵向缩放”
3. `左右滑` 都调透明度
4. 右键尽量统一，但允许不同来源走不同底层实现
5. 阴影 / 光晕统一的目标是让 screenshot 向 text 当前更自然的风格靠拢
6. 这一轮不建议粗暴一步把两个实现硬合并

---

**Review needed before implementation planning.**
