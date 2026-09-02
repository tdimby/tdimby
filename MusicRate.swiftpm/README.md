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
      MusicStore.swift             CloudKit-backed data layer
      DisplayNameStore.swift       Local nickname storage
    Views/                  SwiftUI screens (Feed, Add & Rate, Groups, Profile)
```

## Running it

Open `MusicRate.swiftpm` on an iPad in **Swift Playgrounds**, or open the
folder in **Xcode 14+** (File ▸ Open, pick the `.swiftpm` folder) and run it
in the simulator or on a device.

## Required setup: CloudKit

Worldwide and group ratings are stored in CloudKit's **public database** so
every install of the app shares the same data. Swift Playgrounds' app
format doesn't expose an iCloud/CloudKit capability toggle, so you need to
add it once after opening the project in Xcode:

1. Open the project in Xcode.
2. Select the app target ▸ **Signing & Capabilities** ▸ **+ Capability** ▸
   add **iCloud**, then enable the **CloudKit** service and create/select a
   container.
3. Build and run once — this creates the record types
   (`Song`, `Rating`, `RatingGroup`, `GroupMembership`) in the CloudKit
   Dashboard's *development* schema the first time each is saved.
4. In the [CloudKit Dashboard](https://icloud.developer.apple.com/), mark
   these fields **Queryable** (and **Sortable** where noted) so the app's
   queries work:
   - `Rating`: `songID` (queryable), `groupID` (queryable), `userID`
     (queryable), `createdAt` (queryable + sortable)
   - `RatingGroup`: `inviteCode` (queryable)
   - `GroupMembership`: `userID` (queryable)
5. When you're ready to ship, deploy the schema to the *production*
   environment from the dashboard.

Until iCloud is signed in on the device/simulator, the app shows an alert
and ratings can't be posted — everything else (looking up links) still
works.

## Design notes & limitations

- **No custom Share Extension.** Swift Playgrounds app projects can only
  contain a single app target, so Spotify can't "Share ▸ MusicRate"
  directly. Instead, the app watches the clipboard for a Spotify link
  (a common pattern: tap Share ▸ Copy Link in Spotify, switch to MusicRate).
  If you convert this into a full Xcode project, adding a real Share
  Extension target is a natural next step.
- **Identity is a nickname, not a real account.** Reading a user's iCloud
  name requires extra entitlements this project doesn't request, so
  MusicRate asks you to pick a display name instead. Anyone can type any
  name — there's no verification.
- **Groups aren't access-controlled.** Group ratings live in the same
  public database, scoped only by a `groupID` field the app filters on.
  Anyone who knows a group's CloudKit record name could technically query
  its ratings directly. For real privacy, a future version could use
  `CKShare` and a private/shared database per group instead.
- Track/album/playlist metadata comes from Spotify's oEmbed endpoint, which
  is unauthenticated and doesn't require registering a Spotify Developer
  app — but it also only exposes what's needed for an embed preview (title,
  thumbnail), not full track details like duration or genre.

This was written without access to a Mac/Xcode, so it hasn't been compiled
or run — read it over in Xcode and fix up anything that doesn't build
before relying on it.
