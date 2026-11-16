/* Mr. Now. The icon was the dial's "now" knob all along, seen from very close. The plate rounds into a white disc,
   the logo's nine ticks leave the man for its edge and close into a teal rim (the knob, 6.75 times its size), and the
   man in it opens his eyes and winks; the dial's ring shows under him as a broad road; then ONE camera pull-back
   shows the whole dial, with him riding it at this very minute. As the knob gets small his round portrait draws in
   to the disc's middle and is the knob's teal dot. The dial is never built: it is the world the knob was sitting
   on. Plate = disc, ticks = rim, man = dot. */
Opening.scene({
  id: 'mrnow', chip: 'מר עכשיו', title: 'מר עכשיו.',
  about: 'האייקון מתעגל לעיגול עם טבעת בצבע האפליקציה, ומר משמרת קורץ. המצלמה מתרחקת, ומתברר שהעיגול הוא הסמן של עכשיו על השעון.',
  end: 3.8, rest: 2.3, haptics: [[1.42, 'light']],
  draw(t, K) {
    const { E, seg, spring, lerp, clamp, DIAL, LAUNCH, C, g, o } = K;
    if (t <= .12) { K.launch(); return; }                          // the launch picture, still
    const NOW = DIAL.start + DIAL.now, GOAL = DIAL.start + DIAL.goal;   // the knob's and the flag's angles, clockwise from 12
    const A0 = NOW - 30;                                           // where he rides from
    const Z0 = 216 / 32;                                           // the giant knob against the real one: 6.75
    const T = .86;                                                 // the camera lets go
    const L = T + .56;                                             // the landing: the dial first reaches its own size
    const S = T + 1.2;                                             // and stands still
    const sin = d => Math.sin(d * Math.PI / 180), cos = d => Math.cos(d * Math.PI / 180);

    // ---- the plate grows into the giant knob (a spring, a little over and back), its corner rounding into a circle
    let grow = spring(t, .15, .5, .7); grow += (1 - grow) * seg(t, .6, .84, E.io2);
    const breath = seg(t, .12, .17, E.io2) * (1 - seg(t, .17, .26, E.io2));          // it draws in a little first
    const round = seg(t, .15, .4, E.io2);

    // ---- the camera. At the zoom Z0 the dial's middle is far off the screen, so that the knob, 30 degrees before
    //      "now" on the ring, stands at the launch icon's place. The pull-back is a zoom about one fixed point of the
    //      screen (the dial's middle goes straight to its place as the zoom falls), and ONE spring drives it and the
    //      knob's ride along the ring to "now": it comes in a touch small and settles.
    const far = [LAUNCH.x - Z0 * DIAL.r * sin(A0), LAUNCH.y + Z0 * DIAL.r * cos(A0)];
    const focus = [(Z0 * DIAL.x - far[0]) / (Z0 - 1), (Z0 * DIAL.y - far[1]) / (Z0 - 1)];
    let p = spring(t, T, .84, .8); p += (1 - p) * seg(t, S - .24, S, E.io2);
    const push = seg(t, T - .12, T, E.io2) * (1 - seg(t, T, T + .14, E.io2));        // a breath in before it
    const still = t >= S;
    const cam = Math.pow(Z0, -p) * (1 + .03 * push);
    const zd = still ? 1 : Z0 * cam;                               // the dial's zoom
    const z = still ? 1 : lerp(LAUNCH.size, 216, grow) * (1 - .035 * breath) / 32 * cam;   // the knob's: the plate's own growth, then the dial's
    const a = still ? NOW : lerp(A0, NOW, p);
    const cx = still ? DIAL.x : focus[0] + zd * (DIAL.x - focus[0]), cy = still ? DIAL.y : focus[1] + zd * (DIAL.y - focus[1]);
    const kx = cx + zd * DIAL.r * sin(a), ky = cy - zd * DIAL.r * cos(a);

    // ---- the dial: the road under the knob, then all of it, then the finished Now screen's
    const sweep = seg(t, L, L + .34, E.io2);                       // the pale arc ahead, from the knob to the goal
    const flag = seg(t, L + .28, L + .52, E.back);
    if (still) K.dial();
    else if (t > .59) {
      // the road: the ring at the knob's zoom, shown by a round opening that spreads from under the disc to the
      // screen's corners (a soft start, hidden under the disc, then an even pace): the band comes out of him both
      // ways as one, its front parallel to his rim, and the ticks come up as the opening passes them
      const pace = u => (u < .25 ? 2 * u * u : u - .125) / .875;
      const road = t < T, wipe = 96 + 400 * seg(t, .59, T - .02, pace);
      const band = (from, to, color) => {
        g.save(); g.translate(cx, cy); g.scale(zd, zd);
        g.beginPath(); g.arc(0, 0, DIAL.r, K.rad(from), K.rad(to)); g.lineCap = 'butt'; g.lineWidth = DIAL.w; g.strokeStyle = color; g.stroke();
        g.restore();
      };
      // (the band's own ends, 26 degrees either way, are far beyond the screen: the dial's own band takes over unseen)
      if (road) { g.save(); g.beginPath(); g.arc(kx, ky, wipe, 0, 7); g.clip(); band(a, a + 26, 'rgba(0,0,0,.06)'); }
      K.dial({
        cx, cy, k: zd, track: road ? 0 : 1, numerals: 1,
        tick: road ? i => {
          const d = i * 6 - a, away = zd * Math.hypot(DIAL.r - 138 * cos(d), 138 * sin(d));   // the tick's distance from the knob
          const k = E.back(clamp((wipe - away) / 70));
          return { k, a: Math.min(1, k * 2) };
        } : null,
        span: road ? 0 : a - DIAL.start, ahead: 0, marks: [1, 0, 0],
      });
      if (road) { band(a - 26, a, C.teal); g.restore(); }
      if (sweep > 0) band(a, lerp(a, GOAL, sweep), 'rgba(15,157,143,.18)');
      if (flag > 0) {
        const [fx, fy] = K.at(cx, cy, GOAL, DIAL.r * zd);
        g.save(); g.translate(fx, fy); g.scale(zd * flag, zd * flag); K.flag(g); g.restore();
      }
    }

    // ---- the knob: the icon's plate, then the giant knob, then the real one
    if (!still) {
      const R = 16 * z, size = 2 * R;
      const box = K.box(kx, ky, size, lerp(LAUNCH.r / LAUNCH.size, .5, round) * size);
      const isDisc = round >= 1;
      const shade = seg(t, .2, .5, E.io2), white = seg(t, .14, .4), hair = 1 - seg(t, .14, .4);
      const pulse = 1 + .3 * (seg(t, L - .02, L + .08, E.out2) - seg(t, L + .08, L + .3, E.io2));
      const outline = inset => { if (isDisc) { o.beginPath(); o.arc(kx, ky, Math.max(0, R - inset), 0, 7); } else K.path(o, box, inset); };

      // the plate
      o.save();
      if (shade > 0) { o.shadowColor = `rgba(0,0,0,${.22 * shade})`; o.shadowBlur = 7 * z * K.unit; o.shadowOffsetY = 4 * z * K.unit; }
      if (isDisc) o.fillStyle = '#fff';
      else {
        const fill = o.createLinearGradient(0, box.y, 0, box.y + box.size);
        fill.addColorStop(0, K.mix(C.groundTop, '#FFFFFF', white)); fill.addColorStop(1, K.mix(C.groundBottom, '#FFFFFF', white));
        o.fillStyle = fill;
      }
      outline(0); o.fill();
      o.restore();
      if (hair > 0) { o.save(); outline(1.1 * box.k); o.strokeStyle = `rgba(0,0,0,${.07 * hair})`; o.lineWidth = 2.2 * box.k; o.stroke(); o.restore(); }

      // the man: a round portrait, a little smaller in the disc, to sit inside the rim. As the disc gets small
      // (70 to 38 points across) the portrait draws in to the disc's middle and goes teal: it is the knob's dot
      const fit = seg(t, .14, .5, E.io2), thick = seg(t, .26, .5, E.io2);
      const q = clamp((2.2 - z) / (2.2 - 1.18)), f = lerp(1, 4.5 / 13, E.io2(q));
      const mbox = K.box(kx, ky - 14 * fit * box.k * f, size * lerp(1, .8, fit) * f);
      const open = seg(t, .3, .42, E.io2), lift = spring(t, .3, .3, .5);
      const wink = seg(t, .48, .54, E.io2) - seg(t, .6, .67, E.io2);                   // once the rim has closed
      const look = seg(t, .65, .77, E.io2);                        // a glance down the road
      const level = seg(t, .28, .5, E.io2), lean = seg(t, .66, .86, E.io2);
      const shut = seg(t, T - .03, T + .07, E.io2);                // his eyes shut in the rush: the logo's own smile
      const drag = seg(t, T, T + .1, E.out2) - seg(t, T + .1, T + .34, E.io2);         // and his head left a little behind
      if (q < 1) {
        o.save();
        if (q > 0) { o.beginPath(); o.arc(kx, ky, 13 * z * f, 0, 7); } else outline(3 * z * thick);
        o.clip();
        K.man(o, mbox, {
          // (the lean is the whole man's: more than 5 degrees at the neck shows its cut; on the ride he banks into the curve)
          all: { rot: 4 * lean + 6 * Math.min(1, p), dy: 5 * push },
          head: { rot: 5 * level - 2 * wink - 7 * drag, dy: 2 * level },
          brows: { dy: -6 * lift * (1 - shut) + 3 * shut },
          browL: { dy: 6 * wink },
          eyes: { dx: 2.5 * look * (1 - shut), dy: 1.2 * look * (1 - shut) },
          eyeL: { open: open * (1 - wink) * (1 - shut) }, eyeR: { open: open * (1 - shut) },
          stache: { rot: 5 * wink, split: 5 * wink + 3 * shut },
          bow: { rot: 5 * K.wobble(t, .2, .24, 8) + 12 * K.wobble(t, T + .02, .15, 6) },   // it arrives a beat after him, and flutters in the rush
        });
        o.restore();
      }
      if (q > 0) {
        o.save();
        o.globalAlpha = E.io2(clamp((q - .2) / .8));
        o.fillStyle = C.teal; o.beginPath(); o.arc(kx, ky, 13 * z * f * pulse, 0, 7); o.fill();
        o.restore();
      }

      // the rim: the logo's nine ticks go out to the plate's edge, turning teal, and spread along it until they
      // close into a ring (from the top down both sides; it closes at the bottom), which thickens to the knob's own
      const rim = lerp(17 * mbox.k, 3.5 * z, thick), rho = R - rim / 2;
      o.save();
      o.lineCap = 'round';
      if (t >= .5) { outline(rim / 2); o.strokeStyle = C.teal; o.lineWidth = rim; o.stroke(); }
      else K.TICKS.forEach((tk, i) => {
        const from = .19 + Math.min(tk.hour, 360 - tk.hour) / 30 * .012, land = from + .13, fly = seg(t, from, land, E.io2);
        const th = Math.atan2(tk.cx - 256, 256 - tk.cy), s = K.tickOnScreen(mbox, i);
        o.strokeStyle = K.mix(C.navy, C.teal, fly); o.lineWidth = lerp(s.w, rim, fly);
        o.beginPath();
        if (fly < 1) {
          const x = lerp(s.mid[0], kx + rho * Math.sin(th), fly), y = lerp(s.mid[1], ky - rho * Math.cos(th), fly);
          const hx = (s.b[0] - s.a[0]) / 2 * (1 - fly), hy = (s.b[1] - s.a[1]) / 2 * (1 - fly);
          o.moveTo(x - hx, y - hy); o.lineTo(x + hx, y + hy);
        } else {
          const half = .0005 + 66 * Math.PI / 180 * seg(t, land, .5, E.io2);
          o.arc(kx, ky, rho, th - Math.PI / 2 - half, th - Math.PI / 2 + half);
        }
        o.stroke();
      });
      o.restore();
    }

    // ---- the Now screen comes in round the dial: the words in its middle as it comes to rest (held to the dial's own
    //      place and size until it has), the capsule in its place, the rest rising once the dial has landed
    const words = seg(t, L - .1, L + .22, E.out3), cap = seg(t, L + .06, L + .44, E.out3);
    K.part('center', words, cy - DIAL.y, { dx: cx - DIAL.x, scale: lerp(.94, 1, words) * zd });
    K.part('cap', cap, 10 * (1 - cap));
    K.parts(t, L + .1, { order: ['facts', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });
  },
});
