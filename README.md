# The Diver's Boat — Koh Phangan

A redesign of [thediversboat-kohphangan.com](https://www.thediversboat-kohphangan.com/):
a static site for the SSI dive centre in Chaloklum, Koh Phangan.

No build step, no dependencies. Open `index.html` or serve the folder.

```bash
python3 -m http.server 8000     # then visit http://localhost:8000
```

---

## The idea

**Scrolling the homepage is a descent.** Every section declares the depth it
sits at, and the page changes with it:

| Depth | Section | Why there |
| --- | --- | --- |
| 0 m | Hero — whale shark at Sail Rock | The surface, with light and caustics above you |
| 2 m | Try Dive / Open Water / Fun Dive | Just under, where you choose how you go in |
| 5 m | Why dive with us | Sunlight zone, still bright |
| 8 m | How your dive day goes | |
| 12 m | Experiences | Blue water |
| 18 m | SSI courses | The Open Water depth limit, which is what the section sells |
| 25 m | Dive sites | Deep enough that red light is gone — hence the torch |
| 30 m | The boat and crew | The Deep Specialty ceiling |
| 35 m | Photo gallery | Low light |
| 40 m | Contact and book | Sail Rock's floor — the deepest point on the page |
| 5 m | Footer | Safety stop, then back to the surface |

Sub-pages use the same depth ramp over a shorter run.

### What that buys, concretely

- **A depth computer** fixed to the right edge, reading out metres and the
  current zone. It interpolates between section depths as you scroll, so the
  number always matches what you're reading.
- **Background that darkens** from surface aqua (`--d00`) to abyss
  (`--d42`) through per-section gradients — pure CSS, so it works with
  JavaScript disabled.
- **Sunlight that fades with depth.** The god-ray layer's opacity is driven by
  a `--depth` custom property; suspended particulate fades *in* as it fades out.
- **A dive torch on the dive-site cards.** At 25 m the photos render
  desaturated and blue, the way they actually look down there. Move your
  pointer across a card and a beam restores the colour underneath it.
  Keyboard and touch users get the whole card lit instead of a beam.
- Bubbles rising past you the whole way down, and marine-life silhouettes
  drifting through at depth-appropriate sections (turtle in the shallows,
  eagle ray in blue water, jellyfish in low light).

Everything above is suppressed under `prefers-reduced-motion: reduce`.

---

## Files

```
index.html          The descent — the whole story on one page
experiences.html    Fun Dive, Try Dive, Basic Diver, Sail Rock snorkelling
courses.html        Open Water, Advanced, Specialty, Deep, Rescue, Nitrox
dive-sites.html     Sail Rock, Koh Ma, Little Sail Rock, Oil Platform
about.html          The centre, the boat, the crew, safety and equipment
gallery.html        Photo grid
assets/css/main.css One stylesheet, sectioned and commented
assets/js/main.js   One script, no dependencies
assets/img/         Photography at 800w and 1600w
favicon.svg  robots.txt  sitemap.xml
```

Header and footer are duplicated across pages (no templating layer). If you
change one, change all six — they are byte-identical between `<body>` and
`<main>`, and from `<footer>` to the end.

---

## Design tokens

Set at the top of `main.css`.

- **Depth ramp** `--d00` … `--d42`, one stop roughly every 3–6 m.
- **Accent** `--accent: #ff7a4d`, a warm coral. Every call to action uses it —
  it is the only warm colour on the page, which is what makes it read as
  "press this" against ten shades of blue. It also keeps the palette from
  feeling cold, which matters for families.
- **Data colour** `--aqua: #5ce3d4` for labels, depths, metadata — anything
  that should feel like an instrument readout.
- **Body** `--sand: #f4e8d6`, warm off-white, easier on the eye than pure white
  on deep blue.

**Type.** Archivo (display, set to `wdth 112` for a confident wide grotesque),
Inter (body), IBM Plex Mono (depths, prices, technical labels). The mono is
doing real work: it is what makes prices and depths read as dive-computer data
rather than marketing.

---

## Behaviour notes

- **Reveal on scroll is a progressive enhancement.** An inline script in
  `<head>` adds a `js` class to `<html>`; only then does `.rise` start at
  `opacity: 0`. Without JavaScript the page renders fully visible with no flash.
- **Reveals are driven by the scroll pass, not an IntersectionObserver.** An
  observer created before the browser finishes a deep-link jump (`/#courses`)
  can settle on stale intersections and leave whole sections invisible. A rect
  sweep always agrees with what is on screen, and there is a 4-second failsafe
  that reveals everything regardless.
- **The depth computer owns the right margin** above 1180px: content columns
  get extra right padding so body copy never runs under the readout. Below
  that the readout is replaced by a hairline progress bar under the header.
- No horizontal scroll at any width down to 320px; verified per page.
- Every image carries `width`/`height` matching the file on disk, so nothing
  shifts as photos load.

---

## Content provenance

All copy and photography came from the existing site. Prices, depths, dive-site
descriptions, team bios, languages, equipment and safety claims are the
client's own words, lightly edited for tone.

**Written fresh for this build** (and worth the client's eye before launch):

- The "How your dive day goes" timeline. Only the 10:00 departure is a stated
  fact; the other five steps are deliberately labelled by phase
  ("Morning", "Dive one", "Surface interval") rather than by clock time,
  because exact times were not on the old site. Add real times if they're fixed.
- The FAQ answers on the homepage and experiences page.
- Course descriptions on `courses.html`. These are experiential, not
  curricular — no minimum ages, prerequisites or dive counts are claimed,
  because the old site listed none. The one exception is the Oil Platform's
  "20+ logged dives", which the old site did state.
- Section headings and the hero line.

**Deliberately left out:** the old site had a "What our divers say" heading with
no reviews behind it. Rather than invent testimonials, there is a trust strip
(SSI certification, six languages, Koh Tao since 2015) where they would go.
To add real ones, drop a card grid into the `.trust` block in the 5 m section.

---

## Before launch

- [ ] **Add real reviews** — see above.
- [ ] **Confirm the dive-day timeline** reflects how the day actually runs.
- [ ] **Add an `apple-touch-icon.png`** (180×180) and link it in each `<head>`;
      only `favicon.svg` ships, because there was no raster toolchain here.
- [ ] **Embed a live map** in the `.map` block on the homepage and
      `dive-sites.html` if you want directions — currently static screenshots
      carried over from the old site, linked to Google Maps.
- [ ] **Check the Koh Tao link** (`thediversboat.com`) is the base you want
      to point at.
- [ ] Consider serving the photography as WebP/AVIF alongside the JPEGs; the
      `srcset` structure is already in place for it.

## Contact details used throughout

Phone / WhatsApp `+66 95 438 5374` · `thaidivingpro@gmail.com` ·
25, 47 Moo 7, Chaloklum, Koh Phangan, Surat Thani 84280, Thailand ·
[@thediversboatkpg](https://www.instagram.com/thediversboatkpg/)

Departures daily at 10:00 from Chaloklum.
