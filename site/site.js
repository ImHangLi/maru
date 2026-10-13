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
