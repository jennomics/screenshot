/* ============================================================
   Prototype app logic: tiny state + render + router.
   No framework on purpose — this is a UX prototype meant to
   translate cleanly to SwiftUI screens later.
   ============================================================ */

const screen = document.getElementById("screen");

// ---- helpers ----
const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );

// ephemeral prototype state (resets on reload; the real app persists on-device)
const state = {
  tab: "home",
  activeCollection: null,
  filter: "all",
  // modal working state
  modal: null, // { incoming, chosenCats[], mode, note, reminderId }
  // carousel state: id -> { index, auto (bool) }. Persists across renders so
  // that killing auto-advance (via arrows) stays killed.
  carousels: {},
};

// Live auto-advance timers, keyed by carousel id. Cleared before every render
// so we never leak intervals when the screen is rebuilt.
const carouselTimers = {};
function clearCarouselTimers() {
  Object.values(carouselTimers).forEach((t) => clearInterval(t));
  Object.keys(carouselTimers).forEach((k) => delete carouselTimers[k]);
}

// Get-or-create carousel state. Auto-advance is on by default until an arrow
// is tapped, which sets auto=false permanently for that carousel.
function carousel(id, count) {
  if (!state.carousels[id]) state.carousels[id] = { index: 0, auto: true };
  const c = state.carousels[id];
  if (count > 0) c.index = ((c.index % count) + count) % count; // clamp
  return c;
}

// ---- top-level router ----
function render() {
  clearCarouselTimers(); // never leak intervals across renders
  if (state.tab === "home") screen.innerHTML = HomeScreen();
  else if (state.tab === "collections" && !state.activeCollection) screen.innerHTML = CollectionsScreen();
  else if (state.tab === "collections" && state.activeCollection) screen.innerHTML = CollectionDetailScreen(state.activeCollection);
  bindScreen();
  if (state.tab === "home") startHomeCarousels();
  if (state.modal) mountModal();
}

/* ============================================================
   HOME / DASHBOARD
   Layout:
   1. Top "recent" carousel — most-recent items across all categories,
      interleaved by recency, one item per slide. Auto-advances (slide).
   2. Time-bucket cards (Yesterday → Last year). Each bucket shows only
      items NOT already surfaced in an earlier bucket. Each card is its
      own swap carousel that rotates through that bucket's items.
   ============================================================ */

// Build the ordered list of buckets, each with the items that belong to it and
// haven't already appeared in a more-recent bucket. Empty buckets are dropped.
function buildHomeBuckets() {
  const items = allItemsByRecency();
  const used = new Set();
  const result = [];
  TIME_BUCKETS.forEach((b) => {
    const inWindow = items.filter(
      (it) => !used.has(it.key) && it.daysAgo >= b.min && it.daysAgo <= b.max
    );
    if (inWindow.length === 0) return;
    inWindow.forEach((it) => used.add(it.key));
    result.push({ ...b, items: inWindow });
  });
  return result;
}

function HomeScreen() {
  const recent = allItemsByRecency().slice(0, 8); // compact marquee source
  const due = dueItems();
  const buckets = buildHomeBuckets();

  const dueSection = due.length
    ? `
      <div class="home__section home__section--due">
        <div class="home__section-title">Needs attention</div>
        ${due.map(DueRow).join("")}
      </div>`
    : "";

  return `
  <div class="screen">
    <div class="scroll">
      <div class="home__head">
        <div class="kicker">Sunday · a gentle catch-up</div>
        <h1 class="home__title">Here's what caught your eye.</h1>
      </div>

      ${dueSection}

      <div class="home__section">
        <div class="home__section-title">Most recent</div>
        ${RecentCarousel(recent)}
      </div>

      <div class="home__section">
        <div class="home__section-title">Looking back</div>
        ${buckets.map(BucketCard).join("")}
      </div>

      <div style="height:120px"></div>
    </div>

    <button class="btn btn--live fab" data-act="simulate">＋ Simulate a screenshot</button>
    ${TabBar("home")}
  </div>`;
}

// ---- Needs-attention row (due soon / overdue) ----
function DueRow(it) {
  const co = cat(it.categoryId);
  const d = dueLabel(it.dueInDays);
  const line = it.type === "extract" ? (it.extract || it.why) : it.why;
  return `
    <button class="due" data-act="open-collection" data-id="${it.collectionId}">
      <span class="due__flag due__flag--${d.level}">${esc(d.text)}</span>
      <div class="due__line">${esc(line)}</div>
      <div class="due__foot" style="color:${co.color}">${esc(co.name)} · ${esc(it.collectionName)}</div>
    </button>`;
}

// ---- 1. top recent marquee (compact slide strip) ----
function RecentCarousel(items) {
  const slides = items
    .map((it) => {
      const co = cat(it.categoryId);
      const line = it.type === "extract" ? (it.extract || it.why) : it.why;
      return `
        <button class="rc__slide" data-act="open-collection" data-id="${it.collectionId}">
          <span class="rc__swatch" style="background:${co.color}">${it.type === "extract" ? "✎" : "▣"}</span>
          <span class="rc__text">
            <span class="rc__cat" style="color:${co.color}">${esc(co.name)} · ${esc(it.date)}</span>
            <span class="rc__line">${esc(line)}</span>
          </span>
        </button>`;
    })
    .join("");

  return carouselShell("recent", "slide", slides.length, `
    <div class="rc__track" data-carousel-track="recent">${slides}</div>
  `);
}

// ---- 2. time-bucket swap card ----
function BucketCard(b) {
  const slides = b.items
    .map((it) => {
      const co = cat(it.categoryId);
      const body =
        it.type === "extract"
          ? `<div class="bucket__summary">${esc(it.extract || it.why)}</div>`
          : `<div class="bucket__photo" style="background:${co.color}">${esc(it.tag)} · screenshot</div>`;
      return `
        <button class="bucket__slide" data-act="open-collection" data-id="${it.collectionId}" data-carousel-slide="${b.id}">
          <div class="bucket__cat" style="color:${co.color}">${esc(co.name)} · ${esc(it.collectionName)}</div>
          ${body}
          <div class="bucket__why">${esc(it.why)}</div>
        </button>`;
    })
    .join("");

  const header = `
    <div class="bucket__head">
      <span class="bucket__label">${esc(b.label)}</span>
      <span class="bucket__count">${b.items.length} ${b.items.length === 1 ? "item" : "items"}</span>
    </div>`;

  return `<div class="bucket">${header}${carouselShell(b.id, "swap", slides.length, `
    <div class="bucket__stage" data-carousel-track="${b.id}">${slides}</div>
  `)}</div>`;
}

// ---- shared carousel shell: dots + arrows (arrows kill auto-advance) ----
function carouselShell(id, kind, count, inner) {
  if (count <= 1) {
    // single item: no controls needed
    return `<div class="carousel carousel--${kind}" data-carousel="${id}" data-count="${count}">${inner}</div>`;
  }
  const dots = Array.from({ length: count })
    .map((_, i) => `<span class="carousel__dot" data-carousel-dot="${id}" data-i="${i}"></span>`)
    .join("");
  return `
    <div class="carousel carousel--${kind}" data-carousel="${id}" data-count="${count}">
      ${inner}
      <div class="carousel__controls">
        <button class="carousel__arrow" data-carousel-arrow="${id}" data-dir="-1" aria-label="Previous">‹</button>
        <div class="carousel__dots">${dots}</div>
        <button class="carousel__arrow" data-carousel-arrow="${id}" data-dir="1" aria-label="Next">›</button>
      </div>
    </div>`;
}

// ---- carousel runtime: position slides, wire arrows/dots, auto-advance ----
function startHomeCarousels() {
  screen.querySelectorAll("[data-carousel]").forEach((el) => {
    const id = el.getAttribute("data-carousel");
    const kind = el.classList.contains("carousel--swap") ? "swap" : "slide";
    const count = Number(el.getAttribute("data-count"));
    if (count <= 1) return;

    const c = carousel(id, count);
    applyCarousel(id, kind, count);

    // arrows: advance AND permanently stop auto-advance for this carousel
    el.querySelectorAll(`[data-carousel-arrow="${id}"]`).forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const dir = Number(btn.getAttribute("data-dir"));
        c.auto = false;
        stopTimer(id);
        c.index = (c.index + dir + count) % count;
        applyCarousel(id, kind, count);
      });
    });

    // dots: jump to slide, also stops auto-advance (an explicit interaction)
    el.querySelectorAll(`[data-carousel-dot="${id}"]`).forEach((dot) => {
      dot.addEventListener("click", (e) => {
        e.stopPropagation();
        c.auto = false;
        stopTimer(id);
        c.index = Number(dot.getAttribute("data-i"));
        applyCarousel(id, kind, count);
      });
    });

    if (c.auto) startTimer(id, kind, count);
  });
}

function startTimer(id, kind, count) {
  stopTimer(id);
  const delay = kind === "slide" ? 3800 : 4600;
  carouselTimers[id] = setInterval(() => {
    const c = state.carousels[id];
    if (!c || !c.auto) { stopTimer(id); return; }
    c.index = (c.index + 1) % count;
    applyCarousel(id, kind, count);
  }, delay);
}
function stopTimer(id) {
  if (carouselTimers[id]) { clearInterval(carouselTimers[id]); delete carouselTimers[id]; }
}

// Position the track / swap the active slide + sync dots for one carousel.
function applyCarousel(id, kind, count) {
  const c = state.carousels[id];
  const track = screen.querySelector(`[data-carousel-track="${id}"]`);
  if (track) {
    if (kind === "slide") {
      track.style.transform = `translateX(-${c.index * 100}%)`;
    } else {
      // swap: show only the active slide (cross-fade via .is-active)
      track.querySelectorAll(`[data-carousel-slide="${id}"]`).forEach((s, i) => {
        s.classList.toggle("is-active", i === c.index);
      });
    }
  }
  screen.querySelectorAll(`[data-carousel-dot="${id}"]`).forEach((dot, i) => {
    dot.classList.toggle("carousel__dot--on", i === c.index);
  });
}

/* ============================================================
   COLLECTIONS GRID
   ============================================================ */
function CollectionsScreen() {
  const filtered =
    state.filter === "all"
      ? COLLECTIONS
      : COLLECTIONS.filter((c) => c.categoryId === state.filter);

  return `
  <div class="screen">
    <div class="topbar">
      <div class="topbar__title">Collections</div>
      <div class="topbar__spacer"></div>
    </div>

    <div class="chips">
      <button class="chip ${state.filter === "all" ? "chip--active" : ""}" data-act="filter" data-id="all">All</button>
      ${CATEGORIES.map(
        (c) => `<button class="chip ${state.filter === c.id ? "chip--active" : ""}" data-act="filter" data-id="${c.id}">${esc(c.name)}</button>`
      ).join("")}
    </div>

    <div class="scroll">
      <div class="collections">
        ${filtered.map(CollectionCard).join("")}
      </div>
      <div style="height:100px"></div>
    </div>

    ${TabBar("collections")}
  </div>`;
}

function CollectionCard(c) {
  const co = cat(c.categoryId);
  return `
    <button class="collection" data-act="open-collection" data-id="${c.id}">
      <div class="collection__cover ${c.tall ? "collection__cover--tall" : ""}" style="background:${co.color}">
        ${esc(co.name)}
      </div>
      <div class="collection__meta">
        <div class="collection__name">${esc(c.name)}</div>
        <div class="collection__count">${c.items.length} saved</div>
      </div>
    </button>`;
}

/* ============================================================
   COLLECTION DETAIL  (image saves + extracted-info cards)
   ============================================================ */
function CollectionDetailScreen(id) {
  const c = COLLECTIONS.find((x) => x.id === id);
  const co = cat(c.categoryId);
  return `
  <div class="screen">
    <div class="topbar">
      <button class="topbar__back" data-act="back">←</button>
      <div class="topbar__title">${esc(c.name)}</div>
      <div class="topbar__spacer"></div>
    </div>
    <div class="scroll">
      <div class="items">
        ${c.items.map((it) => ItemCard(it, co)).join("")}
      </div>
      <div style="height:100px"></div>
    </div>
    ${TabBar("collections")}
  </div>`;
}

function ItemCard(it, co) {
  const img =
    it.type === "image"
      ? `<div class="item__img" style="background:${co.color}">${esc(it.tag)} · screenshot</div>`
      : "";
  const extract =
    it.type === "extract"
      ? `<div class="item__extract">${esc(it.extract)}</div>`
      : "";
  const badge =
    it.type === "extract"
      ? `<span class="badge badge--extract">Info kept</span>`
      : `<span class="badge">Image</span>`;
  return `
    <div class="item">
      ${img}
      <div class="item__body">
        <div class="item__why">${esc(it.why)}</div>
        ${extract}
        <div class="item__foot">
          ${badge}
          <span class="item__date">${esc(it.date)}</span>
        </div>
      </div>
    </div>`;
}

/* ============================================================
   BOTTOM TAB BAR
   ============================================================ */
function TabBar(active) {
  const tab = (id, glyph, label) =>
    `<button class="tab ${active === id ? "tab--active" : ""}" data-act="tab" data-id="${id}">
       <span class="tab__glyph">${glyph}</span>${label}
     </button>`;
  return `
    <div class="tabbar">
      ${tab("home", "◆", "Home")}
      ${tab("collections", "▦", "Collections")}
    </div>`;
}

/* ============================================================
   CATEGORIZATION MODAL  (the capture moment)
   ============================================================ */
function openModal() {
  // First simulate shows the To-do/Errands + Kids scenario (the one being
  // designed against); subsequent taps rotate through the rest at random.
  const todoIdx = INCOMING.findIndex((x) => x.suggested === "todo");
  const incoming = state.hasSimulated
    ? INCOMING[Math.floor(Math.random() * INCOMING.length)]
    : INCOMING[todoIdx >= 0 ? todoIdx : 0];
  state.hasSimulated = true;
  state.modal = {
    incoming,
    chosenCats: [incoming.suggested], // multi-select; suggestion is the pre-selected start
    mode: "extract", // default to the better-for-ADHD option: keep the info, not the image
    note: "",
    reminderId: "none",
    // Due date auto-detected from the extracted text. Pre-accepted if found so
    // the zero-effort path keeps it; user can change or clear it.
    dueInDays: incoming.detectedDue ? incoming.detectedDue.inDays : null,
  };
  render();
}

function closeModal() {
  state.modal = null;
  render();
}

// Toggle a category in/out of the multi-select. Guard against emptying the
// list entirely — there must always be at least one reason to save.
function toggleCat(id) {
  const list = state.modal.chosenCats;
  const i = list.indexOf(id);
  if (i >= 0) {
    if (list.length > 1) list.splice(i, 1); // don't allow zero categories
  } else {
    list.push(id);
  }
}

function mountModal() {
  const m = state.modal;
  const inc = m.incoming;

  // "Suggested" while only the AI's single guess is selected; becomes "Purpose"
  // as soon as you customize (add another, or remove the suggestion).
  const isPristineSuggestion =
    m.chosenCats.length === 1 && m.chosenCats[0] === inc.suggested;
  const catLabel = isPristineSuggestion ? "Suggested" : "Purpose";

  // Chip order: suggestion first, then the other candidates.
  const candidateIds = [inc.suggested, ...inc.alts];
  const altsHtml = candidateIds
    .map((cid) => {
      const c = cat(cid);
      const sel = m.chosenCats.includes(cid);
      return `<button class="alt ${sel ? "alt--sel" : ""}" data-mact="cat" data-id="${cid}">${sel ? "✓ " : ""}${esc(c.name)}</button>`;
    })
    .join("");

  const rem = reminder(m.reminderId);
  const remindersHtml = REMINDERS.map(
    (r) => `<button class="alt ${m.reminderId === r.id ? "alt--sel" : ""}" data-mact="remind" data-id="${r.id}">${esc(r.short)}</button>`
  ).join("");
  const expiryHint =
    rem.expiresLabel
      ? `<div class="reminder__hint">Reminds ${esc(rem.short.toLowerCase())} · ${esc(rem.expiresLabel)}</div>`
      : "";

  // ---- Due-date auto-detection block ----
  // If the on-device pass found a date cue, show it pre-selected with the
  // source phrase so it's clear where it came from. Presets let you adjust
  // without typing; "No date" clears it.
  const detected = inc.detectedDue;
  // Preset options, plus the detected offset itself if it isn't one of them,
  // so the auto-detected date is always a highlightable chip.
  const presetOffsets = DUE_PRESETS.map((p) => p.inDays);
  const dueOptions = DUE_PRESETS.slice();
  if (detected && !presetOffsets.includes(detected.inDays)) {
    dueOptions.push({ inDays: detected.inDays, label: dueLabel(detected.inDays).text.replace(/^Due /, "") });
  }
  const duePresetChips = dueOptions
    .map((p) => {
      const sel = m.dueInDays === p.inDays;
      return `<button class="alt ${sel ? "alt--sel" : ""}" data-mact="due" data-id="${p.inDays}">${esc(p.label)}</button>`;
    })
    .join("");
  const noneSel = m.dueInDays === null;
  const noDateChip = `<button class="alt ${noneSel ? "alt--sel" : ""}" data-mact="due" data-id="none">No date</button>`;

  const dueDetectedBanner =
    detected
      ? `<div class="due-detect">
           <span class="due-detect__spark">✦ Detected</span>
           <span class="due-detect__phrase">"${esc(detected.phrase)}"</span>
         </div>`
      : "";
  const dueConfirmHint =
    m.dueInDays !== null
      ? `<div class="reminder__hint">${esc(dueLabel(m.dueInDays).text)} · shows in “Needs attention” when close</div>`
      : "";

  const dueSection = `
      <div class="section-label">${detected ? "Due date" : "Add a due date"}</div>
      ${dueDetectedBanner}
      <div class="alts alts--due">${duePresetChips}${noDateChip}</div>
      ${dueConfirmHint}`;

  const overlay = document.createElement("div");
  overlay.className = "overlay";
  overlay.innerHTML = `
    <div class="sheet">
      <div class="sheet__header">
        <div class="kicker sheet__kicker">Screenshot from ${esc(inc.source)}</div>
        <button class="sheet__close" data-mact="dismiss" aria-label="Close">✕</button>
      </div>

      <div class="sheet__preview" style="background:${inc.previewColor}">${esc(inc.previewLabel)}</div>

      <div class="sheet__q">Why are you saving this?</div>

      <div class="section-label">${esc(catLabel)}</div>
      <div class="alts">${altsHtml}</div>

      <div class="field">
        <textarea id="note" placeholder="Or say it in your own words (optional)…">${esc(m.note)}</textarea>
      </div>

      ${dueSection}

      <div class="section-label">Remind me</div>
      <div class="alts alts--reminders">${remindersHtml}</div>
      ${expiryHint}

      <div class="sheet__actions">
        <button class="btn btn--live" data-mact="save" data-id="extract">
          <span class="save-glyph">✎</span> Save info
        </button>
        <button class="btn btn--primary" data-mact="save" data-id="image">
          <span class="save-glyph">▣</span> Save image
        </button>
      </div>
      <div class="sheet__helper">
        <span class="sheet__helper-hint">Info keeps the details &amp; drops the picture · Image keeps the full screenshot</span>
      </div>

      <button class="sheet__cancel" data-mact="dismiss">Taken by mistake? Cancel</button>
    </div>`;

  // No tap-outside-to-dismiss: the only ways out are the explicit X (top-right)
  // and the "Taken by mistake? Cancel" link, so nothing dismisses invisibly.
  overlay.querySelectorAll("[data-mact]").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.stopPropagation();
      const act = el.getAttribute("data-mact");
      const id = el.getAttribute("data-id");
      if (act === "cat") { toggleCat(id); remountModal(); }
      else if (act === "remind") { state.modal.reminderId = id; remountModal(); }
      else if (act === "due") { state.modal.dueInDays = id === "none" ? null : Number(id); remountModal(); }
      else if (act === "dismiss") closeModal();
      else if (act === "save") { state.modal.mode = id; saveFromModal(); }
    });
  });

  const ta = overlay.querySelector("#note");
  if (ta) ta.addEventListener("input", (e) => { state.modal.note = e.target.value; });

  screen.appendChild(overlay);
}

// re-render only the modal (keeps textarea focus behavior simple for a prototype)
function remountModal() {
  const existing = screen.querySelector(".overlay");
  const note = existing ? existing.querySelector("#note")?.value : "";
  if (note !== undefined) state.modal.note = note;
  if (existing) existing.remove();
  mountModal();
}

function saveFromModal() {
  const m = state.modal;
  const names = m.chosenCats.map((id) => cat(id).name).join(" + ");
  const modeLabel = m.mode === "extract" ? "Kept the useful info" : "Saved the image";
  const extractPreview = m.mode === "extract" ? m.incoming.autoExtract : null;
  const rem = reminder(m.reminderId);
  const reminderLine =
    rem.id !== "none"
      ? `<div class="flash__reminder">⏰ Reminder set for ${esc(rem.short.toLowerCase())} · ${esc(rem.expiresLabel)}</div>`
      : "";
  const dueLine =
    m.dueInDays !== null
      ? `<div class="flash__reminder">✦ ${esc(dueLabel(m.dueInDays).text)}</div>`
      : "";

  // show the confirmation flash, then auto-dismiss "back to what you were doing"
  const flash = document.createElement("div");
  flash.className = "flash";
  flash.innerHTML = `
    <div class="flash__mark">✓</div>
    <div class="flash__title">Filed under<br/>${esc(names)}.</div>
    <div class="flash__sub">${esc(modeLabel)}.${extractPreview ? " " + esc(extractPreview) : ""}</div>
    ${dueLine}
    ${reminderLine}
    <div class="flash__note">Returning you to where you were…</div>`;
  screen.appendChild(flash);

  // in the real app this is where we dismiss the Share Extension and hand
  // control back to the originating app. Here we just close after a beat.
  setTimeout(() => { closeModal(); }, 1600);
}

/* ============================================================
   EVENT BINDING (per-render, for the base screens)
   ============================================================ */
function bindScreen() {
  screen.querySelectorAll("[data-act]").forEach((el) => {
    el.addEventListener("click", () => {
      const act = el.getAttribute("data-act");
      const id = el.getAttribute("data-id");
      if (act === "tab") { state.tab = id; state.activeCollection = null; render(); }
      else if (act === "open-collection") { state.tab = "collections"; state.activeCollection = id; render(); }
      else if (act === "back") { state.activeCollection = null; render(); }
      else if (act === "filter") { state.filter = id; render(); }
      else if (act === "simulate") openModal();
    });
  });
}

// boot
render();
