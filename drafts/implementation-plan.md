# 实施计划与技术细节

## 当前代码分析

### 现有优势

1. **已集成 bisection-key**: `bisection-key.core/bisect` 已导入
2. **完善的样式系统**: 使用 `defstyle` 定义了大量可复用样式
3. **Markdown 支持**: 已有 `comp-md-block` 和相关样式
4. **模态框工具**: `use-modal-menu`, `use-prompt`, `use-drawer` 可直接使用
5. **Gemini API 集成**: 已有 `call-genai-msg!` 函数

### 当前架构问题

1. **单一对话视图**: 当前是全屏对话界面，无侧边栏
2. **Session 混乱**: sessions 用于保存历史对话，与章节概念冲突
3. **状态耦合**: messages 与 state 耦合在一起

## 渐进式改造策略

### 第一阶段：数据层准备（不影响现有功能）

#### 1.1 扩展 Schema

```clojure
; 在 app.schema/store 中添加
:chapters {}           ; 新增：章节数据
:current-chapter-id nil ; 新增：当前章节
```

#### 1.2 新增 Updater 操作

在 app.updater 中添加新的 effect 处理：

- `:create-chapter`
- `:update-chapter`
- `:delete-chapter`
- `:select-chapter`

### 第二阶段：组件开发（并行开发）

#### 2.1 章节工具函数

创建 `app.util.chapters` 命名空间（或直接在 container 中）：

```clojure
(defn get-sorted-chapters [chapters-map]
  "按 order-key 排序返回章节列表"
  (->> chapters-map
       vals
       (sort-by :order-key)
       (map (fn [ch] [(:id ch) ch]))
       (into [])))

(defn create-first-chapter-key []
  "创建第一个章节的 key"
  mid-id)

(defn create-chapter-after [chapters-map after-id]
  "在指定章节后创建新 key"
  (let [sorted (get-sorted-chapters chapters-map)
        idx (index-of sorted (fn [[id _]] (= id after-id)))
        next-idx (inc idx)]
    (if (< next-idx (count sorted))
      (let [curr-key (:order-key (nth sorted idx))
            next-key (:order-key (nth sorted next-idx))]
        (bisect curr-key next-key))
      (bisect (:order-key (nth sorted idx)) max-id))))
```

#### 2.2 侧边栏组件

```clojure
(defcomp comp-chapter-item [chapter selected? on-select on-delete]
  div
    {:class-name (if selected? style-chapter-item-selected style-chapter-item)
     :on-click (fn [e d!] (on-select (:id chapter) d!))}
    div {:class-name style-chapter-title} (:title chapter)
    div {:class-name style-chapter-summary} (:summary chapter)
    =< 8 nil
    span
      {:class-name style-delete-icon
       :on-click (fn [e d!]
         (.stopPropagation e)
         (on-delete (:id chapter) d!))}
      comp-i :x 14 (:color (hsl 0 80 60)))

(defcomp comp-chapter-sidebar [chapters current-id on-select on-create on-delete]
  div {:class-name style-sidebar}
    div {:class-name style-sidebar-header}
      <> "Chapters"
      =< 8 nil
      button
        {:class-name style-create-button
         :on-click (fn [e d!] (on-create d!))}
        comp-i :plus 16
    div {:class-name style-chapter-list}
      list->
        {}
        (->> chapters
             get-sorted-chapters
             (map (fn [[id ch]]
               [id (comp-chapter-item ch (= id current-id) on-select on-delete)])))
```

#### 2.3 预览区组件

```clojure
(defcomp comp-chapter-preview [chapter on-update]
  let
      editing-title? $ or (:editing-title? (>> states :editor)) false
      editing-summary? $ or (:editing-summary? (>> states :editor)) false
    div {:class-name style-preview}
      ; 标题区
      div {:class-name style-preview-header}
        if editing-title?
          input
            {:value (:title chapter)
             :class-name style-title-input
             :on-input (fn [e d!] ...)
             :on-blur (fn [e d!] ...)}
          div
            {:class-name style-chapter-preview-title
             :on-click (fn [e d!] (d! cursor (assoc state :editing-title? true)))}
            <> (:title chapter)

      ; 概要区
      div {:class-name style-preview-summary}
        if editing-summary?
          textarea {...}
          div
            {:on-click ...}
            <> (:summary chapter)

      ; 正文区（Markdown 渲染）
      div {:class-name style-preview-content}
        comp-md-block (:content chapter) {}
```

#### 2.4 聊天面板组件

```clojure
(defcomp comp-chat-panel [messages model on-submit on-clear]
  div {:class-name style-chat-panel}
    ; 对话历史
    div {:class-name style-chat-history}
      list->
        {}
        (->> messages
             (map (fn [msg idx]
               [idx (comp-chat-message msg)])))

    ; 输入区（复用现有）
    comp-message-box states nil on-submit
```

### 第三阶段：布局重构

#### 3.1 修改 comp-container

```clojure
(defcomp comp-container [reel]
  let
      store $ :store reel
      chapters $ or (:chapters store) {}
      current-chapter-id $ :current-chapter-id store
      current-chapter $ get chapters current-chapter-id
      states $ :states store
      ; ... 其他状态

    div
      {:class-name style-app-global}
      div {:class-name style-three-column-layout}
        ; 左侧边栏
        comp-chapter-sidebar chapters current-chapter-id
          fn (id d!) (d! cursor :select-chapter id)
          fn (d!) (d! cursor :create-chapter nil)
          fn (id d!) (d! cursor :delete-chapter id)

        ; 中间预览区
        if (some? current-chapter)
          comp-chapter-preview current-chapter
            fn (updates d!) (d! cursor :update-chapter updates)
          div {:class-name style-empty-state}
            <> "Select or create a chapter"

        ; 右侧聊天区
        comp-chat-panel messages model
          fn (text d!) (submit-message! text d!)
          fn (d!) (d! cursor :clear-chat nil)
```

### 第四阶段：LLM Tools 集成

#### 4.1 定义 Tools Schema

```javascript
const chapterTools = [
  {
    name: "list_chapters",
    description: "List all chapters with their titles and summaries",
    parameters: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "get_chapter",
    description: "Get full content of a specific chapter",
    parameters: {
      type: "object",
      properties: {
        chapter_id: { type: "string", description: "Chapter ID" },
      },
      required: ["chapter_id"],
    },
  },
  {
    name: "update_chapter",
    description: "Update chapter content",
    parameters: {
      type: "object",
      properties: {
        chapter_id: { type: "string" },
        title: { type: "string" },
        summary: { type: "string" },
        content: { type: "string" },
      },
      required: ["chapter_id"],
    },
  },
  // ... 其他 tools
];
```

#### 4.2 修改 submit-message!

```clojure
(defn handle-tool-call [tool-name args chapters dispatch!]
  (case tool-name
    "list_chapters"
      (->> chapters
           get-sorted-chapters
           (map (fn [[id ch]]
             {:id id
              :title (:title ch)
              :summary (:summary ch)}))
           pr-str)

    "get_chapter"
      (let [ch (get chapters (:chapter_id args))]
        (pr-str ch))

    "update_chapter"
      (do
        (dispatch! cursor :update-chapter args)
        "Chapter updated successfully")

    ; ... 其他 tool 处理
    ))
```

## 样式定义（新增）

```clojure
(defstyle style-three-column-layout
  {:display :flex
   :height "100vh"})

(defstyle style-sidebar
  {:width "240px"
   :border-right (str "1px solid " (hsl 0 0 90))
   :display :flex
   :flex-direction :column})

(defstyle style-preview
  {:flex 1
   :overflow :auto
   :padding "16px"})

(defstyle style-chat-panel
  {:width "400px"
   :border-left (str "1px solid " (hsl 0 0 90))
   :display :flex
   :flex-direction :column})

(defstyle style-chapter-item
  {:padding "12px"
   :cursor :pointer
   :border-bottom (str "1px solid " (hsl 0 0 95))
   :transition "background 0.2s"})

(defstyle style-chapter-item-selected
  {:padding "12px"
   :cursor :pointer
   :border-bottom (str "1px solid " (hsl 0 0 95))
   :background (hsl 200 80 95)})
```

## 迁移检查清单

- [ ] 确认不破坏现有的 sessions 功能
- [ ] 测试 bisection-key 排序正确性
- [ ] 验证 Markdown 渲染性能
- [ ] 测试 LLM tool 调用流程
- [ ] 确保数据持久化正常
- [ ] UI 响应式测试

## 风险评估

### 高风险

- 布局重构可能影响现有功能
- bisection-key 排序逻辑错误

### 中风险

- LLM tool 调用可能失败
- 数据结构迁移可能丢失数据

### 低风险

- 样式调整
- 组件拆分

## 回滚策略

1. 使用 git 分支开发
2. 每个阶段完成后提交
3. 保留原有代码注释而非直接删除
4. 添加功能开关控制新旧版本
