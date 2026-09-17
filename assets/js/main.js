/* ==========================================================================
   The Diver's Boat — Koh Phangan
   Scroll = descent. Everything here degrades to a perfectly usable page
   if JS never runs.
   ========================================================================== */
(function () {
  'use strict';

  var root  = document.documentElement;
  var calm  = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ----------------------------------------------------------------------
     Header: solidify once we leave the surface
     ---------------------------------------------------------------------- */
  var hdr = document.querySelector('.hdr');

  /* ----------------------------------------------------------------------
     Mobile drawer
     ---------------------------------------------------------------------- */
  var burger = document.querySelector('.burger');
  var drawer = document.getElementById('drawer');

  function setDrawer(open) {
    if (!burger || !drawer) return;
    burger.setAttribute('aria-expanded', String(open));
    drawer.dataset.open = String(open);
    drawer.setAttribute('aria-hidden', String(!open));
    document.body.classList.toggle('is-locked', open);
  }

  if (burger && drawer) {
    burger.addEventListener('click', function () {
      setDrawer(burger.getAttribute('aria-expanded') !== 'true');
    });
    drawer.addEventListener('click', function (e) {
      if (e.target.closest('a')) setDrawer(false);
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') setDrawer(false);
    });
  }

  /* ----------------------------------------------------------------------
     Reveal on approach

     Driven by the same scroll pass as the depth computer rather than an
     IntersectionObserver: an observer created before the browser finishes a
     deep-link jump (/#courses) can settle on stale intersections and leave
     whole sections at opacity 0. A rect sweep always agrees with what is
     actually on screen, and the list empties as it goes.
     ---------------------------------------------------------------------- */
  var pending = [].slice.call(document.querySelectorAll('.rise'));

  function showAll() {
    pending.forEach(function (el) { el.classList.add('is-in'); });
    pending.length = 0;
  }

  function sweep() {
    if (!pending.length) return;
    var line = window.innerHeight * 0.88;
    for (var i = pending.length - 1; i >= 0; i--) {
      if (pending[i].getBoundingClientRect().top < line) {
        pending[i].classList.add('is-in');
        pending.splice(i, 1);
      }
    }
  }

  if (calm.matches) showAll();

  /* ----------------------------------------------------------------------
     Depth computer
     Each [data-depth] section declares the depth of its top edge. We read
     off where the viewport's eye-line sits between two of them, so the
     number moves smoothly and always matches the section you're reading.
     ---------------------------------------------------------------------- */
  var marks = [].slice.call(document.querySelectorAll('[data-depth]'));
  var pin   = document.querySelector('.hud__pin');
  var out   = document.querySelector('.hud__depth');
  var zone  = document.querySelector('.hud__zone');
  var maxD  = marks.length ? Number(marks[marks.length - 1].dataset.depth) : 40;
  var stops = [];

  function measure() {
    stops = marks.map(function (el) {
      var r = el.getBoundingClientRect();
      return {
        y: r.top + window.scrollY,
        d: Number(el.dataset.depth),
        z: el.dataset.zone || ''
      };
    });
  }

  function lerp(a, b, t) { return a + (b - a) * t; }

  function readDepth() {
    if (!stops.length) return { d: 0, z: '' };
    var eye = window.scrollY + window.innerHeight * 0.42;

    if (eye <= stops[0].y) return { d: stops[0].d, z: stops[0].z };

    for (var i = 0; i < stops.length - 1; i++) {
      var a = stops[i], b = stops[i + 1];
      if (eye >= a.y && eye < b.y) {
        var t = b.y === a.y ? 0 : (eye - a.y) / (b.y - a.y);
        return { d: lerp(a.d, b.d, t), z: t < 0.55 ? a.z : b.z };
      }
    }
    var last = stops[stops.length - 1];
    return { d: last.d, z: last.z };
  }

  var lastZone = '';

  function paint() {
    var r    = readDepth();
    var frac = Math.min(1, Math.max(0, r.d / maxD));

    root.style.setProperty('--depth', frac.toFixed(4));

    if (out)  out.firstChild.nodeValue = r.d.toFixed(1);
    if (pin)  pin.style.top = (frac * 100).toFixed(2) + '%';
    if (zone && r.z !== lastZone) { zone.textContent = r.z; lastZone = r.z; }

    if (hdr) hdr.classList.toggle('is-stuck', window.scrollY > 40);

    sweep();
  }

  var queued = false;
  function onScroll() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(function () { paint(); queued = false; });
  }

  measure();
  paint();
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', function () { measure(); paint(); });

  /* Images and fonts land after first paint, and a fragment jump can happen
     later still, so re-measure once everything has settled. */
  window.addEventListener('load', function () {
    measure(); paint();
    setTimeout(function () { measure(); paint(); }, 120);
    setTimeout(function () { measure(); paint(); }, 600);
  });

  /* Last resort: nothing should ever be left invisible. */
  setTimeout(showAll, 4000);

  /* ----------------------------------------------------------------------
     Bubbles — seeded once, then left to CSS
     ---------------------------------------------------------------------- */
  var ambient = document.querySelector('.ambient');

  if (ambient && !calm.matches) {
    var frag  = document.createDocumentFragment();
    var count = window.innerWidth < 700 ? 14 : 26;

    for (var i = 0; i < count; i++) {
      var b = document.createElement('i');
      var size = 3 + Math.random() * 11;
      b.className = 'bubble';
      b.style.cssText =
        'left:' + (Math.random() * 100).toFixed(2) + '%;' +
        'width:' + size.toFixed(1) + 'px;height:' + size.toFixed(1) + 'px;' +
        'animation-duration:' + (11 + Math.random() * 16).toFixed(1) + 's;' +
        'animation-delay:-' + (Math.random() * 22).toFixed(1) + 's;';
      frag.appendChild(b);
    }
    ambient.appendChild(frag);
  }

  /* ----------------------------------------------------------------------
     Hero parallax — the camera sinks a touch slower than the page
     ---------------------------------------------------------------------- */
  var heroImg = document.querySelector('.hero__media img');

  if (heroImg && !calm.matches) {
    var hero = document.querySelector('.hero');
    var tick = false;
    window.addEventListener('scroll', function () {
      if (tick) return;
      tick = true;
      requestAnimationFrame(function () {
        var h = hero.offsetHeight || 1;
        var p = Math.min(1, window.scrollY / h);
        heroImg.style.transform =
          'scale(' + (1.04 + p * 0.06).toFixed(4) + ') translateY(' + (p * 7).toFixed(2) + '%)';
        tick = false;
      });
    }, { passive: true });
  }

  /* ----------------------------------------------------------------------
     Dive torch — the beam follows the pointer across a dive-site card,
     restoring the colour that depth takes away.
     ---------------------------------------------------------------------- */
  [].slice.call(document.querySelectorAll('.site')).forEach(function (card) {
    function beam(e) {
      var r = card.getBoundingClientRect();
      card.style.setProperty('--mx', (((e.clientX - r.left) / r.width) * 100).toFixed(2) + '%');
      card.style.setProperty('--my', (((e.clientY - r.top) / r.height) * 100).toFixed(2) + '%');
    }
    card.addEventListener('pointermove', beam);
    card.addEventListener('pointerdown', beam);

    /* Keyboard and touch users get the whole card lit rather than a beam. */
    function floodOn()  { card.style.setProperty('--beam', '160%'); }
    function floodOff() { card.style.removeProperty('--beam'); }
    card.addEventListener('focusin', floodOn);
    card.addEventListener('focusout', floodOff);
    card.addEventListener('touchstart', floodOn, { passive: true });
  });

  /* ----------------------------------------------------------------------
     Floating WhatsApp button, once past the hero
     ---------------------------------------------------------------------- */
  var wa = document.querySelector('.wa');
  if (wa) {
    var showWa = function () {
      wa.classList.toggle('is-in', window.scrollY > window.innerHeight * 0.7);
    };
    showWa();
    window.addEventListener('scroll', showWa, { passive: true });
  }

})();
