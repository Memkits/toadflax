import assert from "node:assert/strict";
import { test } from "node:test";
import { checkCdnPath } from "./check-cdn-path.mjs";
const base = "https://cos-sh.tiye.me/Memkits/toadflax/pr/";
const html = `<script src="${base}assets/main.js"></script><link href="${base}assets/main.css" rel="stylesheet"><link href="https://cdn.tiye.me/favored-fonts/main-fonts.css" rel="stylesheet"><link rel="manifest" href="${base}assets/manifest.json">`;
test("generated scripts/styles/manifest use the selected base while fonts stay unchanged", () => checkCdnPath(html, base));
test("relative or production paths cannot satisfy a PR base", () => {
  assert.throws(() => checkCdnPath(html.replace(`${base}assets/main.js`, "./assets/main.js"), base));
  assert.throws(() => checkCdnPath(html.replace(`${base}assets/manifest.json`, "./assets/manifest.json"), base));
});
test("unknown external assets and repeated slashes fail", () => {
  assert.throws(() => checkCdnPath(`${html}<script src="https://unexpected.example/app.js"></script>`, base));
  assert.throws(() => checkCdnPath(html.replace("assets/main.css", "assets//main.css"), base));
});
test("commented entries and missing existing fonts cannot satisfy validation", () => {
  assert.throws(() => checkCdnPath(`<!--${html}-->`, base));
  assert.throws(() => checkCdnPath(html.replace(`<link href="https://cdn.tiye.me/favored-fonts/main-fonts.css" rel="stylesheet">`, ""), base));
});
