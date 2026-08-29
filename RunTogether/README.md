# RunTogether

A React Native (Expo) GPS running app: tracks pace, distance, and route; syncs
finished runs to Strava; and lets you start a run with friends where you see
live, real-time how far ahead or behind each other you are — with a final
results leaderboard when everyone finishes.

## Features

- **GPS run tracking** — live map with route polyline, distance, duration,
  and pace, backed by `expo-location` foreground + background tracking
  (keeps recording with the screen off).
- **Pace & splits** — per-km splits and average pace computed from the
  recorded route (`src/services/pace.ts`, `src/services/geo.ts`).
- **Run history** — runs are saved locally (`AsyncStorage`) and browsable.
- **Strava sync** — OAuth connect from Settings, then "Upload to Strava" on
  any finished run (`src/services/strava.ts`); the route is exported as GPX
  and uploaded via Strava's Uploads API.
- **Group runs** — create a room, share a 5-letter code, friends join, host
  starts the run for everyone. While running, each device streams live
  distance/pace to Firestore; a "Friends' Pace" screen shows, in real time,
  how many meters/seconds ahead or behind each friend you are
  (`src/services/groupRun.ts`, `src/screens/GroupRunLiveScreen.tsx`). When
  everyone finishes, a results leaderboard ranks the group.

## Setup

```bash
cd RunTogether
npm install
cp .env.example .env   # fill in Firebase + Strava credentials
npx expo start
```

You'll need a real device (or dev build) to test GPS and background
location — the iOS Simulator/Android emulator can fake a location but won't
give a realistic run test.

### Firebase

Group runs use Firestore for real-time sync and Firebase Auth (anonymous
sign-in) to identify runners. Create a Firebase project, enable
**Anonymous** auth and **Firestore**, and fill in the `EXPO_PUBLIC_FIREBASE_*`
values in `.env`.

Firestore security rules should restrict `groupRuns/{id}` writes to
authenticated users updating only their own `participants.{uid}` subtree —
see `firestore.rules` for a starting point.

### Strava

Create a Strava API application at
https://www.strava.com/settings/api, set its Authorization Callback Domain
to allow the app's redirect URI (`runtogether://strava-auth`), and fill in
`EXPO_PUBLIC_STRAVA_CLIENT_ID` / `EXPO_PUBLIC_STRAVA_CLIENT_SECRET`.

## Project layout

```
App.tsx                     app entry, providers, navigation root
src/
  types.ts                  RunRecord, GroupRun, Gap, etc.
  firebase.ts                Firebase init
  context/AuthContext.tsx   anonymous auth session
  hooks/useRunRecorder.ts   recording state machine (start/pause/resume/finish)
  services/
    location.ts             expo-location foreground/background tracking
    geo.ts                   haversine distance, GPS-jitter filtering
    pace.ts                  pace/split calculations, formatting
    storage.ts               local run history (AsyncStorage)
    strava.ts                OAuth + GPX upload
    groupRun.ts              Firestore group-run rooms, live gap math
  screens/                  Home, Run, RunSummary, History,
                             GroupRunLobby, GroupRunLive, GroupRunResults,
                             Settings
  navigation/RootNavigator.tsx
```

## Notes / next steps

- Real friend lists (vs. one-off room codes) and push notifications when a
  friend starts a run are natural next additions — the data model
  (`GroupRun.participants`) already supports more metadata per runner.
- The "ahead/behind" estimate in `computeGaps()` converts a distance gap to
  a time gap using your own current pace; for very different paces between
  runners this is an approximation, not an exact time-if-you-both-finished-now.
- This has not been run on a physical device from this environment — verify
  location permissions and background tracking behavior on iOS and Android
  before shipping.
