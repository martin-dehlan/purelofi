(function () {
  "use strict";

  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var canvas = document.getElementById("world");
  var ctx = canvas.getContext("2d");
  var ride = document.getElementById("ride");
  var phoneEl = document.getElementById("phone");
  var barClock = document.getElementById("barClock");
  var wave = document.getElementById("barWave").getContext("2d");
  var momentEls = Array.prototype.slice.call(document.querySelectorAll("#moments li"));
  var stopEls = Array.prototype.slice.call(document.querySelectorAll(".stop"));
  var thumbEls = Array.prototype.slice.call(document.querySelectorAll("#thumbs li[data-room]"));

  // ---- images ----
  var images = {};
  function img(src) { if (!images[src]) { var i = new Image(); i.src = src; images[src] = i; } return images[src]; }
  function ready(i) { return i && i.complete && i.naturalWidth > 0; }
  Object.keys(SCENES).forEach(function (k) { SCENES[k].layers.forEach(function (l) { img(l.src); }); });
  var HILLS = img("a/night_train__L02_hills_64f.png"), POLES = img("a/night_train__L04_poles_16f.png");
  var BIRDS = img("a/ev__rooftop_dusk__L15_birds_91f.png");

  function frame(c, im, frames, idx, dx, dy) {
    if (!ready(im)) return;
    var fw = im.naturalWidth / frames;
    c.drawImage(im, (idx % frames) * fw, 0, fw, im.naturalHeight, Math.round(dx), Math.round(dy), fw, im.naturalHeight);
  }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
  function smooth(t) { return t * t * (3 - 2 * t); }
  function step4(a) { return Math.round(a * 4) / 4; }

  // ---- the rooms, in scroll order ----
  // focus: the scene row the phone centres on; side: where the phone stands
  var STOPS = [
    { room: "rainy_room", bg: "#0D1A2E", side: 0.7, focus: 300, weather: rain, events: ["cat", "moth", "lightning"] },
    { room: "home_studio", bg: "#130C1F", side: 0.3, focus: 440, weather: null, events: [] },
    { room: "night_train", bg: "#080616", side: 0.72, focus: 430, weather: journey, events: ["house"] },
    { room: "autumn_bookshop", bg: "#1D1228", side: 0.72, focus: 450, weather: leaves, events: ["cat", "passerby", "gust"] },
    { room: "snow_cabin", bg: "#16293C", side: 0.28, focus: 450, weather: snow, events: ["sparks", "clump"] },
    { room: "rooftop_dusk", bg: "#30384F", side: 0.7, focus: 420, weather: birds, events: ["dog", "plane"] }
  ];
  var THUMB = {
    rainy_room: [110, 230], autumn_bookshop: [16, 400], laundromat: [70, 470], night_train: [170, 380],
    home_studio: [104, 420], snow_cabin: [16, 522], rooftop_dusk: [180, 240]
  };

  // ---- weather that fills the page ----
  // rain: single drops, each with its own place, speed and length, so no
  // tile or loop shows; quiet next to the room's own rain inside the phone
  function hash(n) { n = Math.sin(n * 127.1) * 43758.5453; return n - Math.floor(n); }
  function rain(t) {
    var n = Math.round(W * H / 7000), base = ctx.globalAlpha;
    for (var i = 0; i < n; i++) {
      var near = i % 4 === 0, len = near ? 6 + Math.floor(hash(i + 3) * 4) : 3 + Math.floor(hash(i + 3) * 3);
      var v = (near ? 150 : 90) * (0.85 + hash(i + 7) * 0.3);
      var y = (hash(i) * (H + 40) + t * v) % (H + 40) - 20;
      var x = Math.round((hash(i + 11) * (W + 40) - y * 0.12 + W + 40) % (W + 40)) - 20;
      ctx.globalAlpha = base * (near ? 0.35 : 0.2);
      ctx.fillStyle = near ? "#7B9AA2" : "#4E6471";
      ctx.fillRect(x, Math.round(y), 1, len);
    }
    ctx.globalAlpha = base;
  }
  // snow and leaves the same way, drifting as they fall: each piece sways
  // on its own period, and leaves tumble between a wide and a tall shape
  function drift(t, o) {
    var n = Math.round(W * H / o.per), base = ctx.globalAlpha;
    for (var i = 0; i < n; i++) {
      var near = i % 3 === 0, v = (near ? o.fast : o.slow) * (0.8 + hash(i + 7) * 0.4);
      var y = (hash(i) * (H + 40) + t * v) % (H + 40) - 20;
      var sway = Math.sin(t / (2 + hash(i + 5) * 3) * Math.PI * 2 + i) * (near ? o.sway : o.sway / 2);
      var x = Math.round((hash(i + 11) * (W + 40) + t * o.wind + sway) % (W + 40)) - 20;
      var c = o.colors[near ? 1 : 0];
      ctx.globalAlpha = base * (near ? o.alpha[1] : o.alpha[0]);
      ctx.fillStyle = c[Math.floor(hash(i + 13) * c.length)];
      var s = near ? o.size[1] : o.size[0], wide = o.tumble && Math.floor(t * (1 + hash(i + 17)) + i) % 2;
      ctx.fillRect(x, Math.round(y), wide ? s + 1 : s, wide ? s : s + (o.tumble ? 1 : 0));
    }
    ctx.globalAlpha = base;
  }
  function snow(t) {
    drift(t, { per: 6000, slow: 16, fast: 30, sway: 8, wind: 4, size: [1, 2], alpha: [0.35, 0.6],
      colors: [["#7B9AA2", "#92B5BB"], ["#B6E2E3", "#FFF2E8"]] });
  }
  function leaves(t) {
    drift(t, { per: 30000, slow: 22, fast: 38, sway: 18, wind: 14, size: [2, 3], alpha: [0.45, 0.8], tumble: true,
      colors: [["#8A4A2A", "#C06A33", "#A64954"], ["#D17055", "#F0A05D", "#DB7D48"]] });
  }
  // outside the train: hills and poles slide past along the bottom of the page
  function journey(t) {
    if (!ready(HILLS) || !ready(POLES)) return;
    var y = H - 200;
    ctx.fillStyle = "#130C1F"; ctx.fillRect(0, y + 230, W, H);
    var hx = -((t * 24) % 128);
    for (var x = hx; x < W; x += 128) frame(ctx, HILLS, 64, 0, x, y);
    var px = -((t * 90) % 192);
    for (x = px; x < W; x += 192) frame(ctx, POLES, 16, 0, x, y);
  }
  function birds(t) {
    if (!ready(BIRDS)) return;
    var f = Math.floor((t / 9.1) * 91) % 91;
    for (var x = 0; x < W; x += 640) frame(ctx, BIRDS, 91, f, x + (x / 640 % 2) * 120, 70 + (x / 640 % 2) * 40);
  }

  // ---- a room, drawn into its own small canvas ----
  var PW = 320, PH = 568, px = 0, py = 0, W = 0, H = 0, mobile = false;
  var roomA = document.createElement("canvas"), roomB = document.createElement("canvas");
  var ca = roomA.getContext("2d"), cb = roomB.getContext("2d");
  var active = { key: null, start: 0 };

  function drawRoom(c, slug, y0, t, h) {
    var sc = SCENES[slug];
    c.clearRect(0, 0, PW, h);
    c.save(); c.translate(0, -y0);
    sc.layers.forEach(function (l) {
      var im = images[l.src];
      if (!ready(im)) return;
      var f = 0;
      // as the app's scheduler does it: a layer that waits for a cue loops
      // its idle frames (the sleeping cat) or rests on its first, and plays
      // the frames after them once when its moment comes
      var fps = l.d ? l.f / l.d : 0, idle = l.idle || 0;
      if (l.ev && active.key === slug + ":" + l.ev) f = Math.min(l.f - 1, idle + Math.floor((t - active.start) * fps));
      else if (reduce || !fps) f = 0;
      else if (idle > 1) f = Math.floor(t * fps) % idle;
      else if (!l.ev && l.f > 1) f = Math.floor(t * fps) % l.f;
      if (l.tile) {
        for (var x = 0; x < 320; x += l.w) {
          if (l.w === l.h) for (var y = 0; y < sc.h; y += l.h) frame(c, im, l.f, f, x, y);
          else frame(c, im, l.f, f, x, l.y);
        }
      } else frame(c, im, l.f, f, l.x, l.y);
    });
    c.restore();
  }
  function cropY(stop, h) { return clamp(Math.round(stop.focus - h / 2), 0, SCENES[stop.room].h - h); }

  // ordered dither between two rooms: 17 steps, Bayer 4x4
  var BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5], masks = {};
  function mask(level) {
    if (!masks[level]) {
      var m = document.createElement("canvas"); m.width = m.height = 4;
      var x = m.getContext("2d"); x.fillStyle = "#000";
      for (var i = 0; i < 16; i++) if (BAYER[i] < level) x.fillRect(i % 4, i >> 2, 1, 1);
      masks[level] = ca.createPattern(m, "repeat");
    }
    return masks[level];
  }

  // ---- the bar: Waveform's 57 bars, played solid and the rest dashed ----
  var TRACK = 151, BARS = [];
  for (var n = 0; n < 57; n++) {
    var swell = 0.55 + 0.45 * Math.sin(n / 57 * Math.PI * 3);
    BARS.push(clamp(0.15 + 0.85 * (swell * 0.6 + hash(n + 40) * 0.4), 0.15, 1));
  }
  function drawBar(t) {
    var sec = (40 + t) % TRACK, played = Math.round(57 * sec / TRACK);
    barClock.textContent = Math.floor(sec / 60) + ":" + ("0" + Math.floor(sec % 60)).slice(-2);
    var cw = wave.canvas.width, ch = wave.canvas.height, slot = cw / 57, bw = Math.round(clamp(slot * 0.5, 1, 4)), mid = ch / 2;
    wave.clearRect(0, 0, cw, ch);
    for (var j = 0; j < 57; j++) {
      var x = Math.round(j * slot + (slot - bw) / 2), full = Math.round(BARS[j] * mid);
      if (j < played) { wave.fillStyle = "#E7E1DE"; wave.fillRect(x, mid - full, bw, full * 2); continue; }
      wave.fillStyle = "rgba(203,197,194,.45)";
      for (var y = mid - full; y < mid + full; y += 4) wave.fillRect(x, y, bw, Math.min(2, mid + full - y));
    }
  }

  // ---- layout ----
  function layout() {
    W = window.innerWidth; H = window.innerHeight;
    canvas.width = W; canvas.height = H;
    canvas.style.width = W + "px"; canvas.style.height = H + "px";
    ctx.imageSmoothingEnabled = false;
    mobile = W < 760;
    PH = Math.min(568, H - 150);
    if (mobile) {
      // On a phone the copy sits under the phone: make the phone end above
      // the tallest block of copy, so no room's text runs over the picture.
      var tallest = 0;
      stopEls.forEach(function (el) { tallest = Math.max(tallest, el.offsetHeight); });
      var top = Math.max(64, Math.round(H * 0.08));
      PH = clamp(H - tallest - 24 - 28 - top, 220, 568);
    }
    roomA.width = roomB.width = PW; roomA.height = roomB.height = PH;
    phoneEl.style.width = PW + "px"; phoneEl.style.height = PH + "px";
    stopEls.forEach(function (el, i) {
      if (mobile) { el.style.left = ""; return; }
      el.style.left = (STOPS[i].side > 0.5 ? Math.max(32, Math.round(W * 0.08)) : Math.round(W * 0.5 + 40)) + "px";
    });
    ride.style.height = Math.round(H * STOPS.length * 1.15) + "px";
  }

  // ---- events: one at a time, a beat after you arrive in a room ----
  var timer = 0, current = -1, n = 0;
  function schedule(i) {
    clearTimeout(timer); active.key = null; n = 0;
    var list = STOPS[i].events;
    if (reduce || !list.length) return;
    function fire() {
      var key = list[n % list.length]; n += 1;
      var l = SCENES[STOPS[i].room].layers.filter(function (x) { return x.ev === key; })[0];
      active = { key: STOPS[i].room + ":" + key, start: performance.now() / 1000, l: l, name: key };
      var playFor = (l.f - (l.idle || 0)) / (l.f / l.d);
      timer = setTimeout(function () { active.key = null; timer = setTimeout(fire, 2500 + Math.random() * 2500); }, playFor * 1000 + 300);
    }
    timer = setTimeout(fire, 1100);
  }

  // ---- loop ----
  var progress = 0;
  function readScroll() {
    var r = ride.getBoundingClientRect();
    progress = clamp(-r.top / Math.max(1, r.height - H), 0, 1);
  }

  function draw(now) {
    var t = reduce ? 0 : now / 1000;
    var pos = progress * (STOPS.length - 1);
    var i = Math.min(STOPS.length - 2, Math.floor(pos));
    var k = smooth(clamp((pos - i - 0.3) / 0.4, 0, 1)); // 0 = room i, 1 = room i+1
    var a = STOPS[i], b = STOPS[i + 1];
    var here = k < 0.5 ? i : i + 1;
    if (here !== current) { current = here; schedule(here); }

    // the room's own light, then its weather
    ctx.globalAlpha = 1; ctx.fillStyle = a.bg; ctx.fillRect(0, 0, W, H);
    if (k > 0) { ctx.globalAlpha = step4(k); ctx.fillStyle = b.bg; ctx.fillRect(0, 0, W, H); }
    if (a.weather && k < 1) { ctx.globalAlpha = step4(1 - k); a.weather(t); }
    if (b.weather && k > 0) { ctx.globalAlpha = step4(k); b.weather(t); }
    ctx.globalAlpha = 1;

    // where the phone stands
    var side = a.side + (b.side - a.side) * k;
    px = mobile ? Math.round((W - PW) / 2) : Math.round(W * side - PW / 2);
    py = mobile ? Math.max(64, Math.round(H * 0.08)) : Math.round((H - PH) / 2);

    // the room on the phone, dissolving into the next one
    drawRoom(ca, a.room, cropY(a, PH), t, PH);
    if (k > 0) {
      drawRoom(cb, b.room, cropY(b, PH), t, PH);
      cb.globalCompositeOperation = "destination-in";
      cb.fillStyle = mask(Math.round(k * 16)); cb.fillRect(0, 0, PW, PH);
      cb.globalCompositeOperation = "source-over";
      ca.drawImage(roomB, 0, 0);
    }
    ctx.save();
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(px, py, PW, PH, 44); else ctx.rect(px, py, PW, PH);
    ctx.clip();
    ctx.drawImage(roomA, px, py);
    // the app's bar over every room, on its scrim
    ctx.globalAlpha = 0.3; ctx.fillStyle = "#000"; ctx.fillRect(px, py, PW, PH); ctx.globalAlpha = 1;
    ctx.restore();
    phoneEl.style.transform = "translate(" + px + "px," + py + "px)";
    drawBar(t);

    // copy: the outgoing room leaves before the next one speaks
    stopEls.forEach(function (el, j) {
      var w = j === i ? 1 - k : j === i + 1 ? k : 0;
      var o = clamp((w - 0.55) * 2.6, 0, 1);
      el.style.opacity = o;
      el.style.visibility = o > 0 ? "visible" : "hidden";
    });

    // thumbnails of every room, in the cabin stop
    var snowW = here === 4 ? (here === i ? 1 - k : k) : 0;
    if (snowW > 0.2) {
      ctx.globalAlpha = step4(clamp((snowW - 0.55) * 2.6, 0, 1));
      thumbEls.forEach(function (li) {
        var r = li.getBoundingClientRect(), slug = li.dataset.room, tw = mobile ? 40 : 56, th = mobile ? 52 : 76;
        var c = THUMB[slug];
        ctx.fillStyle = "#030308"; ctx.fillRect(r.left - 2, r.top - 2, tw + 4, th + 4);
        drawRoom(cb, slug, c[1], t, PH);
        ctx.drawImage(roomB, c[0], 0, tw, th, r.left, r.top, tw, th);
      });
      ctx.globalAlpha = 1;
    }

    // in the bookshop, the moment happening in the phone lights up beside it
    var lit = here === 3 && active.key ? active.name : null;
    momentEls.forEach(function (li) { li.classList.toggle("on", li.dataset.ev === lit); });

    requestAnimationFrame(draw);
  }

  addEventListener("scroll", readScroll, { passive: true });
  addEventListener("resize", function () { layout(); readScroll(); });
  layout(); readScroll();
  // the copy's height depends on the fonts, which may still be on their way
  if (document.fonts) document.fonts.ready.then(function () { layout(); readScroll(); });
  requestAnimationFrame(draw);
})();
