# SignalFire Tradeskill Marketplace Specification

## 1. Baseline

Repository: `joshxor/SignalFire`

Branch: `main`

Commit: `7375c4e814a1d056cc608d907c02b1bc9117064e`

Version: SignalFire 1.5.3 stable

Working tree at planning time: clean

Phase 1 must branch directly from this commit.

## 2. Files Inspected

- `SignalFire/SignalFire.toc`
- `SignalFire/SignalFireCore.lua`
- `SignalFire/BronzeLFG.lua`
- `SignalFire/SignalFireRuntime.lua`
- `SignalFire/SignalFireIntegration.lua`
- `SignalFire/SignalFireNetwork.lua`
- `SignalFire/SignalFireListing.lua`
- `SignalFire/SignalFireUI.lua`
- `SignalFire/SignalFireDiagnostics.lua`

The audit was limited to module ownership, lazy construction, indexed listing storage, persistence, hyperlinks, slash routing, and UI styling.

## 3. Architecture To Reuse

Reuse these existing patterns:

- `SFModuleIsEnabled`, `SFModuleSetEnabled`, and `SFModuleUseProfileDefault` for profile-aware module state.
- `SFModulesBuildSideItems`, `SFModulesRefreshOptions`, and `SFModulesApply` for sidebar and Options integration.
- `SignalFireLazyPanels151` for first-open construction, dirty-state tracking, hidden-panel suppression, and build diagnostics.
- Phase 5 canonical indexing for constant-time identity lookup and repairable indexes.
- Phase 6 and Phase 8 snapshot/view caches for generation-based invalidation.
- Visible-row signatures to avoid unnecessary `SetText`, texture, and backdrop writes.
- `SF151_ScheduleDelayed` and `SF151_CancelDelayed` for sleeping one-shot expiration callbacks.
- Existing black dialog background, gold borders, FRIZQT font, compact dropdowns, paged rows, and selected-detail layout.
- Existing final `/sf` dispatch path. Do not install another independent slash wrapper.
- Existing SignalFire hyperlink handling while preserving ordinary Blizzard links.

Do not reuse or alter Public Groups parsing, Phase 12B workers, Phase 12C resolution, ChatFrame filters, or chat-render wrappers.

## 4. New Source Files

### `SignalFireMarketplace.lua`

Owns:

- Persistent schema initialization
- Validation and normalization
- CRUD operations
- Stable IDs
- Canonical indexes
- Favorites
- Expiration
- Enable and Disable lifecycle
- Module reconciliation
- Exact local link generation and lookup
- Status diagnostics

### `SignalFireMarketplaceUI.lua`

Owns:

- Lazy Marketplace panel construction
- Browse
- My Listings
- Create/Edit Listing
- Favorites
- Snapshot and view caching
- Incremental row rendering
- Marketplace-specific controls and dropdowns

Tests should remain outside the addon package under `tests/`.

## 5. TOC Placement

Recommended order:

```text
SignalFireListing.lua
SignalFireUI.lua
SignalFireMarketplace.lua
SignalFireMarketplaceUI.lua
SignalFireDiagnostics.lua
```

Marketplace loads after the final existing UI/lazy-panel owner and before diagnostics.

`SignalFireMarketplaceUI.lua` registers its lazy panel dynamically only while the module is enabled.

Existing TOC ordering must otherwise remain unchanged.

## 6. Module Registration

Module key:

```text
tradeskillMarketplace
```

Display name:

```text
Tradeskill Marketplace
```

Recommended default:

- Ascension: Off
- Triumvirate: Off

The setting belongs in:

```lua
BronzeLFG_DB.options.modulesByProfile[profile].tradeskillMarketplace
```

Add the key to the UI lifecycle module signature so profile/module changes invalidate the appropriate UI state.

When enabled, insert one sidebar entry:

```text
Marketplace
```

Recommended icon:

```text
Interface\Icons\INV_Hammer_20
```

The sidebar item must not exist while disabled.

`SFModulesApply` should call the Marketplace lifecycle reconciler after the setting changes or the server profile changes.

## 7. SavedVariables Schema

Marketplace data is profile-scoped and created only on first enable:

```lua
BronzeLFG_DB.marketplace = {
  schemaVersion = 1,
  profiles = {
    Ascension = {
      nextSequence = 1,
      listingsById = {},
      listingOrder = {},
      favoritesById = {},
      settings = {
        defaultExpirationMinutes = 60,
        lastListingType = "Crafting Offer",
        lastProfession = "",
        lastLocation = "",
        lastAvailability = "Available Now",
      },
    },
    Triumvirate = {
      nextSequence = 1,
      listingsById = {},
      listingOrder = {},
      favoritesById = {},
      settings = {},
    },
  },
}
```

Derived indexes, snapshots, filtered views, row signatures, queues, and panel state must never be persisted.

Schema migration runs only when Marketplace is enabled or explicitly opened. Disabled profiles perform no Marketplace migration work.

Malformed records are repaired or rejected without resetting unrelated `BronzeLFG_DB` data.

## 8. Listing Schema

```lua
{
  schemaVersion = 1,
  id = "mkt1:a:aesri:1784682000:0001",
  profile = "Ascension",
  owner = "Aesri",
  ownerKey = "aesri",
  listingType = "Crafting Offer",
  profession = "Alchemy",
  professionKey = "alchemy",
  itemName = "Flask of Endless Rage",
  itemKey = "flask of endless rage",
  recipeName = "",
  recipeKey = "",
  materialsPolicy = "Customer Provides",
  priceMode = "Tip",
  priceCopper = 0,
  priceText = "Tips appreciated",
  location = "Dalaran",
  locationKey = "dalaran",
  availability = "Available Now",
  notes = "",
  createdAt = 1784682000,
  updatedAt = 1784682000,
  expiresAt = 1784685600,
}
```

Phase 1 listing types:

- `Crafting Offer`
- `Crafting Request`

Materials policy values:

- `Crafter Provides`
- `Customer Provides`
- `Split Materials`
- `Discuss`

Price modes:

- `Fixed Price`
- `Tip`
- `Negotiable`
- `Free`

Availability values:

- `Available Now`
- `Today`
- `This Session`
- `Scheduled`

Free-form locations are permitted. Filtering uses normalized exact location keys populated from active listings.

## 9. Stable Listing ID

Format:

```text
mkt1:<profile-code>:<owner-slug>:<created-epoch>:<sequence>
```

Example:

```text
mkt1:a:aesri:1784682000:0001
```

Properties:

- Profile-scoped
- Stable across edits and reloads
- Deterministic from persisted creation data
- Collision-resistant through a persisted per-profile sequence
- ASCII and hyperlink-safe
- A copied listing receives a new ID
- Editing never changes the ID

Profile codes:

- `a` for Ascension
- `t` for Triumvirate

## 10. Canonical Indexes

Runtime indexes exist only while enabled:

```lua
runtime.byId[id] = listing
runtime.byOwner[ownerKey][id] = true
runtime.byType[listingType][id] = true
runtime.byProfession[professionKey][id] = true
runtime.byItem[itemKey][id] = true
runtime.byLocation[locationKey][id] = true
runtime.byAvailability[availability][id] = true
runtime.expiration[id] = expiresAt
```

The persisted `listingsById` table remains authoritative.

Indexes are rebuilt once during Enable and updated incrementally during create, edit, remove, and expiration. UI actions must not scan all listings to locate an ID.

A generation counter invalidates one canonical snapshot and a bounded view cache.

Recommended view-cache maximum: 16 entries.

TTL: current data generation.

Eviction: oldest cached signature.

Persistence: session-only.

Cleanup: mutation, profile switch, or Disable.

## 11. Favorites

Store listing favorites by stable ID:

```lua
favoritesById[id] = {
  addedAt = 1784682050,
  owner = "Aesri",
  profession = "Alchemy",
  itemName = "Flask of Endless Rage",
  listingType = "Crafting Offer",
}
```

The summary allows the Favorites panel to identify an expired or removed listing without retaining the full listing object.

Recommended behavior:

- Active favorites open the exact listing.
- Expired or removed favorites display as unavailable.
- Unavailable favorites may be removed manually.
- Stale favorite summaries expire after seven days.
- Favorites remain persisted while the module is disabled.

## 12. Expiration

Recommended selectable durations:

- 30 minutes
- 1 hour
- 2 hours
- 4 hours
- 8 hours
- 24 hours

Default: 1 hour.

Expiration checks occur:

- During Enable
- When Marketplace opens
- After create, edit, or remove
- Through one sleeping callback for the nearest active expiration while the module is enabled

No Marketplace `OnUpdate` is permitted.

The expiration callback removes every record whose `expiresAt <= time()`, updates indexes once, increments the generation once, and refreshes only a visible Marketplace panel.

Disable cancels the callback immediately.

## 13. Enable Lifecycle

`Enable(profile)` must:

1. Confirm the module setting is enabled for the active profile.
2. Initialize or migrate that profile's persisted schema.
3. Create the session runtime namespace.
4. Rebuild canonical indexes once.
5. Remove expired persisted records.
6. Register the Marketplace lazy-panel descriptor.
7. Add the Marketplace sidebar item if the shell exists.
8. Register exact Marketplace link lookup with the existing SignalFire link router.
9. Schedule only the nearest required expiration callback.
10. Mark the Marketplace panel dirty without constructing it.

Enable must not register chat filters, parser listeners, protocol handlers, alerts, or permanent events.

## 14. Disable Lifecycle

`Disable(reason)` must immediately:

1. Cancel Marketplace delayed callbacks.
2. Hide the Marketplace panel if visible.
3. Remove its sidebar entry.
4. Unregister its lazy-panel descriptor.
5. Unregister exact-link lookup ownership.
6. Clear selected rows and edit state.
7. Clear indexes, snapshots, views, row signatures, queues, and diagnostics counters.
8. Remove Marketplace event scripts and registered events.
9. Remove Marketplace `OnUpdate` scripts if any temporary interaction created one.
10. Return to Browse if Marketplace was open.

Persisted listings, favorites, settings, and sequence counters remain intact.

WoW frames cannot be destroyed. A panel constructed before Disable may remain as an inert hidden allocation, but it must have no scripts, events, timers, queues, refresh ownership, or active caches. Re-enable should reuse that frame rather than leak another frame.

## 15. Lazy UI Lifecycle

The Marketplace panel must not be constructed:

- At login
- During `CreateUI`
- During profile application
- During Options construction
- During background data maintenance
- While the module is disabled

Construction occurs only when the enabled Marketplace sidebar item or `/sf marketplace` is opened.

Add focused dynamic APIs to `SignalFireLazyPanels151`:

```text
RegisterPanel
UnregisterPanel
Open
MarkDirty
```

The descriptor must include builder, show, refresh, readiness, visibility, and shell requirements.

Refresh requests before first construction become one dirty flag. Hidden panels do not render.

## 16. UI Layout

The Marketplace uses the existing 820x520 content area.

Top navigation:

- Browse
- My Listings
- Create Listing
- Favorites

Browse toolbar:

- Listing type
- Profession
- Item or recipe search
- Location
- Availability
- Favorites-only toggle
- Clear filters

Browse table:

- Player
- Type
- Profession
- Item / Recipe
- Location
- Availability
- Price / Tip
- Expires

Use eight visible rows with paging and row-signature rendering.

Selected-listing detail area:

- Full item or recipe
- Profession
- Materials policy
- Price or tip
- Availability
- Location
- Notes
- Whisper
- Favorite/unfavorite
- Generate Link

My Listings actions:

- Edit
- Remove
- Generate Link
- Reopen expired listing as a new listing

Create/Edit fields:

- Crafting Offer or Crafting Request
- Profession
- Item
- Optional recipe
- Materials policy
- Price mode
- Gold/silver/copper or price text
- Location
- Availability
- Expiration
- Notes
- Posting preview
- Create or Save Changes

All controls must match SignalFire's black backgrounds, gold borders, compact spacing, existing fonts, and current scale behavior.

## 17. Exact Local Links

Proposed hyperlink type:

```text
signalfiremkt:<stable-id>
```

Rendered example:

```text
[Alchemy: Flask of Endless Rage]
```

Phase 1 links resolve only when the exact listing exists in the local profile's SavedVariables.

Phase 1 must not imply that another player can resolve the link. Posting externally should remain unavailable until the later exact-posted-link milestone defines a portable payload or synchronized lookup.

Native Blizzard item, spell, quest, player, and achievement hyperlinks must continue delegating unchanged.

Do not add a second independent `SetItemRef` wrapper. Add a Marketplace handler to the final SignalFire link dispatcher, with the handler registered only while Marketplace is enabled.

## 18. `/sf marketplace status`

The command must work whether the module is enabled or disabled.

Output:

```text
SignalFire> marketplace owner=<generation>, profile=<profile>, enabled=<true|false>
SignalFire> schema=<version>, persisted=<count>, favorites=<count>, nextSequence=<n>
SignalFire> runtime=<active|inactive>, panel=<unbuilt|hidden|visible>, generation=<n>
SignalFire> indexes=<count>, views=<count>/<maximum>, selected=<id|none>
SignalFire> events=<n>, filters=<n>, timers=<n>, onUpdate=<n>, queues=<n>
SignalFire> expiredRemoved=<n>, indexRepairs=<n>, errors=<n>, disabledClean=<true|false>
```

When disabled, the required runtime values are:

```text
runtime=inactive
events=0
filters=0
timers=0
onUpdate=0
queues=0
indexes=0
views=0
disabledClean=true
```

The status command may count persisted records on demand. It must not initialize runtime state or construct UI.

## 19. Phase 1 Implementation Sequence

1. Create a dedicated feature branch from the approved baseline.
2. Add schema and validation harnesses before runtime integration.
3. Add the Marketplace module key with profile defaults Off.
4. Add core lifecycle, profile-scoped persistence, and stable IDs.
5. Implement canonical indexes and CRUD operations.
6. Add expiration and favorite ownership.
7. Add dynamic lazy-panel registration and disabled cleanup.
8. Build Browse with snapshot/view caching and incremental rows.
9. Build My Listings and Favorites.
10. Build Create/Edit with validation and preview signatures.
11. Add Whisper and local exact-link generation.
12. Add status diagnostics.
13. Add sidebar and Options module controls.
14. Run Marketplace-specific tests.
15. Run every existing SignalFire regression suite.
16. Build an RC package for in-game validation.
17. Stop for user approval before beginning network or chat work.

## 20. Later Roadmap

### Network Synchronization

Add a versioned Marketplace protocol under the existing `BLFG312` transport.

Requirements:

- Module-enabled sender and receiver only
- Strict packet type and length validation
- Bounded deduplication
- Stable IDs
- Incremental upsert/remove operations
- No full-dataset broadcast
- Immediate shutdown when disabled

### Exact Posted Links

Define a compact portable link payload or synchronized ID lookup so recipients can resolve a listing they do not already store locally.

Requirements:

- Exact identity
- Payload size limits
- Safe escaping
- Expiration validation
- No generic placeholder links
- Native hyperlink delegation
- No duplicate parser work

### Optional Chat Parsing

Only after network and posted-link behavior are stable.

Requirements:

- Disabled by default
- One source-level candidate gate
- One budgeted parser worker
- No parser per ChatFrame
- No mutation inside ChatFrame filters
- No filters when Marketplace parsing and links are disabled
- No changes to group or guild parser ownership

## 21. Risks

### FPS

The primary risk is accidentally connecting Marketplace to chat, global refresh, or idle timer paths. Phase 1 must remain local and event-driven.

### Migration

Malformed or partially written profile data must be repaired without resetting `BronzeLFG_DB`.

### Hyperlinks

Adding another `SetItemRef` wrapper could conflict with SignalFire, Blizzard UI, or ElvUI. Extend the existing final dispatcher instead.

### Lazy UI

Dynamic panel registration must not weaken Phase 7's startup guarantees or construct Marketplace during profile application.

### Module Disable

WoW frames cannot be destroyed. Previously built UI can only become inert and reusable. Tests must verify zero scripts, events, timers, queues, caches, and refresh ownership after disable.

### Merge Conflicts

`SignalFireRuntime.lua`, `SignalFireUI.lua`, and the final hyperlink dispatcher are high-conflict ownership files. Changes should be minimal and isolated behind Marketplace APIs.

### Phase 1 Discoverability

Without network synchronization or incoming parsing, Phase 1 Browse contains locally stored listings only. This is an architectural foundation, not yet a server-wide marketplace.

## 22. Phase 1 Tests

Required automated tests:

- Lua 5.1 parsing for every changed file
- Current parser regression suite unchanged
- Current chat/FPS regression suites unchanged
- Current lazy-panel regression suite unchanged
- Current timer regression suite unchanged
- Current cache lifecycle suite unchanged
- Module default Off for both profiles
- Profile-specific module settings
- Enable/Disable/Re-enable lifecycle
- Disabled zero-work invariant
- No Marketplace UI before first open
- CRUD and input validation
- Stable ID uniqueness and edit stability
- Index integrity and repair
- Favorite persistence and stale handling
- Expiration and nearest-deadline scheduling
- Snapshot/view invalidation
- Hidden-panel refresh suppression
- Row-signature rendering
- Native Blizzard hyperlink delegation
- Exact local link lookup
- Malformed SavedVariables migration
- Repeated profile switching
- Package TOC and ZIP-root validation

Required in-game tests:

- Ascension and Triumvirate
- Fresh settings and upgraded settings
- Enable from Options
- Disable while Marketplace is open
- Reload while enabled and disabled
- Create, edit, remove, whisper, and favorite
- Expiration while open and hidden
- 90%, 100%, 110%, and 120% scales
- Existing group and guild chat behavior
- Existing Public Groups links
- Blizzard item and player links
- ElvUI compatibility
- Idle and busy-chat FPS comparison with Marketplace disabled

## 23. Decisions Requiring User Approval

1. Module default: recommended Off for both profiles.
2. Data scope: recommended profile-wide listings, with My Listings filtered to the current character.
3. Maximum persisted listings: recommended 200 per profile and 20 per owner.
4. Default expiration: recommended 1 hour, maximum 24 hours.
5. Favorite retention: recommended seven days after the target disappears.
6. Price model: recommended structured copper for fixed prices plus optional display text.
7. Phase 1 links: recommended local-only and not publicly advertised as recipient-resolvable.
8. Disabled constructed frames: approve retaining one inert reusable frame because WoW cannot destroy frames.
9. Sidebar label: recommended `Marketplace`, with the module named `Tradeskill Marketplace`.
10. First public milestone version: decide whether this ships as SignalFire 1.6.0 or a later feature release.
