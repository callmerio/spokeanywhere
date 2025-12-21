---
description: 智能记忆系统 - INDEX 驱动的项目知识管理
---

# Workflow: /memo - 智能记忆系统

管理项目知识索引 (INDEX.md) 和经验记录 (memory.csv)。

## [FLOW_CONTROL]

### 触发条件

当 `docs/memo/INDEX.md` 不存在时，自动进入此 workflow。

---

### Phase 1: 检查 INDEX.md 是否存在

```
- Step 1: 检查文件
  - Tool Call: `view_file: path=docs/memo/INDEX.md`
  - If SUCCESS: 跳转到 Phase 3 (正常工作流程)
  - If NOT FOUND: 继续 Phase 2 (创建流程)
```

---

### Phase 2: 创建 INDEX.md

当 `docs/memo/INDEX.md` 不存在时执行：

```
- Step 1: 创建目录结构
  - Tool Call: `run_command: mkdir -p docs/memo`

- Step 2: 扫描项目结构
  - Tool Call: `list_dir: DirectoryPath=./`
  - Tool Call: `view_file: path=package.json` (if exists)
  - Tool Call: `view_file: path=README.md` (if exists)
  - Store in: [PROJECT_INFO]

- Step 3: 生成 INDEX.md
  - Tool Call: `write_to_file: path=docs/memo/INDEX.md`
  - Content:
    ```markdown
    # 项目知识索引

    > 本文件由 /memo workflow 自动生成，请根据项目实际情况更新。

    ## 项目概述
    [根据 PROJECT_INFO 生成]

    ## 文档目录

    | 文件 | 描述 | 用途 |
    |------|------|------|
    | `INDEX.md` | 知识索引入口 | AI 首先读取此文件定位相关文档 |
    | `memory.csv` | 经验记录 | 记录操作历史、Bug 修复经验等 |
    | `memory-timeline.md` | 时间线索引 | 按时间排序的独立经验条目 |
    | `cards.md` | 知识卡片 | 问答形式的知识积累 |
    | `FEATURES.md` | 功能文档 | 新功能的详细说明 |

    ## 使用说明

    1. AI 在回答问题前先读取此 INDEX.md
    2. 根据任务类型查找相关文档
    3. 查询 memory.csv 获取历史经验
    4. 完成任务后使用 /brain-5-record 更新记录
    ```

- Step 4: 创建 memory.csv (与 /brain-5-record 格式统一)
  - Tool Call: `write_to_file: path=docs/memo/memory.csv`
  - Content:
    ```csv
    timestamp,file,action,summary,ai_tips,ref
    ```

- Step 5: 确认
  - Prompt to User: "✅ 已创建项目记忆系统: docs/memo/INDEX.md + memory.csv"
```

---

### Phase 3: 更新 INDEX.md

当需要更新 INDEX.md 时执行：

```
- Step 1: 读取当前 INDEX.md
  - Tool Call: `view_file: path=docs/memo/INDEX.md`
  - Store in: [CURRENT_INDEX]

- Step 2: 扫描 docs/memo 目录
  - Tool Call: `list_dir: DirectoryPath=docs/memo/`
  - Store in: [MEMO_FILES]

- Step 3: 更新文档目录
  - Instruction: 将 [MEMO_FILES] 中的新文件添加到 INDEX.md 的文档目录表格

- Step 4: 写入更新
  - Tool Call: `replace_file_content` 或 `write_to_file`

- Step 5: 确认
  - Prompt to User: "✅ INDEX.md 已更新"
```

---

### Phase 4: 更新 memory.csv (兼容 /brain-5-record)

当需要记录新经验时执行。**格式与 /brain-5-record 完全一致**：

```
- Step 1: 读取 memory.csv
  - Tool Call: `view_file: path=docs/memo/memory.csv`
  - Store in: [CURRENT_MEMORY]

- Step 2: 追加新记录
  - 格式: timestamp,file,action,summary,ai_tips,ref

  字段说明:
  | 字段 | 说明 | 必填 | 示例 |
  |------|------|------|------|
  | timestamp | ISO 时间 | ✅ | 2024-01-15T10:30:00+08:00 |
  | file | 相对 memo/ 的路径 | ✅ | memory-timeline.md |
  | action | create/update/fix/delete | ✅ | fix |
  | summary | 简短描述做了什么 | ✅ | 修复音频设备切换崩溃 |
  | ai_tips | 给后续 AI 的经验 | ✅ | 检查 AVAudioSession 错误处理 |
  | ref | 引用详细文档（可选） | - | T001 |

- Step 3: 写入更新
  - Tool Call: `run_command: echo "new_record" >> docs/memo/memory.csv`
  或
  - Tool Call: `replace_file_content` (追加到文件末尾)

- Step 4: 确认
  - Prompt to User: "✅ memory.csv 已更新"
```

---

## 快捷命令

| 命令 | 作用 |
|------|------|
| `/memo init` | 强制重新创建 INDEX.md + memory.csv |
| `/memo update` | 更新 INDEX.md 文档目录 |
| `/memo add [record]` | 添加新的经验记录 |
| `/memo search [keyword]` | 搜索 memory.csv |

---

## 与其他 Workflow 的集成

### 与 mugou.md (always_on) 集成

1. 首先尝试 `view_file("docs/memo/INDEX.md")`
2. 如果不存在 → 自动触发 Phase 2 创建流程
3. 如果存在 → 正常读取并继续工作
4. 任务完成后 → 调用 Phase 4 或 /brain-5-record

### 与 /brain-5-record 集成

- memory.csv 格式完全一致
- /brain-5-record 负责：追加 memory.csv + memory-timeline.md + FEATURES.md + cards.md
- /memo 负责：INDEX.md 管理 + memory.csv 初始化
