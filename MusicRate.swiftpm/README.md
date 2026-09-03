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
- **Private by default.** A new rating is visible only to you unless you
  explicitly pick **Worldwide** or a specific group from the "Rate For"
  picker — Worldwide isn't the default anymore, it's an opt-in choice.
- **Groups**: create a group and share its 6-character invite code, or join
  one with a code someone shares with you — real, cross-device groups.
- **Song of the Week**: inside a group, start a round, everyone submits a
  song, everyone *except the submitter* rates it 1–5 stars, and whoever's
  submission has the best average when the round closes wins — tracked on
  a simple per-group leaderboard. A round auto-closes 7 days after it
  starts (checked whenever a member opens the group — see "How weekly
  rounds close" below for why it works that way instead of a real timer).
- **Profile tab**: your rating history, display name, and account info.

Privacy is enforced by Firestore's **security rules**
(`firestore.rules`), not just by the app defaulting to Private in the
UI — someone hitting the database directly (not through this app) still
can't read another person's private ratings or a group's data without
being a member. Details below.

## Project layout

```
MusicRate.swiftpm/
  Package.swift            App metadata (Swift Playgrounds app format)
  AdditionalInfo.plist     Extra Info.plist content - registers the Google Sign-In URL scheme
  Sources/
    MusicRateApp.swift      App entry point
    Models/
      SpotifyItem.swift (+ MusicSource), Rating.swift (+ RatingAudience), RatingGroup.swift
      WeeklyRound.swift        WeeklyRound, Submission, SubmissionRating, leaderboard entry
    Services/
      FirebaseConfig.swift          Your Firebase project's API key/ID
      FirebaseAuthService.swift     Email/password auth via Firebase's REST API
      GoogleAuthConfig.swift        Your Google OAuth iOS client ID
      GoogleSignInService.swift     Hand-rolled Google OAuth (PKCE) + Firebase IdP exchange
      FirestoreService.swift        Firestore's REST API (get/set/query)
      FirestoreValue.swift          Converts to/from Firestore's typed field format
      AccountStore.swift            Signed-in session + profile
      MusicStore.swift              Ratings/groups/songs, Firestore-backed
      WeeklyPickStore.swift         Weekly round submissions/ratings/leaderboard
      SpotifyLinkParser.swift       Extracts track/album/... IDs from links
      SpotifyMetadataService.swift  Looks up title/artist/art via oEmbed
      AppleMusicSearchService.swift Search + starter list via iTunes Search
    Views/                  SwiftUI screens (Sign In, Feed, Search, Paste Link, Groups, Profile)
  firestore.rules          Security rules - the real enforcement of privacy/groups
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
   `firestore.rules` file included in this project → **Publish**. This is
   what actually enforces privacy/group membership server-side (not just
   the app's UI) — see "How privacy is actually enforced" below for what
   each rule does. I wasn't able to test these against a live Firestore
   project or the Rules Playground, so before trusting them with real
   data: open Firestore → **Rules** → **Rules Playground** in the Firebase
   Console and simulate a few reads/writes (e.g. "can user A read user B's
   private rating?" should be **denied**; "can a group member read that
   group's ratings?" should be **allowed**) to confirm they behave as
   intended, and adjust if not.
5. Firestore's **Indexes** tab → **Create index**, four times, scope
   "Collection" each time:
   - Collection `ratings` — Fields: `songID` Ascending, `groupID`
     Ascending, `createdAt` Descending
   - Collection `ratings` — Fields: `groupID` Ascending, `createdAt`
     Descending
   - Collection `ratings` — Fields: `userID` Ascending, `createdAt`
     Descending
   - Collection `weeklyRounds` — Fields: `groupID` Ascending,
     `weekStartDate` Descending

   (Without these, the app's queries fail with a Firestore
   "FAILED_PRECONDITION: query requires an index" error — Firestore's own
   error normally includes a link that creates the exact index for you,
   which is a faster way to do this than typing them in by hand if you'd
   rather just hit the error once per index and tap the link each time.)
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

## Setup: Google Sign-In (optional)

Google Sign-In only works if you complete this — without it, the button
just doesn't appear (`SignInView` hides it when `GoogleAuthConfig` isn't
configured), and email/password still works fine on its own.

There's no Google/Firebase SDK involved (same reasoning as skipping
Firebase's SDK for everything else): `GoogleSignInService.swift` hand-rolls
an OAuth 2.0 Authorization Code + PKCE flow using `ASWebAuthenticationSession`
(a built-in Apple framework, not a package), then hands the resulting
Google ID token to Firebase's `accounts:signInWithIdp` REST endpoint to get
a normal Firebase session — same as email/password, from that point on.

1. Turning on the "Google" provider under Firebase Authentication (which
   you've already done) auto-creates a **Web client** OAuth credential in
   the same underlying Google Cloud project — that one has a client secret
   and isn't what a native app should use. You need a separate one instead:
2. Go to **console.cloud.google.com**, and make sure you're in the same
   project as your Firebase project (same name/ID — Firebase projects
   *are* Google Cloud projects) — check the project switcher at the top.
3. **APIs & Services → Credentials → + Create Credentials → OAuth client
   ID**.
4. Application type: **iOS**.
5. Bundle ID: `com.example.musicrate` — must match `Package.swift`'s
   `bundleIdentifier` exactly.
6. **Create**. You'll get a Client ID that looks like
   `1234567890-abcdefg.apps.googleusercontent.com`.
7. Open `Sources/Services/GoogleAuthConfig.swift` and paste that whole
   Client ID in as `iOSClientID`.
8. Take that same Client ID and reverse its dot-separated parts — the
   example above becomes `com.googleusercontent.apps.1234567890-abcdefg` —
   then open `AdditionalInfo.plist` (at the project root, next to
   `Package.swift`) and replace the placeholder string inside
   `CFBundleURLSchemes` with that reversed value. This is Google's login
   page's way back into the app after you sign in, so it has to be exact —
   `GoogleAuthConfig.redirectScheme` computes the same value at runtime for
   building the request, but Info.plist can't reference Swift code, so
   these two copies have to be kept in sync by hand.

If you'd rather just send me the Client ID, I can compute the reversed
scheme and fill in both files for you, same as the other credentials.

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

## How privacy is actually enforced

A rating's `groupID` field is one of: `"private"` (default), `"worldwide"`,
or a real group's document ID (see `RatingAudience` in `Rating.swift`).
`firestore.rules` reads that field to decide who can read a given rating
document:

- Always readable by its own author (`resource.data.userID == request.auth.uid`).
- If `groupID == "worldwide"`, readable by anyone signed in.
- Otherwise (a real group ID), readable only if the requester has a
  membership document for that group (`isGroupMember()` in the rules file)
  — `"private"` never matches this branch, so it's never readable by
  anyone but its author.

The same membership check gates group/round/submission reads and writes
throughout the file — e.g. you can't post a rating to a group's `groupID`
you don't belong to, and you can't submit or read weekly-round data for a
group you're not in. `submissionRatings` additionally checks (server-side,
not just in `WeeklyPickStore.rateSubmission`) that you're not the person
who submitted the song you're trying to rate.

This is why the setup section above says to actually test the rules in
the Rules Playground before trusting them — I wrote them carefully but
have no way to run them against a real project from here.

## How weekly rounds close

There's no server in this app — no Cloud Functions, no cron — so a round
can't close itself the instant 7 days pass. Instead, `WeeklyPickStore.load`
checks the elapsed time whenever any member opens the group; if a round is
older than 7 days and still open, that member's device resolves it right
then (tallies each submission's average rating, picks the highest, marks
the round closed) before showing the group screen. In practice this means
a round closes on the next visit after its week is up, not the literal
moment the week ends — a few hours to a few days of drift depending on how
often the group opens the app, not multiple weeks. Any member can also
close a round early with **Close Round & Reveal Winner**.

The leaderboard itself isn't a stored counter (no risk of it drifting out
of sync) — `WeeklyPickStore.loadLeaderboard` recomputes each member's win
count from scratch each time by walking the group's resolved rounds, which
is simpler and always correct at the cost of a few extra reads for groups
with a long history.

## Design notes & limitations

- **Google Sign-In is untested.** Of everything in this app, this is the
  piece I have the least confidence in — a hand-rolled OAuth flow with no
  way to run it end-to-end from here. If it fails, the two likeliest
  causes are the redirect scheme not matching exactly between
  `GoogleAuthConfig.swift` and `AdditionalInfo.plist`, or the Bundle ID on
  the Google Cloud OAuth client not matching `Package.swift`'s
  `bundleIdentifier` character-for-character.
- **No custom Share Extension.** Swift Playgrounds app projects can only
  contain a single app target, so Spotify can't "Share ▸ MusicRate"
  directly. Instead, the app watches the clipboard for a Spotify link.
- **One round of weekly picks at a time per group** — there's no history
  view for past rounds beyond the leaderboard's win tally; the songs
  themselves from resolved rounds aren't shown anywhere after the fact.
- **Submitting to a round is Paste Link only** (not Search) — reuses
  `SpotifyLinkParser`/`SpotifyMetadataService` directly; adding a search
  option there would just mean swapping in `AppleMusicSearchService` the
  same way the Search tab already does.
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
