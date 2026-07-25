self.postMessage(["ready", "worker online"]);

self.onmessage = event => {
  const payload = event.data;
  self.postMessage(["echo", payload]);
};
