(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const root = document.documentElement;

  /* nav turns to glass once you scroll */
  const nav = $("#nav");
  const onScroll = () => nav.classList.toggle("scrolled", scrollY > 12);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* light / dark: follows the system until you pick one */
  $("#theme")?.addEventListener("click", () => {
    const next = root.dataset.theme === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try { localStorage.setItem("theme", next); } catch (e) {}
  });
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", e => {
    let saved = null;
    try { saved = localStorage.getItem("theme"); } catch (err) {}
    if (!saved) root.dataset.theme = e.matches ? "dark" : "light";
  });

  /* reveal on scroll */
  const io = new IntersectionObserver(entries => entries.forEach(e => {
    if (!e.isIntersecting) return;
    e.target.classList.add("in");
    io.unobserve(e.target);
  }), { threshold: 0.15, rootMargin: "0px 0px -6% 0px" });
  $$(".rv").forEach(el => io.observe(el));

  /* story: the phone shows the screen of the step in the middle of the window */
  const steps = $$(".step");
  const imgs = $$("#storyScreen img");
  const dots = $$("#dots i");
  const show = i => {
    steps.forEach(s => s.classList.toggle("on", +s.dataset.i === i));
    imgs.forEach(im => im.classList.toggle("on", +im.dataset.i === i));
    dots.forEach((d, k) => d.classList.toggle("on", k === i));
  };
  const so = new IntersectionObserver(entries => entries.forEach(e => {
    if (e.isIntersecting) show(+e.target.dataset.i);
  }), { rootMargin: "-45% 0px -45% 0px" });
  steps.forEach(s => so.observe(s));
})();
