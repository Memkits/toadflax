
Message Buffer for Gemini API
----

> Respo web page based on [calcit-js](https://github.com/calcit-lang/calcit).

Demo https://r.tiye.me/Termina/msg-buffer/ .

Docs https://ai.google.dev/gemini-api/docs/get-started/tutorial?lang=rest#text-and-image_input .

Configurations:

- `gemini-key` in localStorage
- 模型由界面选择，当前映射以 `app.comp.container/pick-model` 为准；本轮不更换模型或服务端接口。

### 迁移候选状态

本分支正在迁移到配对的 CLI/procs **0.30.1-alpha.5**，不是已完成迁移或正式
0.30.1 发行版。原 0.27 基线 432 个定义检查和现有 6 项离线测试已复现；已先修正
四个发送入口的配置/会话参数顺序，以及 Agent 章节工具的 dispatch/配置参数顺序。
后续还需完整类型加强、原测试和真实 UI/离线 AI 请求合同验收，不把改版本号或单次编译当完成。
不使用真实 API key 或调用付费模型，不合并或部署生产。

声明依赖采用已发布正式 tag，不使用 main/hash；移除没有应用导入/调用的 Lilac，
仍保留实际使用的 Markdown、Memof、Alerts 和 Bisection Key。历史说明和模型信息以实际代码为准，
后续会随完整验收更新；不要把下文旧 0.27 安装说明当当前候选的命令合同。

### Workflow

https://github.com/calcit-lang/respo-calcit-workflow

Use stable Calcit/procs 0.27.0 with `caps --ci`, `yarn install --immutable`,
and `caps verify --toolchain`. Alerts/Feather use their updated compatible
releases; actually used Markdown/Memof and chapter ordering remain intact.
Strict Caps resolution still awaits Markdown's compatible UI/js-ffi release.

Only `calcit.cirru` and `deps.cirru` are canonical; CI rejects retired
`compact.cirru` and `package.cirru`. Edit the Snapshot through the installed
Calcit CLI, following `calcit docs agents --contract` and live command help.
The older `llms/` guides retain historical examples, not current CLI signatures.

Validate the entry with `calcit calcit.cirru --check-only`, and all five public
application namespaces with `calcit calcit.cirru analyze check-public --ns app.comp.container --ns app.config --ns app.main --ns app.schema --ns app.updater --summary-only --format json`.
Generate with `calcit calcit.cirru js`, then run `node --test tests/*.test.mjs`.
Build using `VITE_BASE_URL=https://cos-sh.tiye.me/Memkits/toadflax/ yarn build`
with public upload verification handled by the COS Action's built-in verify
settings, without an extra CDN checker. Shared fonts, external icon and original server deployment paths are
unchanged. Tests use fixtures only and do not call Gemini or consume API credits.

PR 预览路径包含 PR 编号、运行编号和重试次数，避免覆盖其他运行的资源；生产路径保持不变。上传及公开访问校验仅使用正式 COS Action 1.2.0 内置 verify，不保留重复 CDN 校验测试；各 PR/生产队列保留待运行任务，不取消正在上传的任务。

本次仅更新前端发布配置，Calcit/procs 仍为正式 0.27.0，不能据此认定
正式 0.28 类型迁移已完成。原测试和模型/网络请求逻辑不变。

`yarn dev` 先编译一次再启动 Vite；实时修改 Calcit 时另开终端运行 `calcit calcit.cirru js -w`，无需增加 concurrently。

### License

MIT
