const grid = document.getElementById("chordGrid");
const categoriesEl = document.getElementById("categories");
const searchEl = document.getElementById("search");
const modal = document.getElementById("modal");
const modalTitle = document.getElementById("modalTitle");
const fretboardSvg = document.getElementById("fretboard");
const closeModalBtn = document.getElementById("closeModal");

let activeCategory = "All";

function renderCategories() {
  const cats = ["All", ...CHORD_CATEGORIES];
  categoriesEl.innerHTML = "";
  cats.forEach((cat) => {
    const btn = document.createElement("button");
    btn.className = "cat-btn" + (cat === activeCategory ? " active" : "");
    btn.textContent = cat;
    btn.addEventListener("click", () => {
      activeCategory = cat;
      renderCategories();
      renderGrid();
    });
    categoriesEl.appendChild(btn);
  });
}

function renderGrid() {
  const query = searchEl.value.trim().toLowerCase();
  grid.innerHTML = "";
  CHORDS.filter((c) => {
    const matchesCategory = activeCategory === "All" || c.category === activeCategory;
    const matchesQuery = c.name.toLowerCase().includes(query);
    return matchesCategory && matchesQuery;
  }).forEach((chord) => {
    const btn = document.createElement("button");
    btn.className = "chord-btn";
    btn.textContent = chord.name;
    btn.addEventListener("click", () => openModal(chord));
    grid.appendChild(btn);
  });
}

function openModal(chord) {
  modalTitle.textContent = chord.name;
  drawFretboard(chord);
  modal.classList.add("open");
}

function closeModal() {
  modal.classList.remove("open");
}

closeModalBtn.addEventListener("click", closeModal);
modal.addEventListener("click", (e) => {
  if (e.target === modal) closeModal();
});
searchEl.addEventListener("input", renderGrid);

function drawFretboard(chord) {
  const { frets, fingers } = chord;
  const playedFrets = frets.filter((f) => f > 0);
  const maxFret = playedFrets.length ? Math.max(...playedFrets) : 0;
  const startFret = maxFret <= 4 ? 0 : Math.min(...playedFrets) - 1;
  const numFretsShown = 4;

  const svgNS = "http://www.w3.org/2000/svg";
  const width = 220;
  const boardTop = 40;
  const boardBottom = 260;
  const boardLeft = 30;
  const boardRight = 190;
  const stringGap = (boardRight - boardLeft) / 3;
  const fretGap = (boardBottom - boardTop) / numFretsShown;

  fretboardSvg.innerHTML = "";
  const makeEl = (tag, attrs) => {
    const el = document.createElementNS(svgNS, tag);
    Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v));
    return el;
  };

  const style = getComputedStyle(document.documentElement);
  const inkColor = style.getPropertyValue("--ink").trim() || "#2b2118";
  const inkSoft = style.getPropertyValue("--ink-soft").trim() || "#6f5f45";
  const accentColor = style.getPropertyValue("--accent").trim() || "#14807f";
  const accent2Color = style.getPropertyValue("--accent2").trim() || "#c98a12";
  const muteColor = style.getPropertyValue("--mute").trim() || "#a83247";
  const surfaceLine = style.getPropertyValue("--surface-line").trim() || "#e2d2a3";

  // board fill (soundboard wood tone)
  fretboardSvg.appendChild(
    makeEl("rect", { x: boardLeft, y: boardTop, width: boardRight - boardLeft, height: boardBottom - boardTop, fill: surfaceLine, opacity: 0.35 })
  );

  // strings (vertical lines)
  for (let s = 0; s < 4; s++) {
    const x = boardLeft + s * stringGap;
    fretboardSvg.appendChild(
      makeEl("line", { x1: x, y1: boardTop, x2: x, y2: boardBottom, stroke: inkColor, "stroke-width": 2 })
    );
  }

  // frets (horizontal lines)
  for (let f = 0; f <= numFretsShown; f++) {
    const y = boardTop + f * fretGap;
    const isNut = f === 0 && startFret === 0;
    fretboardSvg.appendChild(
      makeEl("line", { x1: boardLeft, y1: y, x2: boardRight, y2: y, stroke: inkColor, "stroke-width": isNut ? 6 : 1.5 })
    );
  }

  // fret position label if not starting at nut
  if (startFret > 0) {
    const label = makeEl("text", { x: boardLeft - 22, y: boardTop + fretGap * 0.7, "font-size": 12, fill: inkColor, "font-weight": "bold" });
    label.textContent = (startFret + 1) + "fr";
    fretboardSvg.appendChild(label);
  }

  const stringLabels = ["G", "C", "E", "A"];
  frets.forEach((fret, s) => {
    const x = boardLeft + s * stringGap;

    // string name at bottom
    const nameLabel = makeEl("text", { x: x - 4, y: boardBottom + 20, "font-size": 13, fill: inkSoft, "font-weight": "bold" });
    nameLabel.textContent = stringLabels[s];
    fretboardSvg.appendChild(nameLabel);

    if (fret === -1) {
      const x2 = makeEl("text", { x: x - 6, y: boardTop - 10, "font-size": 18, fill: muteColor, "font-weight": "bold" });
      x2.textContent = "×";
      fretboardSvg.appendChild(x2);
      return;
    }
    if (fret === 0) {
      fretboardSvg.appendChild(
        makeEl("circle", { cx: x, cy: boardTop - 14, r: 7, fill: "none", stroke: accentColor, "stroke-width": 2.5 })
      );
      return;
    }

    const relFret = fret - startFret;
    const y = boardTop + (relFret - 0.5) * fretGap;
    fretboardSvg.appendChild(makeEl("circle", { cx: x, cy: y, r: 12, fill: accent2Color }));
    const finger = fingers[s];
    if (finger) {
      const t = makeEl("text", {
        x: x, y: y + 4.5, "font-size": 13, fill: "#2b2118", "text-anchor": "middle", "font-weight": "bold"
      });
      t.textContent = finger;
      fretboardSvg.appendChild(t);
    }
  });
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  });
}

renderCategories();
renderGrid();
