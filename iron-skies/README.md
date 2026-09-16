# Iron Skies

A pseudo-3D, pixel-art arcade dogfighting game — pick a fighter, take off,
and hold the line against wave after wave of enemy aircraft. Built entirely
in one HTML file: a small hand-rolled 3D engine (perspective projection,
painter's-algorithm depth sorting, low-poly flat-shaded aircraft) rendered
to a chunky low-resolution canvas for a retro, PS1-era arcade-flight-sim
look. No build step, no dependencies beyond an optional Google Font.

Think *War Thunder*'s arcade dogfights, redrawn at 480×270 with a phosphor-
green military HUD.

## Play

Open `index.html` in any modern browser, or serve the folder locally:

```bash
python3 -m http.server 8000
# then visit http://localhost:8000/iron-skies/
```

## Controls

| Action              | Keys                     |
| ------------------- | ------------------------ |
| Climb / Dive         | `↑`/`W`  ·  `↓`/`S`       |
| Roll (bank & turn)   | `←→` or `A` `D`           |
| Throttle             | `Q` (down) · `E` (up)     |
| Fire guns             | `Space` (hold)          |
| Afterburner boost    | `Shift` (hold)            |
| Pause                | `P` or `Esc`               |
| Mute                 | `M`                        |

Touch controls (virtual stick + fire/boost buttons) appear automatically
on phones and tablets.

## How it plays

- Pick one of three fighters before takeoff — an agile **Interceptor**, a
  tanky **Heavy Fighter**, or a balanced **All-Rounder** — each with
  different speed, agility, armor and firepower.
- Fly with a simplified energy model: **diving builds speed, climbing
  bleeds it**. Let your speed drop too low and you'll stall — the nose
  drops and controls go mushy until you dive to recover. This is the same
  energy-management dogfighting real arcade flight games (and War Thunder)
  are built around.
- Guns overheat with sustained fire — watch the heat gauge.
- Waves of enemy fighters escalate in number and skill (grunts, then
  tougher "aces" mixed in). Downed aircraft are worth more score at higher
  tiers.
- Stray too far from the combat zone and you'll get a boundary warning;
  ignore it and you'll take damage. Flying into the ground is instantly
  fatal — respect your altitude.
- Three lives, full HUD (speed, altitude, heading, radar, throttle, boost
  fuel, hull integrity, gun heat). High score saved locally via
  `localStorage` — no account needed.

## Deploying

The included GitHub Actions workflow (`.github/workflows/pages-iron-skies.yml`)
publishes this folder to GitHub Pages automatically on push. Enable Pages
for the repository (Settings → Pages → Source: GitHub Actions) and the
game will be live at the deployed URL.

## Tech

Plain HTML5 Canvas 2D + vanilla JavaScript, one file, zero build tooling.
The "3D" is a small software renderer written from scratch: aircraft
orientation is tracked as an orthonormal basis (forward/up/right vectors)
updated via Rodrigues' rotation formula each frame — no quaternion or
matrix library needed — projected to screen with a standard pinhole-camera
perspective divide, and depth-sorted with a painter's algorithm before
each polygon is filled. Aircraft are hand-authored low-poly meshes (a
dozen or so flat-shaded triangles each); the ground, mountains, clouds and
scenery reuse the same projection math. All audio (engine drone, gunfire,
explosions) is generated live with the Web Audio API — no audio files.
