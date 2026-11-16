/* The butterfly tie. The icon's tile drops under the dial's place and grows into a small portrait card; on the way
   down his head lags and the air lifts his bow tie's wings, and as he lands they flop. Then the bow tie (in Hebrew: a
   "butterfly tie") flaps its wings by itself, lifts off the collar and flies up as a butterfly; he follows it with
   his eyes. It settles on the dial's ring at this very minute: its knot becomes the "now" knob, the wing behind it
   unrolls back along the ring into the worked arc, the wing ahead on to the goal. The tile becomes the facts card
   and he sinks out of it. */
Opening.scene({
  id: 'butterfly', chip: 'הפרפר', title: 'הפרפר.',
  about: 'עניבת הפרפר שלו מנפנפת בכנפיים, מתנתקת מהצווארון ועפה אל הטבעת. הקשר שלה נהיה הסמן של עכשיו, והכנפיים נפרשות לשעות שכבר עבדת ולדרך עד היעד.',
  end: 4.35, rest: 2.75, haptics: [[1.3, 'light'], [1.94, 'light']],
  draw(t, K) {
    const { E, seg, spring, lerp, clamp, mix, DIAL, LAUNCH, C, P, g, o } = K;
    const hump = x => (1 - Math.cos(2 * Math.PI * clamp(x))) / 2;                  // 0, up to 1, back to 0
    const R = DIAL.r, HW = DIAL.w / 2, NOW = DIAL.start + DIAL.now, AHEAD = DIAL.goal - DIAL.now;
    const [nx, ny] = K.markAt('now');
    const NAVY = '#16265C', PALE = '#BFD9D8';                      // the wings' flat navy; the arc ahead as it shows on the track
    const KNOT = [P.knot[0], P.knot[1]];
    const blend = (a, b, k) => '#' + [1, 3, 5].map(i => Math.round(lerp(parseInt(a.slice(i, i + 2), 16), parseInt(b.slice(i, i + 2), 16), clamp(k))).toString(16).padStart(2, '0')).join('');
    const SIZE = 176, CY = 560;                                    // the tile under the dial
    const LAND = 26 / 98;                                          // the butterfly's size on the ring: its wings a little taller than the ring is wide
    // the moments
    const OWN = .12;                                               // from the first move the bow tie is drawn on its own, over him
    const FLAP1 = .42, FLAP2 = .54, OFF = .66, ON = 1.30;          // two flaps on the collar; it is off; it is on the ring
    const BEAT = (ON - OFF) / 6;                                   // six wing-beats on the way
    const FLIP = ON + .07;                                         // the knot turns over into the knob
    const B0 = ON + .12, B1 = ON + .66, F0 = ON + .16, F1 = ON + .56;   // the wing behind unrolls; the wing ahead
    const DONE = B1 + .2;                                          // from here the dial's own arcs and marks stand for it all
    const CARD = ON + .44;                                         // the tile becomes the facts card

    // ---- the wings' outline on the icon's grid: from the knot outward, how far each edge is from the bow's level line
    //      (`body` units long), and then a round tip (`cap` units long)
    const WING = {
      L: { body: 64.3, cap: 25,
        top: [23.7, 23.2, 22.7, 21.2, 21.2, 24.2, 27.2, 29.7, 32.2, 34.7, 36.7, 38.7, 40.2, 42.2, 43.2, 44.2, 44.2, 44.2, 43.7, 43.2, 42.7],
        bot: [26.3, 25.8, 25.3, 24.3, 22.3, 24.8, 27.8, 30.8, 33.8, 36.3, 38.8, 41.3, 43.3, 45.3, 46.8, 48.3, 49.8, 50.8, 51.8, 52.3, 52.3] },
      R: { body: 60.7, cap: 24,
        top: [23.7, 23.2, 22.7, 22.2, 20.7, 18.7, 21.2, 23.7, 25.7, 27.7, 29.2, 30.7, 32.2, 33.7, 34.7, 35.7, 36.7, 36.7, 37.2, 37.2, 36.7],
        bot: [26.3, 25.8, 25.3, 24.3, 22.3, 25.8, 28.8, 31.3, 34.3, 36.8, 38.8, 41.3, 43.3, 45.3, 47.3, 48.8, 49.8, 50.8, 51.8, 51.8, 51.8] },
    };
    const prof = (arr, u) => { const f = clamp(u) * (arr.length - 1), i = Math.min(arr.length - 2, Math.floor(f)); return lerp(arr[i], arr[i + 1], f - i); };
    /* One wing as a flat shape: a ribbon from the knot at x, y outward (side 'L' backward, 'R' forward) along the line
       `rot`, curved by `bend`, `length` long, and a round tip on its end. flat 0 is the wing's own outline at the size
       k; flat 1 is the ring's even band with a half-round end. */
    const wing = (ctx, side, x, y, k, rot, bend, length, flat, fill, alpha = 1) => {
      const W = WING[side], sign = side === 'L' ? -1 : 1, th0 = rot * Math.PI / 180;
      const cap = lerp(W.cap * k * Math.min(1, length / ((W.body + W.cap) * k)), HW, flat), body = Math.max(.01, length - cap);
      const pt = s => bend ? [x + (Math.sin(th0 + bend * s) - Math.sin(th0)) / bend, y - (Math.cos(th0 + bend * s) - Math.cos(th0)) / bend]
        : [x + s * Math.cos(th0), y + s * Math.sin(th0)];
      const [mx, my] = pt(sign * body / 2);
      const half = (arr, u) => lerp(Math.max(0, prof(arr, u) - .8) * k, HW, flat);       // u from the knot (0) to the tip (1)
      K.ribbon(ctx, { x: mx, y: my, dir: rot + bend * sign * body / 2 * 180 / Math.PI, length: body, bend, fill, alpha, n: flat > 0 ? 96 : 24,
        top: u => half(W.top, sign < 0 ? 1 - u : u), bottom: u => half(W.bot, sign < 0 ? 1 - u : u) });
      const [tx, ty] = pt(sign * body), hT = half(W.top, 1), hB = half(W.bot, 1);
      ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(tx, ty); ctx.rotate(th0 + bend * sign * body); ctx.scale(sign, 1);
      ctx.beginPath(); ctx.moveTo(-.6, -hT); ctx.ellipse(0, 0, cap, hT, 0, -Math.PI / 2, 0); ctx.ellipse(0, 0, cap, hB, 0, 0, Math.PI / 2); ctx.lineTo(-.6, hB); ctx.closePath();
      ctx.fillStyle = fill; ctx.fill(); ctx.restore();
    };
    const span = (s, k) => (WING[s].body + WING[s].cap) * k * .985;   // a wing's own length at the size k (a hair inside its picture)
    /* The butterfly: the bow tie's own picture, its two wings narrowed toward the knot (sx) and raised in a V (vee,
       degrees) for a flap; under the picture, as it fades (shade), the same wings as a flat shape in `fill`. */
    const butterfly = (ctx, x, y, k, rot, sx, vee, shade, fill, bend = 0) => {
      if (shade < 1) for (const s of ['L', 'R']) wing(ctx, s, x, y, k, rot + (s === 'L' ? vee : -vee), bend, span(s, k) * sx, 0, fill, seg(1 - shade, 0, .15));
      if (shade > 0) {
        if (!vee) K.sprite(ctx, 'wings', x, y, { k, rot, sx, alpha: shade, anchor: KNOT });
        else for (const s of [-1, 1]) {
          ctx.save(); ctx.translate(x, y); ctx.rotate((rot - s * vee) * Math.PI / 180);
          ctx.beginPath(); ctx.rect(s < 0 ? -300 : 0, -300, 300, 600); ctx.clip();
          K.sprite(ctx, 'wings', 0, 0, { k, sx, alpha: shade, anchor: KNOT });
          ctx.restore();
        }
      }
      K.sprite(ctx, 'knot', x, y, { k, rot, anchor: KNOT });
    };

    // ---- the tile steps down under the dial's place and grows; later its frame becomes the facts card's
    const step = spring(t, .12, .4, .7);                                             // it dips a little past its place and comes back
    const box = K.box(LAUNCH.x, lerp(LAUNCH.y, CY, step), lerp(LAUNCH.size, SIZE, step));
    const vel = (step - spring(t - .06, .12, .4, .7)) / .416;                        // how fast it moves, 1 at its fastest: his head and the tie's wings lag
    const m = spring(t, CARD, .46, .78);
    const fr = { x: lerp(box.x, 20, m), y: lerp(box.y, 482, m), w: lerp(box.size, 362, m), h: lerp(box.size, 76, m), r: lerp(box.r, 22, m) };
    const sink = -5 * seg(t, CARD - .08, CARD + .04, E.io2) + 135 * seg(t, CARD + .04, CARD + .38, E.in2);   // he sinks out of the card
    const manBox = K.box(box.cx, box.cy + sink, box.size);
    const land = K.wobble(t, .33, .24, 9);                         // he lands in his new place: a soft squash on the tile's floor, and a settle
    const squash = [1 - .015 * vel + .03 * land, 1 + .04 * vel - .08 * land];        // and on the way down he stretches a little

    // ---- the butterfly's way: off the collar to the right, past his face, up beside the tile, into the dial and out to
    //      the ring at "now": two curves, walked at an even pace
    const [cx0, cy0] = box.pt(256 + (KNOT[0] - 256) * squash[0], 512 - (512 - KNOT[1]) * squash[1]);   // the collar
    const out = [Math.sin(NOW * Math.PI / 180), -Math.cos(NOW * Math.PI / 180)];   // outward from the dial at "now"
    const bez = (a, b, c, d, u) => a * (1 - u) ** 3 + 3 * b * u * (1 - u) ** 2 + 3 * c * u * u * (1 - u) + d * u ** 3;
    const edge = LAUNCH.x + SIZE / 2;                              // the tile's right edge
    const AX = [cx0, cx0 + 26, edge + 29, edge + 29], AY = [cy0, cy0 + 2, CY + 58, CY - 24];
    const BX = [edge + 29, edge + 29, nx - 110 * out[0], nx], BY = [CY - 24, CY - 110, ny - 110 * out[1], ny];
    const way = [];
    for (let i = 0; i <= 20; i++) way.push([bez(...AX, i / 20), bez(...AY, i / 20)]);
    for (let i = 1; i <= 30; i++) way.push([bez(...BX, i / 30), bez(...BY, i / 30)]);
    const far = [0];
    for (let i = 1; i < way.length; i++) far.push(far[i - 1] + Math.hypot(way[i][0] - way[i - 1][0], way[i][1] - way[i - 1][1]));
    const total = far[far.length - 1];
    const on = d => {                                              // the point `d` along the way
      d = clamp(d, 0, total);
      let i = 1; while (i < way.length - 1 && far[i] < d) i++;
      const u = (d - far[i - 1]) / (far[i] - far[i - 1] || 1);
      return [lerp(way[i - 1][0], way[i][0], u), lerp(way[i - 1][1], way[i][1], u)];
    };
    const fly = seg(t, OFF - .04, ON, x => x * x * (3 - 2 * x));                      // a gentle start, an even pace, a soft arrival
    const [px, py] = on(fly * total), [pa, pb] = [on(fly * total - 7), on(fly * total + 7)];
    const LIE = NOW - 360;                                         // the bow's turn when it lies along the ring at "now"
    const heading = fly >= 1 ? LIE : Math.atan2(pb[0] - pa[0], -(pb[1] - pa[1])) * 180 / Math.PI;
    const beat = t < OFF ? 0 : (t - OFF) / BEAT;
    const up = t < OFF ? .6 * hump(seg(t, FLAP1, FLAP2)) + hump(seg(t, FLAP2, OFF)) : t < ON ? hump(beat % 1) : 0;   // the wings: 0 flat, 1 raised
    const air = Math.sin(Math.PI * seg(t, OFF, ON));                                  // 0 on the collar and on the ring
    // the second flap lifts it off the collar: a dip as the wings rise, a hop as they come down
    const hop = (1.5 * Math.sin(Math.PI * seg(t, FLAP2, FLAP2 + .06)) - 5 * seg(t, FLAP2 + .06, OFF + .02, E.io2)) * (1 - seg(t, OFF + .04, OFF + .3, E.io2));
    const bx = px, by = py + hop + 4.5 * air * (2 * up - 1);                          // in the air the body bobs up on each down-stroke
    // while he drops the air lifts the tie's wings; as he lands they flop down past level, swing once and lie still
    const trail = 15 * vel - 8 * K.wobble(t, .36, .2, 11);
    const sway = 3 * K.wobble(t, .36, .18, 10);                                       // and the tie swings a little on its knot
    const rot = lerp(heading * seg(fly, .3, .72, E.io2), LIE, seg(fly, .72, 1, E.io2)) + 5 * air * Math.sin(2 * Math.PI * beat) + sway;
    const bk = lerp(box.k, LAND, seg(t, OFF, ON - .04, E.io2));
    const shade = 1 - seg(t, OFF + .14, ON - .08);                                    // the picture's shading gives way to a flat shape
    const tint = .4 * seg(t, OFF + .14, ON, E.io2);

    // ---- the wings on the ring
    const EU = x => 1 - Math.pow(1 - Math.pow(x, 1.5), 3), EUinv = p => Math.pow(1 - Math.pow(1 - clamp(p), 1 / 3), 1 / 1.5);
    const spread = 1 + .12 * K.wobble(t, ON, .16, 14);                                // as it alights its wings spread a little and settle
    const backLen = lerp(span('L', LAND) * spread, R * DIAL.now * Math.PI / 180 + HW, seg(t, B0, B1, EU));
    const frontLen = lerp(span('R', LAND) * spread, R * AHEAD * Math.PI / 180 + HW, seg(t, F0, F1, EU));
    const flat = seg(t, B0 - .02, B0 + .22, E.io2);
    const teal = lerp(.4, 1, seg(t, B0, B0 + .3, E.io2)), pale = seg(t, F0 + .1, F1, E.io2);   // both wings to teal; the one ahead on to its pale

    // ---- the dial
    const wave = i => {
      const a = i * 6, back = ((NOW - a) % 360 + 360) % 360, front = ((a - NOW) % 360 + 360) % 360;
      const tb = back <= DIAL.now ? B0 + (B1 - B0) * EUinv(back / DIAL.now) : B1 + (back - DIAL.now) / 600;
      const tf = front <= AHEAD ? F0 + (F1 - F0) * EUinv(front / AHEAD) : F1 + (front - AHEAD) / 600;
      const at = Math.min(tb, tf) + .03;
      return { k: seg(t, at, at + .24, E.back), a: seg(t, at, at + .12) };
    };
    if (t >= DONE + .4) K.dial();
    else K.dial({
      track: seg(t, FLAP1 + .04, FLAP1 + .36), numerals: seg(t, B0 + .22, B0 + .52), tick: wave,
      span: t >= DONE ? DIAL.now : 0, ahead: t >= DONE ? 1 : 0, marks: t >= DONE ? [1, 1, 1] : [0, 0, 0],
    });

    // ---- the tile: its ground under the facts card, the man over it, cut by its frame
    const tile = 1 - seg(t, CARD + .56, CARD + .7);
    if (tile > 0) {
      const k = box.k;
      g.save(); g.globalAlpha = tile;
      const fill = g.createLinearGradient(0, fr.y, 0, fr.y + fr.h);
      fill.addColorStop(0, C.groundTop); fill.addColorStop(1, mix(C.groundBottom, C.card, m));
      g.beginPath(); g.roundRect(fr.x, fr.y, fr.w, fr.h, fr.r); g.fillStyle = fill; g.fill();
      const mm = clamp(m), inset = lerp(1.1 * k, -.25, mm);
      g.beginPath(); g.roundRect(fr.x + inset, fr.y + inset, fr.w - 2 * inset, fr.h - 2 * inset, Math.max(0, fr.r - inset));
      g.strokeStyle = `rgba(0,0,0,${lerp(.07, .08, mm)})`; g.lineWidth = lerp(2.2 * k, .5, mm); g.stroke();
      g.restore();
    }
    if (t < CARD + .42) {
      // his acting: the eyes open and drop to the tie, the chin tucks, the brows jump; then he follows the butterfly up
      const SEE = FLAP1 + .05;                                                         // he notices: a beat after the first flap begins
      const open = seg(t, SEE, SEE + .1, E.io2) - seg(t, ON + .02, ON + .14, E.io2);
      const tuck = seg(t, SEE, SEE + .14, E.io2) - seg(t, OFF + .06, OFF + .34, E.io2);
      const brow = spring(t, SEE + .02, .28, .5) - seg(t, ON + .04, ON + .2, E.io2);
      const curl = seg(t, OFF + .12, OFF + .32, E.io2) - seg(t, ON + .08, ON + .28, E.io2);
      const nod = hump(seg(t, ON + .08, ON + .36));                                    // "there": a small nod as it lands
      const [ex, ey] = manBox.pt(297, 234), gx = bx - ex, gy = by - ey, away = Math.max(60, Math.hypot(gx, gy));
      const pose = {
        head: { rot: -5.5 * vel + 2.5 * K.wobble(t, .38, .2, 10) + 6 * tuck - 5 * hump(seg(t, OFF + .2, ON + .12)) + 3 * nod, dy: -3 * vel + 3 * tuck + 1.5 * nod },
        brows: { dy: -6 * brow },
        eyes: { open, dx: 4.5 * gx / away * open, dy: 4.5 * gy / away * open },
        stache: { split: 7 * curl },
      };
      if (t >= OWN) pose.hide = ['bow'];
      const gone = 1 - seg(t, CARD - .1, CARD + .02, E.io2);                          // the logo's ticks draw in and go
      o.save();
      o.beginPath(); o.roundRect(fr.x, fr.y, fr.w, fr.h, fr.r); o.clip();
      K.ticks(o, manBox, () => ({ a: gone, len: lerp(.3, 1, gone), out: -16 * (1 - gone) }));
      const [fx, fy] = manBox.pt(256, 512);                                            // the tile's floor, under him
      o.translate(fx, fy); o.scale(squash[0], squash[1]); o.translate(-fx, -fy);
      if (t < OWN) K.man(o, manBox, pose);
      else {
        /* With the tie off his collar shows, and the layers' pictures are rough where the tie used to cover them. So he
           is drawn layer by layer with a clean neck in between, all on the icon's grid: the shirt; the neck going on up
           behind the head, and its two side lines; the head; over the head's lower edge a patch of the neck's color
           and round ends on its outline; last the collar's line and its meeting with the shoulder, drawn again clean. */
        const NECK = '#F3AC79', INK = '#02132F';
        const onGrid = (withHead, fn) => {
          o.save(); o.translate(manBox.x, manBox.y); o.scale(manBox.k, manBox.k);
          if (withHead) { o.translate(P.neck[0], P.neck[1] + pose.head.dy); o.rotate(pose.head.rot * Math.PI / 180); o.translate(-P.neck[0], -P.neck[1]); }
          o.lineCap = o.lineJoin = 'round'; o.strokeStyle = INK;
          fn(); o.restore();
        };
        const shape = (fill, pts) => { o.beginPath(); pts.forEach(([x, y], i) => o[i ? 'lineTo' : 'moveTo'](x, y)); o.closePath(); o.fillStyle = fill; o.fill(); };
        const dot = (x, y, r) => { o.beginPath(); o.arc(x, y, r, 0, 7); o.fillStyle = INK; o.fill(); };
        K.man(o, manBox, { hide: ['head', 'bow'] });
        onGrid(false, () => {
          shape(NECK, [[203, 350], [333, 350], [334, 372], [343, 385], [300, 395], [240, 395], [203, 366]]);
          const s = seg(t, OWN, OWN + .1);                         // the left side line: inside the tie's own corner while the tie lies on it, then its full width
          o.beginPath(); o.moveTo(lerp(183.3, 183.5, s), lerp(376.3, 378, s)); o.quadraticCurveTo(lerp(186.4, 185, s), lerp(367, 365, s), lerp(202.8, 201, s), lerp(360.2, 359, s));
          o.lineWidth = lerp(4.6, 7, s); o.stroke();
          o.beginPath(); o.moveTo(346, 384.5); o.lineTo(330.9, 366.6); o.lineWidth = 8; o.stroke();          // the right one, up into the head
        });
        K.man(o, manBox, { ...pose, hide: ['body', 'bow'] });
        onGrid(true, () => {
          // the patch's upper edge is the tie's own upper edge, so nothing changes while the tie still lies on it
          shape(NECK, [[218.8, 359.6], [228, 364.3], [240, 372.8], [246, 378], [248, 382.1], [252, 383.2], [260, 380.6], [268, 380.6], [276, 383.6], [280, 385.6], [284, 382.1], [286, 379],
            [296, 372.3], [308, 367.8], [316, 365.8], [320, 365.8], [328, 367.3], [331.5, 369.2], [333, 377], [300, 392], [240, 392], [226, 386], [219, 368]]);
          // the small shadow that showed over the knot goes as the tie lifts off
          o.globalAlpha = seg(t, FLAP2, OFF + .1);
          shape(NECK, [[236, 366.5], [252, 370], [264, 372.5], [278, 374], [294, 373.6], [286, 379], [284, 382.1], [280, 385.6], [276, 383.6], [268, 380.6], [260, 380.6], [252, 383.2], [248, 382.1], [246, 378], [240, 372.8]]);
          o.globalAlpha = 1;
          dot(217.6, 361.6, 2.6); dot(333.6, 373.7, 1.9);
        });
        onGrid(false, () => {
          o.beginPath(); o.moveTo(184, 381.8); o.quadraticCurveTo(265.5, 449, 347, 387.3); o.lineWidth = 8.6; o.stroke();
          shape(INK, [[175, 377.6], [180, 376.4], [187, 379], [190, 391.6], [175, 390.4]]);
        });
      }
      o.restore();
    }

    // ---- the butterfly: on the collar, in the air, on the ring
    if (t >= OWN && t < ON) {
      // each beat: the wings up and together over the knot, then down, in the air a little past level
      butterfly(o, bx, by, bk, rot, 1 - .5 * up - Math.max(0, trail) / 60, 30 * up + trail - 9 * air * (1 - up), shade, blend(NAVY, C.teal, tint), seg(t, ON - .08, ON, E.io2) / R);
    } else if (t >= ON && t < DONE) {
      wing(g, 'L', nx, ny, LAND, NOW, 1 / R, backLen, flat, blend(NAVY, C.teal, teal));
      wing(g, 'R', nx, ny, LAND, NOW, 1 / R, frontLen, flat, blend(blend(NAVY, C.teal, teal), PALE, pale));
      // the knot flips into the knob
      const turn = seg(t, FLIP, FLIP + .14);
      if (turn < .4) K.sprite(o, 'knot', nx, ny, { k: LAND, rot: NOW, sx: Math.cos(turn / .4 * Math.PI / 2), anchor: KNOT });
      else {
        const s = lerp(.5, 1, seg(t, FLIP + .056, FLIP + .22, E.back));
        g.save(); g.translate(nx, ny); g.rotate(NOW * Math.PI / 180); g.scale(s * Math.sin((turn - .4) / .6 * Math.PI / 2), s); g.rotate(-NOW * Math.PI / 180);
        K.knob(g); g.restore();
      }
      // the marks, on the wings' tips as they arrive
      const mark = (which, s, fn) => { if (s <= 0) return; const [qx, qy] = K.markAt(which); g.save(); g.translate(qx, qy); g.scale(s, s); fn(g); g.restore(); };
      mark('start', seg(t, B1 - .07, B1 + .15, E.back), K.startMark);
      mark('goal', seg(t, F1 - .07, F1 + .15, E.back), K.flag);
    }

    // ---- the Now screen comes in round it
    const words = seg(t, B0 + .18, B0 + .5, E.out3);
    K.part('center', words, 0, { scale: lerp(.96, 1, words) });
    K.part('facts', seg(t, CARD + .25, CARD + .48, E.io2), 0);                        // once his hair has left the card
    K.parts(t, CARD + .3, { order: ['cap', 'buttons', 'week', 'tabs'], gap: .06, dur: .4 });
  },
});
