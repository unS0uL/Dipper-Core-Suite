let callbackCounter = 0;
function getUniqueCallbackName(prefix) {
  return prefix + '_callback_' + Date.now() + '_' + (callbackCounter++);
}

export function exec(command, options) {
  if (typeof ksu === "undefined") {
    return Promise.reject(new Error("KernelSU/WebUI API unavailable"));
  }
  if (typeof options === "undefined") {
    options = {};
  }
  return new Promise((resolve, reject) => {
    const callbackFuncName = getUniqueCallbackName("exec");
    window[callbackFuncName] = (errno, stdout, stderr) => {
      resolve({ errno, stdout, stderr });
      delete window[callbackFuncName];
    };
    try {
      ksu.exec(command, JSON.stringify(options), callbackFuncName);
    } catch (error) {
      delete window[callbackFuncName];
      reject(error);
    }
  });
}

export function toast(message) {
  if (typeof ksu !== "undefined" && typeof ksu.toast === "function") {
    ksu.toast(message);
  } else {
    alert(message);
  }
}
