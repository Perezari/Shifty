/* The openings' engine: an iPhone showing the app's Now screen, and a kit `K` each scene draws with.

   A scene is registered with Opening.scene({ id, chip, title, about, end, rest, haptics, draw(t, K) }):
     id       a short Latin name                       chip    the picker's word (Hebrew)
     title    the scene's name, with a full stop       about   what happens, in plain Hebrew
     end      the moment (seconds) the loop starts again: the last motion's end + about 1.6 s of the Now screen
     rest     a moment at which everything has settled (for Reduce Motion and for still pictures)
     haptics  [[seconds, 'light' | 'medium' | 'rigid' | 'success'], ...], the iPhone's taps (shown beside the phone)
     draw     draws the whole frame of the moment t (seconds since the opening began; t <= 0 is the launch picture)

   Every frame starts clean: both canvases cleared, every part of the Now screen hidden, and the scene draws all
   that is seen. Two canvases: K.g under the Now screen's parts (the dial belongs there) and K.o over them (the icon,
   the man, effects). Both are in the screen's points: 402 x 874, x to the right, y down. */
window.Opening = (() => {
  const W = 402, H = 874;
  const RIG = window.RIG, P = RIG.points;
  const C = {
    teal: '#0F9D8F', navy: '#0A1435', yellow: '#FEC802', bg: '#F4F5F7', card: '#FFFFFF', ink: '#0B0C0E', gray: '#6C7077',
    orange: '#FF9500', red: '#FF3B30', groundTop: '#FFFFFF', groundBottom: '#ECEFF6', skin: '#FDDDC1', hair: '#1B3168',
  };
  // The launch picture: the icon, 120 points, its corner 27, in the screen's middle
  const LAUNCH = { x: 201, y: 437, size: 120, r: 27 };
  // The Now screen's dial: its middle, the ring's radius and width; a shift since 08:30 (255 degrees clockwise from 12),
  // now 171 degrees on, its goal 252 degrees on
  const DIAL = { x: 201, y: 293, r: 160, w: 22, start: 255, now: 171, goal: 252 };
  // The logo's nine ticks on the icon's 512 grid, clockwise from 12; their circle's middle and radius
  const TC = { x: 256, y: 243.6, r: 203 };
  const clockDeg = t => (Math.atan2((t[0] + t[2]) / 2 - TC.x, TC.y - (t[1] + t[3]) / 2) * 180 / Math.PI + 360) % 360;
  const TICKS = RIG.ticks.map(t => ({ x1: t[0], y1: t[1], x2: t[2], y2: t[3], w: t[4], cx: (t[0] + t[2]) / 2, cy: (t[1] + t[3]) / 2, deg: clockDeg(t) }))
    .sort((a, b) => a.deg - b.deg);
  const HOURS = [0, 30, 60, 90, 120, 240, 270, 300, 330];   // the hour each of them stands at, in degrees
  TICKS.forEach((t, i) => { t.hour = HOURS[i]; });

  // ---- numbers
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const E = {
    lin: t => t,
    in2: t => t * t, in3: t => t * t * t,
    out2: t => 1 - (1 - t) * (1 - t), out3: t => 1 - Math.pow(1 - t, 3), out4: t => 1 - Math.pow(1 - t, 4), out5: t => 1 - Math.pow(1 - t, 5),
    io2: t => t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2,
    io3: t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
    back: t => { const c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
    backIn: t => { const c = 1.9; return (c + 1) * t * t * t - c * t * t; },
  };
  // How far a move from the moment a to the moment b has come at t, from 0 to 1, on the curve e
  const seg = (t, a, b, e = E.lin) => e(clamp((t - a) / (b - a)));
  // A spring let go at the moment a: from 0 to 1, overshooting and settling. `period` is one swing's seconds, `damping`
  // from 0 (rings on) to 1 (no overshoot)
  const spring = (t, a, period = .45, damping = .45) => {
    const x = t - a;
    if (x <= 0) return 0;
    const w = 2 * Math.PI / period, z = damping;
    if (z >= 1) return 1 - Math.exp(-w * x) * (1 + w * x);
    const wd = w * Math.sqrt(1 - z * z);
    return 1 - Math.exp(-z * w * x) * (Math.cos(wd * x) + z * w / wd * Math.sin(wd * x));
  };
  // A swing that dies away, begun at the moment a: 0, then to and fro round 0 (for a wobble after a move)
  const wobble = (t, a, period = .3, decay = 6) => t <= a ? 0 : Math.sin((t - a) * 2 * Math.PI / period) * Math.exp(-(t - a) * decay);
  const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const mix = (a, b, t) => { const x = hex(a), y = hex(b); return `rgb(${x.map((v, i) => Math.round(lerp(v, y[i], clamp(t)))).join(',')})`; };
  const rgba = (h, a) => `rgba(${hex(h).join(',')},${a})`;
  const rad = deg => (deg - 90) * Math.PI / 180;                       // degrees clockwise from 12, as canvas radians
  const at = (x, y, deg, r) => [x + r * Math.cos(rad(deg)), y + r * Math.sin(rad(deg))];
  const pad = n => String(Math.floor(n)).padStart(2, '0');
  const timer = s => `${Math.floor(s / 3600)}:${pad(s / 60 % 60)}:${pad(s % 60)}`;

  // ---- the layers' pictures, loaded once
  const pictures = {};
  const ready = Promise.all([...Object.keys(RIG.layers), 'man'].map(name => new Promise(done => {
    const img = new Image();
    img.onload = img.onerror = done;
    img.src = (window.OPENING_ASSETS && window.OPENING_ASSETS[name]) || `assets/${name}.png`;
    pictures[name] = img;
  })));

  const scenes = [];
  const scene = s => { scenes.push(s); return s; };

  const PARTS = ['cap', 'center', 'facts', 'buttons', 'week', 'tabs'];
  const MARKUP = `
    <canvas class="base"></canvas>
    <div class="now">
      <div class="cap part" data-part="cap"><i></i><span>במשמרת</span></div>
      <div class="center part" data-part="center">
        <div class="day">יום חמישי, 12 בנובמבר</div>
        <div class="time">5:42:18</div>
        <div class="pay">₪ 308</div>
      </div>
      <div class="ui facts part" data-part="facts">
        <div><b>08:30</b><span>התחלה</span></div>
        <div><b>16:54</b><span>יעד · עוד 2:42</span></div>
        <div><b>₪ 454</b><span>צפי ביעד</span></div>
      </div>
      <div class="ui buttons part" data-part="buttons">
        <div class="btn b1"><svg width="15" height="16" viewBox="0 0 15 16" aria-hidden="true"><rect x="1.5" y="1" width="4" height="14" rx="1.2" fill="#FF9500"/><rect x="9.5" y="1" width="4" height="14" rx="1.2" fill="#FF9500"/></svg>הפסקה</div>
        <div class="btn b2"><svg width="15" height="16" viewBox="0 0 15 16" aria-hidden="true"><rect x="1.5" y="2" width="12" height="12" rx="2.4" fill="#FF3B30"/></svg>סיום משמרת</div>
      </div>
      <div class="ui week part" data-part="week">
        <div class="head"><b>השבוע</b><i></i><span>27:45 שעות</span></div>
        <div class="cols">${[['א', 1], ['ב', 1], ['ג', 1], ['ד', .94], ['ה', .68], ['ו', 0, 1], ['ש', 0, 1]].map(([d, h, off]) =>
          `<div class="col"><div class="track${off ? ' off' : ''}"><div class="bar" style="height:${66 * h}px"></div></div><u>${d}</u></div>`).join('')}</div>
      </div>
      <div class="ui tabs part" data-part="tabs">${['עכשיו', 'משמרות', 'לוח', 'הגדרות'].map((w, i) => `<div><svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">${[
        '<circle cx="11" cy="12.5" r="7.5" fill="none" stroke="currentColor" stroke-width="2"/><path d="M11 8.5v4l2.5 1.6M8.5 2h5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
        '<path d="M8 6h11M8 11h11M8 16h11" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="4" cy="6" r="1.3" fill="currentColor"/><circle cx="4" cy="11" r="1.3" fill="currentColor"/><circle cx="4" cy="16" r="1.3" fill="currentColor"/>',
        '<rect x="3" y="4.5" width="16" height="15" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3 9.5h16M7.5 2.5v4M14.5 2.5v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
        '<circle cx="11" cy="11" r="3.2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="11" cy="11" r="8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-dasharray="3 3.3"/>'][i]}</svg>${w}</div>`).join('')}</div>
    </div>
    <canvas class="over"></canvas>
    <div class="island"></div>`;

  /* One iPhone. `scale` is its size against the real 402 x 874; `view` shows only a part of the screen, larger:
     { x, y, w, h } in the screen's points. */
  function phone(host, { scale = 1, view = null, dpr = Math.min(window.devicePixelRatio || 1, 3) } = {}) {
    const root = document.createElement('div');
    root.className = 'phone';
    const screen = document.createElement('div');
    screen.className = 'screen';
    screen.innerHTML = MARKUP;
    root.appendChild(screen);
    host.appendChild(root);
    const base = screen.querySelector('.base'), over = screen.querySelector('.over');
    const g = base.getContext('2d'), o = over.getContext('2d');
    const parts = Object.fromEntries(PARTS.map(id => [id, screen.querySelector(`[data-part="${id}"]`)]));
    const timeText = screen.querySelector('.time'), payText = screen.querySelector('.pay');
    let unit = 1;

    function size(s) {
      scale = s;
      const m = scale * dpr;
      unit = m;
      for (const c of [base, over]) { c.width = Math.round(W * m); c.height = Math.round(H * m); }
      if (view) {
        root.style.width = view.w * scale + 'px'; root.style.height = view.h * scale + 'px';
        root.style.borderRadius = '10px';
        screen.style.transform = `translate(${-view.x * scale}px, ${-view.y * scale}px) scale(${scale})`;
      } else {
        root.style.width = W * scale + 'px'; root.style.height = H * scale + 'px';
        root.style.borderRadius = 56 * scale + 'px';
        root.style.setProperty('--s', scale);
        screen.style.transform = `scale(${scale})`;
      }
    }
    size(scale);

    // ---------------------------------------------------------------- the kit
    const K = {
      W, H, LAUNCH, DIAL, TICKS, HOURS, TC, P, C, E, seg, spring, wobble, lerp, clamp, mix, rgba, rad, at, g, o,
      PARTS,
      get unit() { return unit; },
    };

    /* The Now screen's dial, as the app draws it, on K.g.
       op: cx, cy    its middle (the dial's own place by default)        k       its size (1)
           alpha     all of it (1)                                        track   the pale track under the ring (1)
           reveal    how much of the track and ticks is drawn, in degrees clockwise from 12 (360)
           tick(i)   for each of the 60 ticks (i * 6 degrees): { k: its length's share, a: its alpha } (all there)
           numerals  the 12, 3, 6, 9 (1)
           span      the worked arc's length in degrees from the start mark (the day's: DIAL.now); `from`: its start
           color     the worked arc's color (teal)                        ahead   the pale arc from now to the goal (1)
           marks     [start mark, now knob, goal flag], each a size from 0 to 1 ([1, 1, 1])
           ctx       another canvas to draw on (K.g) */
    K.dial = (op = {}) => {
      const ctx = op.ctx || g, x = op.cx ?? DIAL.x, y = op.cy ?? DIAL.y, k = op.k ?? 1;
      const r = DIAL.r, w = DIAL.w, reveal = op.reveal ?? 360, span = op.span ?? DIAL.now, from = op.from ?? DIAL.start;
      ctx.save();
      ctx.globalAlpha *= op.alpha ?? 1;
      ctx.translate(x, y); ctx.scale(k, k);
      const arc = (a, b, color, width = w) => {
        if (b <= a) return;
        ctx.beginPath(); ctx.arc(0, 0, r, rad(a), rad(Math.min(b, a + 360)));
        ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineCap = 'butt'; ctx.stroke();
      };
      if ((op.track ?? 1) > 0 && reveal > 0) arc(0, Math.min(reveal, 360), `rgba(0,0,0,${.06 * (op.track ?? 1)})`);
      for (let i = 0; i < 60; i++) {
        if (i * 6 > reveal) continue;
        const fx = op.tick ? op.tick(i) : null, tk = fx?.k ?? 1, ta = fx?.a ?? 1;
        if (ta <= 0 || tk <= 0) continue;
        const [[x1, y1], [x2, y2]] = K.tickEnds(i * 6, i % 5 === 0, tk, 0, 0);
        ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2);
        ctx.strokeStyle = `rgba(60,60,67,${(i % 5 === 0 ? .6 : .27) * ta})`; ctx.lineWidth = i % 5 === 0 ? 2 : 1.5; ctx.lineCap = 'round'; ctx.stroke();
      }
      const nums = op.numerals ?? 1;
      if (nums > 0) {
        ctx.font = '600 13px ui-rounded, -apple-system, Heebo, sans-serif';
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = `rgba(60,60,67,${.42 * nums})`;
        for (const h of [12, 3, 6, 9]) { const [nx, ny] = at(0, 0, (h % 12) * 30, 120); ctx.fillText(String(h), nx, ny); }
      }
      const ahead = op.ahead ?? 1;
      if (ahead > 0) arc(DIAL.start + Math.max(span, 0), DIAL.start + DIAL.goal, `rgba(15,157,143,${.18 * ahead})`);
      if (span > 0) arc(from, from + span, op.color || C.teal);
      const marks = op.marks || [1, 1, 1];
      const pop = (s, deg, fn) => { if (s <= 0) return; const [px, py] = at(0, 0, deg, r); ctx.save(); ctx.translate(px, py); ctx.scale(s, s); fn(); ctx.restore(); };
      pop(marks[0], DIAL.start, () => K.startMark(ctx));
      pop(marks[1], op.knobAt ?? DIAL.start + DIAL.now, () => K.knob(ctx));
      pop(marks[2], DIAL.start + DIAL.goal, () => K.flag(ctx));
      ctx.restore();
    };
    // The two ends of a tick of the dial at `deg`, long or short, on the screen (or round cx, cy)
    K.tickEnds = (deg, big, k = 1, cx = DIAL.x, cy = DIAL.y) => {
      const mid = DIAL.r - DIAL.w / 2 - (big ? 11.5 : 9), len = (big ? 9 : 4) * k;
      return [at(cx, cy, deg, mid - len / 2), at(cx, cy, deg, mid + len / 2)];
    };
    // The dial's three marks, each drawn round 0, 0 of the canvas as it is (translate and scale first)
    K.startMark = (ctx = g) => {
      ctx.fillStyle = C.teal; ctx.beginPath(); ctx.arc(0, 0, 11, 0, 7); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.moveTo(-3, -4.6); ctx.lineTo(5, 0); ctx.lineTo(-3, 4.6); ctx.fill();
    };
    K.knob = (ctx = g) => {
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.22)'; ctx.shadowBlur = 7 * unit; ctx.shadowOffsetY = 4 * unit;
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, 0, 16, 0, 7); ctx.fill(); ctx.restore();
      ctx.strokeStyle = C.teal; ctx.lineWidth = 3.5; ctx.beginPath(); ctx.arc(0, 0, 14.25, 0, 7); ctx.stroke();
      ctx.fillStyle = C.teal; ctx.beginPath(); ctx.arc(0, 0, 4.5, 0, 7); ctx.fill();
    };
    K.flag = (ctx = g) => {
      ctx.fillStyle = 'rgba(15,157,143,.2)'; ctx.beginPath(); ctx.arc(0, 0, 21, 0, 7); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, 0, 15, 0, 7); ctx.fill();
      ctx.strokeStyle = C.teal; ctx.lineWidth = 1.8; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(-4, -6.5); ctx.lineTo(-4, 7); ctx.stroke();
      ctx.fillStyle = C.teal; ctx.beginPath(); ctx.moveTo(-3.4, -6.5); ctx.lineTo(6, -3.6); ctx.lineTo(-3.4, -.6); ctx.fill();
    };
    // Where the dial's marks stand on the screen: 'start', 'now', 'goal'
    K.markAt = which => at(DIAL.x, DIAL.y, DIAL.start + (which === 'start' ? 0 : which === 'now' ? DIAL.now : DIAL.goal), DIAL.r);

    /* The app's own way of finishing, from the moment T (about 0.9 s): the whole ring in teal unwinds to the day, the
       60 ticks come in as a wave from 12, the three marks pop up. `op` goes on to K.dial. Nothing before T. */
    K.settle = (t, T, op = {}) => {
      if (t < T) return;
      const unwind = seg(t, T, T + .7, E.io3);
      const pop = d => seg(t, T + d, T + d + .26, E.back);
      K.dial({
        span: lerp(360, DIAL.now, unwind), ahead: unwind, marks: [pop(.5), pop(.58), pop(.66)],
        tick: i => ({ k: seg(t, T + i / 60 * .45, T + i / 60 * .45 + .24, E.back), a: seg(t, T + i / 60 * .45, T + i / 60 * .45 + .12) }),
        ...op,
      });
    };

    /* The Now screen's parts (K.PARTS: 'cap' the capsule on top, 'center' the words in the dial, 'facts', 'buttons',
       'week', 'tabs'). K.part sets one: how much of it is there (0 to 1), and how far it is moved (points) or scaled. */
    K.part = (id, shown, dy = 0, more = {}) => {
      const e = parts[id];
      e.style.opacity = clamp(shown);
      e.style.translate = `${more.dx || 0}px ${dy}px`;
      e.style.scale = more.scale ?? 1;
    };
    // All of them rising one after another from the moment T, as the app brings them: each over `dur` seconds from
    // `rise` points below, `gap` seconds apart. `order` picks which and in what order.
    K.parts = (t, T, { gap = .08, dur = .45, rise = 46, order = PARTS } = {}) => {
      order.forEach((id, i) => {
        const shown = seg(t, T + i * gap, T + i * gap + dur, E.out3);
        K.part(id, shown, (1 - shown) * rise);
      });
    };

    /* The icon's square: its middle on the screen, its side, its corner's radius. Returns the box the icon's parts are
       drawn in: box.k points to one unit of the icon's 512 grid, box.pt(x, y) a grid point on the screen. */
    K.box = (cx = LAUNCH.x, cy = LAUNCH.y, size = LAUNCH.size, r = null) => {
      const x = cx - size / 2, y = cy - size / 2, k = size / 512;
      return { cx, cy, size, r: r ?? size * LAUNCH.r / LAUNCH.size, x, y, k, pt: (gx, gy) => [x + gx * k, y + gy * k] };
    };
    K.path = (ctx, box, inset = 0) => {
      ctx.beginPath();
      const r = Math.max(0, Math.min(box.r - inset, box.size / 2 - inset));
      ctx.roundRect(box.x + inset, box.y + inset, box.size - 2 * inset, box.size - 2 * inset, r);
    };
    /* The icon's ground: white going a little grey downward, as the app's own icon.
       op: toward [color, share]  mixes it into a color        alpha        (1)
           hairline               the faint line inside its edge, as the launch picture has (1)
           shadow [blur, dy, alpha]  a shadow under it (none) */
    K.ground = (ctx, box, op = {}) => {
      const [color, share] = op.toward || [C.teal, 0];
      ctx.save();
      ctx.globalAlpha *= op.alpha ?? 1;
      const fill = ctx.createLinearGradient(0, box.y, 0, box.y + box.size);
      fill.addColorStop(0, mix(C.groundTop, color, share)); fill.addColorStop(1, mix(C.groundBottom, color, share));
      if (op.shadow) { ctx.shadowColor = `rgba(10,20,53,${op.shadow[2]})`; ctx.shadowBlur = op.shadow[0] * unit; ctx.shadowOffsetY = op.shadow[1] * unit; }
      K.path(ctx, box); ctx.fillStyle = fill; ctx.fill();
      ctx.shadowColor = 'transparent';
      const hair = op.hairline ?? 1;
      if (hair > 0) {
        const inset = 1.1 * box.size / 512;
        K.path(ctx, box, inset); ctx.strokeStyle = `rgba(0,0,0,${.07 * hair})`; ctx.lineWidth = 2.2 * box.size / 512; ctx.stroke();
      }
      ctx.restore();
    };
    // Everything drawn inside fn is cut to the icon's rounded square
    K.clip = (ctx, box, fn) => { ctx.save(); K.path(ctx, box); ctx.clip(); fn(); ctx.restore(); };

    /* The logo's nine ticks, in the icon's square. fn(i, tick) may change each (i from 0, clockwise from 12; tick.deg its
       angle, tick.hour the hour it stands at in degrees): { a: alpha, len: its length's share, w: its width's share,
       color, out: moved outward along its ray (grid units), dx, dy (grid units), rot: turned round its middle (degrees) };
       null hides it. */
    K.ticks = (ctx, box, fn = null, color = C.navy) => {
      ctx.save();
      ctx.translate(box.x, box.y); ctx.scale(box.k, box.k);
      TICKS.forEach((tk, i) => {
        const f = fn ? fn(i, tk) : {};
        if (f === null || (f.a ?? 1) <= 0) return;
        const ux = (tk.cx - TC.x) / Math.hypot(tk.cx - TC.x, tk.cy - TC.y), uy = (tk.cy - TC.y) / Math.hypot(tk.cx - TC.x, tk.cy - TC.y);
        const half = Math.hypot(tk.x2 - tk.x1, tk.y2 - tk.y1) / 2 * (f.len ?? 1);
        const mx = tk.cx + ux * (f.out || 0) + (f.dx || 0), my = tk.cy + uy * (f.out || 0) + (f.dy || 0);
        const a = Math.atan2(tk.y2 - tk.y1, tk.x2 - tk.x1) + (f.rot || 0) * Math.PI / 180;
        ctx.globalAlpha = f.a ?? 1;
        ctx.beginPath();
        ctx.moveTo(mx - Math.cos(a) * half, my - Math.sin(a) * half); ctx.lineTo(mx + Math.cos(a) * half, my + Math.sin(a) * half);
        ctx.strokeStyle = f.color || color; ctx.lineWidth = tk.w * (f.w ?? 1); ctx.lineCap = 'round'; ctx.stroke();
      });
      ctx.restore();
    };
    // A tick of the logo on the screen, in the icon's square: its two ends and its width, in points
    K.tickOnScreen = (box, i) => {
      const tk = TICKS[i];
      return { a: box.pt(tk.x1, tk.y1), b: box.pt(tk.x2, tk.y2), w: tk.w * box.k, mid: box.pt(tk.cx, tk.cy) };
    };

    const moveBy = (ctx, T, pivot) => {
      if (!T) return;
      const [px, py] = T.pivot || pivot;
      ctx.translate(px + (T.dx || 0), py + (T.dy || 0));
      if (T.rot) ctx.rotate(T.rot * Math.PI / 180);
      const s = T.s ?? 1;
      ctx.scale((T.sx ?? 1) * s, (T.sy ?? 1) * s);
      ctx.translate(-px, -py);
    };
    const put = (ctx, name, T, pivot) => {
      const L = RIG.layers[name], img = pictures[name];
      if (!img || !img.naturalWidth || (T && (T.alpha ?? 1) <= 0)) return;
      ctx.save();
      if (T) { ctx.globalAlpha *= T.alpha ?? 1; moveBy(ctx, T, pivot || [L.x + L.w / 2, L.y + L.h / 2]); }
      ctx.drawImage(img, L.x, L.y, L.w, L.h);
      ctx.restore();
    };
    const middle = name => { const L = RIG.layers[name]; return [L.x + L.w / 2, L.y + L.h / 2]; };
    const still = T => !T || Object.keys(T).every(k => (k === 'alpha' && T[k] === 1) || ((k === 's' || k === 'sx' || k === 'sy') ? T[k] === 1 : !T[k]));

    /* The man, in the icon's square, each part moved on its own. Every move is { dx, dy (grid units, 512 to the icon's
       side), rot (degrees, clockwise), s, sx, sy (scale), alpha, pivot: [x, y] } about the part's own pivot:
         all     the whole man, about the neck                 body    the shirt (the bow tie goes with it)
         head    the head with its face, about the neck (K.P.neck)
         brows   both eyebrows (or browL, browR)                eyes    both eyes (or eyeL, eyeR); eyes.open from 0
                 (the smiling arcs) to 1 (two friendly dots)
         stache  the mustache, about its middle (K.P.stache); stache.split turns its two halves about the middle,
                 degrees, their tips up when positive
         bow     the bow tie with its knot, about the knot (K.P.knot)     wings, knot   each alone
         hide    names of parts not to draw: 'body', 'head', 'brows', 'eyes', 'stache', 'bow', 'wings', 'knot'
       With nothing moved it is the launch picture's man to the pixel. Under the bow tie the shirt goes on to a round
       collar with the neck above it; under the mustache, the brows and the eyes the skin goes on. */
    K.man = (ctx, box, pose = {}) => {
      const hide = new Set(pose.hide || []);
      ctx.save();
      ctx.translate(box.x, box.y); ctx.scale(box.k, box.k);
      ctx.globalAlpha *= pose.alpha ?? 1;
      const moves = ['all', 'body', 'head', 'brows', 'browL', 'browR', 'eyes', 'eyeL', 'eyeR', 'stache', 'bow', 'wings', 'knot'];
      if (!hide.size && moves.every(m => still(pose[m]) && ((pose[m] || {}).alpha ?? 1) === 1) && !(pose.eyes && pose.eyes.open) && !(pose.stache && pose.stache.split)) {
        const img = pictures.man;
        if (img && img.naturalWidth) ctx.drawImage(img, 0, 0, 512, 512);
        ctx.restore();
        return;
      }
      moveBy(ctx, pose.all, P.neck);
      ctx.save();
      moveBy(ctx, pose.body, [256, 512]);
      if (!hide.has('body')) put(ctx, 'body', { alpha: (pose.body || {}).alpha });
      ctx.restore();
      // the head and its face
      ctx.save();
      moveBy(ctx, pose.body, [256, 512]);
      moveBy(ctx, pose.head, P.neck);
      if (!hide.has('head')) {
        put(ctx, 'head', { alpha: (pose.head || {}).alpha });
        if (!hide.has('brows')) for (const b of ['browL', 'browR']) {
          ctx.save(); ctx.globalAlpha *= (pose.brows || {}).alpha ?? 1; moveBy(ctx, pose.brows, P[b]); put(ctx, b, pose[b] || {}, P[b]); ctx.restore();
        }
        if (!hide.has('eyes')) for (const e of ['eyeL', 'eyeR']) {
          // opening: the smiling arc flattens to a line, and from the line a round eye grows
          const own = pose[e] || {}, open = clamp(own.open ?? ((pose.eyes && pose.eyes.open) || 0));
          ctx.save(); ctx.globalAlpha *= (pose.eyes || {}).alpha ?? 1; moveBy(ctx, pose.eyes, P[e]);
          if (open < .35) put(ctx, e, { ...own, sy: (own.sy ?? 1) * lerp(1, .22, open / .35) }, P[e]);
          else {
            const k = (open - .35) / .65;
            ctx.fillStyle = '#02132F'; ctx.beginPath(); ctx.ellipse(P[e][0], P[e][1] + 4 * k, lerp(11, 9.5, k), lerp(2.4, 13.5, k), 0, 0, 7); ctx.fill();
            ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(P[e][0] - 3, P[e][1] - 1 * k, 3.2 * k, 0, 7); ctx.fill();
          }
          ctx.restore();
        }
        if (!hide.has('stache')) {
          const st = pose.stache || {};
          ctx.save(); ctx.globalAlpha *= st.alpha ?? 1; moveBy(ctx, st, P.stache);
          if (st.split) {
            put(ctx, 'stacheL', { rot: st.split }, P.stache);
            put(ctx, 'stacheR', { rot: -st.split }, P.stache);
          } else put(ctx, 'stache');
          ctx.restore();
        }
      }
      ctx.restore();
      // the bow tie, over the neck
      if (!hide.has('bow')) {
        ctx.save();
        moveBy(ctx, pose.body, [256, 512]);
        ctx.globalAlpha *= (pose.bow || {}).alpha ?? 1;
        moveBy(ctx, pose.bow, P.knot);
        if (!hide.has('wings')) put(ctx, 'wings', pose.wings, P.knot);
        if (!hide.has('knot')) put(ctx, 'knot', pose.knot, P.knot);
        ctx.restore();
      }
      ctx.restore();
    };
    /* One part alone, anywhere: its picture with the point `anchor` (grid units; its own middle by default) at x, y of
       the screen. op: k (points to a grid unit; the launch icon's by default), rot, sx, sy, alpha.
       Parts: 'man' (all of him), 'body', 'head' (no face), 'browL', 'browR', 'eyeL', 'eyeR', 'stache', 'stacheL',
       'stacheR', 'wings', 'knot'. */
    K.sprite = (ctx, name, x, y, op = {}) => {
      const L = name === 'man' ? { x: 0, y: 0, w: 512, h: 512 } : RIG.layers[name], img = pictures[name];
      if (!img || !img.naturalWidth) return;
      const [ax, ay] = op.anchor || [L.x + L.w / 2, L.y + L.h / 2], k = op.k ?? LAUNCH.size / 512;
      ctx.save();
      ctx.globalAlpha *= op.alpha ?? 1;
      ctx.translate(x, y);
      if (op.rot) ctx.rotate(op.rot * Math.PI / 180);
      ctx.scale(k * (op.sx ?? 1), k * (op.sy ?? 1));
      ctx.drawImage(img, L.x - ax, L.y - ay, L.w, L.h);
      ctx.restore();
    };
    K.partBox = name => RIG.layers[name];

    /* A ribbon: a band along a line that may bend, its thickness changing along it; for a shape that stretches along
       the dial's ring. op: x, y   its middle        dir     its line's direction there (degrees: 0 to the right, clockwise)
                           length  along the line    bend    its curvature, 1 / radius; positive bends clockwise, and with
                                                             1 / K.DIAL.r a ribbon whose middle is on the ring lies along the ring
                           top(u), bottom(u)         how far its two edges are from the line at u, from 0 (its start) to 1 (its
                                                     end); `top` is the outer side when it lies along the ring clockwise
                           fill, alpha, n (how many pieces: 48) */
    K.ribbon = (ctx, { x, y, dir = 0, length, bend = 0, top, bottom, fill, alpha = 1, n = 48 }) => {
      const th0 = dir * Math.PI / 180, pts = [], flat = Math.abs(bend) < 1e-6;
      for (let i = 0; i <= n; i++) {
        const u = i / n, d = (u - .5) * length, th = th0 + bend * d;
        pts.push([flat ? x + d * Math.cos(th0) : x + (Math.sin(th) - Math.sin(th0)) / bend,
          flat ? y + d * Math.sin(th0) : y - (Math.cos(th) - Math.cos(th0)) / bend, Math.sin(th), -Math.cos(th), u]);
      }
      ctx.save(); ctx.globalAlpha *= alpha; ctx.beginPath();
      pts.forEach(([px, py, nx, ny, u], i) => { const d = top(u); ctx[i ? 'lineTo' : 'moveTo'](px + nx * d, py + ny * d); });
      for (let i = n; i >= 0; i--) { const [px, py, nx, ny, u] = pts[i], d = bottom(u); ctx.lineTo(px - nx * d, py - ny * d); }
      ctx.closePath(); ctx.fillStyle = fill; ctx.fill(); ctx.restore();
    };
    /* The mustache's outline, for K.ribbon: K.stache.length (grid units), K.stache.middle (its middle on the grid),
       K.stache.top(u) and K.stache.bottom(u) (grid units from its level middle line; multiply by box.k). A ribbon of
       this outline, level and unbent at the mustache's place, covers the mustache's picture. */
    const prof = P.stacheProfile, at2 = (u, j) => {
      const f = clamp(u) * (prof.samples.length - 1), i = Math.min(prof.samples.length - 2, Math.floor(f));
      return lerp(prof.samples[i][j], prof.samples[i + 1][j], f - i);
    };
    K.stache = { length: prof.x1 - prof.x0, middle: [(prof.x0 + prof.x1) / 2, prof.y], top: u => at2(u, 0), bottom: u => at2(u, 1), color: '#111F4A' };

    /* The whole icon in one call: its ground, then, cut to its rounded square, the ticks and the man.
       op: ground  K.ground's options (false: none)      ticks  K.ticks' fn (false: none)      tickColor
           pose    K.man's pose (false: no man)          content  the alpha of the ticks and the man together (1)
           clip    cut to the square (true) */
    K.icon = (ctx, box, op = {}) => {
      if (op.ground !== false) K.ground(ctx, box, op.ground || {});
      const inside = () => {
        ctx.save();
        ctx.globalAlpha *= op.content ?? 1;
        if (op.ticks !== false) K.ticks(ctx, box, op.ticks || null, op.tickColor || C.navy);
        if (op.pose !== false) K.man(ctx, box, op.pose || {});
        ctx.restore();
      };
      if (op.clip === false) inside(); else K.clip(ctx, box, inside);
    };
    // The launch picture itself, as iOS leaves it: where every opening begins
    K.launch = (ctx = o, op = {}) => K.icon(ctx, K.box(), op);

    /* The words in the dial's middle, for this frame: { time: '0:41:07', pay: '₪ 37' }. Left alone they are the made-up
       shift's own (5:42:18 and on, ₪ 308). K.clock(seconds) writes a duration as the timer does. */
    K.center = ({ time, pay } = {}) => {
      if (time != null) timeText.textContent = time;
      if (pay != null) payText.textContent = pay;
    };
    K.clock = timer;
    K.SHIFT = { seconds: 5 * 3600 + 42 * 60 + 18, pay: 308 };

    // The app's background over everything under it on this canvas (to hide the Now screen behind the icon's stage)
    K.backdrop = (ctx, alpha = 1, color = C.bg) => {
      if (alpha <= 0) return;
      ctx.save(); ctx.globalAlpha *= alpha; ctx.fillStyle = color; ctx.fillRect(0, 0, W, H); ctx.restore();
    };

    function draw(sc, t) {
      const m = scale * dpr;
      unit = m;
      for (const ctx of [g, o]) { ctx.setTransform(m, 0, 0, m, 0, 0); ctx.clearRect(0, 0, W, H); ctx.globalAlpha = 1; }
      for (const id of PARTS) K.part(id, 0, 0);
      timeText.textContent = timer(5 * 3600 + 42 * 60 + 18 + Math.floor(Math.max(0, t - 1.5)));
      payText.textContent = '₪ 308';
      K.t = t;
      try { sc.draw(Math.max(0, t), K); } catch (err) {
        if (!sc.failed) { sc.failed = true; console.error(sc.id, err); }
        o.setTransform(m, 0, 0, m, 0, 0); o.fillStyle = '#c00'; o.font = 'bold 13px monospace'; o.textAlign = 'left'; o.fillText('ERROR ' + String(err).slice(0, 46), 8, 420); o.fillText(String(err).slice(46, 100), 8, 438);
      }
    }
    return { root, K, draw, size, get scale() { return scale; } };
  }

  return { W, H, C, LAUNCH, DIAL, scenes, scene, phone, ready, E, seg, lerp, clamp };
})();
