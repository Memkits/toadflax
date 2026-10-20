import assert from "node:assert/strict";
import { test } from "node:test";
import * as c from "../js-out/calcit.core.mjs";
import * as app from "../js-out/app.comp.container.mjs";
import { store, normalize_chapter, normalize_store, normalize_message_box_state, normalize_chat_state, decode_op } from "../js-out/app.schema.mjs";
import { updater } from "../js-out/app.updater.mjs";
import { new_reel } from "../js-out/reel.typed.mjs";
import { make_string } from "../js-out/respo.render.html.mjs";
import { comp_md_block } from "../js-out/respo-md.comp.md.mjs";
const t = c.init_tags(["store", "router", "states", "chapters", "current-chapter-id", "title", "summary", "content", "id", "settings", "update-chapter", "delete-chapter", "data", "answer"]);
const map = (...pairs) => c._$n__$M_(...pairs.flat());
const read = (value, key) => c.option_$o_unwrap(c.get(value, t[key] ?? c.init_tags([key])[key]));
const op = (key, ...args) => decode_op(c._$o__$o_(t[key], ...args));
const chapter = (id) => normalize_chapter(map(t.id, id, t.title, `Title ${id}`, t.summary, "Summary", t.content, "Body"), id);

test("missing and null chapter selection returns none rather than raw nil", () => {
  const chapters = map("T", chapter("T"));
  const restored = normalize_store(map(t["current-chapter-id"], null));
  assert.equal(c.option_$o_unwrap_or(app.get_current_chapter(chapters, read(restored, "current-chapter-id")), null), null);
  assert.equal(c.option_$o_unwrap_or(app.get_current_chapter(chapters, c._PCT_some("missing")), null), null);
  assert.equal(c.option_$o_unwrap(read(c.option_$o_unwrap(app.get_current_chapter(chapters, c._PCT_some("T"))), "id")), "T");
});
test("actual initial container renders with a typed Reel and no chapter selected", () => {
  const root = new_reel(store);
  assert.ok(make_string(app.comp_container(root)).length > 100);
});
test("selected chapter and real Markdown block output remain renderable", () => {
  const before = c.assoc(c.assoc(store, t.chapters, map("T", chapter("T"))), t["current-chapter-id"], c._PCT_some("T"));
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
  assert.deepEqual([0, 1, 2].map((i) => c.option_$o_unwrap(read(c.option_$o_unwrap(c.nth(sorted, i)), "id"))), ["A", "T", "z"]);
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

test("fill-text checks input and preserves explicit submit false", () => {
  const tags = c.init_tags(["handler", "fill-text", "text", "submit?"]);
  const submits = [];
  const updates = [];
  const listener = app.on_fill(c._$L_(), normalize_message_box_state(null), (...args) => { submits.push(args); });
  const handler = c.option_$o_unwrap(c.get(listener, tags.handler));
  const send = (info) => handler(c._$o__$o_(tags["fill-text"], info), (value) => { updates.push(value); });
  send(map(tags.text, "合成文本 🐈", tags["submit?"], false));
  assert.equal(updates.length, 1);
  assert.equal(submits.length, 0);
  send(map(tags.text, "default submit"));
  assert.equal(submits.length, 1);
  assert.deepEqual(submits[0].slice(0, 3), ["default submit", false, false]);
  assert.throws(() => send(map(tags.text, 42)), /string/i);
  assert.equal(updates.length, 2);
});

test("SDK interaction outputs become checked text and tool records", () => {
  const result = app.extract_interaction_outputs({
    id: "offline-interaction",
    outputs: [
      { type: "text", text: "合成回复 🐈" },
      { type: "function_call", id: "call-1", name: "get-chapter", arguments: { chapterId: "T" } },
      { type: "thought", text: "not answer text" },
    ],
  });
  assert.equal(read(result, "text"), "合成回复 🐈");
  assert.equal(read(result, "interaction-id"), "offline-interaction");
  const calls = read(result, "function-calls");
  assert.equal(c._$n_list_$o_count(calls), 1);
  const call = c.option_$o_unwrap(c.first(calls));
  assert.equal(read(call, "name"), "get-chapter");
  assert.equal(read(read(call, "arguments"), "chapterId"), "T");
  assert.equal(read(app.extract_interaction_outputs({ id: "empty" }), "text"), "");
  assert.throws(() => app.extract_interaction_outputs({ id: 42 }), /string/i);
  assert.throws(() => app.extract_interaction_outputs({ id: "bad", outputs: [{ type: "function_call", id: "x", name: "x", arguments: 42 }] }), /map/i);
});

test("chapter tools accept SDK objects and JSON strings without mutating old chapters", () => {
  const chapters = map("A", chapter("A"), "T", chapter("T"));
  const config = read(store, "novel-config");
  const updates = [];
  const dispatch = (value) => { updates.push(value); };
  const get = app.handle_chapter_tool_call("get-chapter", { chapter_id: "T" }, chapters, dispatch, config);
  assert.equal(read(get, "ok?"), true);
  assert.equal(read(read(get, "chapter"), "title"), "Title T");
  app.handle_chapter_tool_call("update-chapter-meta", JSON.stringify({ chapterId: "T", summary: "新概要" }), chapters, dispatch, config);
  assert.equal(updates.length, 1);
  const changed = updater(c.assoc(store, t.chapters, chapters), decode_op(updates[0]), "tool", 0);
  assert.equal(read(read(changed, "chapters").get("T"), "summary"), "新概要");
  assert.equal(read(read(changed, "chapters").get("T"), "title"), "Title T");
  assert.equal(read(chapters.get("T"), "summary"), "Summary");
  assert.throws(() => app.handle_chapter_tool_call("update-chapter-content", { chapterId: "T", content: 42 }, chapters, dispatch, config), /string/i);
  assert.equal(updates.length, 1);
});

test("actual async SDK entry accepts an offline client and finishes after loading", async () => {
  const oldClient = c.deref(app._$s_gen_ai_new);
  const requests = [];
  const updates = [];
  const interactions = {
    async create(request) {
      assert.equal(this, interactions);
      requests.push(request);
      return { id: "offline-final", outputs: [{ type: "text", text: "离线完成 🐈" }] };
    },
    async get() { throw new Error("Unexpected interaction lookup for a text-only response"); },
  };
  c.reset_$x_(app._$s_gen_ai_new, { interactions });
  try {
    await app.call_genai_msg_v2_$x_(
      c.init_tags(["gemini"]).gemini, c._$L_(), read(store, "chapters"), read(store, "novel-config"),
      normalize_chat_state(null), "offline prompt", false, false, null,
      (value) => { updates.push(decode_op(value)); }, c.ref(""), c.ref(""), c._PCT_none(),
    );
    assert.equal(requests.length, 1);
    assert.equal(typeof requests[0].model, "string");
    assert.ok(JSON.stringify(requests[0]).includes("offline prompt"));
    let next = store;
    const loading = [];
    for (const update of updates) {
      next = updater(next, update, "offline-sdk", 0);
      loading.push(read(read(read(next, "states"), "data"), "loading?"));
    }
    assert.deepEqual(loading, [true, false]);
    const state = read(read(next, "states"), "data");
    assert.equal(read(state, "done?"), true);
    assert.equal(c.option_$o_unwrap(read(state, "answer")), "离线完成 🐈");
    assert.equal(c.option_$o_unwrap(read(state, "interaction-id")), "offline-final");
  } finally {
    c.reset_$x_(app._$s_gen_ai_new, oldClient);
  }
});

test("offline agent tool round preserves the chapter mutation and final answer", async () => {
  const oldClient = c.deref(app._$s_gen_ai_new);
  const pending = { id: "offline-tool", outputs: [{ type: "function_call", id: "call-create", name: "create-chapter", arguments: { title: "离线章节", summary: "合成概要" } }] };
  const final = { id: "offline-tool-final", outputs: [{ type: "text", text: "章节已创建" }] };
  const requests = [];
  const lookups = [];
  let next = store;
  c.reset_$x_(app._$s_gen_ai_new, {
    interactions: {
      async create(request) { requests.push(request); return requests.length === 1 ? pending : final; },
      async get(id) { lookups.push(id); return id === pending.id ? pending : final; },
    },
  });
  try {
    await app.call_genai_msg_v2_$x_(
      c.init_tags(["gemini"]).gemini, c._$L_(), read(store, "chapters"), read(store, "novel-config"),
      normalize_chat_state(null), "offline tool prompt", false, false, null,
      (value) => { next = updater(next, decode_op(value), "offline-tool", 0); }, c.ref(""), c.ref(""), c._PCT_none(),
    );
    assert.equal(requests.length, 2);
    assert.equal(requests[1].previous_interaction_id, pending.id);
    assert.equal(requests[1].input[0].call_id, "call-create");
    assert.deepEqual(lookups, [pending.id, final.id]);
    assert.equal(c.count(read(next, "chapters")), 1);
    const state = read(read(next, "states"), "data");
    assert.equal(read(state, "loading?"), false);
    assert.equal(read(state, "done?"), true);
    assert.equal(c.option_$o_unwrap(read(state, "answer")), "章节已创建");
  } finally {
    c.reset_$x_(app._$s_gen_ai_new, oldClient);
  }
});
