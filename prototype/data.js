/* ============================================================
   Seed data for the prototype.
   In the real app this is on-device (SwiftData / Core Data),
   populated by the Share Extension + Photos scanner, with
   category suggestions from Vision + NaturalLanguage on-device.
   ============================================================ */

// Category → cover color (all drawn from the partyswoop palette family)
const CATEGORIES = [
  { id: "inspiration", name: "Inspiration", color: "#A8512C" },
  { id: "todo",        name: "To-do / Errands", color: "#1C1C1A" },
  { id: "shopping",    name: "Shopping", color: "#6B4E9E" },
  { id: "kids",        name: "Kids", color: "#3C6E57" },
  { id: "recipes",     name: "Recipes", color: "#B08114" },
  { id: "read-later",  name: "Read later", color: "#2C5A78" },
];

function cat(id) { return CATEGORIES.find((c) => c.id === id); }

// type: "image"  -> screenshot kept as an image
// type: "extract" -> image discarded, useful info pulled out and stored
// daysAgo powers real time-bucketing on the home screen; date is the display
// label shown in the collection detail view.
// dueInDays (optional): a reminder/deadline relative to today.
//   negative  = overdue (e.g. -1 = due yesterday)
//   0         = due today
//   positive  = due in N days
// Items with dueInDays surface in the "Needs attention" section up top.
// Note: some time buckets are intentionally left empty (no items land in
// This month / This quarter / This year here) to show that empty buckets
// simply don't render.
const COLLECTIONS = [
  {
    id: "painting",
    name: "Painting inspiration",
    categoryId: "inspiration",
    tall: true,
    items: [
      { type: "image", why: "The way the light falls on the water here — want to try this palette.", date: "3d ago", daysAgo: 3, tag: "painting" },
      { type: "image", why: "Loose brushwork on the trees. Reference for the commission.", date: "9d ago", daysAgo: 9, tag: "painting" },
    ],
  },
  {
    id: "drivers-ed",
    name: "Driver's ed for Ellie",
    categoryId: "kids",
    items: [
      { type: "extract", why: "Where to sign Ellie up for driver's ed.",
        extract: "Riverside Driving School — enrollment opens Sep 15. $480 for 30hr course. Ages 15.5+. Phone: (555) 0142. riverside-driving.example",
        date: "1d ago", daysAgo: 1, tag: "driver's ed", dueInDays: 1 },
      { type: "image", why: "The schedule comparison screenshot from the parents group.", date: "1d ago", daysAgo: 1, tag: "driver's ed" },
    ],
  },
  {
    id: "kitten-heels",
    name: "Kitten heels",
    categoryId: "shopping",
    tall: true,
    items: [
      { type: "image", why: "These in the tan color. Wait for a sale.", date: "5d ago", daysAgo: 5, tag: "shoes" },
      { type: "extract", why: "Sizing note so I stop re-checking.",
        extract: "Brand runs a half size small. Reviewer (my usual 8) sized up to 8.5. Free returns within 30 days.", date: "45d ago", daysAgo: 45, tag: "shoes" },
      { type: "image", why: "The pointed-toe pair — sale ends soon per the caption.", date: "120d ago", daysAgo: 120, tag: "shoes", dueInDays: 2 },
    ],
  },
  {
    id: "weeknight",
    name: "Weeknight dinners",
    categoryId: "recipes",
    items: [
      { type: "extract", why: "30-min pasta I actually want to make.",
        extract: "Lemon-garlic orzo w/ spinach. Ingredients: orzo, garlic, lemon, spinach, parm, chili flake. 1 pot, ~25 min. Source: @quickdinners", date: "4d ago", daysAgo: 4, tag: "recipe" },
      { type: "extract", why: "Sheet-pan idea.",
        extract: "Sheet-pan gnocchi + cherry tomatoes + pesto, 425°F 25 min.", date: "11d ago", daysAgo: 11, tag: "recipe" },
    ],
  },
  {
    id: "read-later",
    name: "Read later",
    categoryId: "read-later",
    items: [
      { type: "extract", why: "Article title so I can find it again without the screenshot.",
        extract: "\"How ADHD brains handle time\" — Author: J. Reyes. Est. 12 min read. Search the title; it's on the health blog I follow.", date: "2d ago", daysAgo: 2, tag: "article" },
      { type: "image", why: "The book stack recommendation from that thread.", date: "40d ago", daysAgo: 40, tag: "books" },
      { type: "extract", why: "Long essay I bookmarked ages ago.",
        extract: "\"On slow productivity\" — save for a quiet weekend. It's on the same blog.", date: "400d ago", daysAgo: 400, tag: "article" },
    ],
  },
  {
    id: "home-errands",
    name: "Errands & to-do",
    categoryId: "todo",
    items: [
      { type: "extract", why: "The thing I keep forgetting to order.",
        extract: "Replacement water filter — model DA29-00020B. Fits the fridge. ~$32 for 2-pack.",
        date: "6d ago", daysAgo: 6, tag: "errand", dueInDays: -1 },
      { type: "extract", why: "Return window closes soon on the jacket.",
        extract: "Return the navy jacket — label printed, drop at any carrier point. Order #4471.",
        date: "8d ago", daysAgo: 8, tag: "errand", dueInDays: 0 },
    ],
  },
];

// ---- time bucketing (home screen) ----
// Ordered most-recent → oldest. Each item lands in the FIRST bucket whose
// window contains it; the home screen then only shows, per bucket, items not
// already surfaced by an earlier bucket (so each card reveals new content).
const TIME_BUCKETS = [
  { id: "yesterday",  label: "Yesterday",     min: 1,   max: 1 },
  { id: "this-week",  label: "This week",     min: 2,   max: 6 },
  { id: "last-week",  label: "Last week",     min: 7,   max: 13 },
  { id: "this-month", label: "This month",    min: 14,  max: 29 },
  { id: "last-month", label: "Last month",    min: 30,  max: 59 },
  { id: "this-qtr",   label: "This quarter",  min: 60,  max: 89 },
  { id: "last-qtr",   label: "Last quarter",  min: 90,  max: 179 },
  { id: "this-year",  label: "This year",     min: 180, max: 364 },
  { id: "last-year",  label: "Last year",     min: 365, max: 100000 },
];

// Flatten every item across collections, tagged with its collection + category,
// sorted most-recent first. This is the shared source for the top carousel and
// the time-bucket cards.
function allItemsByRecency() {
  const out = [];
  COLLECTIONS.forEach((c) => {
    c.items.forEach((it, idx) => {
      out.push({
        ...it,
        collectionId: c.id,
        collectionName: c.name,
        categoryId: c.categoryId,
        key: c.id + ":" + idx,
      });
    });
  });
  return out.sort((a, b) => a.daysAgo - b.daysAgo);
}

// Items that carry a due date, considered "needs attention" when overdue or
// due within the next few days. Sorted most-urgent (most overdue) first.
const DUE_SOON_WINDOW = 3; // days ahead that still counts as "due soon"
function dueItems() {
  return allItemsByRecency()
    .filter((it) => typeof it.dueInDays === "number" && it.dueInDays <= DUE_SOON_WINDOW)
    .sort((a, b) => a.dueInDays - b.dueInDays);
}

// Human label + urgency class for a due offset.
function dueLabel(d) {
  if (d < -1) return { text: `${Math.abs(d)} days overdue`, level: "overdue" };
  if (d === -1) return { text: "Overdue since yesterday", level: "overdue" };
  if (d === 0) return { text: "Due today", level: "today" };
  if (d === 1) return { text: "Due tomorrow", level: "soon" };
  return { text: `Due in ${d} days`, level: "soon" };
}

// ADHD resurfacing nudges — the ones you described, plus a stat-style one.
const NUDGES = [
  { id: "n1", accent: true, tag: "Last week", body: "You explored some new painting inspiration. Want to pick up where you left off?", collectionId: "painting" },
  { id: "n2", accent: false, tag: "Yesterday", body: "You were figuring out where to sign Ellie up for driver's ed. The details are saved.", collectionId: "drivers-ed" },
  { id: "n3", accent: false, tag: "Last month", body: "80% of your shopping screenshots were kitten heels. Ready to decide on a pair?", collectionId: "kitten-heels" },
];

// Reminder options. Each carries an implied expiry window: a time-sensitive
// save becomes obsolete shortly after its reminder, so we can auto-fade it.
// expiresLabel is what we show; expiresDays drives archival in the real app.
const REMINDERS = [
  { id: "none",     label: "No reminder", short: "No reminder", expiresLabel: null, expiresDays: null },
  { id: "tomorrow", label: "Tomorrow morning", short: "Tomorrow AM", expiresLabel: "fades in 2 days", expiresDays: 2 },
  { id: "tonight",  label: "Tonight", short: "Tonight", expiresLabel: "fades tomorrow", expiresDays: 1 },
  { id: "weekend",  label: "This weekend", short: "This weekend", expiresLabel: "fades next week", expiresDays: 7 },
  { id: "nextweek", label: "Next week", short: "Next week", expiresLabel: "fades in 2 weeks", expiresDays: 14 },
];
function reminder(id) { return REMINDERS.find((r) => r.id === id); }

// Candidate suggestions for the "simulate a screenshot" demo.
// Each mimics what the on-device model would propose.
// detectedDue (optional): what the on-device date detector found in the
// extracted text. { phrase, inDays } — phrase is the source snippet it matched,
// inDays is the resolved offset from today. Absent = no date cue detected.
const INCOMING = [
  {
    source: "Maps",
    previewColor: "#3C6E57",
    previewLabel: "screenshot · maps",
    suggested: "todo",
    alts: ["kids", "shopping"],
    autoExtract: "Riverside Driving School · enrollment closes Fri · $480 · (555) 0142",
    detectedDue: { phrase: "enrollment closes Fri", inDays: 5 },
  },
  {
    source: "Safari",
    previewColor: "#2C5A78",
    previewLabel: "screenshot · safari",
    suggested: "shopping",
    alts: ["todo", "read-later"],
    autoExtract: "Order #4471 · free returns within 30 days · label enclosed",
    detectedDue: { phrase: "return within 30 days", inDays: 30 },
  },
  {
    source: "Instagram",
    previewColor: "#A8512C",
    previewLabel: "screenshot · instagram",
    suggested: "inspiration",
    alts: ["shopping", "read-later"],
    autoExtract: "Artist @studio.lune · abstract landscape series · muted terracotta + sage palette",
    // no detectedDue: nothing date-like in the text
  },
];

// Preset options offered when a due date is detected (or to set one manually).
// inDays resolves the offset from today; the modal shows a friendly label.
const DUE_PRESETS = [
  { id: "today",    label: "Today",    inDays: 0 },
  { id: "tomorrow", label: "Tomorrow", inDays: 1 },
  { id: "3days",    label: "In 3 days", inDays: 3 },
  { id: "week",     label: "In a week", inDays: 7 },
];
