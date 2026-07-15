/* Shifty service worker — offline app shell */
const CACHE = "shifty-v20";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./assets/css/styles.css",
  "./assets/js/lock.js",
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

// התראות פוש — מגיעות ישירות מהענן (Supabase Edge Function), בלי תלות במחשב
self.addEventListener("push", (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) {}
  e.waitUntil(self.registration.showNotification(d.title || "Shifty", {
    body: d.message || "",
    icon: "./assets/icons/icon.svg",
    dir: "rtl",
    lang: "he",
  }));
});
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  e.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((ws) =>
    ws.length ? ws[0].focus() : clients.openWindow("./")
  ));
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  // only handle our own http(s) GETs — skip chrome-extension:, etc.
  if (req.method !== "GET" || !req.url.startsWith("http")) return;
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
