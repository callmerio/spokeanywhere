# User Requirement

## 功能描述
实现类似 Raycast 的查词功能

## 核心交互
1. **手动输入** - 用户输入单词进行搜索
2. **列表视图** - 显示搜索结果（含词形变化：ripe, ripen, ripening, ripened 等）
3. **键盘导航**
   - `↑↓` 选择结果
   - `Enter` 进入详细释义视图
   - `Tab` 标记/取消标记生词
4. **生词高亮** - 已标记的生词显示橙色

## 参考截图分析
### 列表视图 (Image 1)
- 搜索框在顶部（带返回箭头）
- 结果列表：单词 + 词性 + 简短释义
- 底部操作栏：Define Word | Show Details (↵) | Actions (⌘K)
- 选中项有高亮背景

### 详情视图 (Image 2)
- 返回箭头（可回到列表）
- 词典来源标题 (English Thesaurus)
- 单词 + 词性
- 多个义项，每个义项含：
  - 编号 + 例句（斜体）
  - 同义词（大写加粗主要词 + 普通同义词）
  - 反义词（ANTONYMS 标签）
- 底部操作栏：单词 | Open in Dictionary (↵) | Actions (⌘K)

## 与现有系统的关系
- **VocabularyService** - 生词管理（已有）
- **DictionaryAPIService** - 词典查询 API（已有）
- **DictionaryResultView** - 词典结果展示（已有，但是简化版）
