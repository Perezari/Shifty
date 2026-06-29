/* ============================================================
   Shifty — Israeli holiday detection (offline, any year)
   Uses the browser's built-in Hebrew calendar (Intl) — no data tables.
   Exposes window.Shifty.holidays.info(date) -> { type, name }
     type: "short" (erev chag / Yom HaZikaron — shortened workday)
         | "chag"  (yom tov / Yom Ha'atzmaut — marked, no calc effect)
         | null    (regular day)
   ============================================================ */
(function () {
  const Shifty = (window.Shifty = window.Shifty || {});

  let hf = null;
  function hebParts(date) {
    if (!hf) hf = new Intl.DateTimeFormat("en-u-ca-hebrew", { day: "numeric", month: "long" });
    const p = hf.formatToParts(date);
    return { m: p.find((x) => x.type === "month").value, d: +p.find((x) => x.type === "day").value };
  }

  // religious holidays keyed by "<HebrewMonth>-<day>"
  const EREV = { // shortened workday
    "Elul-29": "ערב ראש השנה",
    "Tishri-9": "ערב יום כיפור",
    "Tishri-14": "ערב סוכות",
    "Tishri-21": "ערב שמחת תורה",
    "Nisan-14": "ערב פסח",
    "Nisan-20": "ערב שביעי של פסח",
    "Sivan-5": "ערב שבועות",
  };
  const CHAG = { // yom tov — off, marked only
    "Tishri-1": "ראש השנה", "Tishri-2": "ראש השנה",
    "Tishri-10": "יום כיפור",
    "Tishri-15": "סוכות",
    "Tishri-22": "שמחת תורה",
    "Nisan-15": "פסח",
    "Nisan-21": "שביעי של פסח",
    "Sivan-6": "שבועות",
  };

  function key(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate(); }

  // Yom HaZikaron / Yom Ha'atzmaut move to avoid adjoining Shabbat — compute per year.
  const natCache = {};
  function findIyar5(year) {
    for (let mo = 3; mo <= 5; mo++) { // April..June
      for (let day = 1; day <= 31; day++) {
        const dt = new Date(year, mo, day);
        if (dt.getMonth() !== mo) break;
        const h = hebParts(dt);
        if (h.m === "Iyar" && h.d === 5) return dt;
      }
    }
    return null;
  }
  function national(year) {
    if (natCache[year]) return natCache[year];
    const base = findIyar5(year);
    let res = { zik: "", atz: "" };
    if (base) {
      const wd = base.getDay(); // 0=Sun..6=Sat
      const atz = new Date(base);
      if (wd === 1) atz.setDate(atz.getDate() + 1);       // Mon -> Tue (postponed)
      else if (wd === 5) atz.setDate(atz.getDate() - 1);  // Fri -> Thu
      else if (wd === 6) atz.setDate(atz.getDate() - 2);  // Sat -> Thu
      else if (wd === 0) atz.setDate(atz.getDate() + 1);  // Sun -> Mon (guard)
      const zik = new Date(atz); zik.setDate(zik.getDate() - 1);
      res = { zik: key(zik), atz: key(atz) };
    }
    return (natCache[year] = res);
  }

  function info(date) {
    const d = new Date(date);
    const h = hebParts(d);
    const hk = h.m + "-" + h.d;
    if (EREV[hk]) return { type: "short", name: EREV[hk] };
    if (CHAG[hk]) return { type: "chag", name: CHAG[hk] };
    const nat = national(d.getFullYear());
    const dk = key(d);
    if (nat.zik === dk) return { type: "short", name: "יום הזיכרון" };
    if (nat.atz === dk) return { type: "chag", name: "יום העצמאות" };
    return { type: null, name: null };
  }

  Shifty.holidays = { info };
})();
