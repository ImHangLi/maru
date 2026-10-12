// Keep the placeholder App Store badge from jumping to the top of the page.
document.querySelectorAll('a[href="#"]').forEach((link) => {
  link.addEventListener("click", (event) => event.preventDefault());
});
