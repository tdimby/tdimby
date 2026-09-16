# Neon Void

A synthwave-flavored arcade shooter, built for the browser — no install, no
build step, just open `index.html`. Pilot a lone ship through a drifting
asteroid field, shatter the rocks, dodge the wreckage, and watch the sky:
a UFO occasionally comes looking for you.

It's a love letter to vector-graphics arcade cabinets (think *Asteroids*),
redrawn in glowing neon with a CRT scanline overlay, screen shake, particle
explosions, and a synth-y sound engine generated entirely with the Web
Audio API — no audio files, no dependencies, no build tooling. One HTML
file, ~700 lines, runs anywhere.

## Play

Open `index.html` in any modern browser, or serve the folder locally:

```bash
python3 -m http.server 8000
# then visit http://localhost:8000/neon-void/
```

## Controls

| Action        | Keys                  |
| ------------- | ---------------------- |
| Rotate        | `←` `→` or `A` `D`     |
| Thrust        | `↑` or `W`              |
| Fire          | `Space`                |
| Pause         | `P` or `Esc`            |
| Mute          | `M`                    |

Touch controls appear automatically on phones and tablets.

## How it plays

- Clear each wave of asteroids to advance — bigger rocks split into
  smaller ones when hit, and each wave gets a little more crowded.
- You have 3 lives. Getting hit costs one and gives you a brief
  invulnerable respawn (it blinks).
- A UFO periodically drifts across the screen and takes shots at you —
  destroy it for a big score bonus.
- Your high score is saved locally in the browser (`localStorage`), no
  account or server needed.

## Deploying

The included GitHub Actions workflow (`.github/workflows/pages-neon-void.yml`)
publishes this folder to GitHub Pages automatically on push. Enable Pages
for the repository (Settings → Pages → Source: GitHub Actions) and the
game will be live at the deployed URL.

## Tech

Plain HTML5 Canvas 2D + vanilla JavaScript, one file, zero dependencies
beyond an optional Google Font for the UI text (the game still runs fine
if that font fails to load). No framework, no bundler, no npm install.
