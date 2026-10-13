(function () {
  // Entrance on scroll. A block is visible with no script. When a block enters the view, the class "is-in"
  // plays the entrance of its parts one time. If the observer does not run, nothing is hidden.
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      });
    });
    document.querySelectorAll("[data-reveal]").forEach(function (el) { io.observe(el); });
  }

  // The hero phone. Its screen scrolls like the app. Wheel, touch, and keys are native. A mouse can also drag a list.
  var phone = document.querySelector(".device-scroll");
  if (phone) {
    var used = false;
    ["wheel", "touchstart", "pointerdown", "keydown"].forEach(function (type) {
      phone.addEventListener(type, function () { used = true; }, { passive: true });
    });
    var draggable = function (list) {
      list.addEventListener("pointerdown", function (event) {
        if (event.pointerType !== "mouse" || event.button !== 0) return;
        var startY = event.clientY;
        var startTop = list.scrollTop;
        var move = function (e) { list.scrollTop = startTop - (e.clientY - startY); };
        var end = function () {
          list.removeEventListener("pointermove", move);
          list.removeEventListener("pointerup", end);
          list.removeEventListener("pointercancel", end);
          list.classList.remove("is-dragging");
        };
        list.setPointerCapture(event.pointerId);
        list.classList.add("is-dragging");
        list.addEventListener("pointermove", move);
        list.addEventListener("pointerup", end);
        list.addEventListener("pointercancel", end);
      });
    };
    draggable(phone);

    // The other screens: My Items (the tab), History (pushed from Today), and the Settings and Add Item sheets.
    // Each is a real capture, and nothing in it works. A button over each control of a capture moves between the
    // screens. The pictures load when the page is idle, or at the first use of the phone.
    var device = phone.closest(".device");
    var face = device.querySelector(".device-screen");
    var labels = JSON.parse(device.dataset.labels);
    var state = { tab: "today", pushed: false, sheet: null };
    var parts = null;
    var shot = function (name, className) {
      var img = new Image();
      img.alt = "";
      img.draggable = false;
      if (className) img.className = className;
      img.src = "/shots/" + name + "-" + device.dataset.shots + ".webp";
      return img;
    };
    var layer = function (className, children) {
      var el = document.createElement("div");
      el.className = className;
      (children || []).forEach(function (child) { el.append(child); });
      face.append(el);
      return el;
    };
    var hit = function (className, label, change) {
      var button = document.createElement("button");
      button.type = "button";
      button.className = "device-hit " + className;
      button.setAttribute("aria-label", label);
      button.addEventListener("click", function () {
        used = true;
        change();
        show(true);
      });
      return button;
    };
    var openSheet = function (name) { return function () { state.sheet = name; }; };
    var toToday = function () { state.tab = "today"; state.pushed = false; };
    var toItems = function () { state.tab = "items"; state.pushed = false; };
    var sheet = function (name) {
      var list = document.createElement("div");
      list.className = "device-scroll";
      list.tabIndex = 0;
      list.setAttribute("role", "img");
      list.setAttribute("aria-label", labels[name + "Name"]);
      list.append(shot(name));
      draggable(list);
      var close = hit(name === "add" ? "hit-cancel" : "hit-done", labels.close, function () { state.sheet = null; });
      return layer("device-sheet", [list, shot(name + "-bar", "device-sheet-bar"), close]);
    };
    var build = function () {
      if (parts) return;
      parts = {
        today: layer("device-hits", [
          hit("hit-lead", labels.settings, openSheet("settings")),
          hit("hit-calendar", labels.history, function () { state.pushed = true; }),
          hit("hit-plus", labels.add, openSheet("add")),
          hit("hit-tab-items", labels.items, toItems)
        ]),
        items: layer("device-page", [
          shot("items"),
          hit("hit-lead", labels.settings, openSheet("settings")),
          hit("hit-plus", labels.add, openSheet("add")),
          hit("hit-tab-today", labels.today, toToday)
        ]),
        history: layer("device-page device-push", [
          shot("history"),
          hit("hit-lead", labels.back, function () { state.pushed = false; })
        ]),
        // The tab bar stays in place while History slides in. It is the tab bar of the Today pictures.
        tabs: layer("device-tabs", [
          shot("today-bars"),
          hit("hit-tab-today", labels.today, toToday),
          hit("hit-tab-items", labels.items, toItems)
        ]),
        dim: layer("device-dim"),
        settings: sheet("settings"),
        add: sheet("add")
      };
      show(false);
    };
    // Shows the screens of the state. A screen that is not in use takes no focus and no click.
    var show = function (moveFocus) {
      var on = {
        today: state.tab === "today" && !state.pushed && !state.sheet,
        items: state.tab === "items",
        history: state.pushed,
        tabs: state.pushed,
        dim: !!state.sheet,
        settings: state.sheet === "settings",
        add: state.sheet === "add"
      };
      var front = state.sheet || (state.pushed ? "history" : state.tab);
      Object.keys(parts).forEach(function (name) {
        var el = parts[name];
        if (on[name] && !el.classList.contains("is-on")) {
          var list = el.querySelector(".device-scroll");
          if (list) list.scrollTop = 0;
        }
        el.classList.toggle("is-on", on[name]);
        el.inert = !(name === front || (name === "tabs" && front === "history"));
      });
      phone.inert = front !== "today";
      if (moveFocus) parts[front].querySelector(".device-hit").focus({ preventScroll: true });
    };
    device.addEventListener("keydown", function (event) {
      if (event.key !== "Escape" || !parts || (!state.sheet && !state.pushed)) return;
      if (state.sheet) state.sheet = null;
      else state.pushed = false;
      show(true);
    });
    ["pointerdown", "focusin"].forEach(function (type) { device.addEventListener(type, build, { once: true }); });
    var later = function () {
      if (window.requestIdleCallback) requestIdleCallback(build, { timeout: 3000 });
      else setTimeout(build, 1500);
    };
    if (document.readyState === "complete") later();
    else window.addEventListener("load", later);

    // One hint that the list scrolls: when the phone is in view, the list moves to its end one time and comes back.
    // The hint stops when the visitor uses the list. It does not play with reduced motion.
    var glide = function (to, then) {
      var from = phone.scrollTop;
      var start = performance.now();
      requestAnimationFrame(function step(now) {
        if (used) return;
        var t = Math.min(1, (now - start) / 900);
        phone.scrollTop = from + (to - from) * t * t * (3 - 2 * t);
        if (t < 1) requestAnimationFrame(step);
        else if (then) setTimeout(then, 1200);
      });
    };
    if (document.documentElement.classList.contains("motion") && "IntersectionObserver" in window) {
      var seen = new IntersectionObserver(function (entries) {
        if (!entries[0].isIntersecting) return;
        seen.disconnect();
        setTimeout(function () {
          glide(phone.scrollHeight - phone.clientHeight, function () { glide(0); });
        }, 1400);
      }, { threshold: 0.9 });
      seen.observe(phone);
    }
  }

  // A page from the back and forward cache shows at rest, with no entrance.
  window.addEventListener("pageshow", function (event) {
    if (event.persisted) document.documentElement.classList.remove("motion");
  });

  // Language. The page never redirects. A first visit can show one quiet hint for the language of the browser.
  // A click on a language, or on the close button, is the choice of the visitor. After that, no hint shows.
  var KEY = "maru-lang";
  var links = document.querySelectorAll(".langs a");
  function remember(lang) {
    try { localStorage.setItem(KEY, lang); } catch (e) { /* Private mode: the hint can show again. */ }
  }
  function chosen() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  document.querySelectorAll("a[hreflang]").forEach(function (a) {
    a.addEventListener("click", function () { remember(a.hreflang); });
  });

  // The language menu in the top bar is a details element. It closes on its button, on Escape, and on a click outside.
  // A close plays the close animation first. The menu stays in the layout until the animation ends.
  var menu = document.querySelector(".lang-menu");
  var summary = menu.querySelector("summary");
  var list = menu.querySelector("ul");
  function closeMenu() {
    if (!menu.open || menu.classList.contains("closing")) return;
    var done = function () {
      list.removeEventListener("animationend", done);
      clearTimeout(timer);
      menu.open = false;
      menu.classList.remove("closing");
    };
    // The timer closes the menu if the animation does not run.
    var timer = setTimeout(done, 400);
    list.addEventListener("animationend", done);
    menu.classList.add("closing");
  }
  summary.addEventListener("click", function (event) {
    if (!menu.open) return;
    event.preventDefault();
    closeMenu();
  });
  document.addEventListener("click", function (event) {
    if (!menu.contains(event.target)) closeMenu();
  });
  menu.addEventListener("keydown", function (event) {
    if (event.key !== "Escape" || !menu.open) return;
    closeMenu();
    summary.focus();
  });

  function supported(tag) {
    tag = tag.toLowerCase();
    if (tag.indexOf("zh") === 0) return /tw|hk|mo|hant/.test(tag) ? null : "zh-Hans";
    var match = null;
    links.forEach(function (a) { if (a.hreflang === tag.slice(0, 2)) match = a.hreflang; });
    return match;
  }
  var page = document.documentElement.lang;
  var wanted = null;
  (navigator.languages || [navigator.language || ""]).some(function (tag) {
    wanted = supported(tag);
    return wanted;
  });
  if (!wanted || wanted === page || chosen()) return;

  var target = document.querySelector('.langs a[hreflang="' + wanted + '"]');
  var hint = document.getElementById("lang-hint").content.firstElementChild.cloneNode(true);
  hint.lang = wanted;
  hint.setAttribute("aria-label", target.textContent);
  var go = hint.querySelector("a");
  go.href = target.href;
  go.textContent = target.dataset.suggest;
  go.addEventListener("click", function () { remember(wanted); });
  var close = hint.querySelector("button");
  close.setAttribute("aria-label", target.dataset.close);
  close.addEventListener("click", function () {
    remember(page);
    hint.remove();
  });
  document.body.append(hint);
})();
