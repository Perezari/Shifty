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

  // Full breakdown for a single shift.
  // `asOf` lets the live (ongoing) shift be computed up to "now".
  function shiftBreakdown(shift, settings, asOf) {
    const s = settings;
    const startMs = new Date(shift.start).getTime();
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
    const list = range ? shifts.filter((s) => inRange(s, range)) : shifts;
    const days = new Set();
    let netHours = 0, overtimeHours = 0, nightHours = 0, pay = 0, count = 0, holidayHours = 0;
    for (const sh of list) {
      const b = shiftBreakdown(sh, settings, asOf);
      netHours += b.netHours;
      overtimeHours += b.overtimeHours;
      nightHours += b.nightHours;
      if (b.isHoliday) holidayHours += b.netHours;
      pay += b.pay;
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
  };
})();
