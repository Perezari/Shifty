/* ============================================================
   Shifty — formatting helpers (Hebrew / RTL aware)
   Exposes window.Shifty.fmt
   ============================================================ */
(function () {
  const Shifty = (window.Shifty = window.Shifty || {});

  const DOW = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"];
  const MONTHS = [
    "ינואר", "פברואר", "מרץ", "אפריל", "מאי", "יוני",
    "יולי", "אוגוסט", "ספטמבר", "אוקטובר", "נובמבר", "דצמבר",
  ];

  function pad(n) { return String(n).padStart(2, "0"); }

  // "07:10"
  function clock(d) {
    d = new Date(d);
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
  }

  // ms -> "04:52:56"  (with seconds)
  function hms(ms) {
    if (ms < 0) ms = 0;
    const t = Math.floor(ms / 1000);
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60);
    const s = t % 60;
    return pad(h) + ":" + pad(m) + ":" + pad(s);
  }

  // hours (number) -> "8:41"
  function hoursToHM(hours) {
    if (!hours || hours < 0) hours = 0;
    const total = Math.round(hours * 60);
    const h = Math.floor(total / 60);
    const m = total % 60;
    return h + ":" + pad(m);
  }

  // hours -> "8.5 שע׳" style short
  function hoursShort(hours) {
    return hoursToHM(hours) + " שע׳";
  }

  // money -> "₪ 442.72"
  function money(n, symbol) {
    symbol = symbol || "₪";
    const v = Math.round((n + Number.EPSILON) * 100) / 100;
    const str = v.toLocaleString("he-IL", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    return symbol + " " + str;
  }
  function moneyShort(n, symbol) {
    symbol = symbol || "₪";
    const v = Math.round(n);
    return symbol + " " + v.toLocaleString("he-IL");
  }

  // "21/6" small, "21 ביוני" long
  function dayMonth(d) {
    d = new Date(d);
    return d.getDate() + "/" + (d.getMonth() + 1);
  }
  function dateLong(d) {
    d = new Date(d);
    return d.getDate() + " ב" + MONTHS[d.getMonth()];
  }
  function dateFull(d) {
    d = new Date(d);
    return "יום " + DOW[d.getDay()] + ", " + d.getDate() + " ב" + MONTHS[d.getMonth()] + " " + d.getFullYear();
  }
  function dow(d) { return "יום " + DOW[new Date(d).getDay()]; }
  function dowShort(d) { return DOW[new Date(d).getDay()]; }
  function monthName(m) { return MONTHS[m]; }

  // for <input type="datetime-local">
  function toLocalInput(d) {
    d = new Date(d);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) +
      "T" + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }
  function toTimeInput(d) {
    d = new Date(d);
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
  }
  function toDateInput(d) {
    d = new Date(d);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }

  Shifty.fmt = {
    pad, clock, hms, hoursToHM, hoursShort, money, moneyShort,
    dayMonth, dateLong, dateFull, dow, dowShort, monthName,
    toLocalInput, toTimeInput, toDateInput, DOW, MONTHS,
  };
})();
