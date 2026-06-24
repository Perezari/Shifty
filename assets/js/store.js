/* ============================================================
   Shifty — data store (localStorage)
   Exposes window.Shifty.store
   ============================================================ */
(function () {
  const Shifty = (window.Shifty = window.Shifty || {});

  const K_SETTINGS = "shifty.settings.v1";
  const K_SHIFTS = "shifty.shifts.v1";

  const DEFAULT_SETTINGS = {
    appName: "Shifty",
    workplaceName: "מקום העבודה שלי",
    currency: "₪",
    theme: "light",                 // "light" | "dark"

    hourlyWage: 50,                 // ₪ per hour
    regularDailyHours: 9.6,         // fallback daily standard (decimal hours) when a day has none set
    // standard ("תקן") hours per weekday, decimal; Sun..Sat. null = day off (falls back to regularDailyHours).
    // this is BOTH the overtime threshold for that day AND the daily ring goal.
    standardByDay: [9.6, 9.6, 9.6, 9.6, 8.6, null, null],
    overtime1Hours: 2,              // first OT tier span (hours)
    overtime1Mult: 1.25,            // 125%
    overtime2Mult: 1.5,             // 150% beyond

    nightEnabled: false,
    nightStart: 22,                 // hour (0-23)
    nightEnd: 6,                    // hour (0-23)
    nightMult: 1.0,                 // premium multiplier on night hours

    holidayMult: 1.5,               // whole-shift multiplier when marked holiday

    holidaysEnabled: true,          // auto-detect Israeli holidays
    holidayEveHours: 4.1,           // standard hours on a shortened day (erev chag / Yom HaZikaron) = 4:06

    autoBreakMinutes: 0,            // auto-deducted break per shift
    autoBreakAfterHours: 6,         // only if gross shift >= this

    travelPerDay: 0,                // reimbursement per worked day
    travelMonthlyCap: 0,            // 0 = no cap

    monthlyIncomeGoal: 0,           // 0 = off
    monthStartDay: 1,               // billing cycle start (1-28)
    weekStartsOn: 0,                // 0 = Sunday
  };

  function load(key, fallback) {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return fallback;
      return JSON.parse(raw);
    } catch (e) {
      return fallback;
    }
  }
  function save(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch (e) {}
  }

  // fired after a LOCAL mutation (not when applying remote) so the cloud layer can push
  let onChange = null;
  function setOnChange(fn) { onChange = fn; }
  function fireChange() { if (onChange) { try { onChange(); } catch (e) {} } }

  function getSettings() {
    const s = Object.assign({}, DEFAULT_SETTINGS, load(K_SETTINGS, {}));
    // migrate older settings that predate the per-weekday standard hours
    if (!Array.isArray(s.standardByDay)) {
      const base = s.regularDailyHours || 8.6;
      s.standardByDay = [base, base, base, base, base, null, null];
    }
    return s;
  }
  function setSettings(patch) {
    const next = Object.assign(getSettings(), patch);
    next.updatedAt = new Date().toISOString();
    save(K_SETTINGS, next);
    fireChange();
    return next;
  }
  // apply settings coming from the cloud (preserve remote updatedAt, no push)
  function applyRemoteSettings(data, updatedAt) {
    const next = Object.assign({}, DEFAULT_SETTINGS, data || {});
    next.updatedAt = updatedAt || next.updatedAt;
    save(K_SETTINGS, next);
  }

  function loadShifts() { return load(K_SHIFTS, []); }
  function saveShifts(arr) { save(K_SHIFTS, arr); }
  // UI-facing: non-deleted shifts, newest first
  function getShifts() {
    return loadShifts().filter((s) => !s.deleted).sort((a, b) => new Date(b.start) - new Date(a.start));
  }
  // sync-facing: every record including soft-deleted tombstones
  function getAllRaw() { return loadShifts(); }

  function uid() {
    return "s" + Date.now().toString(36) + Math.floor(performance.now() % 1000).toString(36);
  }

  function getShift(id) { return getShifts().find((s) => s.id === id) || null; }

  // the open shift (end === null), if any
  function getActive() {
    return getShifts().find((s) => !s.end) || null;
  }

  function upsertShift(shift) {
    shift.updatedAt = new Date().toISOString();
    const arr = loadShifts();
    const i = arr.findIndex((s) => s.id === shift.id);
    if (i >= 0) arr[i] = shift; else arr.push(shift);
    saveShifts(arr);
    fireChange();
    return shift;
  }
  // soft delete: keep a tombstone so the deletion syncs to other devices
  function deleteShift(id) {
    const arr = loadShifts();
    const i = arr.findIndex((s) => s.id === id);
    if (i >= 0) {
      arr[i].deleted = true;
      arr[i].updatedAt = new Date().toISOString();
      saveShifts(arr);
      fireChange();
    }
  }
  // merge cloud records into local (caller passes records that should win; no push)
  function applyRemoteShifts(list) {
    const map = new Map(loadShifts().map((s) => [s.id, s]));
    for (const r of list) map.set(r.id, r);
    saveShifts(Array.from(map.values()));
  }

  // ---- shift lifecycle ----
  function startShift(at) {
    if (getActive()) return getActive();
    const s = {
      id: uid(),
      start: new Date(at || Date.now()).toISOString(),
      end: null,
      breaks: [],
      isHoliday: false,
      note: "",
    };
    upsertShift(s);
    return s;
  }
  function endShift(at) {
    const s = getActive();
    if (!s) return null;
    // close an open break first
    const ob = s.breaks.find((b) => !b.end);
    const stamp = new Date(at || Date.now()).toISOString();
    if (ob) ob.end = stamp;
    s.end = stamp;
    upsertShift(s);
    return s;
  }
  function startBreak(at) {
    const s = getActive();
    if (!s) return null;
    if (s.breaks.some((b) => !b.end)) return s; // already on break
    s.breaks.push({ start: new Date(at || Date.now()).toISOString(), end: null });
    upsertShift(s);
    return s;
  }
  function endBreak(at) {
    const s = getActive();
    if (!s) return null;
    const ob = s.breaks.find((b) => !b.end);
    if (ob) ob.end = new Date(at || Date.now()).toISOString();
    upsertShift(s);
    return s;
  }
  function activeBreak(shift) {
    return shift ? shift.breaks.find((b) => !b.end) || null : null;
  }

  // ---- export / import ----
  function exportAll() {
    return JSON.stringify({ settings: getSettings(), shifts: getShifts(), exportedAt: new Date().toISOString() }, null, 2);
  }
  function importAll(json) {
    const data = typeof json === "string" ? JSON.parse(json) : json;
    if (data.settings) save(K_SETTINGS, Object.assign({}, DEFAULT_SETTINGS, data.settings));
    if (Array.isArray(data.shifts)) saveShifts(data.shifts);
  }
  function clearAll() {
    localStorage.removeItem(K_SHIFTS);
  }

  Shifty.store = {
    DEFAULT_SETTINGS,
    getSettings, setSettings, applyRemoteSettings,
    getShifts, getAllRaw, getShift, getActive, upsertShift, deleteShift, applyRemoteShifts, uid,
    startShift, endShift, startBreak, endBreak, activeBreak,
    exportAll, importAll, clearAll, setOnChange,
  };
})();
