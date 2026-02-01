# Bisection Keys (分段索引) 开发指南

项目采用 `bisection-key` 方案来实现列表元素的逻辑排序。这是一种基于 **Fractional Indexing (分数索引)** 的技术，通过字符串的字典序来决定先后顺序，从而实现在不重新计算全表索引的情况下，在任意位置进行高性能插入。

## 1. 核心原理与优势

- **字典序排列 (Lexicographical Order)**：字符串 A < 字符串 B，则元素 A 排在元素 B 前面。
- **无限可分性**：在任意两个 Key 之间，总是可以生成一个新的字符串。
- **本地操作友好**：插入新元素时，只需要计算自身的 Key，不需要更新数据库或 State 中的其他元素。

## 2. 常用操作集

### 常用常量 (bisection-key.core)

- `min-id`：**逻辑最小值**。作为虚拟的“负无穷”，用于在列表最开头插入。
- `mid-id`：**逻辑中间值**。通常用于初始化列表的第一个元素。
- `max-id`：**逻辑最大值**。作为虚拟的“正无穷”，用于在列表最末尾插入。

### 核心函数 (bisection-key.core)

- `(bisect A B)`：生成一个介于 A 和 B 之间的字符串。
  - **必须保证 A < B**。
  - 应用：`(bisect min-id first-key)` 获取开头插入位。

### 辅助工具 (bisection-key.util)

当 State 结构为 `{key content}` (即以 bisection-key 为键的 Map) 时，使用 these 辅助函数可以极大减少样板代码：

#### 生成 Key

- `(key-before dict base-key)`：根据当前字典，生成一个排在 `base-key` **紧邻前方**的 Key。
- `(key-after dict base-key)`：根据当前字典，生成一个排在 `base-key` **紧邻后方**的 Key。
- `(key-prepend dict)`：生成一个在当前**列表最前方**插入的 Key。
- `(key-append dict)`：生成一个在当前**列表最后方**插入的 Key。

#### 原子操作 Map

- `(assoc-before dict base-key v)`：直接在 `base-key` 前方位置插入值 `v`。
- `(assoc-after dict base-key v)`：直接在 `base-key` 后方位置插入值 `v`。
- `(assoc-prepend dict v)`：在列表最开头插入值 `v`。
- `(assoc-append dict v)`：在列表最后面追加值 `v`。

#### 数据查询

- `(key-nth dict n)`：按顺序获取第 `n` 个 Key。
- `(val-nth dict n)`：按顺序获取第 `n` 个 Value。
- `(key-index-of dict k)`：查找特定 Key `k` 在当前顺序中的索引位置。

## 3. 实战场景详解

### 查找相邻邻居

如果你手里有一个 Key `k`，想要找到它前后的“兄弟节点”：

- **前一个节点**:
  ```clojure
  let ((idx (key-index-of dict k)))
    (if (> idx 0)
      (key-nth dict (dec idx))
      nil)
  ```
- **后一个节点**:
  ```clojure
  (key-nth dict (inc (key-index-of dict k)))
  ```

### 节点拆分 (一分为多)

当你需要把一个节点 `A` 拆成 `A1`, `A2`, `A3` 时：

1. 更新 `A` 的内容为 `A1` (保持原 Key 不变)。
2. 使用 `(assoc-after dict A-key A2)` 插入 A2。
3. 再次在 `A2` 的 Key 基础上 `assoc-after` 插入 A3。

### 节点合并 (多合一)

将 `A`, `B`, `C` 合并为 `NewA`：

1. 将 `A` 的 Key 所对应的内容更新为合并后的新结果。
2. 使用 `(dissoc dict B-key C-key)` 将多余的节点移除。

## 4. 注意事项与规约

- **禁止手动拼凑 Key**：Key 内部使用自定义 Base64 字符集 (`+-/0-9A-Za-z`)，手动拼凑极易导致排序失效或 `bisect` 报错。
- **依赖导入建议**：
  - `bisection-key.core` 负责生成基本 Key。
  - `bisection-key.util` 负责处理 Map 结构的增删改查。
- **空判断**：在对空列表进行 `key-before` 或 `key-after` 操作前，务必检查字典是否为空，或者直接使用 `mid-id` 初始化。
