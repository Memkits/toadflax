# 小说编辑器改造设计方案

## 1. 需求概述

将当前的 LLM 对话界面改造为小说创作工具，支持：

- 左侧边栏：章节列表管理（使用 bisection-key 维护顺序）
- 中间区域：单章节内容预览与编辑
- 右侧区域：LLM 对话输入框
- LLM 可以通过 tools 机制查询和修改章节

## 2. 数据结构设计

### 2.1 章节数据结构 (Chapter)

```clojure
{
  :id "uuid"                  ; 章节唯一标识
  :order-key "bisection-key"  ; 用于排序的 bisection-key
  :title "章节标题"
  :summary "章节概要"
  :content "正文内容"
  :created-at timestamp
  :updated-at timestamp
}
```

### 2.2 Store 结构重构

```clojure
{
  :states {...}                ; UI 状态（保持现有结构）
  :chapters {}                 ; Map<order-key, Chapter>
  :current-chapter-id nil      ; 当前选中的章节 ID
  :chat-history []             ; 对话历史（保持现有 messages 结构）
  :model :gemini              ; 当前使用的模型
  :sessions []                 ; 保存的会话列表
  :current-session-id nil      ; 当前会话 ID
}
```

## 3. 界面布局设计

### 3.1 四区域布局

```
+--------------------------------------------------------------+
|                        顶栏 (48px)                            |
|  Logo | 项目标题 | 保存状态 | 设置按钮                          |
+------------------+---------------------------+------------------+
|   章节侧边栏      |      章节预览区            |    LLM 对话区     |
|   (240px)        |      (flex: 1)            |    (400px)       |
+------------------+---------------------------+------------------+
| - 新建章节按钮    | - 章节标题（可编辑）        | - 输入框         |
| - 章节列表       | - 章节概要（可编辑）        | - 发送按钮       |
|   * 标题         | - 正文内容（Markdown预览） | - 对话历史       |
|   * 概要预览     | - 编辑/保存按钮            | - 清空按钮       |
|   * 拖拽排序     |                           |                  |
+------------------+---------------------------+------------------+
```

### 3.2 可复用的现有组件

- `comp-message-box`: 输入框组件（需调整为聊天模式）
- `style-md-content`: Markdown 样式（用于正文渲染）
- `comp-md-block`: Markdown 渲染组件
- `use-modal-menu`, `use-prompt`: 弹窗组件（用于章节操作）
- 现有的样式系统（defstyle）

## 4. 组件拆分规划

### 4.1 新增组件

1. **comp-chapter-sidebar** (章节侧边栏)
   - comp-chapter-item (单个章节项)
   - comp-new-chapter-button (新建章节按钮)

2. **comp-chapter-preview** (章节预览)
   - comp-chapter-header (标题/概要编辑区)
   - comp-chapter-content (正文显示区)
   - comp-chapter-actions (操作按钮区)

3. **comp-chat-panel** (LLM 对话面板)
   - 复用 comp-message-box
   - 新增 comp-chat-history (对话历史显示)
   - 新增 comp-tool-call-indicator (工具调用指示器)

### 4.2 需要重构的组件

- `comp-container`: 改为三栏布局
- 移除或简化当前的 sessions 相关逻辑

## 5. 状态管理与操作

### 5.1 章节操作 (app.updater)

```clojure
; 新增操作类型
:create-chapter    ; 创建新章节
:update-chapter    ; 更新章节（标题/概要/正文）
:delete-chapter    ; 删除章节
:reorder-chapter   ; 重新排序章节
:select-chapter    ; 选择当前章节
```

### 5.2 bisection-key 操作封装

```clojure
; 在 app.comp.container 或新建 app.util.chapter 中
(defn create-chapter-key [chapters position]
  "position: :first | :last | {:after key} | {:before key}")

(defn get-sorted-chapters [chapters]
  "返回按 order-key 排序的章节列表")
```

## 6. LLM Tools 集成设计

### 6.1 工具函数定义

需要在前端实现以下 "tools" 供 LLM 调用：

1. **list-chapters**: 列出所有章节（标题+概要）
2. **get-chapter**: 获取特定章节的完整内容
3. **create-chapter**: 创建新章节
4. **update-chapter**: 更新章节内容
5. **delete-chapter**: 删除章节
6. **reorder-chapter**: 调整章节顺序

### 6.2 Tool 调用流程

```
用户发送消息
  ↓
调用 Gemini API (包含 tools 定义)
  ↓
LLM 返回 tool_call
  ↓
前端执行对应的章节操作
  ↓
将操作结果返回给 LLM
  ↓
LLM 生成最终回复
```

## 7. 实施步骤

### Phase 1: 数据结构迁移 (优先级: 高)

- [ ] 修改 app.schema/store，添加 :chapters 字段
- [ ] 在 app.updater 中实现章节 CRUD 操作
- [ ] 实现 bisection-key 封装函数

### Phase 2: 侧边栏实现 (优先级: 高)

- [ ] 创建 comp-chapter-sidebar
- [ ] 创建 comp-chapter-item
- [ ] 实现新建章节功能
- [ ] 实现章节选择功能

### Phase 3: 中间预览区实现 (优先级: 高)

- [ ] 创建 comp-chapter-preview
- [ ] 实现标题/概要编辑
- [ ] 集成 Markdown 渲染

### Phase 4: 右侧聊天区实现 (优先级: 中)

- [ ] 复用 comp-message-box
- [ ] 实现对话历史显示
- [ ] 调整布局为固定宽度

### Phase 5: 布局重构 (优先级: 高)

- [ ] 修改 comp-container 为三栏布局
- [ ] 实现响应式宽度调整
- [ ] 添加全局样式

### Phase 6: LLM Tools 集成 (优先级: 中)

- [ ] 定义 tools schema
- [ ] 实现 tool 调用处理逻辑
- [ ] 在 submit-message! 中集成 tools

### Phase 7: 数据持久化 (优先级: 低)

- [ ] 实现章节数据的本地存储
- [ ] 实现自动保存功能
- [ ] 实现导出功能（Markdown/JSON）

## 8. 技术注意事项

### 8.1 bisection-key 使用规范

- 新建第一个章节：使用 `mid-id`
- 末尾追加：`(bisect last-order-key max-id)`
- 开头插入：`(bisect min-id first-order-key)`
- 中间插入：`(bisect prev-key next-key)`

### 8.2 性能优化

- 章节列表使用 `defstyle` 提取静态样式
- 正文渲染使用 `memof1-call` 缓存
- 避免在 render 中对 chapters map 做复杂排序

### 8.3 兼容性考虑

- 保留现有的 sessions 机制（可选）
- 支持从旧版本数据迁移

## 9. 待确认问题

1. 是否需要保留原有的多会话切换功能？
2. 章节内容编辑是否需要富文本编辑器，还是纯 Markdown？
3. LLM tools 调用是否需要用户确认？
4. 是否需要支持章节内的分段管理（如场景、段落）？
5. 数据存储是否需要支持云端同步？

## 10. 文件变更清单（预估）

### 需要修改的文件

- `compact.cirru`:
  - app.schema/store
  - app.updater (新增章节操作)
  - app.comp.container/comp-container (布局重构)
  - 新增多个 defcomp

### 可能复用的现有代码

- 样式系统 (defstyle)
- Markdown 渲染 (comp-md-block)
- 输入框 (comp-message-box)
- 模态框工具 (use-modal-menu, use-prompt)

### 新增依赖

- 可能需要：rich-text-editor 或保持纯文本输入
