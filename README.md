
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

Validate all public application namespaces and the full definition graph with
`calcit calcit.cirru --check-only --keep-going --format json`, generate with
`calcit calcit.cirru js`, then run `node --test tests/*.test.mjs`.
Build using `VITE_BASE_URL=https://cos-sh.tiye.me/Memkits/toadflax/pr/2/ yarn vite build`
with public upload verification handled by the COS Action's built-in verify
settings, without an extra CDN checker. Shared fonts, external icon and original server deployment paths are
unchanged. Tests use fixtures only and do not call Gemini or consume API credits.

### License

MIT
