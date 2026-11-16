/* The grand handlebar. The camera closes in on his mustache until its middle lies, level, on the dial's 6 o'clock. He
   opens his eyes and winds it up; its two tips run out round him along the dial's own circle, each arm swelling from the
   tip's point to the ring's own band, and meet over his head with a tap: the loop of mustache IS the ring. The hoop
   rocks once about his lip; from the kiss a glint runs down both sides and the navy gives way, in place, to the day;
   what is left is his own mustache again, which springs flat on his lip. He leans back into his own tilt and goes down
   behind the facts card, which rises over him like a counter.

   The mustache is drawn here as a shape (its picture's outline from K.stache, with the picture's own dark line and navy
   inside) from the moment he winds it up until it is home again; its picture gives way to the shape and takes over from
   it where the two are the same. The man is on K.g, in front of the dial and behind the Now screen's cards. */
Opening.scene({
  id: 'handlebar', chip: 'השפם', title: 'השפם הגדול.',
  about: 'מר משמרת מסלסל את השפם, ושני הקצוות צומחים, מקיפים אותו ונפגשים מעל הראש: השפם הוא הטבעת של השעון. הטבעת נדלקת בצבע האפליקציה, והוא יורד אל מאחורי הכרטיס.',
  end: 3.9, rest: 2.3, haptics: [[1.06, 'rigid'], [1.31, 'light']],
  draw(t, K) {
    const { E, seg, spring, wobble, lerp, clamp, DIAL, LAUNCH, C, P, g } = K;
    if (t <= .12) { K.launch(); return; }
    const PI = Math.PI, R = DIAL.r, HW = DIAL.w / 2, rad = d => d * PI / 180;
    const sm = (a, b, x) => { const v = clamp((x - a) / (b - a)); return v * v * (3 - 2 * v); };

    const SIZE = 300, RHO = 8.5, KE = SIZE / 512;                   // the icon's size close up; the head's turn that levels the mustache
    const SIX = [DIAL.x, DIAL.y + R];                               // the ring's 6 o'clock, where the mustache's middle parks
    const SL = K.stache.length, H0 = SL / 2 * KE;                   // the mustache's half length on the screen, close up
    const FULL = PI * R - H0;                                       // how far each tip runs: from the mustache's end to 12
    const GROW = .66, KISS = 1.06, GLINT = .32;                     // the tips leave; they meet; the glint's run down to 6
    const BACK = KISS + GLINT * (1 - Math.sqrt((H0 / (PI * R)) / 2));   // the moment the loop is his mustache again
    const HANG = GROW + .16;                                        // from here to BACK the head is dead still and the loop hangs from the ring's own 6 o'clock

    // ---- a point of the head on the icon's grid, the head turned by `a` degrees about the neck (and squashed by `q`)
    const turned = ([x, y], a, q = 0) => {
      const c = Math.cos(rad(a)), s = Math.sin(rad(a)), dx = (x - P.neck[0]) * (1 + q / 2), dy = (y - P.neck[1]) * (1 - q);
      return [P.neck[0] + dx * c - dy * s, P.neck[1] + dx * s + dy * c];
    };

    // ---- the camera: one push toward the mustache, its middle coming to rest on the ring's 6 o'clock
    const push = lerp(spring(t, .12, .42, .8), 1, seg(t, .44, .6, E.io2));
    const [mx, my] = turned(K.stache.middle, RHO);
    const size = lerp(LAUNCH.size, SIZE, push);
    // ---- his exit: a small bow, then straight down behind the card
    const sink = 178 * seg(t, 1.47, 1.74, E.in2) - 5 * (seg(t, 1.36, 1.45, E.io2) - seg(t, 1.45, 1.52, E.in2));
    const box = K.box(lerp(LAUNCH.x, SIX[0] - (mx - 256) * KE, push), lerp(LAUNCH.y, SIX[1] - (my - 256) * KE, push) + sink, size);
    const k = box.k;

    // ---- the loop's own clock
    const run = .93 * seg(t, GROW, KISS - .06, E.io2) + .07 * seg(t, KISS - .08, KISS, E.in3);   // the tips: off, round, a breath short of each other, and a snap
    const glint = E.io2(clamp((t - KISS) / GLINT));                                    // 0 at 12, 1 at 6, down both sides
    const ext = t < KISS ? FULL * run : Math.max(0, FULL - glint * PI * R);            // each tip's way along the ring, in points
    const passed = deg => KISS + GLINT * (deg <= 90 ? Math.sqrt(deg / 360) : 1 - Math.sqrt((1 - deg / 180) / 2));   // when the glint passes `deg` from 12
    // the kiss's wiggle: the hoop rocks once about his lip (the ring's 6 o'clock), the lit part of the dial with it: his
    // mustache only wags where it sits, the top swings about 10 points one way, 5 back, and is still before he moves again
    const wig = 2.6 * wobble(t, KISS, .3, 5) * sm(KISS, KISS + .08, t) * (1 - sm(KISS + .24, KISS + .3, t));
    const rock = () => { if (wig) { g.translate(SIX[0], SIX[1]); g.rotate(rad(wig)); g.translate(-SIX[0], -SIX[1]); } };

    // ---- the man's acting
    const open = seg(t, .3, .42, E.io2) - .45 * (seg(t, .5, .62, E.io2) - seg(t, GROW, GROW + .06, E.out2)) - seg(t, KISS, KISS + .07, E.out2);
    const brow = -6 * spring(t, .33, .3, .5) + 5 * (seg(t, .5, .62, E.io2) - seg(t, GROW, GROW + .08, E.out3)) - 4 * seg(t, GROW, GROW + .1, E.out3)
      + 10 * seg(t, KISS, KISS + .1, E.io2) - 3 * wobble(t, KISS + .02, .2, 9);
    const look = 2 * seg(t, .46, .6, E.io2) - 5 * seg(t, GROW + .04, 1.04, E.io2) + 3 * seg(t, KISS, KISS + .06);
    const up = seg(t, .14, .54, E.io2) - .7 * seg(t, 1.36, 1.5, E.io2);        // he straightens up; and leans back into his own tilt as he goes
    const headRot = RHO * up - .4 * wig * (1 - sm(KISS + .14, BACK, t));        // (and counter-sways a little under the rocking hoop, while it hangs from the ring)
    // the head gathers with the mustache as he winds up, and springs a little tall as the tips leave
    const squash = .035 * (seg(t, .5, .62, E.io2) - seg(t, GROW - .01, GROW + .05, E.out2)) - .02 * (seg(t, GROW - .01, GROW + .05, E.out2) - seg(t, GROW + .05, HANG, E.io2));
    // the bow tie turns a little with the head (it keeps the neck covered), kicks as the tips leave, and shivers at the kiss
    const bowRot = 6 * up + 8 * (seg(t, GROW, GROW + .07, E.out2) - seg(t, GROW + .07, GROW + .34, E.io2)) + 3 * wobble(t, KISS, .2, 9);

    // ---- the facts card, the counter he bows out behind
    // (it comes into sight below his bust, where the page is empty, and is whole before it reaches his shirt)
    const cardUp = t >= 1.9 ? 1 : lerp(spring(t, 1.28, .46, .75), 1, seg(t, 1.6, 1.9)), cardY = 482 + 112 * (1 - cardUp);
    K.part('facts', seg(t, 1.28, 1.33), cardY - 482);

    // ---- the dial under it all: from the kiss, as far as the glint has come down each side
    if (t >= KISS + GLINT + .24) K.dial();                         // all of it has popped by now: the finished dial
    else if (t >= KISS) {
      const pop = (deg, d = .2) => seg(t, passed(deg), passed(deg) + d, E.back);
      g.save(); rock();
      // the ring's band (the track, the worked arc, the arc ahead), cut to the wedge the glints have opened from 12
      g.save(); g.beginPath(); g.moveTo(DIAL.x, DIAL.y);
      g.arc(DIAL.x, DIAL.y, R + 40, K.rad(-glint * 180), K.rad(glint * 180)); g.closePath(); g.clip();
      K.dial({ numerals: 0, tick: () => ({ k: 0, a: 0 }), marks: [0, 0, 0] });
      g.restore();
      // the ticks and the three marks pop as a glint passes each; the numerals fade in
      K.dial({
        track: 0, span: 0, ahead: 0, numerals: seg(t, KISS + .1, KISS + .4),
        tick: i => { const d = Math.min(i * 6, 360 - i * 6), v = seg(t, passed(d), passed(d) + .18, E.back); return { k: v, a: Math.min(1, v * 2) }; },
        marks: [pop(360 - DIAL.start), pop(DIAL.start + DIAL.now - 360), pop(DIAL.start + DIAL.goal - 360)],
      });
      g.restore();
    }

    // ---- the man, in front of the dial; cut at the card's top edge as it rises over him
    const gone = sink >= 178;
    if (!gone) {
      g.save(); g.beginPath(); g.rect(0, 0, K.W, cardY + 30); g.clip();
      // the plate melts into the page from its edges inward, and with it the shirt, which is kept only as a bust:
      // the page's color over both, clear round the bow tie and whole from the plate's edges on
      const melt = seg(t, .12, .3, E.io2), plate = 1 - seg(t, .12, .32, E.io2);
      if (plate > 0) K.ground(g, box, { alpha: plate, hairline: 1 - seg(t, .12, .17) });
      K.clip(g, box, () => K.man(g, box, { hide: ['head', 'bow'] }));
      if (melt > 0) {
        const [bx, by] = box.pt(P.knot[0], P.knot[1] + 6), Y = .52;
        const from = plate > 0 ? box.y - 2 : box.pt(0, 350)[1];        // once the plate is gone, only over the shirt (the dial is above it)
        g.save(); g.globalAlpha = melt; g.translate(bx, by); g.scale(1, Y);
        const fade = g.createRadialGradient(0, 0, 96 * k, 0, 0, 215 * k);
        fade.addColorStop(0, K.rgba(C.bg, 0)); fade.addColorStop(1, K.rgba(C.bg, 1));
        g.fillStyle = fade; g.fillRect(box.x - 2 - bx, (from - by) / Y, box.size + 4, (box.y + box.size + 2 - from) / Y); g.restore();
      }
      // the nine ticks fly past the camera
      const fly = seg(t, .12, .44, E.in2), tk = 1 - seg(t, .16, .34);
      if (tk > 0) K.ticks(g, K.box(box.cx, box.cy, box.size * lerp(1, 3.6, fly)), () => ({ a: tk, w: lerp(1, .55, fly) }));
      // the mustache: its picture, or the shape that stands in for it (below)
      const shape = seg(t, .46, .54) - seg(t, BACK + .18, BACK + .26);
      K.man(g, box, {
        hide: ['body'], head: { rot: headRot, sx: 1 + squash / 2, sy: 1 - squash }, bow: { rot: bowRot },
        brows: { dy: brow }, eyes: { open, dy: look }, stache: { alpha: shape > 0 ? 0 : 1 },
      });

      if (shape > 0) {
        // The mustache as a shape: its picture's outline, turned level with the head; bent onto the ring's circle; its
        // two tips running out along that circle. While it is a loop it hangs from the ring's 6 o'clock itself.
        const loop = t >= HANG && t <= BACK;
        const turn = loop ? RHO : headRot;
        const [hx, hy] = box.pt(...turned(K.stache.middle, turn, loop ? 0 : squash));
        const ax = loop ? SIX[0] : hx, ay = loop ? SIX[1] : hy;
        // its curl: wound up to two and a half times the ring's, let go onto the ring's own; home again it springs flat, a touch past and back
        const bend = 2.5 * seg(t, .5, .63, E.io2) - 1.5 * seg(t, .63, .74, E.out3) - spring(t, BACK + .01, .18, .45);
        const squeeze = 1 - .12 * (seg(t, .5, .63, E.io2) - spring(t, GROW - .02, .2, .5));
        // as he winds it up its tips round and thicken a little, ready to run; and go back when it is home
        const even = seg(t, .55, .67, E.io2) - seg(t, BACK, BACK + .08, E.io2);
        const slim = clamp(even / .6), fat = clamp((even - .4) / .6);  // first its curled tips straighten to points, then the points fatten
        const NECK = 4.5, SWELL = 64;                                  // the tips' half thickness then; the way over which an arm swells from it to the ring's band
        const plump = lerp(1.16, 1, seg(t, KISS - .02, KISS + .03));   // the leading bulb against its arm; even with it from the kiss on
        const kap = bend / R, flat = Math.abs(kap) < 1e-6;
        const at = (s, d) => flat ? [ax + s, ay + d] : [ax + (1 / kap + d) * Math.sin(kap * s), ay - 1 / kap + (1 / kap + d) * Math.cos(kap * s)];
        // its two edges, each from the left end to the right, as (s, d): s along the line from the middle, d across it
        const c = Math.cos(rad(turn)), sn = Math.sin(rad(turn)), N = 64, top = [], bot = [];
        for (let i = 0; i <= N; i++) {
          const u = i / N, x = (u - .5) * SL;
          for (const [edge, y, side] of [[top, -K.stache.top(u), -1], [bot, K.stache.bottom(u), 1]]) {
            let s = (x * c - y * sn) * k, d = (x * sn + y * c) * k;
            d = lerp(d, side * lerp(1.6, NECK, fat), sm(.82, 1, Math.abs(s) / H0) * slim);
            if (i === 0 || i === N) s = lerp(s, Math.sign(s) * H0, even);
            edge.push([s * squeeze, d]);
          }
        }
        // each end: an arm along the line, swelling from the tip's thickness to the ring's band, and the round bulb that
        // leads it; once the two bulbs touch at 12 they are one
        let closed = false;
        if (even > 0) for (const sign of [1, -1]) {
          const a = top[sign < 0 ? 0 : top.length - 1], b = bot[sign < 0 ? 0 : bot.length - 1];
          const s0 = Math.abs(a[0] + b[0]) / 2, mid0 = (a[1] + b[1]) / 2, h0 = Math.max(.01, (b[1] - a[1]) / 2);
          const midAt = x => lerp(mid0, 0, sm(0, SWELL, x)), halfAt = x => lerp(h0, HW, sm(0, SWELL, x));
          const mid = midAt(ext), h = halfAt(ext), r = h * lerp(1, plump, fat);
          const th1 = PI - Math.asin(Math.min(1, h / r)), pc = s0 + ext - r * Math.cos(th1), gap = PI * R - pc;   // the bulb's middle; its way to 12
          closed = gap < r;
          const th0 = closed ? Math.min(th1, Math.acos(clamp(gap / r, -1, 1))) : 0;
          const n = Math.max(1, Math.ceil(ext / 4));
          for (const [edge, side] of [[top, -1], [bot, 1]]) {
            const more = [];
            for (let j = 1; j <= n; j++) { const x = ext * j / n; more.push([sign * (s0 + x), midAt(x) + side * halfAt(x)]); }
            for (let j = 9; j >= 0; j--) { const th = lerp(th0, th1, j / 10); more.push([sign * (pc + r * Math.cos(th)), mid + side * r * Math.sin(th)]); }
            if (sign > 0) edge.push(...more); else edge.unshift(...more.reverse());
          }
        }
        const trace = () => {
          g.beginPath();
          for (const line of closed ? [bot, top.slice().reverse()] : [[...top, ...bot.slice().reverse()]]) {
            line.forEach(([s, d], i) => { const [x, y] = at(s, d); g[i ? 'lineTo' : 'moveTo'](x, y); });
            g.closePath();
          }
        };
        // drawn as his mustache is drawn: the dark line round it, a little heavier below, and the navy inside
        g.save(); rock();
        const navy = g.createRadialGradient(ax, ay - R, R - 15, ax, ay - R, R + 21);
        navy.addColorStop(0, '#1B3064'); navy.addColorStop(1, '#0E214C');
        trace(); g.fillStyle = navy; g.fill(); g.clip();
        g.translate(0, -1.2 * k / KE); trace(); g.strokeStyle = '#02132F'; g.lineWidth = 10 * k / KE; g.lineJoin = 'round'; g.stroke();
        g.restore();
        // the glint on the loop's two receding ends: on the navy's very end, where the day begins. The left one goes out
        // as it comes to his hair (white over the navy hair is a smudge), the right one at his mustache's tip
        const spark = seg(t, KISS - .01, KISS + .03) - seg(t, BACK - .07, BACK + .01), down = glint * 180;
        g.save(); rock();
        if (spark > 0) for (const sign of [-1, 1]) {
          const a = spark * (sign < 0 ? 1 - sm(116, 130, down) : 1);
          if (a <= 0) continue;
          const [x, y] = K.at(DIAL.x, DIAL.y, sign * Math.max(0, down - 3.4), R);
          const glow = g.createRadialGradient(x, y, 0, x, y, 13);
          glow.addColorStop(0, `rgba(255,255,255,${a})`); glow.addColorStop(.3, `rgba(255,255,255,${.6 * a})`); glow.addColorStop(1, 'rgba(255,255,255,0)');
          g.fillStyle = glow; g.beginPath(); g.arc(x, y, 13, 0, 7); g.fill();
        }
        g.restore();
        // its picture gives way to the shape, and takes over from it again
        if (shape < 1) K.sprite(g, 'stache', hx, hy, { k, rot: headRot, alpha: 1 - shape, anchor: K.stache.middle });
      }
      g.restore();
    }

    // ---- the Now screen comes in round the dial
    const words = seg(t, 1.56, 1.86, E.out3);
    K.part('center', words, 0, { scale: lerp(.94, 1, words) });
    K.parts(t, 1.56, { order: ['cap', 'buttons', 'week', 'tabs'], gap: .07, dur: .42 });
  },
});
