(function () {
  "use strict";

  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var canvas = document.getElementById("world");
  var ctx = canvas.getContext("2d");
  var ride = document.getElementById("ride");
  var phoneEl = document.getElementById("phone");
  var lockEl = document.getElementById("lock");
  var callout = document.getElementById("callout");
  var calloutText = document.getElementById("calloutText");
  var calloutLine = callout.querySelector(".callout-line");
  var stopEls = Array.prototype.slice.call(document.querySelectorAll(".stop"));
  var thumbEls = Array.prototype.slice.call(document.querySelectorAll("#thumbs li"));

  // ---- images ----
  var images = {};
  function img(src) { if (!images[src]) { var i = new Image(); i.src = src; images[src] = i; } return images[src]; }
  function ready(i) { return i && i.complete && i.naturalWidth > 0; }
  Object.keys(SCENES).forEach(function (k) { SCENES[k].layers.forEach(function (l) { img(l.src); }); });
  var RAINFAR = img("a/laundromat__L03_rainfar_6f.png"), RAINNEAR = img("a/laundromat__L04_rainnear_5f.png");
  var SNOWFAR = img("a/snow_cabin__L03_snowfar_46f.png"), SNOWNEAR = img("a/snow_cabin__L04_snownear_31f.png");
  var LEAVESFAR = img("a/autumn_bookshop__L02_leavesfar_53f.png"), LEAVESNEAR = img("a/autumn_bookshop__L03_leavesnear_47f.png");
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
  var CALLOUTS = {
    cat: "The shop cat wakes up now and then.",
    passerby: "Someone walks past the window.",
    gust: "The wind takes a few leaves."
  };
  var THUMB = {
    rainy_room: [110, 230], autumn_bookshop: [16, 400], laundromat: [70, 470], night_train: [170, 380],
    home_studio: [104, 420], snow_cabin: [8, 470], rooftop_dusk: [210, 450]
  };

  // ---- weather that fills the page ----
  function tiles(im, frames, fps, t, size, ox, oy) {
    if (!ready(im)) return;
    var f = Math.floor(t * fps), w = im.naturalWidth / frames, h = im.naturalHeight;
    for (var y = (oy || 0) % h - h; y < H; y += h) for (var x = (ox || 0) % w - w; x < W; x += w) frame(ctx, im, frames, f, x, y);
  }
  function rain(t) { tiles(RAINFAR, 6, 12, t); tiles(RAINNEAR, 5, 12, t, 0, 37, 11); }
  function snow(t) { tiles(SNOWFAR, 46, 12, t); tiles(SNOWNEAR, 31, 12, t, 0, 50, 20); }
  function leaves(t) { tiles(LEAVESFAR, 53, 4, t); tiles(LEAVESNEAR, 47, 8, t, 0, 60, 30); }
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
      if (l.ev) {
        if (active.key !== slug + ":" + l.ev) return;
        f = Math.floor(((t - active.start) / l.d) * l.f);
        if (f >= l.f) return;
      } else if (l.f > 1 && l.d && !reduce) f = Math.floor((t / l.d) * l.f) % l.f;
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
      timer = setTimeout(function () { active.key = null; timer = setTimeout(fire, 2500 + Math.random() * 2500); }, l.d * 1000 + 300);
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
    // the train room goes dark behind the lock screen
    var trainW = here === 2 ? (here === i ? 1 - k : k) : 0;
    if (trainW > 0) { ctx.globalAlpha = step4(trainW) * 0.55; ctx.fillStyle = "#030308"; ctx.fillRect(px, py, PW, PH); ctx.globalAlpha = 1; }
    ctx.restore();
    phoneEl.style.transform = "translate(" + px + "px," + py + "px)";
    lockEl.style.opacity = step4(clamp((trainW - 0.5) * 2, 0, 1));

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

    // a note pointing at whatever just happened in the bookshop
    var shopW = here === 3 ? (here === i ? 1 - k : k) : 0;
    if (!mobile && shopW > 0.8 && active.key && CALLOUTS[active.name]) {
      var l = active.l, y0 = cropY(STOPS[3], PH);
      var tx = px + l.x + l.w / 2, ty = py + l.y - y0 + l.h / 2;
      calloutText.textContent = CALLOUTS[active.name];
      var len = Math.max(24, tx - px + 36);
      calloutLine.style.width = len + "px";
      callout.style.transform = "translate(" + Math.round(tx - len - calloutText.offsetWidth - 10) + "px," + Math.round(ty - 10) + "px)";
      callout.style.opacity = 1;
    } else callout.style.opacity = 0;

    requestAnimationFrame(draw);
  }

  addEventListener("scroll", readScroll, { passive: true });
  addEventListener("resize", function () { layout(); readScroll(); });
  layout(); readScroll();
  // the copy's height depends on the fonts, which may still be on their way
  if (document.fonts) document.fonts.ready.then(function () { layout(); readScroll(); });
  requestAnimationFrame(draw);
})();
