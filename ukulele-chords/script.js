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

  // strings (vertical lines)
  for (let s = 0; s < 4; s++) {
    const x = boardLeft + s * stringGap;
    fretboardSvg.appendChild(
      makeEl("line", { x1: x, y1: boardTop, x2: x, y2: boardBottom, stroke: "#3a352f", "stroke-width": 2 })
    );
  }

  // frets (horizontal lines)
  for (let f = 0; f <= numFretsShown; f++) {
    const y = boardTop + f * fretGap;
    const isNut = f === 0 && startFret === 0;
    fretboardSvg.appendChild(
      makeEl("line", { x1: boardLeft, y1: y, x2: boardRight, y2: y, stroke: "#3a352f", "stroke-width": isNut ? 5 : 1.5 })
    );
  }

  // fret position label if not starting at nut
  if (startFret > 0) {
    const label = makeEl("text", { x: boardLeft - 20, y: boardTop + fretGap * 0.7, "font-size": 12, fill: "#3a352f" });
    label.textContent = (startFret + 1) + "fr";
    fretboardSvg.appendChild(label);
  }

  const stringLabels = ["G", "C", "E", "A"];
  frets.forEach((fret, s) => {
    const x = boardLeft + s * stringGap;

    // string name at bottom
    const nameLabel = makeEl("text", { x: x - 4, y: boardBottom + 18, "font-size": 12, fill: "#7a6f5e" });
    nameLabel.textContent = stringLabels[s];
    fretboardSvg.appendChild(nameLabel);

    if (fret === -1) {
      const x2 = makeEl("text", { x: x - 5, y: boardTop - 12, "font-size": 16, fill: "#c0392b", "font-weight": "bold" });
      x2.textContent = "x";
      fretboardSvg.appendChild(x2);
      return;
    }
    if (fret === 0) {
      fretboardSvg.appendChild(
        makeEl("circle", { cx: x, cy: boardTop - 14, r: 6, fill: "none", stroke: "#4a7c59", "stroke-width": 2 })
      );
      return;
    }

    const relFret = fret - startFret;
    const y = boardTop + (relFret - 0.5) * fretGap;
    fretboardSvg.appendChild(makeEl("circle", { cx: x, cy: y, r: 11, fill: "#d97742" }));
    const finger = fingers[s];
    if (finger) {
      const t = makeEl("text", {
        x: x, y: y + 4, "font-size": 12, fill: "white", "text-anchor": "middle", "font-weight": "bold"
      });
      t.textContent = finger;
      fretboardSvg.appendChild(t);
    }
  });
}

renderCategories();
renderGrid();
