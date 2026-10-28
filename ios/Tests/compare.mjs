// Holds the Swift engine's results (actual.json, from CalcCheck) against the web app's (expected.json,
// from calc-cases.mjs), check by check: numbers within a billionth, everything else identical.
// node ios/Tests/compare.mjs <dir>
import fs from "node:fs";
import path from "node:path";

const dir = process.argv[2];
const read = (name) => JSON.parse(fs.readFileSync(path.join(dir, name), "utf8"));
const { checks } = read("cases.json");
const expected = read("expected.json");
const actual = read("actual.json");
if (expected.length !== checks.length || actual.length !== checks.length) {
  console.error(`${checks.length} checks, ${expected.length} results of the web app, ${actual.length} of Swift`);
  process.exit(1);
}

const kinds = {};
const shown = [];
let different = 0, inexact = 0, largest = 0;
for (let i = 0; i < checks.length; i++) {
  const kind = checks[i].kind;
  const k = kinds[kind] || (kinds[kind] = { checks: 0, different: 0 });
  k.checks++;
  const e = expected[i], a = actual[i];
  const wrong = [];
  for (const key of new Set([...Object.keys(e), ...Object.keys(a)])) {
    const x = e[key] ?? null, y = a[key] ?? null;
    if (x === y) continue;
    if (typeof x === "number" && typeof y === "number") {
      const diff = Math.abs(x - y);
      largest = Math.max(largest, diff);
      if (diff <= 1e-9 * Math.max(1, Math.abs(x))) { inexact++; continue; }
    }
    wrong.push(`${key}: web ${JSON.stringify(x)}, Swift ${JSON.stringify(y)}`);
  }
  if (wrong.length) {
    different++;
    k.different++;
    if (shown.length < 25) shown.push(`#${i} ${JSON.stringify(checks[i])}\n    ${wrong.join("\n    ")}`);
  }
}

for (const [kind, k] of Object.entries(kinds)) {
  console.log(`${kind.padEnd(10)} ${String(k.checks).padStart(6)} checks  ${k.different ? k.different + " different" : "equal"}`);
}
console.log(`${checks.length} checks: ${different} different; ${inexact} numbers equal within a billionth but not to the last bit (largest difference ${largest})`);
if (shown.length) console.log(shown.join("\n"));
process.exit(different ? 1 : 0);
