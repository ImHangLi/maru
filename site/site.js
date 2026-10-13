// Set the App Store link here, in one place. Leave it empty until Maru is on the App Store.
var STORE_URL = "";

(function () {
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // App Store buttons: "Coming soon" until STORE_URL is set, then a real download link.
  if (STORE_URL) {
    document.querySelectorAll("[data-store]").forEach(function (el) {
      el.href = STORE_URL;
      el.removeAttribute("aria-disabled");
      el.querySelector("small").textContent = "Download on the";
    });
    document.querySelectorAll("[data-store-nav]").forEach(function (el) {
      el.href = STORE_URL;
      el.textContent = "Download";
    });
    document.querySelectorAll("[data-notify]").forEach(function (el) { el.remove(); });
  }

  // Scroll entrances.
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

  // Screenshots that failed before this script ran show the placeholder.
  document.querySelectorAll(".device-screen img").forEach(function (img) {
    if (img.complete && img.naturalWidth === 0) img.hidden = true;
  });

  // FAQ accordion.
  document.querySelectorAll(".acc-btn").forEach(function (button) {
    var panel = document.getElementById(button.getAttribute("aria-controls"));
    button.addEventListener("click", function () {
      var open = button.getAttribute("aria-expanded") === "true";
      button.setAttribute("aria-expanded", String(!open));
      panel.dataset.open = String(!open);
    });
  });
})();
