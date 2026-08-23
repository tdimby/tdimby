// Ukulele chord database, standard GCEA tuning.
// frets: [G, C, E, A] fret number per string (0 = open, -1 = muted string)
// fingers: same order, 0 = open/no finger, 1-4 = which finger to use

const CHORD_CATEGORIES = ["Major", "Minor", "7th", "Minor 7th", "Major 7th"];

const CHORDS = [
  // Major
  { name: "C",  category: "Major", frets: [0, 0, 0, 3], fingers: [0, 0, 0, 3] },
  { name: "C#", category: "Major", frets: [1, 1, 1, 4], fingers: [1, 1, 1, 4] },
  { name: "D",  category: "Major", frets: [2, 2, 2, 0], fingers: [1, 2, 3, 0] },
  { name: "D#", category: "Major", frets: [0, 3, 3, 1], fingers: [0, 3, 4, 1] },
  { name: "E",  category: "Major", frets: [1, 4, 0, 2], fingers: [1, 4, 0, 2] },
  { name: "F",  category: "Major", frets: [2, 0, 1, 0], fingers: [2, 0, 1, 0] },
  { name: "F#", category: "Major", frets: [3, 1, 2, 1], fingers: [3, 1, 2, 1] },
  { name: "G",  category: "Major", frets: [0, 2, 3, 2], fingers: [0, 1, 3, 2] },
  { name: "G#", category: "Major", frets: [5, 3, 4, 3], fingers: [3, 1, 2, 1] },
  { name: "A",  category: "Major", frets: [2, 1, 0, 0], fingers: [2, 1, 0, 0] },
  { name: "A#", category: "Major", frets: [3, 2, 1, 1], fingers: [4, 3, 1, 1] },
  { name: "B",  category: "Major", frets: [4, 3, 2, 2], fingers: [4, 3, 1, 1] },

  // Minor
  { name: "Cm",  category: "Minor", frets: [0, 3, 3, 3], fingers: [0, 1, 2, 3] },
  { name: "C#m", category: "Minor", frets: [1, 1, 0, 1], fingers: [2, 3, 0, 1] },
  { name: "Dm",  category: "Minor", frets: [2, 2, 1, 0], fingers: [2, 3, 1, 0] },
  { name: "D#m", category: "Minor", frets: [0, 2, 2, 1], fingers: [0, 2, 3, 1] },
  { name: "Em",  category: "Minor", frets: [0, 4, 3, 2], fingers: [0, 4, 3, 1] },
  { name: "Fm",  category: "Minor", frets: [1, 0, 1, 3], fingers: [1, 0, 2, 3] },
  { name: "F#m", category: "Minor", frets: [2, 1, 2, 0], fingers: [2, 1, 3, 0] },
  { name: "Gm",  category: "Minor", frets: [0, 2, 3, 1], fingers: [0, 2, 3, 1] },
  { name: "G#m", category: "Minor", frets: [1, 3, 4, 2], fingers: [1, 3, 4, 2] },
  { name: "Am",  category: "Minor", frets: [2, 0, 0, 0], fingers: [2, 0, 0, 0] },
  { name: "A#m", category: "Minor", frets: [3, 1, 1, 1], fingers: [4, 1, 1, 1] },
  { name: "Bm",  category: "Minor", frets: [4, 2, 2, 2], fingers: [4, 1, 1, 1] },

  // 7th
  { name: "C7",  category: "7th", frets: [0, 0, 0, 1], fingers: [0, 0, 0, 1] },
  { name: "D7",  category: "7th", frets: [2, 2, 2, 3], fingers: [1, 2, 3, 4] },
  { name: "E7",  category: "7th", frets: [1, 2, 0, 2], fingers: [1, 3, 0, 2] },
  { name: "F7",  category: "7th", frets: [2, 3, 1, 3], fingers: [2, 4, 1, 3] },
  { name: "G7",  category: "7th", frets: [0, 2, 1, 2], fingers: [0, 3, 1, 2] },
  { name: "A7",  category: "7th", frets: [0, 1, 0, 0], fingers: [0, 1, 0, 0] },
  { name: "B7",  category: "7th", frets: [2, 3, 2, 2], fingers: [1, 4, 2, 2] },

  // Minor 7th
  { name: "Am7", category: "Minor 7th", frets: [0, 0, 0, 0], fingers: [0, 0, 0, 0] },
  { name: "Dm7", category: "Minor 7th", frets: [2, 2, 1, 3], fingers: [2, 3, 1, 4] },
  { name: "Em7", category: "Minor 7th", frets: [0, 2, 0, 2], fingers: [0, 1, 0, 2] },
  { name: "Gm7", category: "Minor 7th", frets: [0, 2, 1, 1], fingers: [0, 3, 1, 1] },

  // Major 7th
  { name: "Cmaj7", category: "Major 7th", frets: [0, 0, 0, 2], fingers: [0, 0, 0, 2] },
  { name: "Fmaj7", category: "Major 7th", frets: [2, 4, 1, 3], fingers: [2, 4, 1, 3] },
  { name: "Gmaj7", category: "Major 7th", frets: [0, 2, 2, 2], fingers: [0, 1, 1, 1] },
];
