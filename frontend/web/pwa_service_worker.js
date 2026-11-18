const CACHE_NAME = 'business-manager-shell-v1';

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.add(new URL('./', self.registration.scope));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const cacheNames = await caches.keys();
      await Promise.all(
        cacheNames
          .filter(
            (cacheName) =>
              cacheName.startsWith('business-manager-shell-') &&
              cacheName !== CACHE_NAME,
          )
          .map((cacheName) => caches.delete(cacheName)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const requestUrl = new URL(request.url);
  if (
    request.method !== 'GET' ||
    requestUrl.origin !== self.location.origin ||
    requestUrl.pathname.includes('/api/')
  ) {
    return;
  }

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        const response = await fetch(request);
        if (response.ok && response.type === 'basic') {
          await cache.put(request, response.clone());
        }
        return response;
      } catch (error) {
        const cachedResponse = await cache.match(request);
        if (cachedResponse) return cachedResponse;
        if (request.mode === 'navigate') {
          const appShell = await cache.match(
            new URL('./', self.registration.scope),
          );
          if (appShell) return appShell;
        }
        throw error;
      }
    })(),
  );
});
