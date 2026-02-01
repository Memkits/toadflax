# Interactions API 重构方案

## 目标

使用新的 `client.interactions.create()` API 简化 Gemini 调用逻辑，支持 Agent 模式的多轮工具调用。

## 核心改进

### 1. 消息管理简化

**之前：**

- 维护内部消息格式 `{role, content}`
- 手动转换为 Gemini 格式（messages->gemini）
- 工具调用后手动拼接 tool-contents

**之后：**

- 保留内部消息格式用于 UI 显示
- 使用 `previous_interaction_id` 让 Gemini 自动管理上下文
- 减少 50% 的消息处理代码

### 2. 工具调用流程优化

**之前：**

```cirru
;; 1. 检测 functionCall
if (some? fn-call) (reset! *tool-call fn-call)

;; 2. 执行工具
tool-result $ handle-tool-call! tool-name tool-args

;; 3. 手动构造 tool-contents
tool-contents $ -> (messages->gemini messages0)
  .concat $ js-array
    js-object (:role |model) (:parts ...)
    js-object (:role |tool) (:parts ...)

;; 4. 再次调用 generateContentStream
followup-result $ js-await (.!generateContentStream ...)
```

**之后：**

```cirru
;; 1. 检测 function_call
if (= (.-type output) |function_call)

;; 2. 执行工具
tool-result $ handle-chapter-tool-call ...

;; 3. 直接发送结果
interaction $ js-await
  .!create (.-interactions client)
    js-object
      :model model
      :previous_interaction_id $ .-id prev-interaction
      :input $ js-array
        js-object
          :type |function_result
          :name $ .-name output
          :call_id $ .-id output
          :result tool-result
```

### 3. Agent 循环执行

**新增功能：**

```cirru
defn run-agent-loop! (client model interaction-id chapters d!)
  let
      interaction $ js-await
        .!create (.-interactions client)
          js-object
            :model model
            :previous_interaction_id interaction-id
    ;; 检查是否有 function_call
    let
        function-calls $ -> (.-outputs interaction)
          .!filter $ fn (o) (= (.-type o) |function_call)
      if (> (.-length function-calls) 0)
        ;; 执行所有工具调用
        let
            results $ map function-calls
              fn (fc)
                let
                    result $ handle-chapter-tool-call ...
                  js-object
                    :type |function_result
                    :name $ .-name fc
                    :call_id $ .-id fc
                    :result result
            next-interaction $ js-await
              .!create (.-interactions client)
                js-object
                  :model model
                  :previous_interaction_id $ .-id interaction
                  :input results
          ;; 递归继续
          js-await $ run-agent-loop! client model (.-id next-interaction) chapters d!
        ;; 完成，返回最终结果
        , interaction
```

## 实施步骤

### Phase 1: API 兼容性验证

- [ ] 确认新 SDK 是否支持流式响应（streaming）
- [ ] 确认 thinking 模式支持
- [ ] 确认自定义 baseUrl 支持
- [ ] 确认 abortSignal 支持

### Phase 2: 创建新函数（不破坏现有逻辑）

- [ ] 创建 `call-genai-msg-v2!` 函数
- [ ] 实现基本的 interactions.create 调用
- [ ] 实现单轮工具调用
- [ ] 测试基本对话功能

### Phase 3: Agent 循环实现

- [ ] 创建 `run-agent-loop!` 辅助函数
- [ ] 支持多轮工具调用
- [ ] 添加最大循环次数保护（防止死循环）
- [ ] 实现进度反馈（UI 显示当前执行的工具）

### Phase 4: 流式响应集成

- [ ] 如果支持：集成流式 API
- [ ] 如果不支持：使用轮询或 chunked 方式模拟
- [ ] 保持 thinking/answer 实时更新体验

### Phase 5: 切换与清理

- [ ] 添加功能开关（允许在新旧 API 间切换）
- [ ] 全面测试各种场景
- [ ] 逐步弃用旧代码
- [ ] 删除 messages->gemini 等辅助函数

## 关键代码结构

### 新增函数列表

```
app.comp.container/
  call-genai-msg-v2!         // 主入口（使用新 API）
  run-agent-loop!            // Agent 循环执行
  handle-chapter-tool-call   // 工具调用处理（已提取）
  process-interaction-output // 处理 interaction 输出
  update-ui-with-output!     // 更新 UI 状态
```

### 数据流

```
用户输入
  ↓
call-genai-msg-v2!
  ↓
interactions.create (首次调用)
  ↓
process-interaction-output
  ├─ text output → 更新 UI
  └─ function_call → run-agent-loop!
       ↓
       handle-chapter-tool-call (执行工具)
       ↓
       interactions.create (带 function_result)
       ↓
       process-interaction-output
       └─ 如有新 function_call → 继续循环
          否则 → 返回最终结果
```

## 预期收益

1. **代码减少 40%** - 移除消息转换、手动拼接逻辑
2. **可维护性提升** - 更清晰的数据流和控制流
3. **功能增强** - 支持 Agent 模式的多轮工具调用
4. **更好的错误处理** - SDK 内置的错误处理
5. **未来扩展性** - 更容易添加新工具和功能

## 风险评估

| 风险                | 影响 | 缓解措施                   |
| ------------------- | ---- | -------------------------- |
| 新 SDK 不支持流式   | 高   | Phase 1 验证，考虑混合方案 |
| Thinking 模式不兼容 | 中   | 寻找替代方案或保留旧逻辑   |
| 性能下降            | 低   | 性能测试，优化瓶颈         |
| 迁移成本            | 中   | 渐进式迁移，保留回退能力   |

## 时间估算

- Phase 1: 1 天（API 研究 + 测试）
- Phase 2: 2 天（基础实现）
- Phase 3: 1 天（Agent 循环）
- Phase 4: 1-2 天（流式集成，取决于支持情况）
- Phase 5: 1 天（测试 + 清理）

**总计：6-7 天**
