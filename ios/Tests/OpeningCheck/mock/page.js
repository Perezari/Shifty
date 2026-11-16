/* The page: the scenes as chips, one phone playing the chosen one; or, for checking a scene, still pictures of it:
     #film=<id>&n=12&from=0&to=2.6&s=.5       n moments of the scene side by side (to: the scene's rest by default)
     #film=<id>&at=0.2,0.35,0.5&s=.5          those moments
     ...&view=141,377,120,120                  only that part of the screen (x, y, w, h in points), s times larger
     #shot=<id>&t=1.2&s=1                      one moment
     #c=<id>                                   the page, on that scene */
(() => {
  const O = window.Opening, scenes = O.scenes;
  const el = id => document.getElementById(id);
  const query = Object.fromEntries(location.hash.slice(1).split('&').filter(Boolean).map(p => p.split('=')));
  const find = id => {
    const i = scenes.findIndex(s => s.id === id);
    if (i < 0) document.body.insertAdjacentHTML('afterbegin', `<p style="color:#c00;font:bold 16px monospace;direction:ltr">NO SCENE "${id}": scenes/${id}.js did not load or did not register that id</p>`);
    return Math.max(0, i);
  };

  // a scene asked for by its id and not on the page yet is loaded from scenes/<id>.js
  const want = query.frames || query.film || query.shot || query.c;
  if (want && !scenes.some(s => s.id === want) && !window.__sceneTried) {
    window.__sceneTried = true;
    const tag = document.createElement('script');
    tag.src = `scenes/${want}.js`;
    tag.onload = tag.onerror = start;
    document.head.appendChild(tag);
  } else start();

  function start() {
  // #frames=<id>&at=0,0.033,...&s=.5&cols=15: bare pictures of those moments in an exact grid, for tools/check.py
  if (query.frames) {
    document.body.classList.add('film', 'bare');
    const sc = scenes[find(query.frames)], s = Number(query.s || .5), cols = Number(query.cols || 15);
    const w = Math.round(O.W * s), h = Math.round(O.H * s);
    O.ready.then(() => {
      query.at.split(',').map(Number).forEach((t, i) => {
        const cell = document.createElement('div');
        cell.style.cssText = `position:absolute;left:${(i % cols) * w}px;top:${Math.floor(i / cols) * h}px;width:${w}px;height:${h}px;overflow:hidden`;
        document.body.appendChild(cell);
        O.phone(cell, { scale: s, dpr: 1 }).draw(sc, t);
      });
      document.title = 'ready';
    });
    return;
  }
  if (query.film || query.shot) {
    document.body.classList.add('film');
    const sc = scenes[find(query.film || query.shot)];
    const s = Number(query.s || (query.shot ? 1 : .5));
    const view = query.view ? (([x, y, w, h]) => ({ x, y, w, h }))(query.view.split(',').map(Number)) : null;
    let times;
    if (query.shot) times = [Number(query.t || 0)];
    else if (query.at) times = query.at.split(',').map(Number);
    else {
      const n = Number(query.n || 12), from = Number(query.from || 0), to = Number(query.to || sc.rest);
      times = Array.from({ length: n }, (_, i) => from + (to - from) * i / (n - 1));
    }
    const sheet = document.createElement('div');
    sheet.className = 'sheet';
    document.body.appendChild(sheet);
    O.ready.then(() => {
      for (const t of times) {
        const tile = document.createElement('div');
        tile.className = 'tile';
        if (!query.shot) tile.textContent = `${sc.id}  t=${t.toFixed(2)}`;
        sheet.appendChild(tile);
        O.phone(tile, { scale: s, view, dpr: 1 }).draw(sc, t);
      }
      document.title = 'ready';
    });
    return;
  }

  const stage = el('stage');
  const ph = O.phone(stage, { scale: 1 });
  el('options').innerHTML = scenes.map((sc, i) => `<button class="option" id="pick${i}" type="button" aria-pressed="false">${i ? i + ' ' : ''}${sc.chip}</button>`).join('');
  ph.root.setAttribute('role', 'img');
  ph.root.setAttribute('aria-label', 'הדמיה של הפתיחה על נתוני דוגמה. לחיצה מנגנת שוב.');

  const LEAD = .45;                       // the launch picture stands a moment before each opening begins
  let current = 0, begun = 0, speed = 1, frozen = null, last = 0, tapped = 0;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function fit() {
    const box = stage.getBoundingClientRect();
    ph.size(Math.max(.2, Math.min((box.width - 14) / O.W, (box.height - 14) / O.H, 1.1)));
    ph.draw(scenes[current], last);
  }
  function play() { begun = performance.now(); frozen = null; tapped = 0; }
  function choose(i) {
    current = i;
    scenes.forEach((_, n) => el('pick' + n).setAttribute('aria-pressed', String(n === i)));
    const about = el('about'), b = document.createElement('b');
    b.textContent = scenes[i].title + ' ';
    about.replaceChildren(b, scenes[i].about);
    play();
    if (reduced) { frozen = scenes[i].rest; last = frozen; ph.draw(scenes[i], frozen); }
  }
  function frame(now) {
    if (frozen === null) {
      const sc = scenes[current];
      let t = (now - begun) / 1000 * speed - LEAD;
      if (t > sc.end) { play(); t = -LEAD; }
      last = t;
      ph.draw(sc, t);
      const taps = sc.haptics || [];
      while (tapped < taps.length && t >= taps[tapped][0]) {
        const tap = el('tap');
        tap.classList.remove('on'); void tap.offsetWidth; tap.classList.add('on');
        tapped++;
      }
    }
    requestAnimationFrame(frame);
  }

  scenes.forEach((_, i) => el('pick' + i).addEventListener('click', () => choose(i)));
  el('again').addEventListener('click', play);
  ph.root.addEventListener('click', play);
  el('slow').addEventListener('click', () => {
    speed = speed === 1 ? .35 : 1;
    el('slow').setAttribute('aria-pressed', String(speed !== 1));
    play();
  });
  new ResizeObserver(fit).observe(stage);
  O.ready.then(() => {
    fit();
    choose(query.c ? find(query.c) : Math.min(1, scenes.length - 1));
    requestAnimationFrame(frame);
  });
  }
})();
