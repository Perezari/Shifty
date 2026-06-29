/* Shifty service worker — offline app shell */
const CACHE = "shifty-v11";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./assets/css/styles.css",
  "./assets/js/format.js",
  "./assets/js/store.js",
  "./assets/js/holidays.js",
  "./assets/js/calc.js",
  "./assets/js/vendor/supabase.js",
  "./assets/js/cloud.js",
  "./assets/js/app.js",
  "./assets/icons/icon.svg",
  "./assets/fonts/heebo-hebrew.woff2",
  "./assets/fonts/heebo-latin.woff2",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  // network-first: always fresh when online, fall back to cache when offline.
  // (no build hashing here, so cache-first would serve stale app code.)
  e.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.status === 200 && res.type === "basic") {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req).then((cached) => cached || caches.match("./index.html")))
  );
});
