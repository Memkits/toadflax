
Message Buffer for Gemini API
----

> Respo web page based on [calcit-js](https://github.com/calcit-lang/calcit).

Demo https://r.tiye.me/Termina/msg-buffer/ .

Docs https://ai.google.dev/gemini-api/docs/get-started/tutorial?lang=rest#text-and-image_input .

Configurations:

- `gemini-key` in localStorage
- 模型由界面选择，当前映射以 `app.comp.container/pick-model` 为准；本轮不更换模型或服务端接口。

### 迁移候选状态

本分支正在迁移到配对的正式 CLI/procs **0.30.1**；版本声明不等于源码验收或已部署。
升级需同步完整依赖图、重新生成 JS 并刷新页面。UI 0.8 的基础样式可能变化。
旧存档会在读取时转换为真实 Struct/Option；保留缺省值和章节排序，
不要求删除 localStorage。发送入口已修正配置/会话及 dispatch/配置的参数顺序。
请求前同步设置加载状态，Agent 工具结束时保留最终回答，不再被旧会话状态覆盖。

此前 alpha.5 的完整 strict workflow、存档原生回归和现有入口的 11 项 JS 测试通过，
显式 unsafe 已清零。JS 测试保留原 6 项场景，新增合成输入检查、实际异步 SDK 入口及单轮
章节工具链路。浏览器已用合成数据验证创建/切换章节、配置保存、模型菜单、历史选择和正常入口
刷新恢复；空闲时不会再显示 Loading。它们不等于真实服务验收，多工具/多轮和取消仍需审阅。
不使用真实 API key 或调用付费模型，不合并或部署生产；本轮正式图仍需独立完成全部门禁和实际验收。

本轮准备清理代码及附带测试中的旧 Option helper，Map merge 使用接收者方法，
保留原默认值和原断言。启动先成功恢复存档及首次渲染，再注册保存/watch/输入策略，
避免加载失败后离页或 visibilitychange 覆盖原值。解析失败的保护不等于全量存档结构校验。
保留真正的 `hud!` 热更新成功/错误路径，不改成 raise；不增加质量预算、永久审计脚本或测试框架。

声明依赖采用已发布正式 tag，不使用 main/hash；移除没有应用导入/调用的 Lilac，
仍保留实际使用的 Markdown、Memof、Alerts 和 Bisection Key。历史说明和模型信息以实际代码为准，
后续会随完整验收更新；历史 llms 示例不是当前命令合同。
正式图：Alerts 0.10.58、Reel 0.6.42、Feather 0.4.31、Markdown 0.4.60、UI 0.8.1、
Respo 0.16.126、Bisection Key 0.0.37、js-ffi 0.2.6、Memof 0.0.40；保留真实传递 std 0.2.43。
本轮不升级 AI SDK、不改变模型、代理地址、请求协议或取消语义；不声称多轮/取消或真实付费服务已验收。

### Workflow

https://github.com/calcit-lang/respo-calcit-workflow

使用配对的正式 Calcit/procs `0.30.1`，不要混用全局旧 CLI。安装 JS 依赖执行
`yarn install --immutable`。Calcit 模块的正式 tag 已声明在 `deps.cirru`；严格 Caps 安装及
工具链检查由独立 CI 验收，本候选尚未完成该项，不把本地复用模块当作全新安装的证据。
本地不执行 Caps（包括只读命令）或编译/检查/codegen/Snapshot mutation；只读 query/tree 视图允许，写入与完整门禁由官方 Linux 0.30.1 CI 执行。Node 24、Yarn 4.18.0、Vite 8.3.3。

Only `calcit.cirru` and `deps.cirru` are canonical; CI rejects retired
`compact.cirru` and `package.cirru`. Edit the Snapshot through the installed
Calcit CLI, following `calcit docs agents --contract` and live command help.
The older `llms/` guides retain historical examples, not current CLI signatures.

依次运行 `calcit --check-only --all-defs`、`calcit fix --workflow strict --verify`、
`calcit test app.schema/normalize-store --require-match`、`calcit js`，再执行
`node --test tests/reader-regression.test.mjs`。测试必须使用刚生成的 JS，不能复用旧版本输出。
构建执行 `VITE_BASE_URL=https://cos-sh.tiye.me/Memkits/toadflax/ yarn build`。
现有工作流已替换旧 check-public，使用全部定义检查、完整 strict 和存档回归；
本地通过不等于独立 CI 的依赖解析、构建和上传已通过。
共享字体、外部图标和原服务器部署路径未改。离线测试不调用 Gemini 或消耗 API 额度。

PR 预览路径包含 PR 编号、运行编号和重试次数，避免覆盖其他运行的资源；生产路径保持不变。上传及公开访问校验仅使用正式 COS Action 1.2.0 内置 verify，不保留重复 CDN 校验测试；各 PR/生产队列保留待运行任务，不取消正在上传的任务。

本轮包括源码和类型迁移，不只是前端发布配置。模型名称、代理服务 base URL 和原请求协议
保留；真实服务、取消和多工具链路尚未验收，不应仅凭本地测试触发生产部署。

`yarn dev` 先编译一次再启动 Vite；实时修改 Calcit 时另开终端运行 `calcit calcit.cirru js -w`，无需增加 concurrently。

### License

MIT
