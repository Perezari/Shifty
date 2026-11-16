/* The monocle. A close-up on his face: he opens one eye and cocks the eyebrow above it; the eyebrow slides down round
   the eye and closes into a monocle; a glint crosses the monocle, and it grows and is the dial's ring, the clock
   already in its lens. The logo's nine ticks are drawn round that very eye, so at the close-up they stand on the
   dial's hour ticks. One stroke the whole way: an arc over the eye, a circle round it, the ring round the clock. */
Opening.scene({
  id: 'monocle', chip: 'המונוקל', title: 'המונוקל.',
  about: 'הגבה שלו יורדת ונסגרת סביב העין למונוקל. העדשה גדלה עד שהמסגרת שלה היא הטבעת של השעון, והקווים של הלוגו נעשים שנתות השעות.',
  end: 3.8, rest: 2.35, haptics: [[.84, 'rigid'], [1.47, 'light']],
  draw(t, K) {
    const { E, seg, spring, lerp, clamp, DIAL, LAUNCH, TC, P, g, o } = K;
    const OUT = DIAL.r + DIAL.w / 2;                                // the dial's outer circle, 171
    const KEND = 137.5 / TC.r;                                      // the close-up's size: the logo's ticks on the dial's hour ticks
    const rgb = c => `rgb(${c.map(Math.round).join(',')})`, blend = (a, b, k) => a.map((v, i) => v + (b[i] - v) * k);
    const INK = [2, 19, 49], TEAL = [15, 157, 143];                 // the drawing's own line; the app's accent
    // the eyebrow as a stroke on the icon's grid: an arc about (253, 239) with round ends; and the monocle it becomes
    const BROW = { x: 253, y: 239, r: 33.7, w: 12.8, a0: -69, a1: 23 };
    const MONO = { r: 20 / KEND, w: 6 / KEND };
    // the moments: the monocle closes; the glint sets off; the lens begins to grow; the dial itself takes over from the rim
    const CLICK = .84, GLINT = 1.06, GROW = 1.16, LAND = 1.87;

    // ---- the close-up: the tile grows and rises until the ticks' circle (and the eye in its middle) is the dial's
    const cam = lerp(spring(t, .12, .5, .85), 1, seg(t, .66, .82));
    const box = K.box(LAUNCH.x, lerp(LAUNCH.y, DIAL.y - (TC.y - 256) * KEND, cam), lerp(LAUNCH.size, 512 * KEND, cam));
    const half = lerp(LAUNCH.size / 2, OUT, cam);
    const frame = K.box(LAUNCH.x, lerp(LAUNCH.y, DIAL.y, cam), half * 2, half * lerp(LAUNCH.r / (LAUNCH.size / 2), 1, seg(t, .16, .5, E.io2)));
    // the logo's nine ticks stand within two degrees of their hours: during the move each is set exactly on its own
    const set = seg(t, .16, .5, E.io2);
    const onHour = (i, tk) => {
      if (!set) return {};
      const h = tk.hour * Math.PI / 180, turn = ((tk.hour - Math.atan2(tk.x2 - tk.x1, tk.y1 - tk.y2) * 180 / Math.PI + 90) % 180 + 180) % 180 - 90;
      return { dx: (TC.x + TC.r * Math.sin(h) - tk.cx) * set, dy: (TC.y - TC.r * Math.cos(h) - tk.cy) * set, rot: turn * set };
    };

    // ---- his acting
    // the click: his head leans up into the monocle as it comes down, gives as it closes, and returns
    const lean = seg(t, .7, CLICK - .005, E.io2), hit = seg(t, CLICK - .005, CLICK + .075, E.out2), give = hit - seg(t, CLICK + .075, CLICK + .17, E.io2);
    // his head lags a little as the camera sets off, rocks back as it arrives, and settles; the bow tie a beat after it
    const headRot = 2.2 * (seg(t, .14, .24, E.io2) - seg(t, .24, .36, E.io2))
      - 3 * (seg(t, .32, .44, E.io2) - spring(t, .44, .36, .55)) * (1 - seg(t, .66, .72))
      + .9 * lean * (1 - hit) - .7 * give;
    const bowRot = 5 * K.wobble(t, .34, .28, 8) * (1 - seg(t, .72, .82));
    // the eye opens while his head is still settling; the brow above it cocks on a spring, then winds up a little
    const open = seg(t, .46, .59, E.io2);
    const cock = spring(t, .52, .26, .55), wind = seg(t, .64, .7, E.io2);
    const brow = { dy: -11 * cock - 3 * wind, rot: 10 * cock + 2 * wind };
    const squeeze = seg(t, .52, .66, E.io2);
    // the canvas `o` set to the icon's grid on his head, as K.man places it
    const onHead = () => { o.translate(box.x, box.y); o.scale(box.k, box.k); o.translate(P.neck[0], P.neck[1]); o.rotate(headRot * Math.PI / 180); o.translate(-P.neck[0], -P.neck[1]); };

    // ---- the stroke: the cocked eyebrow, sliding down onto the eye while its ends run on round it
    const th = brow.rot * Math.PI / 180, bx = BROW.x - P.browL[0], by = BROW.y - P.browL[1];
    const from = [P.browL[0] + bx * Math.cos(th) - by * Math.sin(th), P.browL[1] + brow.dy + bx * Math.sin(th) + by * Math.cos(th)];
    const slide = seg(t, .7, CLICK, E.io2), run = seg(t, .7, CLICK, E.in2);
    const snap = K.wobble(t, CLICK, .2, 12) * (1 - seg(t, .92, .98));
    const meet = (BROW.a0 + BROW.a1) / 2 + brow.rot + 180;
    const stroke = {
      x: lerp(from[0], TC.x, slide), y: lerp(from[1], TC.y, slide),
      r: lerp(BROW.r, MONO.r, slide) - 2.2 * snap, w: lerp(BROW.w, MONO.w, slide) + 1.2 * snap,
      a0: lerp(BROW.a0 + brow.rot, meet - 360, run), a1: lerp(BROW.a1 + brow.rot, meet, run),
    };

    // ---- the monocle grows into the dial's ring: a small dip, then out on a spring (to about 164) and back to 160
    const radius = s => lerp(20 - 2 * seg(s, GLINT, GROW, E.io2) + 142 * spring(s, GROW, .56, .75), DIAL.r, seg(s, LAND - .14, LAND, E.io2));
    const width = s => lerp(6, DIAL.w, Math.pow(clamp((radius(s) - 20) / 140), 1.15));
    const when = f => { for (let s = GROW; s < LAND; s += .004) if (f(s)) return s; return LAND; };
    const R = radius(t), W = width(t), landed = t >= LAND;
    const tTicks = when(s => radius(s) - width(s) / 2 >= 124);               // the lens reaches the logo's ticks
    // once the rim has covered his head and the bow tie, what is left outside it (the shirt's hem) lets go; the logo's
    // ticks stay whole until the rim is over them (their caps reach 151)
    const leave = 1 - seg(R + W / 2, 140, 153), gone = leave <= 0;
    // the rim's ink turns to the accent as it grows; then all but the time worked pales to the day's track
    const toTeal = seg(R, 28, 88, E.io2), day = seg(R, 84, 150, E.io2);
    // the glint: a band of light crossing the lens from the upper left; its place across the lens, -1 to 1
    const sweep = lerp(-1.5, 2.1, seg(t, GLINT, GLINT + .168));

    // ---- the dial, under it all: its face while the lens grows, then all of it
    const pop = a => seg(t, a, a + .24, E.back);
    const marks = [pop(1.48), pop(1.56), pop(1.64)];
    if (landed) K.dial({ marks });
    else if (t >= GLINT) {
      const sprout = seg(t, tTicks + .02, tTicks + .26, E.back), slim = seg(t, tTicks, tTicks + .26, E.io2);
      const nine = new Set(K.TICKS.map(tk => tk.hour / 6));
      K.dial({ track: 0, span: 0, ahead: 0, marks: [0, 0, 0], tick: i => nine.has(i) ? { a: slim < 1 ? 0 : 1 } : { k: sprout, a: Math.min(1, sprout * 2) } });
      // the logo's nine ticks, seen through the lens: each slims, where it stands, into the dial's hour tick
      if (slim < 1) for (const tk of K.TICKS) {
        const len = lerp(Math.hypot(tk.x2 - tk.x1, tk.y2 - tk.y1) * KEND, 9, slim), ink = blend([10, 20, 53], [60, 60, 67], slim);
        g.beginPath(); g.moveTo(...K.at(DIAL.x, DIAL.y, tk.hour, 137.5 - len / 2)); g.lineTo(...K.at(DIAL.x, DIAL.y, tk.hour, 137.5 + len / 2));
        g.strokeStyle = `rgba(${ink.map(Math.round).join(',')},${lerp(1, .6, slim)})`; g.lineWidth = lerp(tk.w * KEND, 2, slim); g.lineCap = 'round'; g.stroke();
      }
    }

    // ---- the portrait, cut by the lens once it has opened
    if (!gone) {
      o.save();
      if (t >= GLINT && sweep > -1) {
        o.beginPath(); o.rect(0, 0, K.W, K.H);
        const left = sweep >= 1 ? 0 : Math.acos(sweep), a0 = Math.PI / 4 + left;          // the part of the lens the glint has crossed
        o.moveTo(DIAL.x + R * Math.cos(a0), DIAL.y + R * Math.sin(a0)); o.arc(DIAL.x, DIAL.y, R, a0, a0 + 2 * (Math.PI - left)); o.closePath();
        o.clip('evenodd');
      }
      K.ground(o, frame, { hairline: 1, alpha: leave });
      K.path(o, frame); o.clip();
      K.ticks(o, box, onHour);
      o.globalAlpha = leave;
      K.man(o, box, {
        head: { rot: headRot },
        browL: { ...brow, alpha: 1 - seg(t, .65, .69) },
        eyeL: { open, dx: -1.5 * open, dy: -3.5 * open },
        eyeR: { sy: lerp(1, .78, squeeze) }, browR: { dy: 3 * squeeze },
        bow: { rot: bowRot },
        stache: { rot: -4.5 * seg(t, CLICK - .01, CLICK + .05, E.out2) - 1.2 * give },   // the rim sits on its tip and presses it down
      });
      o.globalAlpha = 1;
      // the glass in the closed rim: a faint wash and a small highlight
      const glass = seg(t, CLICK, CLICK + .1, E.out2);
      if (glass > 0) {
        o.save(); onHead();
        o.beginPath(); o.arc(TC.x, TC.y, stroke.r, 0, Math.PI * 2); o.fillStyle = `rgba(255,255,255,${.07 * glass})`; o.fill();
        o.beginPath(); o.arc(TC.x, TC.y, stroke.r * .62, K.rad(-66), K.rad(-66 + 36 * glass));
        o.strokeStyle = 'rgba(255,255,255,.92)'; o.lineWidth = 3.4; o.lineCap = 'round'; o.stroke();
        o.restore();
      }
      o.restore();
    }

    // ---- the stroke itself: the eyebrow, the monocle, the ring
    const strokeIn = seg(t, .62, .66);
    if (t < GLINT && strokeIn > 0) {
      o.save(); onHead();
      o.globalAlpha = strokeIn;
      o.beginPath();
      if (run >= 1) o.arc(stroke.x, stroke.y, stroke.r, 0, Math.PI * 2); else o.arc(stroke.x, stroke.y, stroke.r, K.rad(stroke.a0), K.rad(stroke.a1));
      o.strokeStyle = rgb(INK); o.lineWidth = stroke.w; o.lineCap = 'round'; o.stroke();
      o.restore();
    } else if (t >= GLINT && !landed) {
      // the glint: a band of white light with a crisp front and a long soft tail; before it the lens shows his eye,
      // and behind it the dial comes out of the light
      if (sweep < 2.1) {
        const d = Math.SQRT1_2, along = c => [DIAL.x + d * c * R, DIAL.y + d * c * R];
        o.save();
        o.beginPath(); o.arc(DIAL.x, DIAL.y, R, 0, Math.PI * 2); o.clip();
        const shine = o.createLinearGradient(...along(sweep - 1.05), ...along(sweep + .4));
        shine.addColorStop(0, 'rgba(255,255,255,0)'); shine.addColorStop(.655, 'rgba(255,255,255,1)');
        shine.addColorStop(.807, 'rgba(255,255,255,1)'); shine.addColorStop(1, 'rgba(255,255,255,0)');
        o.fillStyle = shine; o.fillRect(DIAL.x - R, DIAL.y - R, 2 * R, 2 * R);
        o.restore();
      }
      // the rim: ink, then the accent, then the day's own colors: the track, the pale arc ahead, the time worked
      const bg = [244, 245, 247], track = blend(bg, [0, 0, 0], .06), ahead = blend(track, TEAL, .18), live = blend(INK, TEAL, toTeal);
      const arc = (a, b, color) => { o.beginPath(); o.arc(DIAL.x, DIAL.y, R, K.rad(a), K.rad(b)); o.strokeStyle = rgb(color); o.lineWidth = W; o.lineCap = 'butt'; o.stroke(); };
      arc(0, 360, blend(live, track, day));
      if (day > 0) {
        arc(DIAL.start + DIAL.now, DIAL.start + DIAL.goal, blend(live, ahead, day));
        arc(DIAL.start, DIAL.start + DIAL.now, live);
      }
    }

    // ---- the marks, as the ring lands (over the rim until the dial itself takes over)
    if (!landed) [[0, K.startMark], [DIAL.now, K.knob], [DIAL.goal, K.flag]].forEach(([deg, fn], i) => {
      if (marks[i] <= 0) return;
      const [x, y] = K.at(DIAL.x, DIAL.y, DIAL.start + deg, R);
      o.save(); o.translate(x, y); o.scale(marks[i], marks[i]); fn(o); o.restore();
    });

    // ---- the words in the lens: the clock is in it from the glint on, and grows with it
    if (t >= GLINT) K.part('center', 1, 0, { scale: landed ? 1 : clamp((R - W / 2) / (DIAL.r - DIAL.w / 2), 0, 1.03) });
    K.parts(t, 1.5, { order: ['facts', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });
    const cap = seg(t, 1.52, 1.92, E.out3);                          // the capsule, a short way: it stays clear of the ring
    K.part('cap', cap, (1 - cap) * 14);
  },
});
