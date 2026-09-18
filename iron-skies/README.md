# Iron Skies

A 3D arcade dogfighting game — pick a fighter, take off, and hold the line
against wave after wave of enemy aircraft. Built entirely in one HTML file:
a small hand-rolled 3D engine (perspective projection, painter's-algorithm
depth sorting, flat-shaded aircraft) rendered crisp and smooth at native
display resolution. No build step, no dependencies beyond an optional
Google Font.

Think *War Thunder*'s arcade dogfights, with a phosphor-green military HUD.

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
- Controls have real weight: inputs accelerate the plane's rotation rather
  than snapping it, so turns build up and wind down like an aircraft with
  mass and control-surface lag, not a cursor — tuned to stay responsive
  rather than feel delayed. Bank *and* pull together (a real coordinated
  turn) rather than just pulling straight back — pure pitch with no bank
  barely turns you at all, same as a real aircraft.
- **Roll holds at a max bank instead of spinning you out.** A held roll
  input has no natural stopping point on a real aileron, and at these roll
  rates an ordinary hard turn crosses 90° of bank in about a second — carry
  on past that and you'd flip through inverted, with the turn itself
  reversing out from under you. Roll authority eases off as you approach
  max bank (recovering back toward level always stays fully responsive),
  so holding the stick settles into a steep, controllable turn instead of
  an unintended barrel roll — the bank-and-hold feel of an arcade
  dogfighter rather than a full simulator roll axis.
- **The chase camera shows your real bank angle.** It lags a little on
  quick inputs so a snap-roll doesn't spin the world, but on a sustained
  turn it fully catches up to how banked you actually are — you need to
  see that to judge and hold a proper turn.
- **A lead indicator does the hard part of aiming for you.** Your bullets
  take time to arrive, so shooting straight at a moving target usually
  misses. Get a plane within roughly 40° of your nose and inside ~1100m and
  a bracket locks onto it with its range, plus a separate amber pipper
  showing exactly where to put your reticle to actually hit it — the same
  idea as a real (or War Thunder-arcade) lead-computing gunsight. The lock
  is sticky — once acquired it holds onto the same target through a much
  wider cone instead of dropping the instant your nose wanders off by a
  degree — and turns solid red with a **LOCK** readout once you've held it
  for a moment, so you know exactly when a burst is likely to connect.
  Hit detection tracks each bullet's full path between frames rather than
  just sampling its position, so a fast-moving target can't slip through
  the gap between two frames untouched.
- **An off-screen arrow tracks whoever's closest.** Your view is a
  realistic ~62°, so a hard-turning dogfight routinely pushes the target
  out of frame — without a way to know which way they went, you can't
  keep pulling toward them. An amber (red for aces) arrow sits at the
  edge of the screen pointing at the nearest enemy with their range,
  whenever they're not already visible.
- **Flight is a real (simplified) force model, not a speed dial.** Gravity,
  thrust, drag and lift all act on an actual velocity vector that's
  independent of which way your nose is pointed — the nose is just where
  the control surfaces point you, not where you're guaranteed to go. Lift
  depends on angle of attack and collapses past the stall angle, so **a
  stalled aircraft genuinely falls under gravity even while its nose still
  points up** — that gap between where the nose points and where the plane
  is actually going is the whole sensation of a stall, and it's real
  physics here, not a scripted animation. Bank *and* pull together for a
  proper coordinated turn (banking tilts the lift vector, which is what
  actually curves the flight path); pure pitch with no bank barely turns
  you at all, exactly like a real aircraft.
- **G-force is a real number, not an estimate.** It's read directly off
  the lift your wings are generating (shown live in the HUD), darkens your
  vision at the edges the harder you pull, and risks tearing a wing off if
  you hold extreme G too long — the natural check on a hard pull instead
  of an invisible wall.
- **Component damage, not just a health bar.** Every hit lands on a
  specific part — engine, left wing, right wing, or tail — tracked
  separately from overall hull integrity, shown live in the HUD (E/L/R/T).
  Lose the engine and you're gliding on whatever speed and altitude you
  had left. Lose a wing and the aircraft becomes barely controllable and
  will eventually go down — no coming back from that one. Damaged parts
  can catch fire and burn until they're destroyed (or, rarely, burn out on
  their own), and destroyed wings/tail sections visibly disappear from the
  aircraft.
- **Enemy fighters fly with the same energy limits you do.** They chase and
  intercept using the real force model too, with their own angle-of-attack
  guardrail so a hard pursuit doesn't repeatedly snap their nose past the
  stall angle and bleed off speed and altitude they can't get back — expect
  them to hold a sane cruise and actually close the distance, not clump
  together losing airspeed.
- Guns overheat with sustained fire — watch the heat gauge.
- Waves of enemy fighters escalate in number and skill (grunts, then
  tougher "aces" mixed in), and take the same component damage you do —
  shoot a wing off an enemy and watch it spiral in. Downed aircraft are
  worth more score at higher tiers.
- Stray too far from the combat zone and you'll get a boundary warning;
  ignore it and you'll take damage. Flying into the ground is instantly
  fatal — respect your altitude.
- Three lives, full HUD (speed, altitude, heading, G-meter, radar,
  throttle, boost fuel, hull integrity, gun heat, per-component status).
  High score saved locally via `localStorage` — no account needed.

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
each polygon is filled. All drawing happens in a fixed logical coordinate
space that's then scaled onto the canvas's actual backing resolution
(matched to display size and device pixel ratio, recalculated on resize),
so the scene renders crisp and anti-aliased at native resolution instead
of a low-res image stretched up by the browser. Aircraft are hand-authored
meshes — a tapered fuselage built from cross-section rings rather than a
single flat diamond, plus swept wings, tail and canopy — flat-shaded per
face; the ground, mountains, clouds and scenery reuse the same projection
math. All audio (engine drone, gunfire, explosions) is generated live with
the Web Audio API — no audio files.
