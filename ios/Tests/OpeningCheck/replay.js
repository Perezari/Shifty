/* The replay: frames a Swift scene drew (main.swift's JSON: two display lists and the parts' states for each moment)
   played on the mock's own phone, canvas for canvas, so that a Swift scene can be looked at, and held against the
   mock's scene of the same id picture by picture. Whatever the mock's kit draws with canvas calls, the lists replay
   with the same calls in the same order: with the mock's layout and the light theme the two pictures are equal.

   The page is opened with #job=<URL of a job file>, a script that sets window.OPENING_JOB:
     dumps   [ what `dump frames` printed, ... ]
     mock    [ ids of mock scenes to load from mock/scenes/, ... ]
     mode    'grid'   bare pictures in an exact grid, for the tools to cut apart
             'sheet'  labelled pictures side by side, to look at
     s       the pictures' size against the real screen           cols   pictures in a row (grid)
     view    { x, y, w, h }: only that part of the screen (sheet)
     cells   [ { dump: 0, scene: 'mrnow', t: 0.5, label } | { mock: 'mrnow', t: 0.5, label }, ... ]
   When all is drawn the page's title is 'ready'. */
(() => {
  const O = window.Opening, RIG = window.RIG;
  const fail = text => document.body.insertAdjacentHTML('afterbegin', `<p class="replay-error">${text}</p>`);
  const load = src => new Promise(done => {
    const tag = document.createElement('script');
    tag.src = src;
    tag.onload = () => done(true);
    tag.onerror = () => { fail('cannot load ' + src); done(false); };
    document.head.appendChild(tag);
  });

  // the man's pictures, loaded here too: the engine keeps its own to itself
  const pictures = {};
  const loaded = Promise.all([...Object.keys(RIG.layers), 'man'].map(name => new Promise(done => {
    const img = new Image();
    img.onload = img.onerror = done;
    img.src = `mock/assets/${name}.png`;
    pictures[name] = img;
  })));

  const css = c => c[3] === 1 ? `rgb(${c[0]},${c[1]},${c[2]})` : `rgba(${c[0]},${c[1]},${c[2]},${c[3]})`;

  // a path of the display list, laid on the canvas
  const SIZE = { M: 2, L: 2, Q: 4, C: 6, A: 5, E: 7, R: 5, Z: 0 };
  function trace(ctx, p) {
    ctx.beginPath();
    for (let i = 0; i < p.length;) {
      const kind = p[i], n = p.slice(i + 1, i + 1 + SIZE[kind]);
      i += 1 + SIZE[kind];
      if (kind === 'M') ctx.moveTo(n[0], n[1]);
      else if (kind === 'L') ctx.lineTo(n[0], n[1]);
      else if (kind === 'Q') ctx.quadraticCurveTo(n[0], n[1], n[2], n[3]);
      else if (kind === 'C') ctx.bezierCurveTo(n[0], n[1], n[2], n[3], n[4], n[5]);
      // a whole turn is asked for outright (7 radians on, as the mock asks): no rounding can make it less than whole
      else if (kind === 'A') ctx.arc(n[0], n[1], n[2], n[3], Math.abs(n[4]) >= 2 * Math.PI ? n[3] + 7 * Math.sign(n[4]) : n[3] + n[4], n[4] < 0);
      else if (kind === 'E') ctx.ellipse(n[0], n[1], n[2], n[3], n[4], n[5], Math.abs(n[6]) >= 2 * Math.PI ? n[5] + 7 * Math.sign(n[6]) : n[5] + n[6], n[6] < 0);
      else if (kind === 'R') { if (n[4] > 0) ctx.roundRect(n[0], n[1], n[2], n[3], n[4]); else ctx.rect(n[0], n[1], n[2], n[3]); }
      else if (kind === 'Z') ctx.closePath();
    }
  }
  function paint(ctx, p) {
    if (typeof p[0] === 'number') return css(p);
    const fill = p[0] === 'linear' ? ctx.createLinearGradient(p[1], p[2], p[3], p[4]) : ctx.createRadialGradient(p[1], p[2], p[3], p[1], p[2], p[4]);
    for (const [at, color] of p[5]) fill.addColorStop(at, css(color));
    return fill;
  }

  // the dial's marks and numerals, which the app draws with its own views: here as the mock's engine draws them
  // (K.startMark, K.knob, K.flag and K.dial's numerals), in the theme's and the layout's colors. Where the mock is
  // not quite as the app (the knob's ring, the flag's halo and shadow), as the mock for its own layout, which is
  // held against it, and as the app (ShiftDial in Views/NowView.swift) for the others
  function mark(ctx, which, K, dump) {
    const accent = css(dump.theme.accent), knob = css(dump.layout.knob), flag = dump.layout.flagColor, mock = dump.asMock;
    if (which === 'start') {
      ctx.fillStyle = accent; ctx.beginPath(); ctx.arc(0, 0, 11, 0, 7); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.moveTo(-3, -4.6); ctx.lineTo(5, 0); ctx.lineTo(-3, 4.6); ctx.fill();
    } else if (which === 'knob') {
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.22)'; ctx.shadowBlur = 7 * K.unit; ctx.shadowOffsetY = 4 * K.unit;
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, 0, 16, 0, 7); ctx.fill(); ctx.restore();
      ctx.strokeStyle = knob; ctx.lineWidth = 3.5; ctx.beginPath(); ctx.arc(0, 0, mock ? 14.25 : 16, 0, 7); ctx.stroke();
      ctx.fillStyle = knob; ctx.beginPath(); ctx.arc(0, 0, 4.5, 0, 7); ctx.fill();
    } else if (which === 'flag') {
      const reached = dump.layout.reached && !mock;
      ctx.fillStyle = `rgba(${flag[0]},${flag[1]},${flag[2]},${mock ? .2 : .18})`; ctx.beginPath(); ctx.arc(0, 0, 21, 0, 7); ctx.fill();
      ctx.save();
      if (!mock) { ctx.shadowColor = 'rgba(0,0,0,.16)'; ctx.shadowBlur = 4 * K.unit; ctx.shadowOffsetY = 2 * K.unit; }
      ctx.fillStyle = reached ? accent : '#fff'; ctx.beginPath(); ctx.arc(0, 0, 15, 0, 7); ctx.fill();
      ctx.restore();
      if (reached) {
        // the goal reached, with no plan: a white check on the accent
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 2.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        ctx.beginPath(); ctx.moveTo(-4.6, .4); ctx.lineTo(-1.4, 3.6); ctx.lineTo(4.6, -3.4); ctx.stroke();
        return;
      }
      ctx.strokeStyle = css(flag); ctx.lineWidth = 1.8; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(-4, -6.5); ctx.lineTo(-4, 7); ctx.stroke();
      ctx.fillStyle = css(flag); ctx.beginPath(); ctx.moveTo(-3.4, -6.5); ctx.lineTo(6, -3.6); ctx.lineTo(-3.4, -.6); ctx.fill();
    }
  }
  function hours(ctx, share, K, dump) {
    const c = dump.theme.numerals;
    ctx.save();
    ctx.font = '600 13px ui-rounded, -apple-system, Heebo, sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = `rgba(${c[0]},${c[1]},${c[2]},${c[3] * share})`;
    for (const h of [12, 3, 6, 9]) { const [nx, ny] = K.at(0, 0, (h % 12) * 30, 120); ctx.fillText(String(h), nx, ny); }
    ctx.restore();
  }

  // a group: its operations on a layer of their own, put down as one; with an edge, the layer's silhouette, widened,
  // under it in the edge's color (the layer drawn round a circle of that radius, then filled)
  function group(ctx, edge, width, ops, K, dump) {
    const w = ctx.canvas.width, h = ctx.canvas.height;
    const sheet = () => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
    let layer = sheet();
    const lc = layer.getContext('2d');
    lc.setTransform(ctx.getTransform());
    play(lc, ops, K, dump);
    const r = width * K.unit;
    if (edge && r > 0) {
      const wide = sheet(), wc = wide.getContext('2d');
      for (const ring of r > 2.5 ? [r, r / 2] : [r]) {
        const n = Math.max(12, Math.ceil(2 * Math.PI * ring / .8));
        for (let i = 0; i < n; i++) wc.drawImage(layer, ring * Math.cos(2 * Math.PI * i / n), ring * Math.sin(2 * Math.PI * i / n));
      }
      wc.drawImage(layer, 0, 0);
      wc.globalCompositeOperation = 'source-in'; wc.fillStyle = css(edge); wc.fillRect(0, 0, w, h);
      wc.globalCompositeOperation = 'source-over'; wc.drawImage(layer, 0, 0);
      layer = wide;
    }
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(layer, 0, 0); ctx.restore();
  }

  // a display list, on a canvas (OpeningPen.Op, in ios/Shifty/Opening/OpeningPen.swift, says what each means)
  function play(ctx, ops, K, dump) {
    for (const op of ops) {
      switch (op[0]) {
        case 'save': ctx.save(); break;
        case 'restore': ctx.restore(); break;
        case 'translate': ctx.translate(op[1], op[2]); break;
        case 'rotate': ctx.rotate(op[1]); break;
        case 'scale': ctx.scale(op[1], op[2]); break;
        case 'alpha': ctx.globalAlpha = op[1]; break;
        case 'clip': trace(ctx, op[1]); ctx.clip(op[2] ? 'evenodd' : 'nonzero'); break;
        case 'fill': trace(ctx, op[1]); ctx.fillStyle = paint(ctx, op[2]); ctx.fill(op[3] ? 'evenodd' : 'nonzero'); break;
        case 'stroke': trace(ctx, op[1]); ctx.strokeStyle = paint(ctx, op[2]); ctx.lineWidth = op[3]; ctx.lineCap = op[4]; ctx.lineJoin = op[5]; ctx.stroke(); break;
        case 'image': { const img = pictures[op[1]]; if (img && img.naturalWidth) ctx.drawImage(img, op[2], op[3], op[4], op[5]); break; }
        // in points, whatever the scale: times the canvas's pixels to a point
        case 'shadow': ctx.shadowColor = css(op[1]); ctx.shadowBlur = op[2] * K.unit; ctx.shadowOffsetX = op[3] * K.unit; ctx.shadowOffsetY = op[4] * K.unit; break;
        case 'blur': ctx.filter = `blur(${op[1] * K.unit}px)`; break;
        case 'group': group(ctx, op[1], op[2], op[3], K, dump); break;
        case 'mark': mark(ctx, op[1], K, dump); break;
        case 'hours': hours(ctx, op[1], K, dump); break;
        default: throw new Error('no operation ' + op[0]);
      }
    }
  }

  // a set of dumped frames as a scene of the mock's engine: its draw plays the frame nearest to t
  function scene(dump, set) {
    return {
      id: `swift:${set.scene}`, rest: set.rest, end: set.end,
      draw(t, K) {
        let frame = set.frames[0];
        for (const f of set.frames) if (Math.abs(f.t - t) < Math.abs(frame.t - t)) frame = f;
        if (!frame || Math.abs(frame.t - t) > 1e-6) throw new Error(`no frame of ${set.scene} at ${t}`);
        play(K.g, frame.under, K, dump);
        play(K.o, frame.over, K, dump);
        for (const id of K.PARTS) { const [shown, dx, dy, scale] = frame.parts[id]; K.part(id, shown, dy, { dx, scale }); }
        // the count-up, in the mock's own words: of its made-up 5:42:18 and 308 shekels
        if (frame.count != null) K.center({ time: K.clock(K.SHIFT.seconds * frame.count), pay: '₪ ' + Math.round(K.SHIFT.pay * frame.count) });
      },
    };
  }

  async function run() {
    const query = Object.fromEntries(location.hash.slice(1).split('&').filter(Boolean).map(p => [p.slice(0, p.indexOf('=')), decodeURIComponent(p.slice(p.indexOf('=') + 1))]));
    if (!query.job) return fail('open with #job=<URL of a job file> (tools/film.py, compare.py and check.py do)');
    if (!await load(query.job)) return;
    const job = window.OPENING_JOB;
    for (const id of job.mock || []) await load(`mock/scenes/${id}.js`);
    await Promise.all([O.ready, loaded]);

    const s = job.s || .5, grid = job.mode === 'grid', cols = job.cols || 15;
    document.body.classList.add('film');
    if (grid) document.body.classList.add('bare');
    const w = Math.round(O.W * s), h = Math.round(O.H * s);
    let sheet = null;
    if (!grid) { sheet = document.createElement('div'); sheet.className = 'sheet'; document.body.appendChild(sheet); }
    const made = new Map();
    job.cells.forEach((cell, i) => {
      let sc, dark = false;
      if (cell.mock != null) {
        sc = O.scenes.find(x => x.id === cell.mock);
        if (!sc) return fail(`no mock scene "${cell.mock}"`);
      } else {
        const dump = job.dumps[cell.dump], set = dump && dump.sets.find(x => x.scene === cell.scene);
        if (!set) return fail(`no frames of "${cell.scene}" in dump ${cell.dump}`);
        const key = cell.dump + ':' + cell.scene;
        if (!made.has(key)) made.set(key, scene(dump, set));
        sc = made.get(key);
        dark = dump.theme.dark;
      }
      const box = document.createElement('div');
      if (grid) box.style.cssText = `position:absolute;left:${(i % cols) * w}px;top:${Math.floor(i / cols) * h}px;width:${w}px;height:${h}px;overflow:hidden`;
      else {
        // a label no wider than its picture, so that the sheet's rows hold as many as the tool counted on
        box.className = 'tile';
        const label = document.createElement('span');
        label.textContent = cell.label ?? `t=${cell.t.toFixed(2)}  ${sc.id}`;
        label.style.cssText = `display:block;width:${(job.view ? job.view.w : O.W) * s}px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis`;
        box.appendChild(label);
      }
      if (dark) box.classList.add('dark');
      (sheet || document.body).appendChild(box);
      const phone = O.phone(box, { scale: s, view: grid ? null : job.view || null, dpr: 1 });
      // a part's state to a millionth, for the mock's scenes and the Swift ones alike: the two compute the same
      // numbers with different math libraries, and a last digit's difference can move a letter's edge
      const part = phone.K.part, fine = v => Math.round(v * 1e6) / 1e6;
      phone.K.part = (id, shown, dy = 0, more = {}) => part(id, fine(shown), fine(dy), { dx: fine(more.dx || 0), scale: fine(more.scale ?? 1) });
      phone.draw(sc, cell.t);
      // a bare picture is marked in its four corners once it is drawn (2 x 2 pixels each): the tools know by them
      // that a sheet was whole when Chrome took it (tools/opening.py's grid), and black them out
      if (grid) for (const at of ['left:0;top:0', 'right:0;top:0', 'left:0;bottom:0', 'right:0;bottom:0']) {
        box.insertAdjacentHTML('beforeend', `<i style="position:absolute;${at};width:2px;height:2px;background:#f0f;z-index:99"></i>`);
      }
    });
    document.title = 'ready';
  }
  run().catch(err => fail(String(err && err.stack || err)));
})();
