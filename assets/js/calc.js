/* ============================================================
   Shifty — calculation engine
   Hours breakdown + salary, Israeli-style daily overtime tiers.
   Exposes window.Shifty.calc
   ============================================================ */
(function () {
  const Shifty = (window.Shifty = window.Shifty || {});
  const HOUR = 3600000;

  // standard ("תקן") daily hours for the weekday of `date`.
  // Per-day value if set, else the global regularDailyHours fallback.
  // Also the daily ring goal on the Now screen.
  function standardHoursFor(date, s) {
    // shortened days (erev chag / Yom HaZikaron) override the weekday standard.
    // chag days are intentionally ignored here (treated as a regular day for calc).
    if (s.holidaysEnabled !== false && Shifty.holidays && (s.holidayEveHours || 0) > 0) {
      const hi = Shifty.holidays.info(date);
      if (hi.type === "short") return s.holidayEveHours;
    }
    const dow = new Date(date).getDay();
    const v = s.standardByDay && s.standardByDay[dow];
    return (v != null && v > 0) ? v : (s.regularDailyHours || 8.6);
  }

  // total completed break ms for a shift, up to `asOf`
  function breaksMs(shift, asOf) {
    let ms = 0;
    for (const b of shift.breaks || []) {
      const bs = new Date(b.start).getTime();
      const be = b.end ? new Date(b.end).getTime() : asOf;
      if (be > bs) ms += be - bs;
    }
    return ms;
  }

  // overlap (ms) between [start,end] and the nightly window [nightStart .. nightEnd]
  // window may cross midnight (e.g. 22 -> 6). nightStart/End are decimal hours (e.g. 22.5).
  function nightMs(startMs, endMs, nightStart, nightEnd) {
    if (endMs <= startMs) return 0;
    const setHM = (d, v) => { const hh = Math.floor(v); d.setHours(hh, Math.round((v - hh) * 60), 0, 0); return d; };
    let total = 0;
    // walk each calendar day the shift touches (±1 for safety)
    const dayStart = new Date(startMs); dayStart.setHours(0, 0, 0, 0);
    for (let off = -1; off <= 2; off++) {
      const base = new Date(dayStart.getTime());
      base.setDate(base.getDate() + off);
      const winStart = setHM(new Date(base), nightStart);
      const winEnd = setHM(new Date(base), nightEnd);
      if (nightEnd <= nightStart) winEnd.setDate(winEnd.getDate() + 1); // crosses midnight
      const a = Math.max(startMs, winStart.getTime());
      const b = Math.min(endMs, winEnd.getTime());
      if (b > a) total += b - a;
    }
    return total;
  }

  function dayKeyOf(dateOrMs) { const d = new Date(dateOrMs); return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate(); }
  function sickDatesOf(shifts) {
    const set = new Set();
    for (const x of shifts) if (x.type === "sick" && !x.deleted) set.add(dayKeyOf(x.start));
    return set;
  }
  function sickPctFor(s, tier) {
    const idx = Math.min(Math.max(tier, 1), 4) - 1;
    const v = [s.sickDay1Pct, s.sickDay2Pct, s.sickDay3Pct, s.sickDay4Pct][idx];
    return v != null ? v : [0, 50, 50, 100][idx];
  }
  // consecutive sick days ending at dateMs (inclusive); off-days (no standard) don't break the
  // streak, a worked non-sick day does. Capped at 4 (= "day 4+").
  function sickTier(dateMs, sickDates, s) {
    let n = 1;
    const cur = new Date(dateMs); cur.setHours(0, 0, 0, 0);
    for (let i = 0; i < 120 && n < 4; i++) {
      cur.setDate(cur.getDate() - 1);
      if (sickDates.has(dayKeyOf(cur))) { n++; continue; }
      const wd = s.standardByDay && s.standardByDay[cur.getDay()];
      if (wd == null || wd <= 0) continue; // off-day: neither counts nor breaks
      break;
    }
    return n;
  }

  // Full breakdown for a single shift.
  // `asOf` lets the live (ongoing) shift be computed up to "now". `ctx.sickDates` enables sick tiering.
  function shiftBreakdown(shift, settings, asOf, ctx) {
    const s = settings;
    const wage = s.hourlyWage;
    const type = shift.type || "work";
    const startMs = new Date(shift.start).getTime();

    // paid non-work days: a flat paid amount, no overtime / night / break
    if (type === "vacation" || type === "sick") {
      let hrs, extra = {};
      if (type === "vacation") {
        hrs = (s.vacationHours != null ? s.vacationHours : 8.6);
      } else {
        const tier = (ctx && ctx.sickDates) ? sickTier(startMs, ctx.sickDates, s) : 1;
        const pct = sickPctFor(s, tier);
        hrs = standardHoursFor(startMs, s) * pct / 100;
        extra = { sickTier: tier, sickPct: pct };
      }
      const pay = hrs * wage;
      return Object.assign({
        id: shift.id, type, startMs, endMs: startMs, ongoing: false,
        grossMs: 0, breakMs: 0, netMs: hrs * HOUR, netHours: hrs,
        regularHours: hrs, ot1Hours: 0, ot2Hours: 0, overtimeHours: 0, nightHours: 0,
        isHoliday: false, basePay: pay, otPay: 0, nightPremium: 0, pay,
      }, extra);
    }

    const ongoing = !shift.end;
    const endMs = ongoing ? (asOf || Date.now()) : new Date(shift.end).getTime();

    const grossMs = Math.max(0, endMs - startMs);

    // breaks: logged breaks, plus auto-break if configured and shift long enough
    let brkMs = breaksMs(shift, endMs);
    const autoMs = (s.autoBreakMinutes || 0) * 60000;
    if (autoMs > 0 && grossMs >= (s.autoBreakAfterHours || 0) * HOUR) {
      brkMs = Math.max(brkMs, autoMs);
    }
    brkMs = Math.min(brkMs, grossMs);

    const netMs = Math.max(0, grossMs - brkMs);
    const netHours = netMs / HOUR;

    // night portion of worked (gross) span — informational premium
    const nHours = s.nightEnabled ? nightMs(startMs, endMs, s.nightStart, s.nightEnd) / HOUR : 0;

    // split net hours into regular / OT tier1 / OT tier2 — threshold is per-weekday
    const reg = Math.min(netHours, standardHoursFor(startMs, s));
    let rest = netHours - reg;
    const ot1 = Math.min(rest, s.overtime1Hours);
    rest -= ot1;
    const ot2 = Math.max(0, rest);

    let basePay, otPay, nightPremium, pay;

    if (shift.isHoliday) {
      // whole shift at holiday multiplier
      basePay = netHours * s.hourlyWage * s.holidayMult;
      otPay = 0;
      nightPremium = 0;
      pay = basePay;
    } else {
      basePay = reg * s.hourlyWage;
      otPay = (ot1 * s.overtime1Mult + ot2 * s.overtime2Mult) * s.hourlyWage;
      nightPremium = s.nightEnabled ? nHours * s.hourlyWage * (s.nightMult - 1) : 0;
      if (nightPremium < 0) nightPremium = 0;
      pay = basePay + otPay + nightPremium;
    }

    return {
      id: shift.id,
      startMs, endMs, ongoing,
      grossMs, breakMs: brkMs, netMs,
      netHours,
      regularHours: reg, ot1Hours: ot1, ot2Hours: ot2,
      overtimeHours: ot1 + ot2,
      nightHours: nHours,
      isHoliday: !!shift.isHoliday,
      basePay, otPay, nightPremium,
      pay, // salary for this shift (excludes travel)
    };
  }

  // ---- date-range helpers ----
  // returns {start, end} Date for the billing period containing `ref`,
  // based on monthStartDay.
  function periodRange(ref, monthStartDay) {
    const d = new Date(ref);
    const day = monthStartDay || 1;
    let start = new Date(d.getFullYear(), d.getMonth(), day, 0, 0, 0, 0);
    if (d.getDate() < day) start = new Date(d.getFullYear(), d.getMonth() - 1, day, 0, 0, 0, 0);
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);
    return { start, end };
  }
  function shiftPeriod(ref, monthStartDay, offset) {
    const r = periodRange(ref, monthStartDay);
    if (offset) {
      r.start.setMonth(r.start.getMonth() + offset);
      r.end.setMonth(r.end.getMonth() + offset);
    }
    return r;
  }

  function dayRange(ref) {
    const d = new Date(ref);
    const start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
    const end = new Date(start); end.setDate(end.getDate() + 1);
    return { start, end };
  }
  function weekRange(ref, weekStartsOn) {
    const d = new Date(ref);
    const dow = d.getDay();
    const diff = (dow - (weekStartsOn || 0) + 7) % 7;
    const start = new Date(d.getFullYear(), d.getMonth(), d.getDate() - diff, 0, 0, 0, 0);
    const end = new Date(start); end.setDate(end.getDate() + 7);
    return { start, end };
  }

  function inRange(shift, range) {
    const t = new Date(shift.start).getTime();
    return t >= range.start.getTime() && t < range.end.getTime();
  }

  // Aggregate a list of shifts (already filtered or not) over a range.
  function aggregate(shifts, settings, range, asOf) {
    const ctx = { sickDates: sickDatesOf(shifts) };
    const list = range ? shifts.filter((s) => inRange(s, range)) : shifts;
    const days = new Set();
    let netHours = 0, overtimeHours = 0, nightHours = 0, pay = 0, count = 0, holidayHours = 0;
    for (const sh of list) {
      const b = shiftBreakdown(sh, settings, asOf, ctx);
      pay += b.pay;                                              // vacation/sick are paid…
      if (b.type === "vacation" || b.type === "sick") continue; // …but not "worked" hours/days
      netHours += b.netHours;
      overtimeHours += b.overtimeHours;
      nightHours += b.nightHours;
      if (b.isHoliday) holidayHours += b.netHours;
      count++;
      const d = new Date(sh.start);
      days.add(d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate());
    }

    // travel reimbursement per worked day, optional monthly cap
    let travel = (settings.travelPerDay || 0) * days.size;
    if (settings.travelMonthlyCap > 0) travel = Math.min(travel, settings.travelMonthlyCap);

    return {
      count,
      netHours, overtimeHours, nightHours, holidayHours,
      pay,                       // salary (no travel)
      travel,
      total: pay + travel,       // total income
      workedDays: days.size,
      avgShiftHours: count ? netHours / count : 0,
    };
  }

  Shifty.calc = {
    HOUR, shiftBreakdown, aggregate, standardHoursFor,
    periodRange, shiftPeriod, dayRange, weekRange, inRange, nightMs,
    dayKeyOf, sickDatesOf, sickTier, sickPctFor,
  };
})();
