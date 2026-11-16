/* The ride. The icon's tile closes in round the man into a little white medallion (his head and his bow tie; the shirt
   goes as the tile cuts it away); he hops onto the dial's ring where
   the shift began and rides it clockwise to this very minute, the worked arc laid behind him and the hours and the
   shekels counting up with him; he brakes, and the medallion contracts into the white "now" knob: the tile is the
   knob's disc, its rim the knob's rim, his head the knob's dot. */
Opening.scene({
  id: 'ride', chip: 'הסיבוב', title: 'הסיבוב.',
  about: 'מר משמרת קופץ על הטבעת ורוכב עליה מתחילת המשמרת ועד הדקה הזאת, והשעות והשקלים נספרים איתו. בסוף הוא מתכווץ לסמן של עכשיו.',
  end: 4.2, rest: 2.6, haptics: [[.64, 'light'], [1.66, 'medium'], [2.08, 'light']],
  draw(t, K) {
    const { E, seg, spring, wobble, lerp, clamp, DIAL, LAUNCH, C, g, o } = K;
    if (t < .12) { K.launch(); return; }                           // the launch picture, still
    if (t >= 2.56) {                                               // the Now screen, whole
      K.dial();
      for (const id of K.PARTS) K.part(id, 1, 0);
      return;
    }

    // ---- the medallion: a disc of 64 points (twice the knob's), the man in it at 0.7 of the launch picture's size,
    //      the grid point GC (the middle of the logo's ring of ticks) at its middle
    const R = 32, MS = .7, GC = [256, 242], k0 = LAUNCH.size / 512;
    const HOME = [LAUNCH.x + (GC[0] - 256) * k0, LAUNCH.y + (GC[1] - 256) * k0];    // where GC is in the launch picture
    const S = K.markAt('start'), NOW = DIAL.start + DIAL.now;
    // ---- the moments
    const CLOSE = [.18, .42], CROUCH = [.34, .44], HOP = [.44, .64], WIND = [.72, .86], GO = .86, BRAKE = 1.64, TURN = 1.9, KNOB = 2.16;

    // ---- where he is on the ring: a wind back, the ride (he arrives with speed), and a spring that takes that speed
    const SL = .72, KICK = .8, PER = .32, Z = .45;                 // KICK under 1: he is off at once after the wind back
    const ringAt = t => {
      const u = Math.pow(clamp((t - GO) / (BRAKE - GO)), KICK);
      let p = (3 - SL) * u * u + (SL - 2) * u * u * u;
      if (t > BRAKE) {
        const w = 2 * Math.PI / PER, wd = w * Math.sqrt(1 - Z * Z), x = t - BRAKE;
        p = 1 + SL * KICK / (BRAKE - GO) / wd * Math.exp(-Z * w * x) * Math.sin(wd * x) * (1 - seg(t, TURN - .1, TURN + .04));
      }
      return lerp(DIAL.start - 7 * seg(t, WIND[0], WIND[1], E.io2), NOW, p);
    };
    // ---- where the medallion's middle is: at home, in the hop's flight, on the ring
    const HOPH = 62;
    const arrive = (() => { const vx = S[0] - HOME[0], vy = S[1] - HOME[1] + 4 * HOPH, n = Math.hypot(vx, vy); return [vx / n, vy / n]; })();
    const where = t => {
      if (t <= HOP[0]) { const e = seg(t, CLOSE[0], CLOSE[1], E.io2); return [lerp(LAUNCH.x, HOME[0], e), lerp(LAUNCH.y, HOME[1], e)]; }
      if (t < HOP[1]) { const f = Math.pow((t - HOP[0]) / (HOP[1] - HOP[0]), 1.25); return [lerp(HOME[0], S[0], f), lerp(HOME[1], S[1], f) - HOPH * 4 * f * (1 - f)]; }
      const [x, y] = K.at(DIAL.x, DIAL.y, ringAt(t), DIAL.r), b = 4 * wobble(t, HOP[1], .2, 12);
      return [x + arrive[0] * b, y + arrive[1] * b];
    };
    const ang = ringAt(t), ridden = Math.max(0, ang - DIAL.start), prog = clamp(ridden / DIAL.now);
    const [x, y] = where(t), [xb, yb] = where(t - .06), [x1, y1] = where(t - .012), [x2, y2] = where(t + .012);
    const vx = (x2 - x1) / .024, vy = (y2 - y1) / .024, speed = Math.hypot(vx, vy);
    const tangent = a => [Math.cos(a * Math.PI / 180), Math.sin(a * Math.PI / 180)];      // the clockwise way along the ring at a

    // ---- the dial under him
    const wave = i => { const d = ((i * 6 - DIAL.start + 720) % 360) / 360, a = HOP[1] + .02 + d * .2; return [seg(t, a, a + .18, E.back), seg(t, a, a + .09)]; };
    K.dial({
      track: seg(t, .14, .46), numerals: seg(t, HOP[1] + .1, HOP[1] + .45),
      tick: i => { const [k, a] = wave(i); return { k, a }; },
      span: ridden, ahead: 0, marks: [seg(t, GO + .04, GO + .2, E.back) * (1 + .16 * wobble(t, GO + .17, .2, 10)), 0, 0],
    });
    // the pale arc ahead runs on from him to the goal, and the flag pops at its end
    const run = seg(t, TURN + .08, TURN + .44, E.io2);
    if (run > 0) {
      g.beginPath(); g.arc(DIAL.x, DIAL.y, DIAL.r, K.rad(ang), K.rad(lerp(NOW, DIAL.start + DIAL.goal, run)));
      g.strokeStyle = 'rgba(15,157,143,.18)'; g.lineWidth = DIAL.w; g.lineCap = 'butt'; g.stroke();
    }
    const mark = (which, s, fn) => { if (s <= 0) return; const [px, py] = K.markAt(which); g.save(); g.translate(px, py); g.scale(s, s); fn(g); g.restore(); };
    if (t >= KNOB) mark('now', 1, K.knob);
    mark('goal', seg(t, TURN + .38, TURN + .62, E.back), K.flag);

    // ---- the words in the dial's middle: pale at nought, then counting with him, and landing with him
    const words = seg(t, HOP[1], HOP[1] + .24, E.out3);
    K.part('center', words * lerp(.5, 1, seg(t, GO, GO + .3)), 0, { scale: lerp(.96, 1, words) + .028 * wobble(t, BRAKE, .3, 9) });
    if (t < BRAKE) K.center({ time: K.clock(K.SHIFT.seconds * prog), pay: '₪ ' + Math.round(K.SHIFT.pay * prog) });
    // the rest of the screen comes in with the knob, after his last look at us: the capsule from above (clear of the
    // ring), the cards rising
    const cap = seg(t, TURN - .02, TURN + .4, E.out3);
    K.part('cap', cap, -14 * (1 - cap));
    K.parts(t, TURN + .02, { order: ['facts', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });

    if (t >= KNOB) return;                                         // from here he is the dial's own knob

    // ---- the medallion's shape
    const close = seg(t, CLOSE[0], CLOSE[1], E.io2);
    const shrink = seg(t, TURN, KNOB - .06, E.io2);                // his head into the dot
    const pop = seg(t, TURN + .03, KNOB - .02, E.io3);             // the disc into the knob
    const snap = lerp(spring(t, TURN + .03, .26, .62), 1, seg(t, KNOB - .07, KNOB - .01));   // its size: a little under, and back
    const swell = 1.4 * seg(t, TURN - .08, TURN + .03, E.io2);    // a breath in before it closes
    const h = lerp(lerp(60, R, close) + swell, 16, snap);
    const corner = lerp(27, h, seg(t, .16, .36, E.io2));
    const ms = lerp(lerp(1, MS, seg(t, .25, CLOSE[1], E.io2)), .1, shrink);    // he keeps his size until the tile reaches him, then is squeezed with it
    const k = k0 * ms;

    // ---- how he is carried: the head lags behind the disc, he leans into the way, and is thrown on when he brakes
    let lx = (xb - x) * .07, ly = (yb - y) * .07;
    const far = Math.hypot(lx, ly); if (far > 3.6) { lx *= 3.6 / far; ly *= 3.6 / far; }
    const windUp = seg(t, WIND[0], WIND[1], E.io2) - seg(t, GO, GO + .1, E.out2);
    const [wx, wy] = tangent(DIAL.start), [nx, ny] = tangent(NOW);
    const thrown = wobble(t, BRAKE + .01, .3, 8);
    lx += -wx * 3 * windUp - nx * 2.5 * thrown; ly += -wy * 3 * windUp - ny * 2.5 * thrown;
    const brace = seg(t, BRAKE - .17, BRAKE - .05, E.io2) - seg(t, BRAKE - .03, BRAKE + .04, E.out2);   // he leans back to brake
    const lean = clamp(-lx * 4, -15, 15) - 10 * brace + 9 * thrown;
    const calm = 1 - shrink;

    // ---- his face
    const crouch = seg(t, CROUCH[0], CROUCH[1] - .02, E.out2) - seg(t, CROUCH[1] - .02, CROUCH[1] + .03, E.in2);
    const riding = seg(t, GO, GO + .12) - seg(t, BRAKE - .06, BRAKE + .02);
    const open = seg(t, .13, .23, E.io2) - seg(t, HOP[1] - .01, HOP[1] + .07, E.io2) + seg(t, BRAKE - .02, BRAKE + .07, E.out3);
    const brow = spring(t, .12, .3, .5)
      - 1.5 * (seg(t, CROUCH[0], CROUCH[0] + .07, E.io2) - seg(t, HOP[0] - .01, HOP[0] + .06, E.io2))
      - 1.7 * (seg(t, WIND[0], WIND[1], E.io2) - seg(t, GO, GO + .12, E.out3))
      + .3 * wobble(t, HOP[1], .2, 9) - .9 * brace + .5 * wobble(t, BRAKE, .26, 8)
      - .7 * seg(t, TURN - .1, TURN, E.io2);
    // where the open eyes look: up at the dial, then at the place he will land on; after the ride, on along the ring, then straight out
    const lookX = -2 * seg(t, .26, .36, E.io2) + 4 * seg(t, .9, 1.1) - 2 * seg(t, BRAKE + .1, TURN - .04, E.io2);
    const lookY = -2 * seg(t, .14, .24, E.io2) + 1.5 * seg(t, .26, .36, E.io2) + .5 * seg(t, .9, 1.1);
    const flap = (t - GO) / .11 * 2 * Math.PI;                   // the wind in his mustache: its halves flap a beat apart
    const split = 8 * wobble(t, .15, .2, 9) - 6 * crouch
      + 12 * (seg(t, HOP[0], HOP[0] + .08) - seg(t, HOP[1] - .02, HOP[1] + .04)) + 10 * wobble(t, HOP[1], .2, 8)
      - 9 * windUp + (8 + 5 * Math.sin(flap)) * riding + 14 * wobble(t, BRAKE, .28, 6.5)
      + 7 * seg(t, BRAKE + .14, BRAKE + .24, E.io2);                            // and a last smile, straight at us
    const glance = seg(t, .14, .26, E.io2) - seg(t, .3, .4, E.io2);           // he lifts his face to the dial as he wakes
    const pose = {
      all: { rot: .4 * lean * calm, pivot: GC },
      body: { alpha: 1 - seg(t, .3, .42) },                        // the shirt goes as the tile cuts it away: a medallion shows his head and his bow tie
      head: { dx: .6 * lx / k * calm, dy: (.6 * ly / k + 4 * crouch) * calm, rot: .6 * lean * calm - 4 * glance },
      // the bow tie goes with the head, over the neck, and swings on a beat after it when he lands and when he brakes
      bow: { dx: .6 * lx / k * calm, dy: .6 * ly / k * calm, rot: (.5 * lean + 7 * wobble(t, HOP[1] + .04, .2, 9) + 9 * wobble(t, BRAKE + .05, .24, 8)) * calm },
      brows: { dy: -7 * brow },
      eyes: { open, dx: lookX * calm, dy: lookY * calm - 3 * riding, s: 1 + .06 * riding, sy: 1 - .3 * windUp },
      stache: { split: split * calm, rot: 5 * Math.cos(flap) * riding * calm, dx: .3 * lx / k * calm, dy: (clamp(.2 * ly / k, -2, 3) + 3 * riding) * calm },
    };

    // ---- squash and stretch: the crouch (about the disc's bottom), the stretch along his way, the landing, the brake
    const squashes = [];
    const along = .12 * clamp(speed / 1000);
    if (along > .001) squashes.push([Math.atan2(vy, vx), 1 + along, 1 - along * .6]);
    const land = wobble(t, HOP[1], .2, 10);
    if (land) squashes.push([Math.atan2(arrive[1], arrive[0]), 1 - .16 * land, 1 + .1 * land]);
    const brake = wobble(t, BRAKE, .28, 9);
    if (brake) squashes.push([Math.atan2(ny, nx), 1 - .08 * brake, 1 + .05 * brake]);
    if (windUp) squashes.push([Math.atan2(wy, wx), 1 - .08 * windUp, 1 + .05 * windUp]);
    if (crouch) squashes.push([Math.PI / 2, 1 - .12 * crouch, 1 + .08 * crouch]);

    // ---- draw him
    const white = seg(t, TURN, KNOB - .04), rim = lerp(2.5 * seg(t, .25, .42, E.out2), 3.5, pop);
    const air = t > HOP[0] && t < HOP[1] ? Math.sin(Math.PI * Math.pow((t - HOP[0]) / (HOP[1] - HOP[0]), 1.25)) : 0;   // how high he is in the hop
    const shade = [lerp(9, 7, pop) + 6 * air, 4 + 7 * air, lerp(.24 * seg(t, .2, .4), .22, pop) * (1 - .35 * air)], sc = [10, 20, 53].map(v => Math.round(v * (1 - pop)));
    o.save();
    o.translate(x, y + h * .12 * crouch);
    for (const [a, sa, sb] of squashes) { o.rotate(a); o.scale(sa, sb); o.rotate(-a); }
    const frame = K.box(0, 0, h * 2, corner);
    if (shade[2] > 0) {
      o.save(); o.shadowColor = `rgba(${sc.join(',')},${shade[2]})`; o.shadowBlur = shade[0] * K.unit; o.shadowOffsetY = shade[1] * K.unit;
      K.path(o, frame); o.fillStyle = '#fff'; o.fill(); o.restore();
    }
    K.ground(o, frame, { hairline: 1 - seg(t, .16, .34), toward: ['#ffffff', white] });
    const dot = seg(t, KNOB - .09, KNOB - .03);
    if (dot < 1) {
      o.save();
      if (shrink > 0) { o.beginPath(); o.arc(0, 0, lerp(R, 4.5, shrink), 0, 7); } else K.path(o, frame);
      o.clip();
      if (shrink > 0) { o.fillStyle = K.mix('#ffffff', C.teal, E.in2(shrink)); o.fillRect(-R, -R, 2 * R, 2 * R); }
      const gc = [lerp(GC[0], 254, shrink), lerp(GC[1], 233, shrink)];
      const off = t <= HOP[0] ? [HOME[0] - x, HOME[1] - y] : [0, 0];        // while the tile closes in, he stays where he is
      const box = K.box(off[0] + .4 * lx * calm + (256 - gc[0]) * k, off[1] + .4 * ly * calm + (256 - gc[1]) * k, LAUNCH.size * ms);
      if (t < .4) K.ticks(o, box, i => { const s = seg(t, .12 + i * .011, .23 + i * .011, E.io2); return s >= 1 ? null : { len: 1 - s, out: -70 * s }; });
      K.man(o, box, pose);
      o.restore();
    }
    if (rim > 0) { K.path(o, frame, rim / 2); o.strokeStyle = C.teal; o.lineWidth = rim; o.stroke(); }
    if (dot > 0) { o.globalAlpha = dot; o.fillStyle = C.teal; o.beginPath(); o.arc(0, 0, 4.5, 0, 7); o.fill(); o.globalAlpha = 1; }
    o.restore();
  },
});
