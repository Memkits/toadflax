// Listen for messages
chrome.runtime.onMessage.addListener(function (msg, sender, sendResponse) {
  // If the received message has the expected format...
  console.log("[Side Message] msg", msg);
  if (msg.get === "selected") {
    // Call the specified callback, passing
    // the web-page's DOM content as argument
    sendResponse(getSelectedText());
    return;
  }
  if (msg.action === "fill-text") {
    insertTextAtCursor(String(msg.text || ""));
  }
});

let getSelectedText = () => {
  if (window.getSelection) {
    // 标准浏览器
    return window.getSelection().toString();
  } else if (document.selection) {
    // IE 浏览器
    return document.selection.createRange().text;
  } else {
    return "<未获取到内容>";
  }
};

console.log("[Side Message] prepared content script");

function insertTextAtCursor(text) {
  try {
    const active = document.activeElement;
    if (!active) return;

    if (active.tagName === "INPUT" || active.tagName === "TEXTAREA") {
      const input = active;
      if (input.readOnly || input.disabled) return;
      const start = input.selectionStart ?? input.value.length;
      const end = input.selectionEnd ?? input.value.length;
      input.setRangeText(text, start, end, "end");
      input.dispatchEvent(new Event("input", { bubbles: true }));
      return;
    }

    if (active.isContentEditable) {
      const sel = window.getSelection();
      if (!sel || sel.rangeCount === 0) return;
      const range = sel.getRangeAt(0);
      if (!active.contains(range.commonAncestorContainer)) return;
      range.deleteContents();
      const textNode = document.createTextNode(text);
      range.insertNode(textNode);
      range.setStartAfter(textNode);
      range.setEndAfter(textNode);
      sel.removeAllRanges();
      sel.addRange(range);
    }
  } catch (err) {
    console.error("[Side Message] failed to insert text", err);
  }
}
