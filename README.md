
Message Buffer for Gemini API
----

> Respo web page based on [calcit-js](https://github.com/calcit-lang/calcit).

Demo https://r.tiye.me/Termina/msg-buffer/ .

Docs https://ai.google.dev/gemini-api/docs/get-started/tutorial?lang=rest#text-and-image_input .

Configurations:

- `gemini-key` in localStorage
- `?model=YOUR_MODEL`, defaults to `gemini-1.5-flash`

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
