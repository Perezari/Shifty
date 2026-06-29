/* ============================================================
   Shifty desktop widget — controller (live cloud data)
   Auth = system-browser + localhost loopback (see lib.rs begin_login).
   The cloud is the source of truth; the widget computes the live
   timer/earnings locally with the real Shifty engine, and fires a
   native notification when the daily goal is reached.
   ============================================================ */
(function () {
  const { fmt, calc, store } = window.Shifty;
  const HOUR = calc.HOUR;
  const $ = (s) => document.querySelector(s);
  const invoke = window.__TAURI__ && window.__TAURI__.core && window.__TAURI__.core.invoke;

  const SUPABASE_URL = "https://btspqotfbejauwpfhayj.supabase.co";
  const SUPABASE_KEY = "sb_publishable_IVqM6u55E9ZqIaHCohyzlw_1ZW2ONRu";
  const REDIRECT = "http://localhost:14500";

  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: "pkce" },
  });

  let session = null, active = null, settings = null, todayShifts = [];
  let notifGoalShiftId = null, notifGoalDone = false; // notify once per shift on goal crossing

  function remoteToLocal(r) {
    return { id: r.id, start: r.start_at, end: r.end_at, breaks: r.breaks || [], isHoliday: !!r.is_holiday, note: r.note || "" };
  }

  function reflectAuth() {
    $("#w-signin").style.display = session ? "none" : "flex";
    $("#w-bar").style.display = session ? "flex" : "none";
  }

  async function pull() {
    if (!session) return;
    const uid = session.user.id;
    const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0);
    try {
      const [a, t, st] = await Promise.all([
        client.from("shifts").select("*").is("end_at", null).eq("deleted", false),
        client.from("shifts").select("*").eq("deleted", false).gte("start_at", dayStart.toISOString()),
        client.from("settings").select("*").eq("user_id", uid).maybeSingle(),
      ]);
      active = (a.data && a.data.length) ? remoteToLocal(a.data[0]) : null;
      todayShifts = (t.data || []).map(remoteToLocal);
      settings = Object.assign({}, store.DEFAULT_SETTINGS, (st.data && st.data.data) || {});
      if (settings.theme) document.documentElement.setAttribute("data-theme", settings.theme);
    } catch (e) { /* keep last good state */ }
    render();
  }

  function goalReached(b, goal) {
    // initialise on a new shift (suppress notifying for a shift already past goal
    // when the widget first opens); then fire once when it actually crosses.
    if (active.id !== notifGoalShiftId) {
      notifGoalShiftId = active.id;
      notifGoalDone = b.netHours >= goal;
      return;
    }
    if (!notifGoalDone && b.netHours >= goal) {
      notifGoalDone = true;
      if (invoke) invoke("notify", {
        title: "🎯 הגעת ליעד היומי",
        body: fmt.hoursToHM(b.netHours) + " שעות · " + fmt.money(b.pay, settings.currency),
      }).catch(() => {});
    }
  }

  function render() {
    if (!settings) return;
    const now = Date.now();
    const goal = calc.standardHoursFor(now, settings);
    const set = (id, v) => { const n = $("#" + id); if (n) n.textContent = v; };
    if (active) {
      const b = calc.shiftBreakdown(active, settings, now);
      const onBreak = (active.breaks || []).some((x) => !x.end);
      $("#w-cap").classList.toggle("working", !onBreak);
      set("w-status", (onBreak ? "בהפסקה" : "במשמרת") + (settings.workplaceName ? " · " + settings.workplaceName : ""));
      set("w-time", fmt.hms(b.netMs));
      set("w-pay", fmt.money(b.pay, settings.currency));
      const projected = b.netHours > 0.001 ? b.pay * (goal / b.netHours) : null;
      set("w-proj", projected == null ? "" : "צפי " + fmt.money(projected, settings.currency));
      $("#w-fill").style.width = (Math.min(1, goal > 0 ? b.netHours / goal : 0) * 100).toFixed(1) + "%";
      set("w-foot-a", fmt.hoursToHM(b.netHours) + " ש׳");
      const startMs = new Date(active.start).getTime();
      const loggedMs = (active.breaks || []).reduce((acc, brk) =>
        acc + Math.max(0, (brk.end ? new Date(brk.end).getTime() : now) - new Date(brk.start).getTime()), 0);
      const autoMs = (settings.autoBreakMinutes || 0) * 60000;
      const finishMs = startMs + goal * HOUR + Math.max(loggedMs, autoMs);
      set("w-foot-b", b.netHours >= goal ? "הגעת ליעד ✓" : "יעד " + fmt.hoursToHM(goal) + " · סיום " + fmt.clock(finishMs));
      goalReached(b, goal);
    } else {
      notifGoalShiftId = null; // reset so the next shift can notify
      const today = calc.aggregate(todayShifts, settings, calc.dayRange(now), now);
      $("#w-cap").classList.remove("working");
      set("w-status", "מוכן להתחיל");
      set("w-time", today.netHours > 0 ? fmt.hms(today.netHours * HOUR) : "00:00:00");
      set("w-pay", fmt.money(today.total, settings.currency));
      set("w-proj", "");
      $("#w-fill").style.width = (Math.min(1, goal > 0 ? today.netHours / goal : 0) * 100).toFixed(1) + "%";
      set("w-foot-a", fmt.hoursToHM(today.netHours) + " ש׳");
      set("w-foot-b", "אין משמרת פעילה");
    }
  }

  async function signIn() {
    const btn = $("#w-signin-btn");
    btn.disabled = true; btn.textContent = "מתחבר… השלם בדפדפן";
    try {
      const { data, error } = await client.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: REDIRECT, skipBrowserRedirect: true },
      });
      if (error || !data || !data.url) throw new Error("no oauth url");
      const code = await invoke("begin_login", { url: data.url });
      const { error: exErr } = await client.auth.exchangeCodeForSession(code);
      if (exErr) throw exErr;
      const { data: sess } = await client.auth.getSession();
      session = sess ? sess.session : null;
      reflectAuth();
      await pull();
    } catch (e) {
      btn.disabled = false; btn.textContent = "נכשל — נסה שוב";
    }
  }

  function wireClose() {
    const btn = $("#w-close");
    if (!btn) return;
    btn.addEventListener("click", async () => {
      try {
        const w = window.__TAURI__ && window.__TAURI__.window;
        const cur = w && (w.getCurrentWindow ? w.getCurrentWindow() : null);
        if (cur) { await cur.close(); return; }
      } catch (e) {}
      window.close();
    });
  }

  async function init() {
    wireClose();
    $("#w-signin-btn").addEventListener("click", signIn);
    const { data } = await client.auth.getSession();
    session = data ? data.session : null;
    reflectAuth();
    if (session) await pull();
    setInterval(() => { if (session) render(); }, 1000);        // live timer (no network)
    setInterval(() => { if (session) pull(); }, 20000);          // refresh from cloud
  }

  init();
})();
