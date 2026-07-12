/* ============================================================
   Shifty — app lock (PIN + Face ID)
   A device-local gate: the PIN hash and the WebAuthn credential id
   live in this device's localStorage only — each device sets up its
   own lock. The biometric unlock is a platform-authenticator check
   (Shifty has no backend to verify assertions; cloud data is guarded
   separately by Supabase auth + RLS).
   ============================================================ */
(function () {
  "use strict";
  const Shifty = (window.Shifty = window.Shifty || {});

  const KEY = "shifty.lock.v1";
  const PIN_LEN = 4;
  const RELOCK_MS = 60 * 1000; // relock when backgrounded longer than this

  function cfg() { try { return JSON.parse(localStorage.getItem(KEY)) || null; } catch (e) { return null; } }
  function save(c) { if (c) localStorage.setItem(KEY, JSON.stringify(c)); else localStorage.removeItem(KEY); }
  function haptic(ms) { try { navigator.vibrate && navigator.vibrate(ms || 8); } catch (e) {} }

  /* ---------- hashing ---------- */
  // SHA-256 in secure contexts; FNV-style fallback elsewhere (still just a
  // UI gate — a 4-digit code is not meant to survive an offline attack).
  async function hashPin(salt, pin) {
    const msg = salt + ":" + pin;
    if (window.crypto && crypto.subtle) {
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(msg));
      return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
    }
    let h1 = 0x811c9dc5, h2 = 0xcbf29ce4;
    for (let i = 0; i < msg.length; i++) {
      h1 = Math.imul(h1 ^ msg.charCodeAt(i), 0x01000193) >>> 0;
      h2 = Math.imul(h2 ^ msg.charCodeAt(i), 0x85ebca6b) >>> 0;
    }
    return h1.toString(16) + "-" + h2.toString(16);
  }
  function randHex(n) {
    const a = new Uint8Array(n);
    crypto.getRandomValues(a);
    return Array.from(a).map((b) => b.toString(16).padStart(2, "0")).join("");
  }

  /* ---------- WebAuthn (Face ID / fingerprint) ---------- */
  function b64u(buf) {
    return btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  function unb64u(s) {
    s = s.replace(/-/g, "+").replace(/_/g, "/");
    const bin = atob(s);
    const a = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) a[i] = bin.charCodeAt(i);
    return a.buffer;
  }

  let bioOk = false;
  if (window.PublicKeyCredential && PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
    PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().then((v) => {
      bioOk = !!v;
      // the lock screen may already be up (detection is async) — repaint so
      // the Face ID key shows right away, not only after the first keypress
      if (overlay && !overlay.hidden) paint();
    }).catch(() => {});
  }

  async function enrollBio() {
    const c = cfg();
    if (!c) return false;
    try {
      const cred = await navigator.credentials.create({
        publicKey: {
          challenge: crypto.getRandomValues(new Uint8Array(32)),
          rp: { name: "Shifty" },
          user: { id: crypto.getRandomValues(new Uint8Array(16)), name: "Shifty", displayName: "Shifty" },
          pubKeyCredParams: [{ type: "public-key", alg: -7 }, { type: "public-key", alg: -257 }],
          authenticatorSelection: { authenticatorAttachment: "platform", userVerification: "required" },
          timeout: 60000,
          attestation: "none",
        },
      });
      if (!cred) return false;
      c.credId = b64u(cred.rawId);
      save(c);
      return true;
    } catch (e) { return false; }
  }

  async function tryBio() {
    const c = cfg();
    if (!c || !c.credId) return false;
    try {
      const cred = await navigator.credentials.get({
        publicKey: {
          challenge: crypto.getRandomValues(new Uint8Array(32)),
          allowCredentials: [{ type: "public-key", id: unb64u(c.credId), transports: ["internal"] }],
          userVerification: "required",
          timeout: 60000,
        },
      });
      return !!cred;
    } catch (e) { return false; }
  }

  /* ---------- overlay UI ---------- */
  const ICO_FACE = `<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 8V6.5A2.5 2.5 0 0 1 6.5 4H8M16 4h1.5A2.5 2.5 0 0 1 20 6.5V8M20 16v1.5a2.5 2.5 0 0 1-2.5 2.5H16M8 20H6.5A2.5 2.5 0 0 1 4 17.5V16" stroke-linecap="round"/><path d="M8.6 9.8v1.6M15.4 9.8v1.6M12 9.8v3.1a1 1 0 0 1-.9.9M8.8 16a4.7 4.7 0 0 0 6.4 0" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const ICO_DEL = `<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M8.2 5.5h10.3A2.5 2.5 0 0 1 21 8v8a2.5 2.5 0 0 1-2.5 2.5H8.2a2 2 0 0 1-1.5-.7L3 12l3.7-5.8a2 2 0 0 1 1.5-.7z" stroke-linejoin="round"/><path d="M11.5 9.5l5 5M16.5 9.5l-5 5" stroke-linecap="round"/></svg>`;
  const ICO_LOCK = `<svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="4.5" y="10" width="15" height="10.5" rx="3"/><path d="M8 10V7.8a4 4 0 0 1 8 0V10" stroke-linecap="round"/><circle cx="12" cy="15.2" r="1.4" fill="currentColor" stroke="none"/></svg>`;

  let overlay = null, subEl = null, dotsEl = null, bioKey = null, cancelBtn = null;
  let mode = null;       // "unlock" | "confirm" | "set1" | "set2"
  let entered = "", firstPin = "";
  let resolver = null;   // pending promise resolve for prompt flows
  let locked = false;
  let busy = false;      // ignore keys while verifying/animating

  function build() {
    if (overlay) return;
    const el = document.createElement("div");
    el.className = "lock-screen";
    el.hidden = true;
    const keys = [];
    for (let i = 1; i <= 9; i++) keys.push(`<button class="lock-key" data-k="${i}">${i}</button>`);
    keys.push(`<button class="lock-key fn" data-k="bio" aria-label="פתיחה עם Face ID">${ICO_FACE}</button>`);
    keys.push(`<button class="lock-key" data-k="0">0</button>`);
    keys.push(`<button class="lock-key fn" data-k="del" aria-label="מחיקה">${ICO_DEL}</button>`);
    el.innerHTML = `
      <div class="lock-body">
        <div class="lock-ico">${ICO_LOCK}</div>
        <div class="lock-app">Shifty</div>
        <div class="lock-sub"></div>
        <div class="lock-dots">${'<i></i>'.repeat(PIN_LEN)}</div>
        <div class="lock-pad">${keys.join("")}</div>
        <button class="lock-cancel" hidden>ביטול</button>
      </div>`;
    document.body.appendChild(el);
    overlay = el;
    subEl = el.querySelector(".lock-sub");
    dotsEl = el.querySelector(".lock-dots");
    bioKey = el.querySelector('[data-k="bio"]');
    cancelBtn = el.querySelector(".lock-cancel");

    el.querySelector(".lock-pad").addEventListener("click", (e) => {
      const btn = e.target.closest(".lock-key");
      if (!btn || busy) return;
      const k = btn.dataset.k;
      haptic(5);
      if (k === "del") { entered = entered.slice(0, -1); paint(); return; }
      if (k === "bio") { bioAttempt(); return; }
      if (entered.length >= PIN_LEN) return;
      entered += k;
      paint();
      if (entered.length === PIN_LEN) { busy = true; setTimeout(finish, 140); }
    });
    cancelBtn.onclick = () => { haptic(5); settle(false); };
  }

  function paint() {
    const dots = dotsEl.children;
    for (let i = 0; i < dots.length; i++) dots[i].classList.toggle("on", i < entered.length);
    const c = cfg();
    bioKey.style.visibility = (mode !== "set1" && mode !== "set2" && bioOk && c && c.credId) ? "visible" : "hidden";
  }

  function show(m, sub, cancellable) {
    build();
    mode = m; entered = ""; busy = false;
    subEl.textContent = sub;
    cancelBtn.hidden = !cancellable;
    paint();
    overlay.hidden = false;
  }
  function hide() {
    if (overlay) overlay.hidden = true;
    mode = null;
  }
  function settle(val) {
    const r = resolver;
    resolver = null;
    hide();
    if (r) r(val);
  }
  function shake(msg) {
    haptic(30);
    entered = "";
    if (msg) subEl.textContent = msg;
    dotsEl.classList.add("shake");
    setTimeout(() => { dotsEl.classList.remove("shake"); paint(); busy = false; }, 450);
  }

  async function finish() {
    if (mode === "set1") {
      firstPin = entered;
      show("set2", "הזן את הקוד שוב לאימות", true);
      return;
    }
    if (mode === "set2") {
      if (entered === firstPin) {
        const c = cfg() || {};
        c.salt = randHex(16);
        c.hash = await hashPin(c.salt, firstPin);
        save(c);
        settle(true);
      } else {
        mode = "set1";
        shake("הקודים לא תאמו — בחר קוד חדש");
      }
      return;
    }
    // unlock / confirm
    const c = cfg();
    const ok = c && (await hashPin(c.salt, entered)) === c.hash;
    if (!ok) { shake("קוד שגוי — נסה שוב"); return; }
    if (mode === "confirm") settle(true);
    else { locked = false; hide(); }
  }

  async function bioAttempt() {
    if (busy) return;
    busy = true;
    const ok = await tryBio();
    busy = false;
    if (!ok) return; // stay on the keypad — the PIN is the fallback
    if (mode === "confirm") settle(true);
    else { locked = false; hide(); }
  }

  /* ---------- public API ---------- */
  function isEnabled() { const c = cfg(); return !!(c && c.hash); }

  function lockNow() {
    if (!isEnabled() || mode === "set1" || mode === "set2") return;
    locked = true;
    show("unlock", "הזן קוד גישה", false);
    // one automatic Face ID attempt; if the browser blocks it (no user
    // gesture yet), the keypad's Face ID key is the manual path
    const c = cfg();
    if (bioOk && c.credId) setTimeout(bioAttempt, 350);
  }

  function promptSetPin() {
    return new Promise((res) => { resolver = res; show("set1", "בחר קוד בן 4 ספרות", true); });
  }
  function promptConfirm(sub) {
    return new Promise((res) => { resolver = res; show("confirm", sub || "הזן קוד גישה", true); });
  }

  Shifty.lock = {
    isEnabled,
    hasBio: () => { const c = cfg(); return !!(c && c.credId); },
    bioSupported: () => bioOk,
    promptSetPin,
    promptConfirm,
    enrollBio,
    removeBio: () => { const c = cfg(); if (c) { delete c.credId; save(c); } },
    disable: () => save(null),
    lockNow,
  };

  /* ---------- boot + relock ---------- */
  if (isEnabled()) lockNow();

  let hiddenAt = 0;
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    if (isEnabled() && !locked && hiddenAt && Date.now() - hiddenAt > RELOCK_MS) lockNow();
  });
})();
