let sidepanelOpen = false;
let pendingMessage = null;

let sendToSidepanel = (message, tabId) => {
  console.log("[Worker] Sending message to sidepanel:", message.action);
  chrome.runtime.sendMessage(message);
  if (sidepanelOpen) {
    return;
  }
  console.log(
    "[Worker] Sidepanel not marked as open, attempting to open and queueing message",
  );
  pendingMessage = message;
  chrome.sidePanel.open({ tabId });
};

chrome.runtime.onInstalled.addListener(() => {
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });

  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "msg-gemini-root",
      title: "Msg Gemini",
      type: "normal",
      contexts: ["selection"],
    });
    chrome.contextMenus.create({
      id: "msg-gemini-summary",
      title: "Summary",
      type: "normal",
      contexts: ["selection"],
      parentId: "msg-gemini-root",
    });
    chrome.contextMenus.create({
      id: "msg-gemini-translate",
      title: "Translate",
      type: "normal",
      contexts: ["selection"],
      parentId: "msg-gemini-root",
    });
    chrome.contextMenus.create({
      id: "msg-gemini-custom",
      title: "Custom...",
      type: "normal",
      contexts: ["selection"],
      parentId: "msg-gemini-root",
    });
  });
});

chrome.contextMenus.onClicked.addListener((item, tab) => {
  let content = item.selectionText;
  if (item.menuItemId === "msg-gemini-translate") {
    sendToSidepanel({ action: "menu-translate", content }, tab.id);
  } else if (item.menuItemId === "msg-gemini-custom") {
    sendToSidepanel({ action: "menu-custom", content }, tab.id);
  } else {
    sendToSidepanel({ action: "menu-summary", content }, tab.id);
  }
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message && message.action === "fill-text") {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const tab = tabs && tabs[0];
      if (tab && tab.id != null) {
        chrome.tabs.sendMessage(tab.id, {
          action: "fill-text",
          text: message.text || "",
        });
      }
    });
  }
});

// https://stackoverflow.com/a/77106777/883571
chrome.runtime.onConnect.addListener(function (port) {
  if (port.name === "mySidepanel") {
    sidepanelOpen = true;
    console.log("[Worker] Sidepanel connected.");
    if (pendingMessage) {
      console.log("[Worker] Sending pending message after connection.");
      chrome.runtime.sendMessage(pendingMessage);
      pendingMessage = null;
    }
    port.onDisconnect.addListener(async () => {
      sidepanelOpen = false;
      console.log("[Worker] Sidepanel disconnected.");
    });
  }
});
