/* Purenista M - art checkup offline model cache */
const ART_MODEL_CACHE = 'purenista-art-models-v1';
const MODEL_URL_PREFIXES = [
  'https://huggingface.co/onnx-community/anime-seg-ONNX/resolve/'
];

self.addEventListener('install', event => {
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  const url = event.request.url;
  if (!MODEL_URL_PREFIXES.some(prefix => url.startsWith(prefix))) return;
  event.respondWith((async () => {
    const cache = await caches.open(ART_MODEL_CACHE);
    const hit = await cache.match(event.request, {ignoreVary: true}) || await cache.match(url, {ignoreVary: true});
    if (hit) return hit;
    const response = await fetch(event.request);
    if (response && response.ok) {
      try { await cache.put(url, response.clone()); } catch (_) {}
    }
    return response;
  })());
});
