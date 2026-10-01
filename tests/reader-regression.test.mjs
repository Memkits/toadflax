import assert from "node:assert/strict";
import { test } from "node:test";
import * as c from "../js-out/calcit.core.mjs";
import * as app from "../js-out/app.comp.container.mjs";
import { store } from "../js-out/app.schema.mjs";
import { updater } from "../js-out/app.updater.mjs";
import { new_reel } from "../js-out/reel.typed.mjs";
import { make_string } from "../js-out/respo.render.html.mjs";
import { comp_md_block } from "../js-out/respo-md.comp.md.mjs";
const t = c.init_tags(["store", "router", "states", "chapters", "current-chapter-id", "title", "summary", "content", "id", "settings", "update-chapter", "delete-chapter", "data", "answer"]);
const map = (...pairs) => c._$n__$M_(...pairs.flat());
const read = (value, key) => c._$n_map_$o_get(value, t[key]);
const op = (key, ...args) => c._$o__$o_(t[key], ...args);
const chapter = (id) => map(t.id, id, t.title, `Title ${id}`, t.summary, "Summary", t.content, "Body");

test("missing and null chapter selection returns none rather than raw nil", () => {
  const chapters = map("T", chapter("T"));
  assert.equal(c.option_$o_unwrap_or(app.get_current_chapter(chapters, null), null), null);
  assert.equal(c.option_$o_unwrap_or(app.get_current_chapter(chapters, "missing"), null), null);
  assert.equal(read(c.option_$o_unwrap(app.get_current_chapter(chapters, "T")), "id"), "T");
});
test("actual initial container renders with a typed Reel and no chapter selected", () => {
  const root = new_reel(store);
  assert.ok(make_string(app.comp_container(root)).length > 100);
});
test("selected chapter and real Markdown block output remain renderable", () => {
  const before = c.assoc(c.assoc(store, t.chapters, map("T", chapter("T"))), t["current-chapter-id"], "T");
  const html = make_string(app.comp_container(new_reel(before)));
  assert.ok(html.includes("Title T"));
  assert.ok(html.includes("Body"));
  const messages = app.append_user_message(c._$L_(), "**Fixture** message");
  assert.equal(c._$n_list_$o_count(messages), 1);
  assert.ok(make_string(comp_md_block("**Fixture** message", map())).includes("Fixture"));
});
test("chapter sorting unwraps pair Options and preserves lexical order", () => {
  const chapters = map("z", chapter("z"), "A", chapter("A"), "T", chapter("T"));
  const sorted = app.get_sorted_chapters(chapters);
  assert.deepEqual([0, 1, 2].map((i) => read(c.option_$o_unwrap(c.nth(sorted, i)), "id")), ["A", "T", "z"]);
});
test("single Enum updates and deletion preserve other chapters and immutable old store", () => {
  const chapters = map("A", chapter("A"), "T", chapter("T"));
  const before = c.assoc(store, t.chapters, chapters);
  const changed = updater(before, op("update-chapter", "A", map(t.content, "Changed")), "op", 0);
  assert.equal(read(read(changed, "chapters").get("A"), "content"), "Changed");
  assert.equal(read(chapters.get("A"), "content"), "Body");
  const deleted = updater(changed, op("delete-chapter", "A"), "op2", 0);
  assert.equal(read(deleted, "chapters").contains("A"), false);
  assert.equal(read(read(deleted, "chapters").get("T"), "content"), "Body");
});
test("whole-store state operation retains chapters and router", () => {
  const before = c.assoc(store, t.router, t.settings);
  const next = updater(before, op("states", c._$L_("editor"), map(t.answer, "saved")), "op", 0);
  assert.equal(read(next, "router"), t.settings);
  assert.equal(read(next, "chapters"), read(before, "chapters"));
  assert.equal(read(read(read(next, "states").get("editor"), "data"), "answer"), "saved");
});
