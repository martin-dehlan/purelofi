// The web player (#150): one room at a time, PureLofi's tracks shuffled,
// the system's media keys. No account, no Pro, no downloads: the app is the
// whole thing, this is a taste of it.
(function () {
  "use strict";

  var cfg = window.PURELOFI || {};
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var canvas = document.getElementById("room");
  var ctx = canvas.getContext("2d");
  var audio = document.getElementById("audio");
  var $ = function (id) { return document.getElementById(id); };
  var playBtn = $("play"), nextBtn = $("next");

  // ---- the room: the site's own copies of the sprites (scenes.js) ----
  var ROOMS = Object.keys(SCENES);
  var NAMES = {
    rainy_room: "Rainy Room", home_studio: "Home Studio", night_train: "Night Train",
    autumn_bookshop: "Autumn Bookshop", snow_cabin: "Snow Cabin",
    rooftop_dusk: "Rooftop at Dusk", laundromat: "Laundromat"
  };
  var room = 0;
  var images = {};
  function img(src) { if (!images[src]) { var i = new Image(); i.src = src; images[src] = i; } return images[src]; }
  function ready(i) { return i && i.complete && i.naturalWidth > 0; }

  function showRoom(i) {
    room = (i + ROOMS.length) % ROOMS.length;
    var slug = ROOMS[room];
    SCENES[slug].layers.forEach(function (l) { img(l.src); });
    $("roomName").textContent = NAMES[slug] || slug.replace(/_/g, " ");
  }

  // Scaled by a whole number and centred, so the pixels stay square.
  function draw(now) {
    var t = now / 1000;
    var slug = ROOMS[room], sc = SCENES[slug];
    var dpr = window.devicePixelRatio || 1;
    var w = Math.round(innerWidth * dpr), h = Math.round(innerHeight * dpr);
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    var scale = Math.max(1, Math.ceil(Math.max(w / 320, h / sc.h)));
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = "#030308";
    ctx.fillRect(0, 0, w, h);
    ctx.save();
    ctx.translate(Math.round((w - 320 * scale) / 2), Math.round((h - sc.h * scale) / 2));
    ctx.scale(scale, scale);
    var playing = !audio.paused;
    sc.layers.forEach(function (l) {
      var im = images[l.src];
      if (!ready(im) || l.ev) return; // rare events belong to the app
      var fps = l.d ? l.f / l.d : 0;
      var f = reduce || !fps || l.f < 2 ? 0 : Math.floor(t * fps) % l.f;
      if (l.paused && !playing) f = 0;
      var fw = im.naturalWidth / l.f;
      function at(x, y) { ctx.drawImage(im, f * fw, 0, fw, im.naturalHeight, x, y, fw, im.naturalHeight); }
      if (l.tile) {
        for (var x = 0; x < 320; x += l.w) {
          if (l.w === l.h) for (var y = 0; y < sc.h; y += l.h) at(x, y);
          else at(x, l.y);
        }
      } else at(l.x, l.y);
    });
    ctx.restore();
    requestAnimationFrame(draw);
  }

  // ---- the music: PureLofi's tracks, read with the public key ----
  var tracks = [], artists = {}, order = [], at = -1;

  function rest(path) {
    return fetch(cfg.supabaseUrl + "/rest/v1/" + path, {
      headers: { apikey: cfg.anonKey, Authorization: "Bearer " + cfg.anonKey }
    }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  function shuffle(n) {
    var a = []; for (var i = 0; i < n; i++) a.push(i);
    for (var j = n - 1; j > 0; j--) { var k = Math.floor(Math.random() * (j + 1)); var x = a[j]; a[j] = a[k]; a[k] = x; }
    return a;
  }

  // Only ever a web link from our own storage: a row is data, not a place
  // to send the browser.
  function safeAudio(url) {
    try { var u = new URL(url); return u.protocol === "https:" ? u.href : null; } catch (e) { return null; }
  }

  function playAt(i) {
    if (!tracks.length) return;
    if (i >= order.length) { order = shuffle(tracks.length); i = 0; }
    at = i;
    var tr = tracks[order[at]];
    var src = safeAudio(tr.audio_url);
    if (!src) { playAt(at + 1); return; }
    audio.src = src;
    $("title").textContent = tr.title;
    $("artist").textContent = (tr.artist_id && artists[tr.artist_id]) || "PureLofi";
    audio.play().catch(function () {});
    if ("mediaSession" in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: tr.title,
        artist: $("artist").textContent,
        album: $("roomName").textContent
      });
    }
  }

  function toggle() {
    if (at < 0) return playAt(0);
    if (audio.paused) audio.play().catch(function () {}); else audio.pause();
  }

  function sync() {
    var on = !audio.paused;
    playBtn.innerHTML = on ? "&#10074;&#10074;" : "&#9654;";
    playBtn.setAttribute("aria-label", on ? "Pause" : "Play");
  }

  audio.addEventListener("play", sync);
  audio.addEventListener("pause", sync);
  audio.addEventListener("ended", function () { playAt(at + 1); });
  audio.addEventListener("error", function () { $("note").textContent = "That track would not play; on to the next."; playAt(at + 1); });
  playBtn.addEventListener("click", toggle);
  nextBtn.addEventListener("click", function () { playAt(at + 1); });
  $("prevRoom").addEventListener("click", function () { showRoom(room - 1); });
  $("nextRoom").addEventListener("click", function () { showRoom(room + 1); });
  document.addEventListener("keydown", function (e) {
    if (e.target && (e.target.tagName === "BUTTON" || e.target.tagName === "A")) return;
    if (e.code === "Space") { e.preventDefault(); toggle(); }
    else if (e.code === "ArrowRight") showRoom(room + 1);
    else if (e.code === "ArrowLeft") showRoom(room - 1);
  });
  if ("mediaSession" in navigator) {
    navigator.mediaSession.setActionHandler("play", toggle);
    navigator.mediaSession.setActionHandler("pause", toggle);
    navigator.mediaSession.setActionHandler("nexttrack", function () { playAt(at + 1); });
  }

  showRoom(0);
  requestAnimationFrame(draw);

  if (!cfg.supabaseUrl || !cfg.anonKey) {
    $("note").textContent = "The web player is not switched on yet. The app has it all.";
    return;
  }

  Promise.all([
    rest("tracks?select=id,title,audio_url,artist_id&is_active=eq.true&order=created_at"),
    rest("artists?select=id,name&is_active=eq.true").catch(function () { return []; })
  ]).then(function (res) {
    tracks = res[0] || [];
    (res[1] || []).forEach(function (a) { artists[a.id] = a.name; });
    order = shuffle(tracks.length);
    if (!tracks.length) { $("note").textContent = "No tracks yet."; return; }
    playBtn.disabled = false;
    nextBtn.disabled = false;
    $("note").textContent = tracks.length + " tracks by real musicians. Press play.";
  }).catch(function () {
    $("note").textContent = "The music could not be reached. Try again in a moment.";
  });
})();
