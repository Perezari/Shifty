// The cases on which the Swift engine (ios/Shifty/Core) must give the web app's results, and the web
// app's results for them: assets/js/format.js, store.js, holidays.js and calc.js run as the page loads
// them. Run in Jerusalem time (ios/scripts/check-calc.sh):
// TZ=Asia/Jerusalem node ios/Tests/calc-cases.mjs <dir>    writes <dir>/cases.json and <dir>/expected.json
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const dir = process.argv[2] || path.join(root, "ios/build/calc");
fs.mkdirSync(dir, { recursive: true });

globalThis.window = globalThis;
globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };
for (const name of ["format", "store", "holidays", "calc"]) {
  vm.runInThisContext(fs.readFileSync(path.join(root, "assets/js", name + ".js"), "utf8"), { filename: name + ".js" });
}
const { calc, holidays, fmt, store } = globalThis.Shifty;
const HOUR = calc.HOUR, MIN = 60000;

// a fixed run of random numbers (mulberry32): the same cases every time
let seed = 20261028;
function rand() {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const int = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));
const chance = (p) => rand() < p;
const pick = (list) => list[Math.floor(rand() * list.length)];

const at = (y, m, d, h = 0, mi = 0, s = 0, ms = 0) => new Date(y, m, d, h, mi, s, ms).getTime();
const iso = (ms) => new Date(ms).toISOString();
const asOf = at(2026, 9, 28, 15, 37, 12, 345);

// a moment of 2025 or 2026, now and then on a day the clocks change
const clockDays = [at(2025, 2, 28), at(2025, 9, 26), at(2026, 2, 27), at(2026, 9, 25)];
function moment() {
  if (chance(0.08)) return pick(clockDays) + int(0, 24 * 60) * MIN + int(0, 59999);
  return at(2025, 0, 1) + Math.floor(rand() * (at(2027, 0, 1) - at(2025, 0, 1)));
}

/* ---------- settings ---------- */
const D = store.DEFAULT_SETTINGS;
const settings = [
  { ...D },
  { ...D, hourlyWage: 57.3, standardByDay: [9.1, 9.1, 9.1, 9.1, 8.1, null, null], autoBreakMinutes: 30,
    autoBreakAfterHours: 6, nightEnabled: true, nightStart: 22, nightEnd: 6, nightMult: 1.25,
    travelPerDay: 22.6, travelMonthlyCap: 300, monthStartDay: 25, monthlyIncomeGoal: 12000 },
  { ...D, hourlyWage: 43.75, regularDailyHours: 0, standardByDay: [8, 0, 7.5, null, 8.25, 5, null],
    overtime1Hours: 1.5, overtime1Mult: 1.3, overtime2Mult: 1.75, nightEnabled: true, nightStart: 2.5,
    nightEnd: 7.75, nightMult: 1.5, holidaysEnabled: false, monthStartDay: 10, sickDay2Pct: 60, sickDay3Pct: 60,
    vacationHours: 9, autoBreakMinutes: 45, autoBreakAfterHours: 0, travelPerDay: 15 },
  { ...D, hourlyWage: 61, regularDailyHours: 10, standardByDay: [null, 9, 9, 9, 9, null, 6.5], nightEnabled: true,
    nightStart: 21.75, nightEnd: 5.5, nightMult: 1.35, holidayEveHours: 0, holidayMult: 2, monthStartDay: 28,
    autoBreakMinutes: 20, autoBreakAfterHours: 4.5, travelPerDay: 11.8, travelMonthlyCap: 200, sickDay4Pct: 90 },
  // a night that ends in the hour the clocks skip
  { ...D, nightEnabled: true, nightStart: 23, nightEnd: 2.5, nightMult: 1.1, holidayEveHours: 5.5,
    monthStartDay: 15, standardByDay: [7, 7, 7, 7, 7, 7, 7] },
];

/* ---------- shifts ---------- */
let next = 0;
const id = () => "t" + (next++).toString(36);
function work(start, end, extra = {}) {
  return { id: id(), start: iso(start), end: end == null ? null : iso(end), breaks: [], isHoliday: false, note: "",
    updatedAt: iso(start), ...extra };
}
function dayOff(y, m, d, type, extra = {}) {
  const noon = at(y, m, d, 12);
  return { id: id(), start: iso(noon), end: iso(noon), breaks: [], isHoliday: false, note: "", type, ...extra };
}
// the order the app keeps them in (store.getShifts)
const newestFirst = (list) => list.sort((a, b) => new Date(b.start) - new Date(a.start));

// A: two years of random days: a shift or two with breaks, Shabbat, vacation and sick days
const A = [];
for (let day = new Date(2025, 0, 1); day < new Date(2027, 0, 1); day.setDate(day.getDate() + 1)) {
  if (chance(0.3)) continue;
  const y = day.getFullYear(), m = day.getMonth(), d = day.getDate();
  const r = rand();
  if (r < 0.04) { A.push(dayOff(y, m, d, "vacation")); continue; }
  if (r < 0.1) { A.push(dayOff(y, m, d, "sick", chance(0.1) ? { deleted: true } : {})); continue; }
  let cursor = at(y, m, d, int(4, 14), int(0, 59), int(0, 59), int(0, 999));
  for (let k = chance(0.12) ? 2 : 1; k > 0; k--) {
    const start = cursor;
    const end = start + Math.round((0.25 + rand() * 13.75) * HOUR);
    const shift = work(start, end, { isHoliday: chance(0.08) });
    if (chance(0.3)) shift.type = "work";
    for (let j = int(0, 3); j > 0; j--) {
      const bs = start + Math.round(rand() * (end - start));
      const be = chance(0.03) ? null : bs + int(1, 75) * MIN + int(0, 59999);
      shift.breaks.push({ start: iso(bs), end: be == null ? null : iso(be) });
    }
    A.push(shift);
    cursor = end + int(20, 240) * MIN;
  }
}
newestFirst(A);

// B: the edges
const B = [];
B.push(work(at(2026, 5, 7, 8), at(2026, 5, 7, 14))); // exactly the automatic break's 6 hours
B.push(work(at(2026, 5, 8, 8), at(2026, 5, 8, 14) - 1)); // a millisecond short of them
B.push(work(at(2026, 5, 9, 8), at(2026, 5, 9, 12, 30))); // exactly 4.5 hours
B.push({ ...work(at(2026, 5, 10, 9), at(2026, 5, 10, 10)), // a break longer than the shift
  breaks: [{ start: iso(at(2026, 5, 10, 8)), end: iso(at(2026, 5, 10, 11)) }] });
B.push({ ...work(at(2026, 5, 11, 9), at(2026, 5, 11, 17)), // an open break on a shift that ended
  breaks: [{ start: iso(at(2026, 5, 11, 12)), end: null }] });
B.push(work(at(2026, 5, 12, 17), at(2026, 5, 12, 9))); // an end before the start
B.push(work(at(2026, 0, 16, 9), at(2026, 0, 16, 9))); // nothing worked
// over midnight on the nights the clocks change, and through the hour skipped and the hour repeated
B.push(work(at(2026, 2, 26, 21), at(2026, 2, 27, 9)));
B.push(work(at(2026, 9, 24, 20), at(2026, 9, 25, 7, 30)));
B.push(work(at(2025, 2, 27, 22), at(2025, 2, 28, 6)));
B.push(work(at(2025, 9, 25, 23), at(2025, 9, 26, 5)));
B.push(work(at(2026, 2, 27, 1), at(2026, 2, 27, 4)));
B.push(work(at(2026, 9, 25, 0, 30), at(2026, 9, 25, 3)));
B.push(work(at(2026, 0, 14, 18), at(2026, 0, 15, 14))); // twenty hours, over midnight
// a shift on every shortened day and holiday of the two years
for (let day = new Date(2025, 0, 1); day < new Date(2027, 0, 1); day.setDate(day.getDate() + 1)) {
  const kind = holidays.info(day).type;
  const y = day.getFullYear(), m = day.getMonth(), d = day.getDate();
  if (kind) B.push(work(at(y, m, d, 7, 45), at(y, m, d, 16, 10), { isHoliday: kind === "chag" }));
}
B.push({ ...work(at(2026, 9, 28, 7, 2, 41, 120), null), breaks: [ // the shift running now, on a break
  { start: iso(at(2026, 9, 28, 10)), end: iso(at(2026, 9, 28, 10, 25)) },
  { start: iso(at(2026, 9, 28, 15, 1)), end: null },
] });
newestFirst(B);

// C: runs of sick days over weekends, holidays and a day worked, a deleted one, vacation days
const C = [];
for (const d of [5, 8, 9, 10, 11, 12, 13, 15, 16, 18, 19, 22]) C.push(dayOff(2026, 10, d, "sick"));
C.push(work(at(2026, 10, 17, 8), at(2026, 10, 17, 17)));
C.push(dayOff(2026, 10, 20, "sick", { deleted: true }));
for (const d of [9, 10, 11, 13, 14]) C.push(dayOff(2026, 8, d, "sick")); // around Rosh Hashana 5787
for (const d of [1, 2, 3]) C.push(dayOff(2026, 3, d, "vacation")); // Pesach 5786
for (const d of [20, 21, 22, 23]) C.push(dayOff(2026, 3, d, "sick")); // Yom HaZikaron 5786
for (const d of [6, 7]) C.push(dayOff(2026, 11, d, "vacation"));
newestFirst(C);

const sets = [A, B, C];

/* ---------- checks ---------- */
const checks = [];
const expected = [];
const add = (check, result) => { checks.push(check); expected.push(result); };
const ctx = sets.map((set) => ({ sickDates: calc.sickDatesOf(set) }));

const breakdownOut = (b) => ({
  id: b.id, type: b.type || "work", startMs: b.startMs, endMs: b.endMs, ongoing: b.ongoing, grossMs: b.grossMs,
  breakMs: b.breakMs, netMs: b.netMs, netHours: b.netHours, regularHours: b.regularHours, ot1Hours: b.ot1Hours,
  ot2Hours: b.ot2Hours, overtimeHours: b.overtimeHours, nightHours: b.nightHours, isHoliday: b.isHoliday,
  basePay: b.basePay, otPay: b.otPay, nightPremium: b.nightPremium, pay: b.pay,
  sickTier: b.sickTier ?? null, sickPct: b.sickPct ?? null,
});
const totalsOut = (t) => ({
  count: t.count, netHours: t.netHours, overtimeHours: t.overtimeHours, nightHours: t.nightHours,
  holidayHours: t.holidayHours, pay: t.pay, travel: t.travel, total: t.total, workedDays: t.workedDays,
  avgShiftHours: t.avgShiftHours,
});
const span = (r) => ({ start: r.start.getTime(), end: r.end.getTime() });

// app.js expectedStandard and renderShifts' shortfall, as they are there
function expectedStandard(date, s) {
  if (s.holidaysEnabled !== false && holidays && (s.holidayEveHours || 0) > 0) {
    const hi = holidays.info(date);
    if (hi.type === "short") return s.holidayEveHours;
  }
  const wd = s.standardByDay && s.standardByDay[new Date(date).getDay()];
  return (wd != null && wd > 0) ? wd : null;
}
function shortfall(all, s, range, now) {
  const list = all.filter((sh) => calc.inRange(sh, range));
  const c = { sickDates: calc.sickDatesOf(all) };
  const dayNet = {}, dayDate = {};
  for (const sh of list) {
    if (sh.type === "vacation" || sh.type === "sick") continue;
    const d = new Date(sh.start);
    const key = calc.dayKeyOf(d);
    dayNet[key] = (dayNet[key] || 0) + calc.shiftBreakdown(sh, s, now, c).netHours;
    dayDate[key] = d;
  }
  let total = 0, days = 0;
  for (const key in dayNet) {
    const exp = expectedStandard(dayDate[key], s);
    if (exp != null) {
      const miss = Math.max(0, exp - dayNet[key]);
      if (miss > 0.001) { days++; total += miss; }
    }
  }
  return { total, days };
}
// the numbers of app.js updateNow, as they are there: the running shift (store.getActive), or today
function nowStatus(all, s, now) {
  const active = all.find((x) => !x.deleted && !x.end && (!x.type || x.type === "work")) || null;
  const goal = calc.standardHoursFor(now, s);
  let netH, netMs, overtime, pay;
  if (active) {
    const b = calc.shiftBreakdown(active, s, now);
    netH = b.netHours; netMs = b.netMs; overtime = b.overtimeHours; pay = b.pay;
  } else {
    const today = calc.aggregate(all, s, calc.dayRange(now), now);
    netH = today.netHours; netMs = today.netHours * HOUR; overtime = today.overtimeHours; pay = today.total;
  }
  const remaining = goal - netH;
  let finishMs = null;
  if (active && remaining > 0.001) {
    const loggedMs = (active.breaks || []).reduce((a, brk) => {
      const be = brk.end ? new Date(brk.end).getTime() : now;
      return a + Math.max(0, be - new Date(brk.start).getTime());
    }, 0);
    const autoMs = (s.autoBreakMinutes || 0) * 60000;
    finishMs = new Date(active.start).getTime() + goal * HOUR + Math.max(loggedMs, autoMs);
  }
  const periodTotal = s.monthlyIncomeGoal > 0
    ? calc.aggregate(all, s, calc.shiftPeriod(now, s.monthStartDay, 0), now).total : null;
  return {
    active: active ? active.id : null, onBreak: !!(active && active.breaks.find((b) => !b.end)),
    goal, netMs, netHours: netH, overtimeHours: overtime, pay,
    progress: Math.max(0, Math.min(1, goal > 0 ? netH / goal : 0)), remaining, finishMs,
    projected: netH > 0.001 ? pay * (goal / netH) : null, periodTotal,
  };
}
// moments for the Now screen: around the running shift of B, and any day
const nowMoments = [asOf, asOf - 3 * HOUR, asOf - 7 * HOUR, asOf + 2 * HOUR, asOf + 10 * HOUR];
for (let j = 0; j < 12; j++) nowMoments.push(moment());

settings.forEach((s, si) => {
  sets.forEach((set, k) => {
    set.forEach((shift, i) => {
      add({ kind: "breakdown", s: si, set: k, i, asOf }, breakdownOut(calc.shiftBreakdown(shift, s, asOf, ctx[k])));
    });
    add({ kind: "aggregate", s: si, set: k, asOf }, totalsOut(calc.aggregate(set, s, null, asOf)));
    for (let offset = -24; offset <= 3; offset++) {
      const r = calc.shiftPeriod(asOf, s.monthStartDay, offset);
      add({ kind: "aggregate", s: si, set: k, asOf, ...span(r) }, totalsOut(calc.aggregate(set, s, r, asOf)));
      add({ kind: "shortfall", s: si, set: k, asOf, ...span(r) }, shortfall(set, s, r, asOf));
    }
    for (let j = 0; j < 20; j++) {
      const ref = moment();
      for (const r of [calc.dayRange(ref), calc.weekRange(ref, int(0, 6))]) {
        add({ kind: "aggregate", s: si, set: k, asOf, ...span(r) }, totalsOut(calc.aggregate(set, s, r, asOf)));
      }
    }
    for (const now of nowMoments) add({ kind: "now", s: si, set: k, asOf: now }, nowStatus(set, s, now));
    for (const shift of set) {
      if (shift.type !== "sick") continue;
      const t = new Date(shift.start).getTime();
      add({ kind: "sickTier", s: si, set: k, date: t }, { value: calc.sickTier(t, ctx[k].sickDates, s) });
    }
  });
  for (let day = new Date(2025, 0, 1); day < new Date(2027, 0, 1); day.setDate(day.getDate() + 1)) {
    const t = at(day.getFullYear(), day.getMonth(), day.getDate(), 8);
    add({ kind: "standard", s: si, date: t }, { value: calc.standardHoursFor(t, s) });
    add({ kind: "expected", s: si, date: t }, { value: expectedStandard(new Date(t), s) });
  }
});

// holidays: every day of fourteen years at noon, and of 2025-2026 at its first and last moment too
for (let day = new Date(2019, 0, 1); day < new Date(2033, 0, 1); day.setDate(day.getDate() + 1)) {
  const y = day.getFullYear(), m = day.getMonth(), d = day.getDate();
  const times = y >= 2025 && y <= 2026 ? [at(y, m, d), at(y, m, d, 12), at(y, m, d, 23, 59, 59, 999)] : [at(y, m, d, 12)];
  for (const t of times) {
    const h = holidays.info(t);
    add({ kind: "holiday", date: t }, { kind: h.type, name: h.name });
  }
}

// pay periods from any first day (also past the 28th, which the settings do not allow), and moved
const refs = [at(2026, 0, 31), at(2026, 1, 28), at(2028, 1, 29), at(2026, 2, 27, 1, 30), at(2026, 9, 25, 1, 30),
  at(2026, 11, 31, 23, 59, 59, 999), at(2027, 0, 1), at(2026, 4, 25), at(2026, 4, 24, 23, 59)];
for (let j = 0; j < 40; j++) refs.push(moment());
for (const ref of refs) {
  for (const msd of [0, 1, 2, 10, 15, 24, 25, 28, 29, 30, 31]) {
    for (const offset of [-13, -2, -1, 0, 1, 2, 12]) {
      add({ kind: "period", date: ref, msd, offset }, span(calc.shiftPeriod(ref, msd, offset)));
    }
  }
}
for (let j = 0; j < 150; j++) {
  const ref = moment();
  add({ kind: "dayRange", date: ref }, span(calc.dayRange(ref)));
  for (let wso = 0; wso < 7; wso++) add({ kind: "weekRange", date: ref, wso }, span(calc.weekRange(ref, wso)));
}

// night windows of every shape: crossing midnight or not, a whole day, edges at a minute's rounding
const edges = [22, 23, 21.75, 22.5, 2.5, 6, 5.5, 0, 7.75, 12, 23.9999, 2, 3];
for (let j = 0; j < 4000; j++) {
  const start = moment();
  const end = start + Math.round((rand() * 30 - 2) * HOUR);
  const a = chance(0.6) ? pick(edges) : Math.round(rand() * 24000) / 1000;
  const b = chance(0.1) ? a : chance(0.6) ? pick(edges) : Math.round(rand() * 24000) / 1000;
  add({ kind: "night", start, end, a, b }, { value: calc.nightMs(start, end, a, b) });
}

// formatting
const amounts = [0, 0.005, 1.005, 2.675, 1.115, 0.125, 1234.565, 999999.995, 442.72, 12.5, 2.5, 1234567.891];
for (let j = 0; j < 400; j++) {
  const hours = chance(0.1) ? pick([0, -1, 0.0083, 9.1, 8.6, 4.1, 23.99, 100.5]) : rand() * 14;
  add({ kind: "format", fn: "hoursToHM", x: hours }, { text: fmt.hoursToHM(hours) });
  const ms = Math.round((rand() * 20 - 1) * HOUR);
  add({ kind: "format", fn: "hms", x: ms }, { text: fmt.hms(ms) });
  const amount = chance(0.15) ? pick(amounts) : Math.round(rand() * 2000000) / 100 + (chance(0.3) ? rand() / 1000 : 0);
  add({ kind: "format", fn: "money", x: amount }, { text: fmt.money(amount) });
  add({ kind: "format", fn: "moneyShort", x: amount }, { text: fmt.moneyShort(amount) });
  const t = moment();
  for (const fn of ["clock", "dayMonth", "dateLong", "dateFull"]) add({ kind: "format", fn, x: t }, { text: fmt[fn](t) });
}

fs.writeFileSync(path.join(dir, "cases.json"), JSON.stringify({ settings, sets, checks }));
fs.writeFileSync(path.join(dir, "expected.json"), JSON.stringify(expected));
console.log(`web: ${checks.length} checks, ${A.length + B.length + C.length} shifts, ${settings.length} settings`);
