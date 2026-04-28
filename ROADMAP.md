# SpokenAnyWhere Roadmap

> 版本: `v2026.04-outline`
> 更新: `2026-04-19`
> 定位: `桌面理解层 + 工作流层`
> 主线: `跨应用流转`
> 爆点: `看屏即问`
> 标签: `#桌面上下文` `#跨应用流转` `#看屏即问` `#桌面对象`
> 详版: [`ROADMAP.detail.md`](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/ROADMAP.detail.md)
> 会话镜像: [`.draft.md`](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/.draft.md)
> 归档: [`spoke/docs/roadmap/2026-02-execution-roadmap-archive.md`](/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/docs/roadmap/2026-02-execution-roadmap-archive.md)

SpokenAnyWhere 的核心不是做更大的单点功能，而是把桌面上正在发生的内容，快速变成可提问、可加工、可沉淀、可流转的上下文。

—————— SUM ——————————————————

1. `产品定义` 这是一个围绕桌面上下文持续协作的助手，不只是转写、截图或查词工具。
2. `当前状态` 采集与入口已经较强，理解、动作、回流正在收束成统一体验。
3. `近期方向` 先打穿 `看屏即问`，再把这条最短路径外溢到 `跨应用流转`。
4. `文档分工` 主文档保留骨架与判断；展开说明统一写入 `ROADMAP.detail.md`。

—————— SUM ——————————————————

## A. 产品定义

- `A.1 一句话` `#identity`
  SpokenAnyWhere 帮用户把桌面上正在发生的内容，变成可以立即提问、加工、记录和流转的上下文。
- `A.2 主用户` `#user/知识工作者` `#user/双语信息工作者` `#user/上下文创作者`
  小批注：共同点不是“都要语音”，而是都在高频处理屏幕、文本、音频和上下文切换。
- `A.3 边界` `#not/长文笔记软件` `#not/通用自动化平台` `#not/单点录音工具`
  小批注：产品的重心是桌面上下文协作，不是独立赛道工具的大而全扩张。
- `A.4 主轴` `#axis/跨应用流转` `#breakout/看屏即问`
  小批注：主轴决定产品长期形态，爆点决定最近一段时间最值得打穿的最短路径。

```text
[ 当前桌面 ]
      │
      ▼
[ 上下文进入系统 ]
      │
      ├─ 理解
      ├─ 动作
      └─ 回流到用户手边
```

## B. 当前能力树

```text
[ Desktop Context ]
    │
    ├─ B.1 采集                #maturity/high
    │   ├─ Screenshot
    │   ├─ OCR
    │   ├─ Selection
    │   ├─ Clipboard
    │   └─ PinnedText as source
    │
    ├─ B.2 理解                #maturity/medium
    │   ├─ Quick Ask
    │   ├─ Subtitle / Translation
    │   ├─ Dictionary
    │   └─ AI processing
    │
    ├─ B.3 动作                #maturity/medium
    │   ├─ Answer Panel
    │   ├─ Message Panel
    │   ├─ Toolbar actions
    │   └─ Screenshot actions
    │
    ├─ B.4 回流 / 沉淀         #maturity/high-potential
    │   ├─ PinnedText
    │   ├─ History
    │   └─ Desktop objects
    │
    └─ B.5 入口 / 个性化       #maturity/high
        ├─ Hotkeys
        ├─ Menu bar
        ├─ HUD / Panels
        └─ Settings / Rules
```

- `B.1 采集` `#entry/hotkey` `#entry/menu` `#entry/selection` `#output/context` `#maturity/high`
  代表能力：`截图` `OCR` `选区监听` `剪贴板注入` `PinnedText`
  小批注：入口已经够强，缺的不是功能数量，而是统一表达。
- `B.2 理解` `#entry/quick-ask` `#entry/live-caption` `#output/explain` `#output/translate` `#maturity/medium`
  代表能力：`Quick Ask 上下文拼装` `实时字幕` `翻译` `词典` `AI 理解`
  小批注：强能力点已经出现，但还没完全收束成统一上下文包。
- `B.3 动作` `#entry/toolbar` `#entry/panel` `#output/answer` `#output/action` `#maturity/medium`
  代表能力：`Answer Panel` `Message Panel` `工具栏动作` `截图标注 / Pin`
  小批注：差异化开始成型，但动作语言还偏分散。
- `B.4 回流 / 沉淀` `#output/pinned` `#output/history` `#output/object` `#maturity/high-potential`
  代表能力：`PinnedText` `History` `截图资产` `可继续编辑的桌面对象`
  小批注：这是最值得持续放大的产品杠杆，因为结果会留在用户手边。
- `B.5 入口 / 个性化` `#entry/global` `#entry/menu-bar` `#prefs/settings` `#prefs/rules` `#maturity/high`
  代表能力：`全局快捷键` `状态栏` `HUD / 浮窗` `Settings` `AppRule / 偏好`
  小批注：入口已经够多，后续重点是收敛，不是继续扩入口。

## C. 高价值工作流树

```text
[ Entrypoints ]
    │
    ├─ C.1 看屏即问
    │   HotKey / Screenshot
    │      -> OCR / Context Pack
    │      -> Quick Ask
    │      -> Answer Panel
    │
    ├─ C.2 跨应用流转
    │   Selection / Clipboard / Screenshot
    │      -> Message Panel
    │      -> Workflow / follow-up action
    │
    ├─ C.3 边看边记
    │   Screen / Selected text
    │      -> AI / transform
    │      -> PinnedText / desktop object
    │
    └─ C.4 边听边懂
        Live Caption / system audio
           -> Translation / Dictionary
           -> History / screen return
```

- `C.1 看屏即问` `#workflow/breakout` `#entry/screenshot` `#return/answer-panel`
  小批注：这是当前最短、最容易形成“第一次就懂”的产品路径。
- `C.2 跨应用流转` `#workflow/core-axis` `#entry/selection` `#entry/clipboard` `#return/workflow`
  小批注：这条链路决定产品是不是一个真正的桌面工作流层。
- `C.3 边看边记` `#workflow/objectify` `#return/pinned`
  小批注：这里最能体现“结果不消失，而是回到现场”。
- `C.4 边听边懂` `#workflow/audio-context` `#return/history`
  小批注：这是独特能力线，但还需要更明确地接入共享上下文体系。

## D. 当前缺口

- `D.1 上下文对象还不统一` `#gap/context-pack`
  小批注：截图、OCR、字幕、选区、剪贴板仍像多套来源，而不像同一种上下文对象。
- `D.2 动作语言还不统一` `#gap/action-language`
  小批注：用户现在更容易记住入口，而不是记住动作。
- `D.3 结果载体边界还不清` `#gap/return-surface`
  小批注：`Answer Panel`、`Message Panel`、`PinnedText`、`History` 都在承接结果，但分工还不够一眼看懂。
- `D.4 主线聚焦还不够强` `#gap/focus`
  小批注：功能已经很多，但“为什么现在要用它”还可以更锋利。

## E. 路线图

### E.1 未来 3-6 个月

```text
[ NOW / 3-6M ]
├─ E.1.1 统一上下文入口      #status/now #axis/core
│  └─ 用户先送入当前上下文，而不是先选功能
├─ E.1.2 统一动作层          #status/now #axis/core
│  └─ 用户记住动作，不再记住入口差异
├─ E.1.3 统一结果回流        #status/next #return
│  └─ 结果继续停留、编辑、再利用
└─ E.1.4 入口 / 设置收敛     #status/next #ux
   └─ 入口命名、设置组织与交互语义对齐
```

- `E.1.1 统一上下文入口` `#status/now` `#lane/context-ingest`
  小批注：目标不是新增更多入口，而是把已有入口收束成统一感知。
- `E.1.2 统一动作层` `#status/now` `#lane/action-model`
  小批注：重点围绕 `理解 / 沉淀 / 流转` 三类动作来压缩心智模型。
- `E.1.3 统一结果回流` `#status/next` `#lane/return-loop`
  小批注：产品不只“会回答”，而是“会把结果送回用户手边”。
- `E.1.4 入口 / 设置收敛` `#status/next` `#lane/ux-coherence`
  小批注：减少能力目录感，改成围绕任务链组织。

### E.2 未来 12-24 个月

- `E.2.1 个人上下文图谱` `#future/personal-context`
  小批注：从记住历史，走向逐步理解用户的长期工作现场。
- `E.2.2 持续桌面理解` `#future/ambient-context`
  小批注：不是无边界监控，而是在授权前提下更懂当前桌面状态。
- `E.2.3 可组合动作系统` `#future/composable-actions`
  小批注：让一次动作自然接到下一步，而不是停在单点输出。
- `E.2.4 桌面对象化` `#future/desktop-objects`
  小批注：继续放大 `PinnedText` 一类可见、可编辑、可流转的桌面对象。

### E.3 明确等待

- `#wait/大规模平台扩展`
- `#wait/模型接入竞赛`
- `#wait/重插件生态`
- `#wait/大规模 UI 重绘`

小批注：这些方向不是没价值，而是现在会稀释主线。

## F. 取舍规则

- `F.1` `#rule/capture-vs-flow`
  它是在增强 `上下文采集`，还是 `上下文流转`？
- `F.2` `#rule/focus-vs-fragment`
  它会让主线更清晰，还是让入口更分散？
- `F.3` `#rule/return-to-user`
  它会让结果更容易回到用户手边，还是只增加一次性输出？
- `F.4` `#rule/product-axis`
  它是否真的强化了 `桌面理解层 + 工作流层` 的定位？

如果这四个问题都答不扎实，就不该进入近期路线。
