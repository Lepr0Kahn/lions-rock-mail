self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map(k => caches.delete(k)));
      await self.registration.unregister();
      await self.clients.claim();
    } catch (_) {}
  })());
});
