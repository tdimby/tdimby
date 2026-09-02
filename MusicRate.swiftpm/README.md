# MusicRate

A SwiftUI app for rating music you find on Spotify — paste in a share link,
rate it, and see how it stacks up worldwide or inside a private group of
friends.

## Features

- **Search the Spotify catalog** for songs, albums, or playlists right in
  the app — no link needed. Opens on a "New Releases" browse list so
  there's always something to look at. (Needs your own free Spotify API
  keys — see "Search setup" below.)
- **Paste a Spotify link** (track, album, or playlist) and MusicRate looks
  up its title, artist/owner, and artwork automatically via Spotify's public
  oEmbed endpoint — no API key or login required.
- **Clipboard detection**: when you switch to MusicRate right after tapping
  "Copy Link" in Spotify's share sheet, the app offers to use that link
  immediately.
- **Rate 1–5 stars** with an optional note.
- **Worldwide ratings**: every rating you post without picking a group is
  visible to (and counted for) everyone using the app.
- **Groups**: create a group and share its 6-character invite code, or join
  one with a code someone shares with you. Ratings posted to a group only
  show up in that group's feed and average.
- **Profile tab**: see your rating history and pick the display name shown
  next to your ratings.

## Project layout

```
MusicRate.swiftpm/
  Package.swift            App metadata (Swift Playgrounds app format)
  Sources/
    MusicRateApp.swift      App entry point
    Models/                 SpotifyItem, Rating, RatingGroup
    Services/
      SpotifyLinkParser.swift      Extracts track/album/... IDs from links
      SpotifyMetadataService.swift Looks up title/artist/art via oEmbed
      SpotifyCredentialsStore.swift Local storage for your Spotify API keys
      SpotifyAuthService.swift     Client Credentials OAuth for the Web API
      SpotifySearchService.swift   Search + New Releases via the Web API
      MusicStore.swift             Local JSON-backed data layer
      DisplayNameStore.swift       Local nickname storage
    Views/                  SwiftUI screens (Feed, Search, Paste Link, Groups, Profile)
```

## Running it

Open `MusicRate.swiftpm` on an iPad in **Swift Playgrounds**, or open the
folder in **Xcode 14+** (File ▸ Open, pick the `.swiftpm` folder) and run it
in the simulator or on a device.

## Search setup: Spotify API keys

The Search tab needs a real Spotify Web API access token, which needs a
registered Spotify app (this is separate from, and in addition to, the
oEmbed lookup the Paste Link tab uses — oEmbed has no search endpoint).

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
   and log in with any Spotify account (free is fine).
2. Create an app. Any name/description works; for the redirect URI, put
   anything like `https://example.com` — MusicRate never opens a login
   screen, so it's never actually used.
3. Open the app's Settings and copy its **Client ID** and **Client Secret**.
4. In MusicRate, go to the **Search** tab ▸ tap the gear icon ▸ paste both
   in ▸ Save.

Under the hood this uses Spotify's **Client Credentials** flow
(`SpotifyAuthService.swift`): it authenticates as the *app*, not as a
person, so it can search the public catalog but can't see anyone's
playlists, library, or account. The Client ID/Secret are stored in
`UserDefaults` on-device for simplicity — fine for personal use, but don't
ship an app built this way to other people without moving that to Keychain
and keeping the secret server-side instead of in the client.

## How data is stored (and why)

Ratings, songs, and groups are all stored as a single JSON file in the app's
Documents folder (see `MusicStore.swift`) — no server, no account, no
special entitlement. That keeps the app runnable straight out of Swift
Playgrounds with zero setup, but it also means "worldwide" really means
*"everyone who's rated something in this app on this device"* — there's no
syncing between installs or devices yet.

This wasn't the original plan — the first version used CloudKit's public
database so ratings really would sync across everyone's installs. That
version got stuck loading and got killed after a few seconds inside Swift
Playgrounds. The likely cause: the app called CloudKit
(`CKContainer.default().userRecordID()`) on launch, and Swift Playgrounds
has no way to grant an app the iCloud/CloudKit capability at all — it's
simply missing from its capability list, unlike Xcode. Without that
entitlement, the CloudKit call seems to hang rather than fail cleanly.

If you want real cross-device/cross-person sharing, the natural next step
is to open this project in Xcode on a Mac (which *can* grant iCloud
capabilities), swap `MusicStore` back to a CloudKit- or server-backed
implementation, and add the iCloud capability under **Signing &
Capabilities**. The rest of the app (all the SwiftUI views) talks to
`MusicStore` through a small async API (`submitRating`, `feed(for:)`,
`createGroup`, `joinGroup`, …) and doesn't know or care how it's persisted,
so that swap shouldn't require touching any view code.

## Design notes & limitations

- **No custom Share Extension.** Swift Playgrounds app projects can only
  contain a single app target, so Spotify can't "Share ▸ MusicRate"
  directly. Instead, the app watches the clipboard for a Spotify link
  (a common pattern: tap Share ▸ Copy Link in Spotify, switch to MusicRate).
  If you convert this into a full Xcode project, adding a real Share
  Extension target is a natural next step.
- **Data is local to this install.** See "How data is stored" above —
  ratings don't currently leave the device they were made on.
- **Identity is a nickname, not a real account.** Anyone can type any name
  in Profile — there's no verification, and a fresh install gets a new
  random local user ID.
- Track/album/playlist metadata comes from Spotify's oEmbed endpoint, which
  is unauthenticated and doesn't require registering a Spotify Developer
  app — but it also only exposes what's needed for an embed preview (title,
  thumbnail), not full track details like duration or genre.

This was written without access to a Mac/Xcode, so it hasn't been compiled
or run — read it over in Xcode and fix up anything that doesn't build
before relying on it.
