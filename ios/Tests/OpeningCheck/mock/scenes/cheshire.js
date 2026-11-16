/* Only the mustache stays. The icon rises into the dial's place and becomes its round face, the man in it; he opens
   his eyes and wags his mustache; then he fades away part by part and the mustache alone hangs in the empty dial,
   grins once more, leaps onto the ring and stretches along it into the shift's arc. */
Opening.scene({
  id: 'cheshire', chip: 'רק השפם', title: 'רק השפם נשאר.',
  about: 'מר משמרת עולה אל השעון, פוקח עיניים ומנענע את השפם. אז הוא נעלם חלק אחרי חלק, ורק השפם נשאר באוויר. השפם קופץ אל הטבעת ונמתח לאורכה עד שהוא הקשת של המשמרת: ככל שעבדת יותר, השפם ארוך יותר.',
  end: 4.5, rest: 2.85, haptics: [[1.7, 'light'], [2.04, 'light']],
  draw(t, K) {
    const { E, seg, spring, lerp, mix, DIAL, LAUNCH, C, g, o } = K;
    const FACE = DIAL.r - DIAL.w / 2;                              // the dial's face: the ring's inner edge, 149
    const MID = DIAL.start + DIAL.now / 2;                         // the middle of the shift's arc, on the ring
    const [mx, my] = K.at(DIAL.x, DIAL.y, MID, DIAL.r);

    // ---- the icon rises to the dial's middle and grows into its face, its corners rounding into a circle
    const rise = spring(t, .12, .7, .8);
    const size = lerp(LAUNCH.size, FACE * 2, rise);
    const box = K.box(LAUNCH.x, lerp(LAUNCH.y, DIAL.y, rise), size, lerp(LAUNCH.r, size / 2, seg(t, .16, .56, E.io2)));

    // ---- the man's hello
    const open = seg(t, .54, .66, E.io2) - seg(t, 1.14, 1.22, E.io2);                     // the eyes open, and close before he goes
    const lift = spring(t, .54, .3, .5) - seg(t, .96, 1.1, E.io2);                         // the brows
    const wagOn = seg(t, .68, .72) - seg(t, .9, .96);                                      // the mustache see-saws twice
    const wag = 13 * Math.sin((t - .68) / .24 * 2 * Math.PI) * wagOn;
    const curl = 16 * (spring(t, .92, .26, .5) - seg(t, 1.32, 1.42, E.io2)) + 5 * K.wobble(t, 1.26, .16, 9);   // its tips up: a grin
    // ---- he goes, from the outside in; the mustache stays
    const gone = (a, b) => 1 - seg(t, a, b, E.out2);
    const leap = t >= 1.42;

    // ---- the dial under it all: its track from the moment the face is round, then all that the mustache brings
    const wave = i => { const d = Math.abs(((i * 6 - MID + 540) % 360) - 180) / 180; return seg(t, 1.72 + d * .34, 1.72 + d * .34 + .24, E.back); };
    const landed = t >= 2.3;                                       // from here the dial's own arc stands for the ribbon
    K.dial({
      track: seg(t, .4, .7), numerals: seg(t, 1.9, 2.15), tick: i => ({ k: wave(i), a: Math.min(1, wave(i) * 2) }),
      span: landed ? DIAL.now : 0, ahead: seg(t, 2.04, 2.28), marks: [0, 0, 0],
    });

    // ---- the face and the man
    if (t < 1.32) {
      K.icon(o, box, {
        ground: { alpha: gone(1.04, 1.3), hairline: 1 - seg(t, .16, .5) },
        ticks: (i) => ({ a: gone(1.0, 1.12), out: -9 * seg(t, 1.0, 1.12, E.in2) }),
        pose: {
          head: { rot: -4 * (seg(t, .54, .7, E.io2) - seg(t, .7, .96, E.io2)), alpha: gone(1.06, 1.22) },
          body: { alpha: gone(1.0, 1.14) }, bow: { alpha: gone(1.0, 1.14) },
          brows: { dy: -6 * lift - 2.5 * Math.abs(wag) / 13, alpha: gone(1.14, 1.26) },
          eyes: { open, alpha: gone(1.2, 1.3) },
          stache: { rot: wag, split: curl, dy: -1.5 * curl / 16 },
        },
      });
    } else if (!leap) {
      // the mustache alone, hanging where his face was: it lifts a little and its tips flick once more
      K.man(o, box, { hide: ['body', 'bow', 'brows', 'eyes'], head: { alpha: 0 }, stache: { split: curl, dy: -1.5 * curl / 16 - 3 * seg(t, 1.3, 1.42, E.io2) } });
    }

    // ---- the leap: a crouch, a flight in an arc to the ring, turning to lie along it; then it stretches along the ring
    if (leap && !landed) {
      const k = box.k, [sx0, sy0] = box.pt(K.stache.middle[0], K.stache.middle[1] - 3);
      const crouch = seg(t, 1.42, 1.5, E.out2) - seg(t, 1.5, 1.6, E.io2);
      const fly = seg(t, 1.5, 1.7, E.io3);
      const x = lerp(sx0, mx, fly) - 26 * Math.sin(Math.PI * fly), y = lerp(sy0, my, fly) - 10 * Math.sin(Math.PI * fly);
      const dir = lerp(0, MID - 360, seg(t, 1.5, 1.68, E.io2));                              // to the ring's direction at the arc's middle
      const bend = seg(t, 1.58, 1.7, E.io2) / DIAL.r;
      const along = 1 + .1 * crouch + .14 * Math.sin(Math.PI * fly);                         // squash, then stretch in flight
      const flat = seg(t, 1.66, 1.92, E.io2);                                                // its outline into the ring's even band
      const reach = spring(t, 1.7, .52, .8);                                                 // its tips race apart to the arc's two ends
      const length = lerp(K.stache.length * k * along, DIAL.now * Math.PI / 180 * DIAL.r, reach);
      const thin = 1 - .2 * crouch;
      const color = mix(K.stache.color, C.teal, seg(t, 1.72, 1.98, E.io2));
      const ribbon = (ctx, alpha) => K.ribbon(ctx, {
        x, y, dir, length, bend, fill: color, alpha, n: 72,
        top: u => lerp(K.stache.top(u) * k * thin, DIAL.w / 2, flat), bottom: u => lerp(K.stache.bottom(u) * k * thin, DIAL.w / 2, flat),
      });
      // the picture of the mustache gives way to its shape as it takes off
      const drawn = seg(t, 1.44, 1.56);
      ribbon(fly < 1 ? o : g, 1);
      if (drawn < 1) K.sprite(o, 'stache', x, y, { k, rot: dir, sx: along, sy: thin, alpha: 1 - drawn, anchor: K.stache.middle });
    }

    // ---- the marks, over the ribbon's ends: the start mark where its tail stops, the knob on its leading tip
    const mark = (which, s, fn) => { if (s <= 0) return; const [px, py] = K.markAt(which); g.save(); g.translate(px, py); g.scale(s, s); fn(g); g.restore(); };
    mark('start', seg(t, 1.98, 2.2, E.back), K.startMark);
    mark('now', seg(t, 2.04, 2.28, E.back), K.knob);
    mark('goal', seg(t, 2.2, 2.44, E.back), K.flag);

    // ---- the Now screen comes in round the dial
    const words = seg(t, 1.78, 2.08, E.out3);
    K.part('center', words, 0, { scale: lerp(.96, 1, words) });
    K.parts(t, 1.96, { order: ['cap', 'facts', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });
  },
});
