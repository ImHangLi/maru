(function () {
  // Scroll entrances.
  var items = document.querySelectorAll("[data-reveal]");
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce || !("IntersectionObserver" in window)) {
    items.forEach(function (el) { el.classList.add("is-in"); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    items.forEach(function (el) { io.observe(el); });
  }

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
  links.forEach(function (a) {
    a.addEventListener("click", function () { remember(a.hreflang); });
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
  var hint = document.createElement("div");
  hint.className = "lang-hint";
  hint.lang = wanted;
  var go = document.createElement("a");
  go.href = target.href;
  go.textContent = target.dataset.suggest;
  go.addEventListener("click", function () { remember(wanted); });
  var close = document.createElement("button");
  close.type = "button";
  close.setAttribute("aria-label", target.dataset.close);
  close.textContent = "×";
  close.addEventListener("click", function () {
    remember(page);
    hint.remove();
  });
  hint.append(go, close);
  document.body.append(hint);
})();
