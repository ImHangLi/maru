// Scroll entrances and the FAQ accordion. No libraries, no network.
(function () {
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var items = document.querySelectorAll("[data-reveal]");
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
    items.forEach(function (el) {
      var siblings = el.parentElement ? el.parentElement.querySelectorAll(":scope > [data-reveal]") : [];
      var index = Array.prototype.indexOf.call(siblings, el);
      if (index > 0) el.style.setProperty("--delay", Math.min(index, 4) * 40 + "ms");
      io.observe(el);
    });
  }

  document.querySelectorAll(".acc-btn").forEach(function (button) {
    var panel = document.getElementById(button.getAttribute("aria-controls"));
    button.addEventListener("click", function () {
      var open = button.getAttribute("aria-expanded") === "true";
      button.setAttribute("aria-expanded", String(!open));
      panel.dataset.open = String(!open);
    });
  });
})();
