export let get_selected = () => {
  return new Promise((resolve, reject) => {
    if (window.chrome?.runtime?.id == null) {
      resolve(null);
      return;
    }
    console.log("calling content script...");
    window.chrome.tabs
      .query({ active: true, currentWindow: true })
      .then((x) => {
        let activeTab = x[0];
        if (activeTab) {
          let id = activeTab.id;
          window.chrome.tabs.sendMessage(id, { get: "selected" }, function (response) {
            // 接收来自 content.js 的返回数据
            // console.info('Content script returned: ' + response);
            resolve(response);
          });
        } else {
          reject("found not active tab");
        }
      })
      .catch((error) => {
        console.error("Error", error);
      });
  });
};

//   setTimeout(()=>{
//   chrome.tabs.query({active: true, currentWindow: true}).then(x => {
//     let activeTab = x[0]
//     if (activeTab) {
//       let id = activeTab.id
//       chrome.tabs.sendMessage(id, {get: 'selected'}, function(response) {
//         // 接收来自 content.js 的返回数据
//         console.info('Content script returned: ' + response);
//       });

//     } else {
//       throw Error("no active tab found")
//     }
//   })
// }, 2000)

// chrome.scripting.executeScript({
//   target: { tabId: 1201634844 },
//   function: () => { console.log(document.body.innerText) }
// });

// chrome.tabs.sendMessage(1201634844, {get: 'selected'}, function(response) {
//   // 接收来自 content.js 的返回数据
//   console.info('Content script returned: ' + response.message);
// });
