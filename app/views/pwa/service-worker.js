// Lean service worker: cache-first for digest-stamped assets (instant repeat
// loads), network-first for pages with an offline fallback. No HTML caching —
// puzzle content is dynamic and we don't want stale boards. Bump CACHE to purge.
const CACHE = "quartets-v1"
const OFFLINE_URL = "/offline.html"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.add(OFFLINE_URL)))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return

  const url = new URL(request.url)

  // Digest-stamped assets are immutable — serve from cache, fill on first miss.
  if (url.origin === self.location.origin && url.pathname.startsWith("/assets/")) {
    event.respondWith(
      caches.open(CACHE).then((cache) =>
        cache.match(request).then((hit) =>
          hit || fetch(request).then((response) => {
            if (response.ok) cache.put(request, response.clone())
            return response
          })
        )
      )
    )
    return
  }

  // Full-page loads: try the network, fall back to the offline page. (Turbo's own
  // fetches aren't `navigate`, so in-app navigation is untouched.)
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(OFFLINE_URL)))
  }
})
