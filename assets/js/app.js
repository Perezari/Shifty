/* ============================================================
   Shifty — app controller & views
   ============================================================ */
(function () {
  const S = window.Shifty;
  const { fmt, store, calc } = S;
  const $ = (sel, root) => (root || document).querySelector(sel);
  const HOUR = calc.HOUR;

  const state = {
    view: "now",
    periodOffset: 0,   // shifts view billing-period offset
    calOffset: 0,      // calendar view month offset
    cloudStage: "email", // cloud auth form: "email" | "code"
    cloudEmail: "",
    tick: null,
    live: {},          // nodes updated by ticker
  };

  /* ---------- tiny helpers ---------- */
  function h(html) {
    const t = document.createElement("template");
    t.innerHTML = html.trim();
    return t.content.firstElementChild;
  }
  function haptic(ms) { try { navigator.vibrate && navigator.vibrate(ms || 8); } catch (e) {} }

  let toastTimer;
  function toast(msg) {
    const host = $("#toast-host");
    host.innerHTML = "";
    const t = h(`<div class="toast">${msg}</div>`);
    host.appendChild(t);
    requestAnimationFrame(() => t.classList.add("show"));
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      t.classList.remove("show");
      setTimeout(() => t.remove(), 250);
    }, 2200);
  }

  /* ---------- theme ---------- */
  function applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    const c = getComputedStyle(document.body).backgroundColor;
    const meta = $("#theme-color-meta");
    if (meta) meta.setAttribute("content", c);
  }
  function toggleTheme() {
    const s = store.getSettings();
    const next = s.theme === "dark" ? "light" : "dark";
    store.setSettings({ theme: next });
    applyTheme(next);
    haptic();
  }

  /* ============================================================
     NOW VIEW
     ============================================================ */
  function renderNow() {
    const s = store.getSettings();
    const active = store.getActive();
    const now = Date.now();
    const root = $("#view-root");

    const goal = calc.standardHoursFor(now, s);
    const R = 106, C = 2 * Math.PI * R;

    const el = h(`
      <section class="now fade-in">
        <div class="now-stage">
          <div class="now-status ${active ? "working" : ""}" id="now-status"></div>
          <div class="now-date">${fmt.dateFull(now)}</div>

          <div class="ring-wrap" id="ring-wrap">
            <svg viewBox="0 0 252 252">
              <defs>
                <linearGradient id="ringGrad" gradientUnits="userSpaceOnUse" x1="20" y1="20" x2="232" y2="232">
                  <stop offset="0" stop-color="var(--accent-strong)"/>
                  <stop offset="1" stop-color="var(--accent)"/>
                </linearGradient>
              </defs>
              <circle class="ring-halo" cx="126" cy="126" r="92" fill="none" stroke-width="1.5"/>
              <circle class="ring-halo" cx="126" cy="126" r="73" fill="none" stroke-width="1.5"/>
              <circle class="ring-track" cx="126" cy="126" r="${R}" fill="none" stroke-width="18"/>
              <line class="ring-tick" x1="126" y1="11" x2="126" y2="17"/>
              <circle class="ring-fill" id="ring-fill" cx="126" cy="126" r="${R}" fill="none" stroke-width="18"
                      stroke-dasharray="${C.toFixed(1)}" stroke-dashoffset="${C.toFixed(1)}"/>
              <circle class="ring-knob" id="ring-knob" data-hidden="1" cx="126" cy="20" r="7"/>
            </svg>
            <div class="ring-center">
              <div class="ring-time idle" id="ring-time">00:00:00</div>
              <div class="ring-label" id="ring-label">לא במשמרת</div>
              <div class="ring-sub" id="ring-sub"></div>
            </div>
          </div>
        </div>

        <div class="now-stats">
          <div class="stat">
            <div class="stat-head"><div class="stat-k" id="stat1-k">שעות היום</div><span class="stat-ico" id="stat1-ico"></span></div>
            <div class="stat-v" id="stat1-v">0:00</div>
          </div>
          <div class="stat money">
            <div class="stat-head"><div class="stat-k" id="stat2-k">שכר היום</div><span class="stat-ico stat-ico-text">${s.currency}</span></div>
            <div class="stat-v money" id="stat2-v">${fmt.money(0, s.currency)}</div>
          </div>
        </div>

        <div class="now-actions" id="now-actions"></div>

        <div class="now-goal" id="now-goal">
          <div class="now-goal-head">
            <span class="k" id="goal-head-k">היעד היומי</span>
            <span class="v" id="goal-readout">0:00 / ${fmt.hoursToHM(goal)} ש׳</span>
          </div>
          <div class="now-goal-bar"><div class="now-goal-fill" id="goal-fill"></div></div>
          <div class="now-goal-sub">
            <span class="rem" id="goal-rem">נותרו ${fmt.hoursToHM(goal)} ליעד</span>
          </div>
          <div class="now-goal-proj">
            <span class="k" id="goal-proj-k">צפי שכר בסיום היעד</span>
            <span class="v" id="goal-proj-v">${fmt.money(0, s.currency)}</span>
          </div>
        </div>
      </section>
    `);
    root.innerHTML = "";
    root.appendChild(el);

    $("#stat1-ico").innerHTML = '<svg class="ico" width="15" height="15" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>';

    renderNowActions(active);

    state.live = {
      mode: "now",
      ringFill: $("#ring-fill"), ringTime: $("#ring-time"),
      ringLabel: $("#ring-label"), ringSub: $("#ring-sub"),
      ringWrap: $("#ring-wrap"), ringKnob: $("#ring-knob"),
      status: $("#now-status"),
      stat1k: $("#stat1-k"), stat1v: $("#stat1-v"),
      stat2k: $("#stat2-k"), stat2v: $("#stat2-v"),
      goalReadout: $("#goal-readout"), goalFill: $("#goal-fill"), goalRem: $("#goal-rem"),
      goalProjK: $("#goal-proj-k"), goalProjV: $("#goal-proj-v"),
      C, goal, R,
    };
    updateNow();
  }

  // position the leading knob on the arc (SVG is CSS-rotated -90deg, so angle 0 = top)
  function positionKnob(knob, progress, r) {
    if (!knob) return;
    if (progress <= 0) { knob.dataset.hidden = "1"; return; }
    knob.dataset.hidden = "0";
    const a = progress * 2 * Math.PI;
    knob.setAttribute("cx", (126 + r * Math.cos(a)).toFixed(1));
    knob.setAttribute("cy", (126 + r * Math.sin(a)).toFixed(1));
  }

  function renderNowActions(active) {
    const wrap = $("#now-actions");
    if (!wrap) return;
    wrap.innerHTML = "";
    const onBreak = active && store.activeBreak(active);

    if (!active) {
      wrap.appendChild(btn("btn-primary", icoPlay() + "התחל משמרת", () => doStart()));
      wrap.appendChild(btn("btn-secondary", "הוספת משמרת ידנית", () => openShiftEditor(null)));
    } else if (onBreak) {
      const banner = h(`<div class="break-banner">בהפסקה <span id="brk-timer" style="direction:ltr;font-variant-numeric:tabular-nums">0:00</span></div>`);
      wrap.appendChild(banner);
      wrap.appendChild(btn("btn-soft", "סיים הפסקה", () => doEndBreak()));
      wrap.appendChild(btn("btn-danger", icoStop() + "סיים משמרת", () => doEnd()));
    } else {
      const row = h(`<div class="btn-row"></div>`);
      row.appendChild(btn("btn-ghost", "התחל הפסקה", () => doStartBreak()));
      row.appendChild(btn("btn-danger", icoStop() + "סיים משמרת", () => doEnd()));
      wrap.appendChild(row);
    }
  }

  function updateNow() {
    const L = state.live;
    if (!L || L.mode !== "now") return;
    const s = store.getSettings();
    const active = store.getActive();
    const now = Date.now();
    let netH = 0, payNow = 0; // fed to the shared goal strip below

    if (active) {
      const b = calc.shiftBreakdown(active, s, now);
      const onBreak = store.activeBreak(active);
      netH = b.netHours; payNow = b.pay;
      const progress = Math.min(1, b.netHours / L.goal);
      L.ringFill.setAttribute("stroke-dashoffset", (L.C * (1 - progress)).toFixed(1));
      positionKnob(L.ringKnob, progress, L.R);
      L.ringWrap.classList.toggle("working", !onBreak); // breathe only while truly working
      L.ringTime.classList.remove("idle");
      L.ringTime.textContent = fmt.hms(b.netMs);
      L.ringLabel.textContent = onBreak ? "בהפסקה" : "זמן עבודה";
      L.ringSub.textContent = "התחלה " + fmt.clock(active.start);
      L.status.textContent = "במשמרת" + (active.isHoliday ? " · שבת/חג" : "");
      L.status.classList.add("working");

      L.stat1k.textContent = "שעות נטו";
      L.stat1v.textContent = fmt.hoursToHM(b.netHours);
      L.stat2k.textContent = "שכר במשמרת";
      L.stat2v.textContent = fmt.money(b.pay, s.currency);

      if (onBreak) {
        const bt = $("#brk-timer");
        if (bt) bt.textContent = fmt.hms(now - new Date(onBreak.start).getTime());
      }
    } else {
      // today's totals
      const today = calc.aggregate(store.getShifts(), s, calc.dayRange(now), now);
      netH = today.netHours; payNow = today.total;
      const progress = Math.min(1, today.netHours / L.goal);
      L.ringFill.setAttribute("stroke-dashoffset", (L.C * (1 - progress)).toFixed(1));
      positionKnob(L.ringKnob, progress, L.R);
      L.ringWrap.classList.toggle("working", false); // idle = perfectly still
      L.ringTime.classList.toggle("idle", today.netHours === 0);
      L.ringTime.textContent = today.netHours > 0 ? fmt.hms(today.netHours * HOUR) : "00:00:00";
      L.ringLabel.textContent = today.netHours > 0 ? "עבדת היום" : "לא במשמרת";
      L.ringSub.textContent = "";
      L.status.textContent = "מוכן להתחיל";
      L.status.classList.remove("working");

      L.stat1k.textContent = "שעות היום";
      L.stat1v.textContent = fmt.hoursToHM(today.netHours);
      L.stat2k.textContent = "שכר היום";
      L.stat2v.textContent = fmt.money(today.total, s.currency);
    }

    // ---- מסלול היעד: daily-goal + projection strip (live, runs in both states) ----
    if (L.goalFill) {
      const goalH = L.goal;
      const pct = Math.max(0, Math.min(1, goalH > 0 ? netH / goalH : 0));
      L.goalFill.style.width = (pct * 100).toFixed(1) + "%";
      L.goalReadout.textContent = fmt.hoursToHM(netH) + " / " + fmt.hoursToHM(goalH) + " ש׳";

      const remH = goalH - netH;
      if (remH <= 0.001) {
        L.goalRem.textContent = "הגעת ליעד ✓";
        L.goalRem.classList.add("done");
      } else {
        let txt = "נותרו " + fmt.hoursToHM(remH) + " ליעד";
        if (active) {
          // clock time you reach the goal: start + goal hours + the break that applies
          const startMs = new Date(active.start).getTime();
          const loggedMs = (active.breaks || []).reduce((a, brk) => {
            const be = brk.end ? new Date(brk.end).getTime() : now;
            return a + Math.max(0, be - new Date(brk.start).getTime());
          }, 0);
          const autoMs = (s.autoBreakMinutes || 0) * 60000;
          const finishMs = startMs + goalH * HOUR + Math.max(loggedMs, autoMs);
          txt += " · סיום ב־" + fmt.clock(finishMs);
        }
        L.goalRem.textContent = txt;
        L.goalRem.classList.remove("done");
      }

      if (s.monthlyIncomeGoal > 0) {
        const period = calc.aggregate(store.getShifts(), s, calc.shiftPeriod(now, s.monthStartDay, 0), now);
        L.goalProjK.textContent = "יעד חודשי";
        L.goalProjV.textContent = fmt.moneyShort(period.total, s.currency) + " מתוך " + fmt.moneyShort(s.monthlyIncomeGoal, s.currency);
      } else {
        L.goalProjK.textContent = "צפי שכר בסיום היעד";
        const projected = netH > 0.001 ? payNow * (goalH / netH) : null;
        L.goalProjV.textContent = projected == null ? "—" : fmt.money(projected, s.currency);
      }
    }
  }

  /* lifecycle actions */
  function doStart() { store.startShift(); haptic(12); renderNow(); toast("המשמרת התחילה ✓"); }
  function doEnd() {
    const s = store.getSettings();
    const sh = store.getActive();
    const b = calc.shiftBreakdown(sh, s, Date.now());
    store.endShift(); haptic(12); renderNow();
    toast(`משמרת נסגרה · ${fmt.hoursToHM(b.netHours)} שע׳ · ${fmt.money(b.pay, s.currency)}`);
  }
  function doStartBreak() { store.startBreak(); haptic(); renderNow(); }
  function doEndBreak() { store.endBreak(); haptic(); renderNow(); }

  /* ============================================================
     SHIFTS VIEW
     ============================================================ */
  function renderShifts() {
    const s = store.getSettings();
    const now = Date.now();
    const range = calc.shiftPeriod(now, s.monthStartDay, state.periodOffset);
    const all = store.getShifts();
    const list = all.filter((sh) => calc.inRange(sh, range));
    const agg = calc.aggregate(all, s, range, now);
    const root = $("#view-root");

    const label = fmt.dayMonth(new Date(range.end.getTime() - 1)) + " – " + fmt.dayMonth(range.start);

    const el = h(`
      <section class="fade-in">
        <div class="period-bar">
          <button id="per-prev" aria-label="הקודם">${icoChevron("right")}</button>
          <button class="period-label" id="per-jump">${label}${icoCaret()}</button>
          <button id="per-next" aria-label="הבא">${icoChevron("left")}</button>
        </div>

        <div class="summary-card">
          <div class="cell"><div class="summary-k">שעות</div><div class="summary-v" id="sum-hours">${fmt.hoursToHM(agg.netHours)}</div></div>
          <div class="cell"><div class="summary-k">משמרות</div><div class="summary-v">${agg.count}</div></div>
          <div class="cell"><div class="summary-k">סה״כ</div><div class="summary-v" id="sum-total">${fmt.moneyShort(agg.total, s.currency)}</div></div>
        </div>

        <div id="shift-list"></div>
      </section>
    `);
    root.innerHTML = "";
    root.appendChild(el);

    const listHost = $("#shift-list");
    if (!list.length) {
      listHost.appendChild(h(`
        <div class="empty">
          <div class="big">🗓️</div>
          <div class="t">אין משמרות בתקופה זו</div>
          <div class="s">לחץ על ＋ למעלה כדי להוסיף משמרת</div>
        </div>`));
    } else {
      for (const sh of list) listHost.appendChild(shiftRow(sh, s, now));
    }

    $("#per-prev").onclick = () => { state.periodOffset--; renderShifts(); }; // earlier (RTL: right = back)
    $("#per-next").onclick = () => { state.periodOffset++; renderShifts(); }; // later
    $("#per-jump").onclick = () => {
      const mid = new Date((range.start.getTime() + range.end.getTime()) / 2);
      openPeriodPicker(mid, (year, m) => { state.periodOffset = periodOffsetFor(year, m, s.monthStartDay); renderShifts(); });
    };

    // capture refs for live (per-second) updates — only the ongoing shift in view
    const active = store.getActive();
    const liveRow = active && calc.inRange(active, range)
      ? listHost.querySelector(`[data-id="${active.id}"]`)
      : null;
    state.live = {
      mode: "shifts",
      range,
      ongoingId: liveRow ? active.id : null,
      sumHours: $("#sum-hours"),
      sumTotal: $("#sum-total"),
      rowMeta: liveRow ? liveRow.querySelector(".shift-meta") : null,
      rowMoney: liveRow ? liveRow.querySelector(".shift-money") : null,
    };
  }

  function shiftMetaHtml(b) {
    const parts = [`${fmt.hoursToHM(b.netHours)} שע׳`];
    if (b.breakMs > 0) parts.push(`הפסקה ${Math.round(b.breakMs / 60000)}׳`);
    if (b.overtimeHours > 0.01) parts.push(`נ.ש ${fmt.hoursToHM(b.overtimeHours)}`);
    if (b.isHoliday) parts.push("שבת/חג");
    return parts.join('<span class="sep">·</span>');
  }

  function shiftRow(sh, s, now) {
    const b = calc.shiftBreakdown(sh, s, now);
    const d = new Date(sh.start);
    const timeStr = b.ongoing
      ? `${fmt.clock(sh.start)} – <span class="live">עכשיו</span>`
      : `${fmt.clock(sh.start)} – ${fmt.clock(sh.end)}`;

    const row = h(`
      <div class="shift-row" role="button" data-id="${sh.id}">
        <div class="shift-date">
          <div class="d">${d.getDate()}</div>
          <div class="dow">${fmt.dowShort(d)}</div>
        </div>
        <div class="shift-main">
          <div class="shift-line">
            <div class="shift-time">${timeStr}</div>
            <div class="shift-money">${fmt.money(b.pay, s.currency)}</div>
          </div>
          <div class="shift-meta">${shiftMetaHtml(b)}</div>
        </div>
      </div>`);
    row.onclick = () => openShiftEditor(sh.id);
    return row;
  }

  // update only the live numbers on the shifts screen (no full re-render)
  function updateShiftsLive() {
    const L = state.live;
    if (!L || L.mode !== "shifts" || !L.ongoingId) return;
    const active = store.getActive();
    if (!active || active.id !== L.ongoingId) { renderShifts(); return; } // state changed
    const s = store.getSettings();
    const now = Date.now();
    const b = calc.shiftBreakdown(active, s, now);
    if (L.rowMeta) L.rowMeta.innerHTML = shiftMetaHtml(b);
    if (L.rowMoney) L.rowMoney.textContent = fmt.money(b.pay, s.currency);
    const agg = calc.aggregate(store.getShifts(), s, L.range, now);
    if (L.sumHours) L.sumHours.textContent = fmt.hoursToHM(agg.netHours);
    if (L.sumTotal) L.sumTotal.textContent = fmt.moneyShort(agg.total, s.currency);
  }

  /* ============================================================
     CALENDAR VIEW — a "work heat-map": each worked day filled by hours/standard
     ============================================================ */
  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  function renderCalendar() {
    const s = store.getSettings();
    const now = new Date();
    // follow the user's billing cycle (same period as the Shifts screen), not the calendar month
    const range = calc.shiftPeriod(now, s.monthStartDay, state.calOffset);
    const cycleStart = range.start;                          // e.g. 25/5 00:00
    const cycleLast = new Date(range.end.getTime() - 1);     // e.g. 24/6
    const root = $("#view-root");
    const dayKey = (d) => d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();

    // group this cycle's shifts by date
    const byDay = {};
    for (const sh of store.getShifts()) {
      const d = new Date(sh.start);
      if (d >= range.start && d < range.end) {
        const b = calc.shiftBreakdown(sh, s, Date.now());
        const k = dayKey(d);
        (byDay[k] || (byDay[k] = { net: 0, pay: 0, n: 0 }));
        byDay[k].net += b.netHours; byDay[k].pay += b.pay; byDay[k].n++;
      }
    }
    const agg = calc.aggregate(store.getShifts(), s, range, Date.now());
    // match the Shifts screen label order exactly (end – start)
    const label = fmt.dayMonth(cycleLast) + " – " + fmt.dayMonth(cycleStart);

    const el = h(`
      <section class="fade-in">
        <div class="period-bar">
          <button id="cal-prev" aria-label="הקודם">${icoChevron("right")}</button>
          <button class="period-label" id="cal-jump">${label}${icoCaret()}</button>
          <button id="cal-next" aria-label="הבא">${icoChevron("left")}</button>
        </div>

        <div class="cal-weekdays">${fmt.DOW.map((d) => `<span>${d.replace("׳", "")}</span>`).join("")}</div>
        <div class="cal-grid" id="cal-grid"></div>

        <div class="cal-summary">
          <div class="cell"><div class="k">ימי עבודה</div><div class="v">${agg.workedDays}</div></div>
          <div class="cell"><div class="k">שעות</div><div class="v">${fmt.hoursToHM(agg.netHours)}</div></div>
          <div class="cell"><div class="k">סה״כ</div><div class="v">${fmt.moneyShort(agg.total, s.currency)}</div></div>
        </div>
      </section>
    `);
    root.innerHTML = "";
    root.appendChild(el);

    // grid spans the cycle, padded to whole weeks (Sun-first); out-of-cycle days are faint
    const grid = $("#cal-grid");
    const gridStart = new Date(cycleStart.getFullYear(), cycleStart.getMonth(), cycleStart.getDate() - cycleStart.getDay());
    const gridEnd = new Date(cycleLast.getFullYear(), cycleLast.getMonth(), cycleLast.getDate() + (6 - cycleLast.getDay()));
    const cells = Math.round((gridEnd - gridStart) / 86400000) + 1;
    const holsOn = s.holidaysEnabled !== false && Shifty.holidays;
    for (let i = 0; i < cells; i++) {
      const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i);
      const inCycle = date >= range.start && date < range.end;
      const isToday = sameDay(date, now);
      const data = inCycle ? byDay[dayKey(date)] : null;
      const hol = inCycle && holsOn ? Shifty.holidays.info(date) : null;
      const holCls = hol && hol.type ? " hol hol-" + hol.type : "";
      const cell = h(`<button class="cal-day${inCycle ? "" : " out"}${isToday ? " today" : ""}${data ? " worked" : ""}${holCls}">
        <span class="num">${date.getDate()}</span>
        ${data ? `<span class="hrs">${fmt.hoursToHM(data.net)}</span>`
          : (hol && hol.type ? `<span class="hol-name">${hol.name}</span>` : "")}
      </button>`);
      if (data) {
        const std = calc.standardHoursFor(date, s);
        const prog = Math.max(0, Math.min(1, std > 0 ? data.net / std : 0));
        cell.style.background = `color-mix(in srgb, var(--accent) ${(9 + prog * 17).toFixed(0)}%, transparent)`;
      }
      if (inCycle) cell.onclick = () => openDayDetail(date);
      grid.appendChild(cell);
    }

    $("#cal-prev").onclick = () => { state.calOffset--; renderCalendar(); }; // ‹ earlier (RTL: right = back)
    $("#cal-next").onclick = () => { state.calOffset++; renderCalendar(); }; // later
    $("#cal-jump").onclick = () => {
      const mid = new Date((range.start.getTime() + range.end.getTime()) / 2);
      openPeriodPicker(mid, (year, m) => { state.calOffset = periodOffsetFor(year, m, s.monthStartDay); renderCalendar(); });
    };
    state.live = { mode: "calendar" };
  }

  function openDayDetail(date) {
    const s = store.getSettings();
    const dayShifts = store.getShifts()
      .filter((sh) => sameDay(new Date(sh.start), date))
      .sort((a, b) => new Date(a.start) - new Date(b.start));
    const hol = s.holidaysEnabled !== false && Shifty.holidays ? Shifty.holidays.info(date) : null;
    const holLine = hol && hol.type
      ? `<div class="day-hol hol-${hol.type}">${hol.name}${hol.type === "short" ? " · יום מקוצר" : ""}</div>`
      : "";

    const sheet = h(`
      <div class="sheet">
        <div class="sheet-grip"></div>
        <h3 class="sheet-title">${fmt.dateFull(date)}</h3>
        ${holLine}
        <div id="day-list"></div>
        <div class="sheet-actions" style="margin-top:14px">
          <button class="btn btn-primary" id="day-add">${icoPlus()}הוספת משמרת ליום זה</button>
        </div>
      </div>`);
    openSheet(sheet);

    const list = $("#day-list", sheet);
    if (!dayShifts.length) {
      list.appendChild(h(`<div class="empty" style="padding:30px 10px"><div class="t">אין משמרת ביום זה</div></div>`));
    } else {
      for (const sh of dayShifts) {
        const b = calc.shiftBreakdown(sh, s, Date.now());
        const meta = [`${fmt.hoursToHM(b.netHours)} שע׳`];
        if (b.breakMs > 0) meta.push(`הפסקה ${Math.round(b.breakMs / 60000)}׳`);
        if (b.isHoliday) meta.push("שבת/חג");
        const row = h(`
          <div class="shift-row" role="button" style="margin-bottom:10px">
            <div class="shift-main">
              <div class="shift-line">
                <div class="shift-time">${b.ongoing ? `${fmt.clock(sh.start)} – <span class="live">עכשיו</span>` : `${fmt.clock(sh.start)} – ${fmt.clock(sh.end)}`}</div>
                <div class="shift-money">${fmt.money(b.pay, s.currency)}</div>
              </div>
              <div class="shift-meta">${meta.join('<span class="sep">·</span>')}</div>
            </div>
          </div>`);
        row.onclick = () => openShiftEditor(sh.id);
        list.appendChild(row);
      }
    }
    $("#day-add", sheet).onclick = () => openShiftEditor(null, date);
  }

  /* ============================================================
     SETTINGS VIEW
     ============================================================ */
  function renderSettings() {
    const s = store.getSettings();
    const root = $("#view-root");
    const el = h(`<section class="fade-in"></section>`);

    appendCloudSection(el);

    el.appendChild(h(`<div class="section-title">שכר ומקום עבודה</div>`));
    const g1 = group();
    g1.appendChild(textRow("שם מקום עבודה", "workplaceName", s));
    g1.appendChild(numRow("שכר לשעה", "hourlyWage", s, { unit: s.currency, step: 0.5 }));
    el.appendChild(g1);

    el.appendChild(h(`<div class="section-title">שעות תקן ליום</div>`));
    el.appendChild(h(`<div class="group-note">השעות התקניות לכל יום (שעות:דקות). מעבר להן נספרות שעות נוספות, והן גם היעד בטבעת במסך «עכשיו».</div>`));
    const gDays = group();
    for (let d = 0; d < 7; d++) gDays.appendChild(dayHoursRow(d, s));
    el.appendChild(gDays);

    el.appendChild(h(`<div class="section-title">חגי ישראל</div>`));
    el.appendChild(h(`<div class="group-note">זיהוי אוטומטי של חגים, ערבי חג ויום הזיכרון — לכל שנה, אופליין. בערב חג ובימים מקוצרים התקן היומי הוא הערך שתגדיר כאן.</div>`));
    const gHol = group();
    gHol.appendChild(toggleRow("זיהוי חגים אוטומטי", "holidaysEnabled", s));
    gHol.appendChild(wheelRow("שעות עבודה בערב חג", "holidayEveHours", s));
    el.appendChild(gHol);

    el.appendChild(h(`<div class="section-title">שעות נוספות</div>`));
    const g2 = group();
    g2.appendChild(numRow("שעתיים ראשונות", "overtime1Mult", s, { unit: "%", percent: true, step: 5, hint: "ברירת מחדל 125%" }));
    g2.appendChild(numRow("מעבר לכך", "overtime2Mult", s, { unit: "%", percent: true, step: 5, hint: "ברירת מחדל 150%" }));
    el.appendChild(g2);

    el.appendChild(h(`<div class="section-title">הפסקות, שבת ולילה</div>`));
    const g3 = group();
    g3.appendChild(numRow("הפסקה אוטומטית", "autoBreakMinutes", s, { unit: "דק׳", step: 5, hint: "יורד מכל משמרת ארוכה" }));
    g3.appendChild(numRow("מעל כמה שעות", "autoBreakAfterHours", s, { unit: "שע׳", step: 0.5 }));
    g3.appendChild(numRow("תוספת שבת/חג", "holidayMult", s, { unit: "%", percent: true, step: 5, hint: "כשמשמרת מסומנת כשבת/חג" }));
    g3.appendChild(toggleRow("חישוב שעות לילה", "nightEnabled", s));
    g3.appendChild(wheelRow("שעת התחלת לילה", "nightStart", s));
    g3.appendChild(wheelRow("שעת סיום לילה", "nightEnd", s));
    g3.appendChild(numRow("תוספת לילה", "nightMult", s, { unit: "%", percent: true, step: 5 }));
    el.appendChild(g3);

    el.appendChild(h(`<div class="section-title">נסיעות ותקופה</div>`));
    const g4 = group();
    g4.appendChild(numRow("החזר נסיעות ליום", "travelPerDay", s, { unit: s.currency, step: 1 }));
    g4.appendChild(numRow("תקרת נסיעות חודשית", "travelMonthlyCap", s, { unit: s.currency, step: 50, hint: "0 = ללא תקרה" }));
    g4.appendChild(numRow("יום תחילת חודש", "monthStartDay", s, { step: 1, min: 1, max: 28, hint: "מחזור חישוב חודשי" }));
    g4.appendChild(numRow("יעד הכנסה חודשי", "monthlyIncomeGoal", s, { unit: s.currency, step: 100, hint: "0 = כבוי" }));
    el.appendChild(g4);

    el.appendChild(h(`<div class="section-title">תצוגה וגיבוי</div>`));
    const g5 = group();
    g5.appendChild(themeRow(s));
    g5.appendChild(textRow("שם האפליקציה", "appName", s));
    el.appendChild(g5);

    const g6 = group();
    g6.appendChild(actionRow("גיבוי נתונים", "ייצוא לקובץ", doExport));
    g6.appendChild(actionRow("שחזור מגיבוי", "ייבוא מקובץ", doImport));
    el.appendChild(g6);

    el.appendChild(h(`<div style="text-align:center;color:var(--text-faint);font-size:12px;margin:22px 0 8px">Shifty · נתונים נשמרים במכשיר בלבד</div>`));

    root.innerHTML = "";
    root.appendChild(el);
    state.live = { mode: "settings" };
  }

  function group() { return h(`<div class="settings-group"></div>`); }

  function relTime(iso) {
    const diff = Date.now() - new Date(iso).getTime();
    if (diff < 45000) return "הרגע";
    if (diff < 3600000) return "לפני " + Math.round(diff / 60000) + " דק׳";
    if (diff < 86400000) return "לפני " + Math.round(diff / 3600000) + " שע׳";
    return fmt.dayMonth(iso);
  }

  /* ---------- cloud sync section (settings) ---------- */
  function appendCloudSection(el) {
    const cloud = Shifty.cloud;
    el.appendChild(h(`<div class="section-title">סנכרון וגיבוי בענן</div>`));

    if (!cloud || !cloud.available()) {
      el.appendChild(h(`<div class="group-note">הסנכרון אינו זמין כרגע (אין חיבור לרשת). כל הנתונים נשמרים במכשיר ועובדים אופליין.</div>`));
      return;
    }

    if (cloud.isSignedIn()) {
      const email = cloud.userEmail() || "";
      const last = cloud.lastSync();
      const statusText = cloud.status === "syncing" ? "מסנכרן…"
        : cloud.status === "error" ? "שגיאה בסנכרון"
        : (last ? "סונכרן " + relTime(last) : "מחובר");
      const card = h(`
        <div class="cloud-card">
          <div class="cloud-status">
            <div>
              <div class="cloud-email">${email}</div>
              <div class="cloud-sub ${cloud.status === "error" ? "err" : ""}">${statusText}</div>
            </div>
            <span class="cloud-dot ${cloud.status}"></span>
          </div>
          <div class="cloud-row">
            <button class="btn btn-ghost" id="cloud-out">התנתקות</button>
            <button class="btn btn-soft" id="cloud-sync">סנכרן עכשיו</button>
          </div>
        </div>`);
      $("#cloud-sync", card).onclick = () => { cloud.syncNow(); haptic(); };
      $("#cloud-out", card).onclick = async () => { await cloud.signOut(); state.cloudStage = "email"; toast("התנתקת"); renderSettings(); };
      el.appendChild(card);
      return;
    }

    // signed out — one-tap Google
    const card = h(`
      <div class="cloud-card">
        <div class="group-note" style="margin:0 0 12px">היכנס כדי לגבות את הנתונים בענן ולסנכרן בין המכשירים שלך. בלי סיסמה.</div>
        <button class="btn cloud-google" id="cloud-google">
          <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true"><path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92c1.71-1.57 2.68-3.89 2.68-6.62z"/><path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26c-.81.54-1.84.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18z"/><path fill="#FBBC05" d="M3.97 10.72a5.4 5.4 0 0 1 0-3.44V4.95H.96a9 9 0 0 0 0 8.1l3.01-2.33z"/><path fill="#EA4335" d="M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.95l3.01 2.33C4.68 5.16 6.66 3.58 9 3.58z"/></svg>
          המשך עם Google
        </button>
      </div>`);
    $("#cloud-google", card).onclick = async () => {
      try { haptic(); await cloud.signInWithGoogle(); } catch (e) { toast("לא הצלחנו להתחבר"); }
    };
    el.appendChild(card);
  }

  // update the sync status text/dot in place (no re-render) — only when the signed-in card is on screen
  function updateCloudStatus() {
    const cloud = Shifty.cloud;
    const sub = document.querySelector(".cloud-card .cloud-sub");
    const dot = document.querySelector(".cloud-card .cloud-dot");
    if (!cloud || !sub || !dot) return;
    const last = cloud.lastSync();
    sub.textContent = cloud.status === "syncing" ? "מסנכרן…"
      : cloud.status === "error" ? "שגיאה בסנכרון"
      : (last ? "סונכרן " + relTime(last) : "מחובר");
    sub.classList.toggle("err", cloud.status === "error");
    dot.className = "cloud-dot" + (cloud.status === "syncing" ? " syncing" : cloud.status === "error" ? " error" : "");
  }

  // per-weekday standard-hours row: day name + HH:MM inputs + working/off toggle
  const DAY_NAMES = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"];
  function setStandardDay(dow, value) {
    const arr = (store.getSettings().standardByDay || []).slice();
    arr[dow] = value;
    store.setSettings({ standardByDay: arr });
  }
  function dayHoursRow(dow, s) {
    const val = s.standardByDay ? s.standardByDay[dow] : null;
    const off = val == null;
    const row = h(`
      <div class="row day-row ${off ? "off" : ""}">
        <div class="dname">${DAY_NAMES[dow]}</div>
        <button class="day-val" type="button">${off ? "חופש" : fmt.hoursToHM(val)}</button>
        <label class="switch"><input type="checkbox" ${off ? "" : "checked"}/><span class="slider"></span></label>
      </div>`);
    const valBtn = row.querySelector(".day-val");
    const toggle = row.querySelector('input[type="checkbox"]');

    valBtn.onclick = () => {
      if (row.classList.contains("off")) return; // toggle the day on first
      const cur = store.getSettings().standardByDay[dow] || (s.regularDailyHours || 8.6);
      const H = Math.floor(cur), M = Math.round((cur - H) * 60);
      openTimeWheel(DAY_NAMES[dow], H, M, (nh, nm) => {
        const dec = nh + nm / 60;
        setStandardDay(dow, dec);
        valBtn.textContent = fmt.hoursToHM(dec);
      });
    };
    toggle.onchange = () => {
      if (toggle.checked) {
        row.classList.remove("off");
        let cur = store.getSettings().standardByDay[dow];
        if (cur == null) { cur = s.regularDailyHours || 8.6; setStandardDay(dow, cur); }
        valBtn.textContent = fmt.hoursToHM(cur);
      } else {
        row.classList.add("off");
        setStandardDay(dow, null);
        valBtn.textContent = "חופש";
      }
      haptic(5);
    };
    return row;
  }

  // iOS-alarm-style HH:MM wheel picker (scroll-snap). onSave(hours, minutes).
  function openTimeWheel(title, h0, m0, onSave) {
    const ITEM = 40;
    const col = (n, fmtFn) => Array.from({ length: n }, (_, i) => `<div class="wheel-item">${fmtFn(i)}</div>`).join("");
    const sheet = h(`
      <div class="sheet">
        <div class="sheet-grip"></div>
        <h3 class="sheet-title">${title}</h3>
        <div class="wheel-labels"><span>שעות</span><span class="wcsp">:</span><span>דקות</span></div>
        <div class="wheel-wrap">
          <div class="wheel-center"></div>
          <div class="wheel" id="wheel-h">${col(24, (i) => i)}</div>
          <div class="wheel-colon">:</div>
          <div class="wheel" id="wheel-m">${col(60, (i) => fmt.pad(i))}</div>
        </div>
        <div class="sheet-actions">
          <button class="btn btn-ghost" id="wheel-cancel">ביטול</button>
          <button class="btn btn-primary" id="wheel-done">שמירה</button>
        </div>
      </div>`);
    openSheet(sheet, "#modal-host-2"); // stacks above any open sheet (e.g. the shift editor)
    const wh = $("#wheel-h", sheet), wm = $("#wheel-m", sheet);
    // snap to the initial values — force layout, then retry across the open animation so it sticks
    const setInitial = () => { wh.scrollTop = h0 * ITEM; wm.scrollTop = m0 * ITEM; };
    void wh.offsetHeight; // flush layout
    setInitial();
    requestAnimationFrame(setInitial);
    setTimeout(setInitial, 60);
    $("#wheel-cancel", sheet).onclick = () => closeSheet("#modal-host-2");
    $("#wheel-done", sheet).onclick = () => {
      const H = Math.max(0, Math.min(23, Math.round(wh.scrollTop / ITEM)));
      const M = Math.max(0, Math.min(59, Math.round(wm.scrollTop / ITEM)));
      haptic(10);
      closeSheet("#modal-host-2");
      onSave(H, M);
    };
  }

  // settings row whose value (decimal hours) is edited with the HH:MM wheel picker
  function wheelRow(label, key, s, opts) {
    opts = opts || {};
    const cur0 = s[key] != null ? s[key] : 0;
    const row = h(`
      <div class="row">
        <div class="row-label">${label}${opts.hint ? `<span class="row-hint">${opts.hint}</span>` : ""}</div>
        <button class="day-val" type="button">${fmt.hoursToHM(cur0)}</button>
      </div>`);
    const chip = row.querySelector(".day-val");
    chip.onclick = () => {
      const cur = store.getSettings()[key] || 0;
      const H = Math.floor(cur), M = Math.round((cur - H) * 60);
      openTimeWheel(label, H, M, (nh, nm) => {
        const dec = nh + nm / 60;
        store.setSettings({ [key]: dec });
        chip.textContent = fmt.hoursToHM(dec);
      });
    };
    return row;
  }

  // months between the current (offset 0) cycle and the cycle around (year, monthIdx)
  function periodOffsetFor(year, monthIdx, msd) {
    const base = calc.shiftPeriod(Date.now(), msd, 0).start;
    const tgt = calc.shiftPeriod(new Date(year, monthIdx, 15), msd, 0).start;
    return (tgt.getFullYear() * 12 + tgt.getMonth()) - (base.getFullYear() * 12 + base.getMonth());
  }

  // tap the period label -> jump to any month/year quickly
  function openPeriodPicker(midDate, onPick) {
    const now = new Date();
    let yr = midDate.getFullYear();
    const curY = midDate.getFullYear(), curM = midDate.getMonth();
    const sheet = h(`
      <div class="sheet">
        <div class="sheet-grip"></div>
        <h3 class="sheet-title">מעבר לתקופה</h3>
        <div class="yr-nav">
          <button id="yr-prev" aria-label="שנה קודמת">${icoChevron("right")}</button>
          <div class="yr-label" id="yr-label">${yr}</div>
          <button id="yr-next" aria-label="שנה הבאה">${icoChevron("left")}</button>
        </div>
        <div class="mon-grid" id="mon-grid"></div>
        <div class="sheet-actions">
          <button class="btn btn-ghost" id="pp-cancel">סגירה</button>
          <button class="btn btn-soft" id="pp-today">היום</button>
        </div>
      </div>`);
    openSheet(sheet);
    const grid = $("#mon-grid", sheet), yrLabel = $("#yr-label", sheet);
    function paint() {
      yrLabel.textContent = yr;
      grid.innerHTML = "";
      for (let m = 0; m < 12; m++) {
        const b = h(`<button class="mon-btn${yr === curY && m === curM ? " on" : ""}">${fmt.monthName(m)}</button>`);
        b.onclick = () => { closeSheet(); onPick(yr, m); };
        grid.appendChild(b);
      }
    }
    paint();
    $("#yr-prev", sheet).onclick = () => { yr--; paint(); };
    $("#yr-next", sheet).onclick = () => { yr++; paint(); };
    $("#pp-cancel", sheet).onclick = () => closeSheet();
    $("#pp-today", sheet).onclick = () => { closeSheet(); onPick(now.getFullYear(), now.getMonth()); };
  }

  function numRow(label, key, s, opts) {
    opts = opts || {};
    const display = opts.percent ? Math.round(s[key] * 100) : s[key];
    const row = h(`
      <div class="row">
        <div class="row-label">${label}${opts.hint ? `<span class="row-hint">${opts.hint}</span>` : ""}</div>
        <div class="row-control">
          <input class="row-input" type="number" inputmode="decimal" value="${display}" step="${opts.step || 1}"${opts.min != null ? ` min="${opts.min}"` : ""}${opts.max != null ? ` max="${opts.max}"` : ""}/>
          ${opts.unit ? `<span class="row-unit">${opts.unit}</span>` : ""}
        </div>
      </div>`);
    const input = $("input", row);
    input.onchange = () => {
      let v = parseFloat(input.value);
      if (isNaN(v)) v = 0;
      if (opts.min != null) v = Math.max(opts.min, v);
      if (opts.max != null) v = Math.min(opts.max, v);
      if (opts.percent) v = v / 100;
      store.setSettings({ [key]: v });
      haptic(5);
    };
    return row;
  }

  function textRow(label, key, s) {
    const row = h(`
      <div class="row">
        <div class="row-label">${label}</div>
        <input class="row-input wide" type="text" value="${(s[key] || "").replace(/"/g, "&quot;")}"/>
      </div>`);
    const input = $("input", row);
    input.onchange = () => {
      store.setSettings({ [key]: input.value.trim() || store.DEFAULT_SETTINGS[key] });
      if (key === "appName") $("#header-title").textContent = input.value.trim() || "Shifty";
    };
    return row;
  }

  function toggleRow(label, key, s) {
    const row = h(`
      <div class="row">
        <div class="row-label">${label}</div>
        <label class="switch"><input type="checkbox" ${s[key] ? "checked" : ""}/><span class="slider"></span></label>
      </div>`);
    $("input", row).onchange = (e) => { store.setSettings({ [key]: e.target.checked }); haptic(5); };
    return row;
  }

  function themeRow(s) {
    const row = h(`
      <div class="row">
        <div class="row-label">ערכת נושא</div>
        <div class="segment" style="width:160px">
          <button data-t="light" class="${s.theme === "light" ? "on" : ""}">בהיר</button>
          <button data-t="dark" class="${s.theme === "dark" ? "on" : ""}">כהה</button>
        </div>
      </div>`);
    row.querySelectorAll("button").forEach((b) => {
      b.onclick = () => {
        const t = b.dataset.t;
        store.setSettings({ theme: t });
        applyTheme(t);
        row.querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
        haptic(5);
      };
    });
    return row;
  }

  function actionRow(label, value, onClick) {
    const row = h(`
      <div class="row" role="button">
        <div class="row-label">${label}</div>
        <div class="row-control"><span class="row-unit" style="color:var(--accent);font-weight:600">${value}</span></div>
      </div>`);
    row.onclick = onClick;
    return row;
  }

  /* ============================================================
     SHIFT EDITOR (sheet)
     ============================================================ */
  function openShiftEditor(id, presetDate) {
    const s = store.getSettings();
    const isNew = !id;
    const now = new Date();
    let shift = id ? store.getShift(id) : null;
    if (!shift) {
      const day = presetDate ? new Date(presetDate) : now;
      const start = new Date(day); start.setHours(9, 0, 0, 0);
      const end = new Date(day); end.setHours(17, 0, 0, 0);
      shift = { id: store.uid(), start: start.toISOString(), end: end.toISOString(), breaks: [], isHoliday: false, note: "" };
    }
    const ongoing = !shift.end;
    const breakMin = Math.round((shift.breaks || []).reduce((a, b) => {
      const be = b.end ? new Date(b.end).getTime() : Date.now();
      return a + Math.max(0, be - new Date(b.start).getTime());
    }, 0) / 60000);
    const sStart = new Date(shift.start), sEnd = ongoing ? null : new Date(shift.end);
    // mutable time state — edited via the wheel picker (chips below)
    let sH = sStart.getHours(), sM = sStart.getMinutes();
    let eH = sEnd ? sEnd.getHours() : 17, eM = sEnd ? sEnd.getMinutes() : 0;
    let hasEnd = !!sEnd;
    const dDay = fmt.pad(sStart.getDate()), dMon = fmt.pad(sStart.getMonth() + 1), dYear = sStart.getFullYear();

    const sheet = h(`
      <div class="sheet">
        <div class="sheet-grip"></div>
        <h3 class="sheet-title">${isNew ? "משמרת חדשה" : "עריכת משמרת"}</h3>

        <div class="field">
          <label>תאריך</label>
          <div class="datefield">
            <input class="df-in df-d" id="f-day" type="number" inputmode="numeric" min="1" max="31" value="${dDay}"/>
            <span class="df-sep">/</span>
            <input class="df-in df-m" id="f-mon" type="number" inputmode="numeric" min="1" max="12" value="${dMon}"/>
            <span class="df-sep">/</span>
            <input class="df-in df-y" id="f-year" type="number" inputmode="numeric" min="2000" max="2100" value="${dYear}"/>
          </div>
        </div>
        <div class="field-2">
          <div class="field"><label>שעת כניסה</label>
            <button class="timechip" id="f-start" type="button">${fmt.pad(sH)}:${fmt.pad(sM)}</button>
          </div>
          <div class="field"><label>שעת יציאה</label>
            <button class="timechip${hasEnd ? "" : " empty"}" id="f-end" type="button">${hasEnd ? fmt.pad(eH) + ":" + fmt.pad(eM) : "—"}</button>
          </div>
        </div>
        <div class="field-2">
          <div class="field"><label>הפסקה (דקות)</label><input type="number" id="f-break" inputmode="numeric" value="${breakMin}" step="5" min="0"/></div>
          <div class="field">
            <label>שבת / חג</label>
            <label class="switch" style="margin-top:8px"><input type="checkbox" id="f-holiday" ${shift.isHoliday ? "checked" : ""}/><span class="slider"></span></label>
          </div>
        </div>
        <div class="field">
          <label>הערה</label>
          <textarea id="f-note" placeholder="לא חובה">${(shift.note || "").replace(/</g, "&lt;")}</textarea>
        </div>

        <div class="sheet-actions">
          <button class="btn btn-ghost" id="f-cancel">ביטול</button>
          <button class="btn btn-primary" id="f-save">שמירה</button>
        </div>
        ${isNew ? "" : `<div class="delete-link" id="f-delete">מחיקת משמרת</div>`}
      </div>`);

    openSheet(sheet);

    $("#f-cancel", sheet).onclick = () => closeSheet();
    $("#f-start", sheet).onclick = () => openTimeWheel("שעת כניסה", sH, sM, (h, m) => {
      sH = h; sM = m; $("#f-start", sheet).textContent = fmt.pad(h) + ":" + fmt.pad(m);
    });
    $("#f-end", sheet).onclick = () => openTimeWheel("שעת יציאה", eH, eM, (h, m) => {
      eH = h; eM = m; hasEnd = true;
      const b = $("#f-end", sheet); b.textContent = fmt.pad(h) + ":" + fmt.pad(m); b.classList.remove("empty");
    });
    function readDate() {
      const dv = $("#f-day", sheet).value, mv = $("#f-mon", sheet).value, yv = $("#f-year", sheet).value;
      if (dv === "" || mv === "" || yv === "") return null;
      let d = Math.max(1, Math.min(31, parseInt(dv, 10) || 1));
      let mo = Math.max(1, Math.min(12, parseInt(mv, 10) || 1));
      let y = parseInt(yv, 10); if (isNaN(y) || y < 2000 || y > 2100) y = new Date().getFullYear();
      return { y, mo, d };
    }

    $("#f-save", sheet).onclick = () => {
      const D = readDate();
      if (!D) { toast("חסר תאריך"); return; }

      const start = new Date(D.y, D.mo - 1, D.d, sH, sM, 0, 0);
      let end = null;
      if (hasEnd) {
        end = new Date(D.y, D.mo - 1, D.d, eH, eM, 0, 0);
        if (end.getTime() <= start.getTime()) end.setDate(end.getDate() + 1); // crosses midnight
      }
      const bMin = Math.max(0, parseInt($("#f-break", sheet).value, 10) || 0);

      shift.start = start.toISOString();
      shift.end = end ? end.toISOString() : null;
      shift.isHoliday = $("#f-holiday", sheet).checked;
      shift.note = $("#f-note", sheet).value.trim();
      // represent break as a single synthetic interval
      if (bMin > 0 && end) {
        const bs = new Date(start.getTime() + 60000);
        shift.breaks = [{ start: bs.toISOString(), end: new Date(bs.getTime() + bMin * 60000).toISOString() }];
      } else if (bMin > 0 && !end) {
        const bs = new Date(start.getTime() + 60000);
        shift.breaks = [{ start: bs.toISOString(), end: new Date(bs.getTime() + bMin * 60000).toISOString() }];
      } else {
        shift.breaks = [];
      }

      store.upsertShift(shift);
      haptic(10);
      closeSheet();
      toast(isNew ? "המשמרת נוספה ✓" : "נשמר ✓");
      rerender();
    };

    if (!isNew) {
      $("#f-delete", sheet).onclick = () => {
        store.deleteShift(shift.id);
        haptic(14);
        closeSheet();
        toast("המשמרת נמחקה");
        rerender();
      };
    }
  }

  /* ---------- sheet host ---------- */
  const sheetCloseTimers = {};
  function openSheet(sheetEl, hostSel) {
    hostSel = hostSel || "#modal-host";
    const host = $(hostSel);
    clearTimeout(sheetCloseTimers[hostSel]); // cancel a pending close so reopening fast doesn't wipe the new sheet
    host.innerHTML = "";
    host.hidden = false;
    const scrim = h(`<div class="scrim"></div>`);
    scrim.onclick = () => closeSheet(hostSel);
    host.appendChild(scrim);
    host.appendChild(sheetEl);
    requestAnimationFrame(() => host.classList.add("open"));
  }
  function closeSheet(hostSel) {
    hostSel = hostSel || "#modal-host";
    const host = $(hostSel);
    host.classList.remove("open");
    clearTimeout(sheetCloseTimers[hostSel]);
    sheetCloseTimers[hostSel] = setTimeout(() => { host.hidden = true; host.innerHTML = ""; }, 300);
  }

  /* ============================================================
     BACKUP / RESTORE
     ============================================================ */
  function doExport() {
    const data = store.exportAll();
    const blob = new Blob([data], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    const stamp = fmt.toDateInput(new Date());
    a.href = url; a.download = `shifty-backup-${stamp}.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast("הגיבוי הורד ✓");
  }
  function doImport() {
    const input = document.createElement("input");
    input.type = "file"; input.accept = "application/json,.json";
    input.onchange = () => {
      const file = input.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        try {
          store.importAll(reader.result);
          applyTheme(store.getSettings().theme);
          toast("הנתונים שוחזרו ✓");
          rerender();
        } catch (e) { toast("קובץ לא תקין"); }
      };
      reader.readAsText(file);
    };
    input.click();
  }

  /* ============================================================
     ICONS / BUTTONS
     ============================================================ */
  function btn(cls, inner, onClick) {
    const b = h(`<button class="btn ${cls}">${inner}</button>`);
    b.onclick = onClick;
    return b;
  }
  function icoPlay() { return `<svg class="ico" viewBox="0 0 24 24" width="20" height="20"><path d="M7 5l12 7-12 7z" fill="currentColor" stroke="none"/></svg>`; }
  function icoStop() { return `<svg class="ico" viewBox="0 0 24 24" width="18" height="18"><rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor" stroke="none"/></svg>`; }
  function icoChevron(dir) {
    const d = dir === "left" ? "M14.5 6l-6 6 6 6" : "M9.5 6l6 6-6 6";
    return `<svg class="ico" viewBox="0 0 24 24" width="24" height="24"><path d="${d}" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  }
  function icoPlus() { return `<svg class="ico" viewBox="0 0 24 24" width="26" height="26"><path d="M12 5v14M5 12h14" stroke-linecap="round"/></svg>`; }
  function icoCaret() { return `<svg class="ico caret" viewBox="0 0 24 24" width="15" height="15"><path d="M7 10l5 5 5-5" stroke-linecap="round" stroke-linejoin="round"/></svg>`; }

  /* ============================================================
     ROUTER + HEADER + TICKER
     ============================================================ */
  function setView(view) {
    state.view = view;
    document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.view === view));
    updateHeader();
    if (view === "now") renderNow();
    else if (view === "shifts") renderShifts();
    else if (view === "calendar") renderCalendar();
    else renderSettings();
  }

  function updateHeader() {
    const action = $("#header-action");
    if (state.view === "shifts" || state.view === "calendar") {
      action.innerHTML = icoPlus();
      action.style.color = "var(--accent)";
      action.onclick = () => openShiftEditor(null);
    } else {
      action.innerHTML = "";
      action.onclick = null;
    }
  }

  function rerender() {
    if (state.view === "now") renderNow();
    else if (state.view === "shifts") renderShifts();
    else if (state.view === "calendar") renderCalendar();
    else renderSettings();
  }

  function startTicker() {
    if (state.tick) clearInterval(state.tick);
    state.tick = setInterval(() => {
      if (state.live.mode === "now") updateNow();
      else if (state.live.mode === "shifts") updateShiftsLive();
    }, 1000);
  }

  /* ---------- boot ---------- */
  function init() {
    const s = store.getSettings();
    applyTheme(s.theme);
    $("#header-title").textContent = s.appName || "Shifty";
    $("#theme-toggle").onclick = toggleTheme;

    document.querySelectorAll(".tab").forEach((t) => {
      t.onclick = () => { haptic(); setView(t.dataset.view); };
    });

    setView("now");
    startTicker();

    // re-sync on resume (e.g. returning to PWA)
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) rerender();
    });

    // optional cloud sync. Status flips update only the small card in place (never
    // the data views); auth transitions re-render settings; applied remote data
    // refreshes the relevant list view. The Now screen is never re-rendered here —
    // its 1s ticker already reflects any local change.
    if (Shifty.cloud) {
      Shifty.cloud.onStatus = updateCloudStatus;
      Shifty.cloud.onAuth = () => { if (state.view === "settings") renderSettings(); };
      Shifty.cloud.onData = () => {
        if (state.view === "shifts" || state.view === "calendar") rerender();
        else if (state.view === "settings") renderSettings();
      };
      Shifty.cloud.init();
    }

    // service worker (PWA / offline)
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("sw.js").catch(() => {});
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
