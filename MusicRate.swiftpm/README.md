# MusicRate

A SwiftUI app for rating music you find on Spotify — paste in a share link
or search for it, rate it, and see how it stacks up worldwide or inside a
group of friends. Real accounts, backed by Firebase.

## Features

- **Real accounts.** Sign up with email/password; your ratings and groups
  follow you across devices.
- **Search for songs and albums** right in the app — no link needed. Uses
  Apple's free iTunes Search API (see "Why Search uses Apple's catalog,
  not Spotify's" below for why it isn't Spotify's own search).
- **Paste a Spotify link** (track, album, or playlist) and MusicRate looks
  up its title, artist/owner, and artwork via Spotify's public oEmbed
  endpoint — no API key needed for this part.
- **Clipboard detection**: switch to MusicRate right after "Copy Link" in
  Spotify's share sheet, and the app offers to use that link immediately.
- **Rate 1–5 stars** with an optional note.
- **Worldwide ratings**: every rating you post without picking a group is
  visible to (and counted for) everyone using the app.
- **Groups**: create a group and share its 6-character invite code, or join
  one with a code someone shares with you — real, cross-device groups.
- **Profile tab**: your rating history, display name, and account info.

Two things asked for but not built yet — **private-by-default ratings**
(right now, not posting to a group still means "Worldwide," same as
before) and **weekly group song picks with voting** — are planned as the
next two stages on top of this one; this stage is the account/backend
foundation they both need.

## Project layout

```
MusicRate.swiftpm/
  Package.swift            App metadata (Swift Playgrounds app format)
  Sources/
    MusicRateApp.swift      App entry point
    Models/                 SpotifyItem (+ MusicSource), Rating, RatingGroup
    Services/
      FirebaseConfig.swift          Your Firebase project's API key/ID
      FirebaseAuthService.swift     Email/password auth via Firebase's REST API
      FirestoreService.swift        Firestore's REST API (get/set/query)
      FirestoreValue.swift          Converts to/from Firestore's typed field format
      AccountStore.swift            Signed-in session + profile
      MusicStore.swift              Ratings/groups/songs, Firestore-backed
      SpotifyLinkParser.swift       Extracts track/album/... IDs from links
      SpotifyMetadataService.swift  Looks up title/artist/art via oEmbed
      AppleMusicSearchService.swift Search + starter list via iTunes Search
    Views/                  SwiftUI screens (Sign In, Feed, Search, Paste Link, Groups, Profile)
```

## Setup: connect your Firebase project

Accounts, groups, and ratings all live in Firebase now, so the app needs a
Firebase project before any of that works (Search and Paste Link work
without this — only sign-in/accounts need it).

1. Go to **console.firebase.google.com** → **Add project** → name it
   anything (Google Analytics isn't needed, skip it) → Create.
2. **Build → Authentication** → **Get started** → enable the
   **Email/Password** sign-in provider.
3. **Build → Firestore Database** → **Create database** → start in
   **production mode** → any location.
4. Firestore's **Rules** tab → replace the contents with the
   `firestore.rules` file provided alongside this project → **Publish**.
   (This stage's rules are permissive-but-authenticated — any signed-in
   account can read/write anything. Real per-group/private restrictions
   are added when the privacy stage lands.)
5. Firestore's **Indexes** tab → **Create index**, three times, matching
   these exactly (collection ID `ratings` for all three; scope
   "Collection"):
   - Fields: `songID` Ascending, `groupID` Ascending, `createdAt` Descending
   - Fields: `groupID` Ascending, `createdAt` Descending
   - Fields: `userID` Ascending, `createdAt` Descending

   (Without these, the app's queries fail with a Firestore
   "FAILED_PRECONDITION: query requires an index" error — Firestore's own
   error normally includes a link that creates the exact index for you,
   which is a faster way to do this than typing them in by hand if you'd
   rather just hit the error once and tap the link each time.)
6. Project Settings (gear icon, top of the left sidebar) → **General** tab
   → scroll to "Your apps" → click **`</>`** (the Web icon) to register a
   web app (yes, even though MusicRate is an iOS app — this is just how
   you get a REST-usable API key from Firebase; skip Firebase Hosting when
   asked) → give it any nickname → **Register app**. You'll see a
   `firebaseConfig` object — copy its `apiKey` and `projectId`.
7. Open `Sources/Services/FirebaseConfig.swift` and paste those two values
   in as `apiKey` and `projectID`.

The API key isn't a secret (it just says which project a request is for —
Firestore's **Rules**, not this key, are what actually control access), so
it's fine for it to live in the app's source like this.

## Why Search uses Apple's catalog, not Spotify's

Search originally called Spotify's real Web API (`/v1/search`),
authenticated via a personal Spotify Developer app's Client Credentials —
every request failed with a `400 "Invalid limit"` error that turned out to
be misleading. The real cause: since a November 2024 policy change,
Spotify blocks catalog endpoints (search, browse, etc.) for any app in the
default "Development Mode," which is what every newly created Spotify app
starts in — real access needs Spotify approving the app for **Extended
Quota Mode**, a manual review generally aimed at apps planning public
release, not personal projects. That's a platform restriction, not
something fixable in this app's code.

So Search uses **Apple's iTunes Search API** instead
(`AppleMusicSearchService.swift`) — free, public, keyless, no registered
app or approval process. The tradeoff: search results and their
"Open in ___" links point to Apple Music, not Spotify (tracked via each
item's `source`, see `SpotifyItem.swift`) — though a "Search on Spotify"
link is shown alongside those too, which at least gets you to Spotify's
own search results for that title/artist even without a direct catalog
link. There's also no real "browse/new releases" endpoint without auth, so
the starter list you see on opening Search is a broad canned search rather
than real curated charts.

**Paste Link** is unaffected by any of this — it never needed an API key
(Spotify's oEmbed endpoint is public) and still resolves real Spotify
links directly.

## Design notes & limitations

- **No custom Share Extension.** Swift Playgrounds app projects can only
  contain a single app target, so Spotify can't "Share ▸ MusicRate"
  directly. Instead, the app watches the clipboard for a Spotify link.
- **Not private yet.** Every rating not posted to a group is visible to
  everyone in Worldwide — the "private by default, opt-in to Worldwide"
  model is planned but not built in this stage.
- **No weekly group picks yet** — also planned, not built in this stage.
- The Firebase API key is stored in source (see "Setup" above for why
  that's fine) but note there's currently no Keychain-backed secure
  storage for the session's refresh token either — it's in UserDefaults,
  fine for personal use.
- Track/album/playlist metadata from Paste Link comes from Spotify's
  oEmbed endpoint, which only exposes what's needed for an embed preview
  (title, thumbnail) — not full details like duration or genre.

This was written without access to a Mac/Xcode or a real Firebase project
to test against, so it hasn't been compiled or run — read it over and fix
up anything that doesn't build or doesn't match Firestore's actual REST
API shape before relying on it.
