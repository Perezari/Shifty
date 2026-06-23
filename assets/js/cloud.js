/* ============================================================
   Shifty — optional cloud sync (Supabase)
   Local-first stays the source of truth; this is an additive layer.
   Exposes window.Shifty.cloud
   ============================================================ */
(function () {
  const Shifty = (window.Shifty = window.Shifty || {});
  const store = Shifty.store;

  // public, embeddable keys (RLS protects the data)
  const SUPABASE_URL = "https://btspqotfbejauwpfhayj.supabase.co";
  const SUPABASE_KEY = "sb_publishable_IVqM6u55E9ZqIaHCohyzlw_1ZW2ONRu";
  const K_LAST = "shifty.lastSync.v1";

  let client = null;
  let session = null;
  let pushTimer = null;

  const cloud = {
    onStatus: null,                 // sync status changed (in-place card update)
    onAuth: null,                   // signed in/out (settings card structure)
    onData: null,                   // remote data applied (refresh data view)
    status: "idle",                 // idle | syncing | error
    error: "",
  };

  function nowISO() { return new Date().toISOString(); }
  function available() { return !!client; }
  function isSignedIn() { return !!session; }
  function userEmail() { return session && session.user ? session.user.email : null; }
  function lastSync() { try { return localStorage.getItem(K_LAST); } catch (e) { return null; } }
  function setLastSync(v) { try { localStorage.setItem(K_LAST, v); } catch (e) {} }
  // status changes (syncing/idle/error) update only the small status card, never a full re-render
  function fireStatus() { if (cloud.onStatus) { try { cloud.onStatus(); } catch (e) {} } }
  // auth changes (signed in/out) — settings card structure changes
  function fireAuth() { if (cloud.onAuth) { try { cloud.onAuth(); } catch (e) {} } }
  // remote data was actually applied — the visible data view should refresh
  function fireData() { if (cloud.onData) { try { cloud.onData(); } catch (e) {} } }
  function setStatus(s, err) { cloud.status = s; cloud.error = err || ""; fireStatus(); }

  /* ---------- record mapping (app shape <-> db shape) ---------- */
  function remoteToLocal(r) {
    return {
      id: r.id, start: r.start_at, end: r.end_at,
      breaks: r.breaks || [], isHoliday: !!r.is_holiday,
      note: r.note || "", deleted: !!r.deleted, updatedAt: r.updated_at,
    };
  }
  function localToRemote(s, uid) {
    return {
      id: s.id, user_id: uid, start_at: s.start, end_at: s.end || null,
      breaks: s.breaks || [], is_holiday: !!s.isHoliday, note: s.note || "",
      deleted: !!s.deleted, updated_at: s.updatedAt || nowISO(),
    };
  }
  function settingsForCloud(s) { const c = Object.assign({}, s); delete c.updatedAt; return c; }

  /* ---------- the merge (bidirectional, last-write-wins) ---------- */
  async function syncNow() {
    if (!client || !session) return;
    setStatus("syncing");
    try {
      const uid = session.user.id;

      const { data: remoteShifts, error: e1 } = await client.from("shifts").select("*");
      if (e1) throw e1;
      const { data: remoteSettings, error: e2 } = await client
        .from("settings").select("*").eq("user_id", uid).maybeSingle();
      if (e2) throw e2;

      // ---- shifts ----
      const local = store.getAllRaw();
      const lMap = new Map(local.map((s) => [s.id, s]));
      const rMap = new Map((remoteShifts || []).map((r) => [r.id, r]));
      const applyLocal = [], pushRemote = [];
      const ids = new Set([...lMap.keys(), ...rMap.keys()]);
      for (const id of ids) {
        const L = lMap.get(id), R = rMap.get(id);
        const lt = L ? new Date(L.updatedAt || 0).getTime() : -1;
        const rt = R ? new Date(R.updated_at || 0).getTime() : -1;
        if (L && R) { if (lt > rt) pushRemote.push(L); else if (rt > lt) applyLocal.push(remoteToLocal(R)); }
        else if (L) pushRemote.push(L);
        else if (R) applyLocal.push(remoteToLocal(R));
      }
      let dataChanged = false;
      if (applyLocal.length) { store.applyRemoteShifts(applyLocal); dataChanged = true; }
      if (pushRemote.length) {
        const { error } = await client.from("shifts").upsert(pushRemote.map((s) => localToRemote(s, uid)));
        if (error) throw error;
      }

      // ---- settings (single row per user) ----
      const ls = store.getSettings();
      const lst = ls.updatedAt ? new Date(ls.updatedAt).getTime() : 0;
      const rst = remoteSettings ? new Date(remoteSettings.updated_at).getTime() : -1;
      if (remoteSettings && rst > lst) {
        store.applyRemoteSettings(remoteSettings.data, remoteSettings.updated_at);
        dataChanged = true;
      } else {
        const { error } = await client.from("settings").upsert({
          user_id: uid, data: settingsForCloud(ls), updated_at: ls.updatedAt || nowISO(),
        });
        if (error) throw error;
      }

      setLastSync(nowISO());
      setStatus("idle");
      if (dataChanged) fireData(); // only refresh the data view when remote actually changed something
    } catch (err) {
      setStatus("error", (err && err.message) || "שגיאת סנכרון");
    }
  }

  function schedulePush() {
    if (!session) return;
    clearTimeout(pushTimer);
    pushTimer = setTimeout(syncNow, 1800); // coalesce rapid local edits
  }

  /* ---------- auth (Google OAuth, PKCE) ---------- */
  function appUrl() { return window.location.origin + window.location.pathname; }
  async function signInWithGoogle() {
    if (!client) throw new Error("הסנכרון אינו זמין");
    // navigates the current window to Google and back to the app (PWA-friendly)
    const { error } = await client.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: appUrl() },
    });
    if (error) throw error;
  }
  async function signOut() {
    if (client) await client.auth.signOut();
    session = null;
    fireAuth();
  }

  /* ---------- boot ---------- */
  async function init() {
    if (!window.supabase || !window.supabase.createClient) return; // offline / lib not loaded
    try {
      client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: "pkce" },
      });
    } catch (e) { client = null; return; }

    // local edits → debounced push
    store.setOnChange(schedulePush);

    const { data } = await client.auth.getSession();
    session = data ? data.session : null;

    client.auth.onAuthStateChange((event, sess) => {
      const wasSignedIn = !!session;
      session = sess;
      // only refresh the settings card on real sign-in/out transitions, not on token refresh
      if (wasSignedIn !== !!sess || event === "SIGNED_IN" || event === "SIGNED_OUT") fireAuth();
      if (event === "SIGNED_IN") syncNow();
    });

    // re-sync when returning to the app (cheap multi-device freshness)
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden && session) syncNow();
    });

    if (session) syncNow();
    fireAuth();
  }

  Object.assign(cloud, {
    init, available, isSignedIn, userEmail, lastSync,
    signInWithGoogle, signOut, syncNow,
  });
  Shifty.cloud = cloud;
})();
