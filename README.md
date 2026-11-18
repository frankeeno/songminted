# Song Minted AI — iOS App (SwiftUI)

Starter Xcode project for **Song Minted AI**. It reproduces the prototype's screens
natively in SwiftUI (onboarding, paywall, Studio, Cover, Tools, Explore, Vault,
generating, and player) with a provider-agnostic service layer ready to connect
to your backend.

---

## Open it in Xcode

You need **Xcode 15 or newer** on a Mac. Pick whichever option is easier for you.

### Option A — Let Xcode create the project (no tools to install)

1. Open **Xcode** → **File ▸ New ▸ Project…**
2. Choose **iOS ▸ App**, then **Next**.
3. Product Name: **SongMintedAI**  ·  Interface: **SwiftUI**  ·  Language: **Swift**.
   Uncheck "Use Core Data" and "Include Tests". Click **Next** and save it anywhere.
4. In the new project, **delete** the two files Xcode generated:
   `SongMintedAIApp.swift` and `ContentView.swift` (Move to Trash).
5. In Finder, open this folder's **`SongMintedAI/`** subfolder and **drag all the
   `.swift` files** into the Xcode project's yellow **SongMintedAI** group.
   In the dialog, tick **"Copy items if needed"** and **"Create groups"**.
6. Press **▶ Run**. The app boots to onboarding.

### Option B — Generate the project automatically (XcodeGen)

If you have Homebrew, paste this block into Terminal exactly as-is (no comments,
full path — spaces are handled by the quotes):

```bash
brew install xcodegen
cd "/Users/franciscapone/Desktop/Ai Music App/Ai music app/SongMintedAI"
xcodegen generate
open SongMintedAI.xcodeproj
```

Then in Xcode pick a simulator (e.g. **iPhone 16**) at the top and press **▶ Run**.

> If Terminal shows `Spec not found`, the `cd` line didn't land — run that line
> on its own first and confirm there's no error before running `xcodegen generate`.

---

## What's inside `SongMintedAI/`

| File | Purpose |
|------|---------|
| `SongMintedAIApp.swift` | App entry point, root navigation, shared header |
| `Theme.swift` | Brand colors + gradients (Liquid Glass palette) |
| `Models.swift` | `Song`, `FeedItem`, and the `AppState` store (mock mint flow) |
| `SongService.swift` | Provider-agnostic interface + notes for the real backend call |
| `OnboardingView.swift` | 4-slide intro |
| `PaywallView.swift` | Minted Pro subscription screen |
| `MainTabView.swift` | The 5-tab bar |
| `StudioView.swift` | Core "Mint Song" screen |
| `CoverToolsViews.swift` | Cover Studio + Tools |
| `ExploreVaultViews.swift` | Community feed + your library |
| `GeneratingPlayerViews.swift` | Minting animation + player |

---

## App icon

A Song Minted app icon (emerald gem + gold note) is included at
`SongMintedAI/Assets.xcassets/AppIcon.appiconset/`. If you generated the project
*before* the icon was added, just re-run `xcodegen generate` (or, if you created the
project manually, drag `Assets.xcassets` into the project) and rebuild — the icon
will then show on the simulator/home screen.

## Layout

- `SongMintedAI/` — iOS SwiftUI app (Xcode).
- `web/` — browser client (same Liquid Glass UI). Talks to Supabase with the **anon** key only.

This GitHub repo is the source of truth. Pull on the Mac after changes.

## Current status (18 Nov 2026)

**iOS (`Config.swift`):** `useRealBackend`, `stemsEnabled`, `cinematicVideoEnabled` are all true. Mint goes through Supabase. Paywall is still not Stripe/RevenueCat.

**Web (`web/`):** mint, lyrics, credits, extend, stems, download, publish are wired. Paywall is local Pro only (no Stripe). `/video` is not deployed, so cinematic video is blocked on web.

**Android:** not in this repo yet.

## vs Suno, Udio, Mozart AI

We match the *song factory* loop they all share: prompt → two takes → lyrics → cover from audio → extend → stems → publish.

Shipped this pass:
- Take A / Take B after a mint (Suno)
- Extend from the playhead (Udio)
- Vibe iterate on the player (Mozart chat edits, still a full remint, 1 credit)
- Lyrics on the player, share link

We are **not** them yet:
- No section inpaint / replace-bar (Udio)
- No DAW, MIDI, VST, or 6-stem mixer (Mozart Studio)
- No custom voice personas / trained models
- No licensed commercial rights story, no Stripe
- Cinematic video endpoint not deployed
- No Android app

Audio quality is the EvoLink/Suno-class model behind `/mint`. UI cannot fake a better model.

> Security: service-role and Suno/EvoLink keys stay on the backend, never in the app or `web/`.
