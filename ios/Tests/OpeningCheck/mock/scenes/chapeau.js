/* Chapeau. The icon rises into the dial's place and becomes its round face, the man in it. He looks up, knows you, and
   tips his mustache to you as a gentleman tips his hat: it lifts off his lip, sails up to the ring, lands on this very
   minute and unrolls both ways into the shift: teal back to the start (the hours done), pale on to the goal (the hours
   left). The white "now" knob pops where its halves meet, like a nose; a new mustache pops onto his lip; he bows out. */
Opening.scene({
  id: 'chapeau', chip: 'שאפו', title: 'שאפו.',
  about: 'מר משמרת קד קידה ומסיר את השפם כמו כובע. השפם עף אל הטבעת, נוחת על הדקה הזאת ונפרש לקשת של המשמרת, ולו צץ שפם חדש.',
  end: 4.0, rest: 2.4, haptics: [[.7, 'light'], [1.12, 'medium']],
  draw(t, K) {
    const { E, seg, spring, wobble, lerp, mix, clamp, DIAL, LAUNCH, C, o } = K;
    if (t >= 2.36) {                                               // the Now screen, whole
      K.dial();
      for (const id of K.PARTS) K.part(id, 1, 0);
      return;
    }
    const R = DIAL.r, HALF = DIAL.w / 2, FACE = R - HALF, DEG = 180 / Math.PI;
    const NOW = DIAL.start + DIAL.now, GOAL = DIAL.start + DIAL.goal;      // clock degrees, counted on from the start mark
    const N = K.markAt('now');
    const ST = K.stache, NOTCH = 38 / 64;                          // where the mustache's two halves meet, along its outline
    const NG = [ST.middle[0] + (NOTCH - .5) * ST.length, ST.middle[1]];    // that notch on the icon's grid
    const TIP = [ST.middle[0] - ST.length / 2, ST.middle[1] + 7];          // its left tip
    // the mustache's outline as a wavy middle line and a half thickness: on the ring the middle line straightens onto the ring's
    const stMid = u => (ST.top(u) - ST.bottom(u)) / 2, stHalf = u => (ST.top(u) + ST.bottom(u)) / 2, HUG = .7;
    // his head nods forward about the neck and tips back about the jaw's end: so the cut at the neck never shows
    const NECK = K.P.neck, JAW = [346, 364];

    // ---- the moments
    const T_OFF = .66;             // the mustache leaves his lip
    const T_FLY = .92;             // it is let go, up to the ring
    const T_LAND = T_FLY + .157;   // it touches the ring
    const T_KNOB = 1.1;            // the "now" knob pops on its notch, and a new mustache on his lip
    const T_SPLIT = 1.2;           // from here its two halves are drawn each on its own (their seam is under the knob)
    const T_UN = 1.27;             // the halves begin to unroll
    const T_ARR = 1.62;            // and arrive at the start mark and at the goal
    const T_GONE = 1.86;           // the face has melted and the man has left

    // ---- the push-in: the icon rises to the dial's middle and grows into its round face
    const rise = spring(t, .12, .7, .8);
    const size = lerp(LAUNCH.size, FACE * 2, rise);
    const box = K.box(LAUNCH.x, lerp(LAUNCH.y, DIAL.y, rise), size, lerp(LAUNCH.r, size / 2, seg(t, .16, .56, E.io2)));
    const k0 = box.k;

    // ---- the man's acting
    const lag = spring(t, .12, .7, .8) - spring(t, .16, .7, .52);                          // what hangs on him: a beat behind the plate, and past it
    const perk = spring(t, T_KNOB + .02, .32, .5);                                         // the new mustache: he comes up
    const out = seg(t, 1.38, 1.52, E.io2);                                                 // and bows out
    const head = tt => {                                                                   // his head up to the new mustache
      const behind = Math.max(0, spring(tt, .12, .7, .8) - spring(tt, .16, .7, .52));      // it arrives a beat after the body
      const up = spring(tt, .3, .36, .5);                                                  // and is carried on: chin up, he looks at you
      const bow = seg(tt, .62, .8, E.io2);                                                 // the doff's bow
      const back = spring(tt, .9, .42, .62);                                               // he straightens as he lets it go
      const rot = -3.5 * up + 10.5 * bow + 1.2 * wobble(tt, .8, .26, 8) - 5.5 * back;
      return { rot, dy: 60 * behind + 5 * bow - 4 * back, pivot: rot < 0 ? JAW : NECK };
    };
    const h = head(t), headRot = h.rot - 2 * perk + 8 * out;
    const H = { rot: headRot, dy: h.dy + 4 * out, pivot: headRot < 0 ? JAW : NECK };       // his head now
    const slide = 480 * seg(t, 1.48, 1.82, E.in2);                                         // straight down behind the lower rim
    const tall = .028 * (seg(t, 1.38, 1.48, E.io2) - seg(t, 1.48, 1.56, E.io2));           // a little taller before he goes (his shirt stays on the rim)
    const watch = seg(t, .97, 1.07, E.out2) * (1 - seg(t, 1.38, 1.47, E.in2));             // his eyes open after the mustache, up to the ring
    const gaze = lerp(4, -2.5, seg(t, T_UN + .03, 1.45, E.io2));                           // and follow its tip back over his head
    const open = seg(t, .34, .46, E.out2) * (1 - seg(t, .64, .74, E.in2)) + watch;
    const browUp = spring(t, .34, .3, .5) * (1 - seg(t, .64, .76, E.io2)) + .8 * watch;
    const grin = spring(t, .42, .24, .5) * (1 - seg(t, .57, .65, E.io2));                  // the mustache lifts and its tips curl: he knows you
    const fresh = seg(t, T_KNOB, T_KNOB + .28, E.back);                                    // the new mustache on his lip
    // a point of his head, on the icon's grid, with the head turned and lowered as in h
    const onHead = ([px, py], h) => {
      const a = h.rot / DEG, dx = px - h.pivot[0], dz = py - h.pivot[1];
      return [h.pivot[0] + dx * Math.cos(a) - dz * Math.sin(a), h.pivot[1] + h.dy + dx * Math.sin(a) + dz * Math.cos(a)];
    };

    // ---- the mustache off his lip: lifted by one end like a hat by its brim, held out, then let go up to the ring
    const h0 = head(T_OFF), tip0 = onHead(TIP, h0);
    const wind = seg(t, T_FLY - .1, T_FLY, E.io2) - seg(t, T_FLY, T_FLY + .08, E.out2);    // a little back before it goes
    const tilt = lerp(h0.rot, -15, seg(t, T_OFF, T_OFF + .15, E.out2)) - 2 * wobble(t, T_OFF + .15, .24, 8) - 2 * wind;
    const up = seg(t, T_OFF + .03, T_OFF + .21, E.back) + .05 * seg(t, T_OFF + .21, T_FLY, E.io2);
    const ta = tilt / DEG, vx = NG[0] - TIP[0], vy = NG[1] - TIP[1];
    const held = box.pt(tip0[0] + vx * Math.cos(ta) - vy * Math.sin(ta) + 70 * up - 3 * wind, tip0[1] + vx * Math.sin(ta) + vy * Math.cos(ta) + 21 * up + 5 * wind);
    const fly = spring(t, T_FLY, .3, .7), arc = t < T_LAND ? Math.sin(Math.PI * fly) : 0;
    const turn = lerp(spring(t, T_FLY + .05, .26, .7), 1, seg(t, T_SPLIT - .06, T_SPLIT));  // its tail whips round onto the ring
    const fit = seg(t, T_FLY + .02, T_FLY + .2, E.io2);
    // its size against its size on his lip: laid on the ring it stretches out a little
    const KL = lerp(1, .92, fit) + .5 * spring(t, T_LAND, .28, .62), KT = lerp(1, .9, fit);
    // how far it still is from the "now" point: all the way while held, then its landing's swing past the ring and back
    const swing = (fly - 1) * (1 - seg(t, T_SPLIT, T_SPLIT + .12)), off = [(N[0] - held[0]) * swing, (N[1] - held[1]) * swing];
    // a smooth closed shape through the points: curves between the middles of its sides
    const shape = (pts, fill, alpha) => {
      const n = pts.length;
      let p = pts[n - 1], q = pts[0];
      o.beginPath(); o.moveTo((p[0] + q[0]) / 2, (p[1] + q[1]) / 2);
      for (let i = 0; i < n; i++) { p = pts[i]; q = pts[(i + 1) % n]; o.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2); }
      o.closePath();
      o.save(); o.globalAlpha *= alpha; o.fillStyle = fill; o.fill(); o.restore();
    };

    // ---- its two halves along the ring, from the notch at "now"
    const reach = E.io2(.9 * seg(t, T_UN, T_ARR)) / E.io2(.9);                             // they arrive still moving
    const L10 = NOTCH * ST.length * k0 * KL, L20 = (1 - NOTCH) * ST.length * k0 * KL;
    const L1 = lerp(L10, DIAL.now / DEG * R, reach), L2 = lerp(L20, (DIAL.goal - DIAL.now) / DEG * R, reach);
    const tipBack = NOW - L1 / R * DEG, tipOn = NOW + L2 / R * DEG;                        // where the two tips are, clock degrees

    // ---- the dial's ticks come on just inside each half as its tip passes; the rest after, down to the bottom
    const gate = seg(t, T_UN, T_UN + .1), late = seg(t, T_ARR - .04, T_ARR + .14);
    const tick = i => {
      const th = i * 6, ph = th < DIAL.start ? th + 360 : th;
      let k;
      if (ph <= NOW) k = clamp((ph - tipBack) / 12 + late);
      else if (ph <= GOAL) k = clamp((tipOn - ph) / 12 + late);
      else { const d = Math.min(ph - GOAL, DIAL.start + 360 - ph) / 54; k = seg(t, T_ARR + d * .22, T_ARR + d * .22 + .22); }
      k = E.back(k) * gate;
      return { k, a: Math.min(1, k * 2) };
    };
    const numerals = seg(t, T_UN + .12, T_ARR + .1);
    const pops = [seg(t, T_ARR - .02, T_ARR + .24, E.back), seg(t, T_KNOB, T_KNOB + .28, E.back), seg(t, T_ARR, T_ARR + .26, E.back)];
    const landed = t >= T_ARR + .1, gone = t >= T_GONE;            // landed: the marks cover the halves' round ends

    // ---- the dial under it all
    K.dial({
      track: seg(t, .38, .6), numerals: gone ? numerals : 0, tick: gone ? tick : () => ({ k: 0, a: 0 }),
      span: landed ? DIAL.now : 0, ahead: landed ? 1 : 0, marks: gone ? pops : [0, 0, 0],
    });

    // ---- the face and the man; the dial's ticks and numerals over the face's white while it is there
    if (!gone) {
      K.ground(o, box, { alpha: 1 - seg(t, 1.5, 1.84, E.io2), hairline: 1 - seg(t, .16, .5) });
      K.dial({ ctx: o, track: 0, span: 0, ahead: 0, marks: [0, 0, 0], numerals, tick });
      K.clip(o, box, () => {
        K.ticks(o, box, () => ({ a: 1 - seg(t, .34, .54, E.io2), out: 16 * seg(t, .3, .54, E.in2) }));
        K.man(o, box, {
          all: { dy: slide }, body: { sy: 1 + tall },
          head: H.rot < 0 ? H : { rot: H.rot, dy: H.dy },
          brows: { dy: -6 * browUp },
          eyes: { open, dx: gaze * watch, dy: -4 * watch },
          stache: t < T_OFF ? { split: 5 * grin, dy: -2.5 * grin, sx: 1 + .04 * grin } : { s: Math.max(fresh, .001), rot: 7 * wobble(t, T_KNOB + .1, .2, 9) },
          bow: { rot: -40 * lag + 3 * wobble(t, .8, .22, 9) - 4 * wobble(t, T_KNOB + .08, .2, 9) + 3 * wobble(t, 1.5, .22, 9) },
          hide: t >= T_OFF && fresh <= 0 ? ['stache'] : [],
        });
      });
    }

    // ---- the mustache in the air: one shape, its notch at m.x, m.y
    if (t >= T_OFF && t < T_SPLIT) {
      const near = .09 * Math.min(1, up) * (1 - fit);                                      // lifted toward you, it is a little larger
      const m = {
        x: N[0] + off[0] + 9 * arc, y: N[1] + off[1] + 3 * arc,
        dir: lerp(tilt, NOW - 360, turn), bend: seg(t, T_FLY + .07, T_FLY + .2, E.io2) / R,
        kL: k0 * KL * (1 + near - .06 * wind + .08 * arc), kT: k0 * KT * (1 + near + .05 * wind - .05 * arc),
        hug: HUG * seg(t, T_FLY + .03, T_FLY + .19, E.io2),
      };
      // K.stache's outline along a line through the notch, which may bend (as K.ribbon lays it), its edges smooth
      const whole = (m, fill, alpha) => {
        const L = ST.length * m.kL, th0 = m.dir / DEG, b = m.bend, flat = Math.abs(b) < 1e-6, top = [], bottom = [];
        for (let i = 0; i <= 64; i++) {
          const u = i / 64, d = (u - NOTCH) * L, th = th0 + b * d;
          const x = flat ? m.x + d * Math.cos(th0) : m.x + (Math.sin(th) - Math.sin(th0)) / b;
          const y = flat ? m.y + d * Math.sin(th0) : m.y - (Math.cos(th) - Math.cos(th0)) / b;
          const wave = stMid(u) * (1 - m.hug) * m.kT, w = stHalf(u) * m.kT;
          top.push([x + Math.sin(th) * (wave + w), y - Math.cos(th) * (wave + w)]);
          bottom.push([x + Math.sin(th) * (wave - w), y - Math.cos(th) * (wave - w)]);
        }
        shape(top.concat(bottom.reverse()), fill, alpha);
      };
      // its shadow on his face, soft, fainter as it rises
      const lifted = seg(t, T_OFF, T_OFF + .2, E.out2) * (1 - seg(t, T_FLY, T_FLY + .1));
      if (lifted > 0) {
        const lip = box.pt(...onHead(NG, H));
        o.save();
        o.beginPath(); o.arc(box.cx, box.cy, box.size / 2, 0, 7); o.clip();
        o.filter = `blur(${3 * K.unit}px)`;
        whole({ ...m, x: lerp(lip[0], m.x, .4) + 1, y: lerp(lip[1], m.y, .4) + 5 }, C.navy, .2 * lifted);
        o.restore();
      }
      whole(m, ST.color, 1);
      const drawn = seg(t, T_FLY - .08, T_FLY + .04);                                      // its picture gives way to its shape as it is let go
      if (drawn < 1) K.sprite(o, 'stache', m.x, m.y, { k: k0, sx: m.kL / k0, sy: m.kT / k0, rot: m.dir, alpha: 1 - drawn, anchor: NG });
    }

    // ---- the mustache becomes the shift: each half a ribbon from the notch, stretching along the ring
    if (t >= T_SPLIT && !landed) {
      const flat = seg(t, T_UN + .02, T_UN + .26, E.io2);                                  // its outline into the ring's even band
      const round = seg(t, T_UN, T_UN + .12, E.io2);                                       // each tip rounds, and stays round on its way
      const dye = seg(t, T_UN + .04, T_ARR - .04, E.io2);
      // one half: from the notch along the ring, back against the clock (dirn -1) or on with it (+1), L points long, to
      // the outline's end uTip; its tip a round end, which at the start mark is the mark's own disc
      const half = (dirn, L, uTip, fill, alpha) => {
        const span = dirn * L / R * DEG, n = Math.max(40, Math.ceil(L / 2.5)), top = [], bottom = [], cap = [];
        const edge = (v, side) => { const u = lerp(NOTCH, uTip, v); return lerp((stHalf(u) + side * stMid(u) * (1 - HUG)) * k0 * KT, HALF, flat); };
        for (let i = 0; i <= n; i++) {
          top.push(K.at(DIAL.x, DIAL.y, NOW + span * i / n, R + edge(i / n, 1)));
          bottom.push(K.at(DIAL.x, DIAL.y, NOW + span * i / n, R - edge(i / n, -1)));
        }
        const r = (edge(1, 1) + edge(1, -1)) / 2, c = K.at(DIAL.x, DIAL.y, NOW + span, R + (edge(1, 1) - edge(1, -1)) / 2), a = K.rad(NOW + span);
        for (let j = 1; j < 14; j++) {
          const f = j / 14 * Math.PI, across = r * Math.cos(f), along = dirn * r * round * Math.sin(f);
          cap.push([c[0] + across * Math.cos(a) - along * Math.sin(a), c[1] + across * Math.sin(a) + along * Math.cos(a)]);
        }
        shape(top.concat(cap, bottom.reverse()), fill, alpha);
      };
      o.save();
      o.translate(off[0], off[1]);                                                         // what is left of its landing's swing
      half(1, L2, 1, mix(ST.color, C.teal, dye), lerp(1, .18, dye));                       // on to the goal: navy into teal, thinning to the pale arc ahead
      half(-1, L1, 0, mix(ST.color, C.teal, dye), 1);                                      // back to the start: navy into teal
      o.restore();
    }

    // ---- the marks, over the face while it is there: the knob on the notch, the start mark and the flag at the tips' ends
    if (!gone) {
      const mark = (which, s, fn, dx = 0, dy = 0) => { if (s <= 0) return; const [px, py] = K.markAt(which); o.save(); o.translate(px + dx, py + dy); o.scale(s, s); fn(o); o.restore(); };
      mark('start', pops[0], K.startMark);
      mark('goal', pops[2], K.flag);
      mark('now', pops[1], K.knob, off[0], off[1]);                // in the mustache's notch, settling onto the ring with it
    }

    // ---- the Now screen comes in round the dial: the words in its middle once his hair has passed them
    const words = seg(t, 1.72, 1.98, E.out3);
    K.part('center', words, -8 * (1 - words));
    K.parts(t, 1.62, { order: ['cap', 'facts', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });
  },
});
