# MusicRate

A SwiftUI app for rating music you find on Spotify — paste in a share link,
rate it, and see how it stacks up worldwide or inside a private group of
friends.

## Features

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
      MusicStore.swift             Local JSON-backed data layer
      DisplayNameStore.swift       Local nickname storage
    Views/                  SwiftUI screens (Feed, Add & Rate, Groups, Profile)
```

## Running it

Open `MusicRate.swiftpm` on an iPad in **Swift Playgrounds**, or open the
folder in **Xcode 14+** (File ▸ Open, pick the `.swiftpm` folder) and run it
in the simulator or on a device.

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
