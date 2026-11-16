/* What the app plays today (ios/Shifty/Views/Opening.swift), at its real speed: its own moments, the design's seconds,
   are stretched by 1.7. Here for comparison; the new openings stand beside it. */
Opening.scene({
  id: 'today', chip: 'היום', title: 'מה שיש היום.',
  about: 'האייקון גדל במקומו לעיגול של השעון ונצבע בצבע האפליקציה, הדמות דוהה ונפתח חור באמצע עד שנשארת הטבעת. הטבעת מתגלגלת אל היום, השעון עולה למקומו והמסך נבנה סביבו.',
  end: 4.1, rest: 2.6, haptics: [[1.46, 'light']],
  draw(t, K) {
    const u = t / 1.7, { E, seg, lerp, mix, DIAL, LAUNCH, C, g, o } = K;
    const settled = seg(u, .66, 1.1, E.out5);                      // the dial, from the screen's middle up to its place
    const cy = lerp(LAUNCH.y, DIAL.y, settled), lift = cy - DIAL.y;
    const unwind = seg(u, .38, .86, E.io3);
    const pop = a => Math.max(0, seg(u, a, a + .18, E.back));
    K.dial({
      cy, track: seg(u, .2, .38), numerals: seg(u, .52, .74),
      tick: i => { const from = .3 + i / 60 * .34, k = seg(u, from, from + .16, E.back); return { k, a: Math.min(1, k) }; },
      span: u >= .36 ? lerp(360, DIAL.now, unwind) : 0, ahead: unwind * seg(u, .36, .5),
      marks: [pop(.66), pop(.74), pop(.82)],
    });
    // the icon: a rounded square growing into the dial's circle in the accent, its mark fading, a hole opening in it
    const p = seg(u, .03, .36, E.io3);
    if (p < 1) {
      const half = lerp(60, DIAL.r + DIAL.w / 2, p), corner = lerp(27, half, Math.pow(p, .55));
      const hole = (DIAL.r - DIAL.w / 2) * seg(u, .13, .36, E.io3);
      const box = K.box(LAUNCH.x, cy, half * 2, corner);
      const fill = o.createLinearGradient(0, box.y, 0, box.y + box.size);
      fill.addColorStop(0, mix(C.groundTop, C.teal, p)); fill.addColorStop(1, mix(C.groundBottom, C.teal, p));
      o.beginPath(); o.roundRect(box.x, box.y, box.size, box.size, corner);
      if (hole > 0) o.arc(box.cx, box.cy, hole, 0, Math.PI * 2);
      o.fillStyle = fill; o.fill('evenodd');
      K.icon(o, box, { ground: false, content: 1 - seg(u, .04, .17, E.out3) });
      o.beginPath(); o.roundRect(box.x + 1.1 * box.k, box.y + 1.1 * box.k, box.size - 2.2 * box.k, box.size - 2.2 * box.k, Math.max(0, corner - 1.1 * box.k));
      o.strokeStyle = `rgba(0,0,0,${.07 * (1 - p)})`; o.lineWidth = 2.2 * box.k; o.stroke();
    }
    K.part('center', seg(u, .7, .98, E.out3), lift);
    const rise = (id, a) => { const s = seg(u, a, a + .34, E.out3); K.part(id, s, (1 - s) * 46); };
    rise('cap', .85); rise('facts', .8); rise('buttons', .8); rise('week', .85);
    K.part('tabs', seg(u, .96, 1.3, E.out3), 0);
  },
});
