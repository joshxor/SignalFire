# SignalFire 1.5.1

SignalFire 1.5.1 is a reliability and performance update for Ascension / Conquest of Azeroth and Triumvirate.

## Chat and Public Groups

- Improved SignalFire activity links across multiple chat windows and tabs.
- Links now display the recognized activity and required roles instead of a generic label.
- Clicking a SignalFire link opens and highlights the exact Public Groups listing.
- Reduced duplicate parsing, duplicate listings, and repeated alerts.
- Improved recognition for RDF, dungeon shorthand, role-first messages, and Ascension activities.
- Improved filtering for players seeking a guild so those messages do not appear as group or recruitment listings.
- Corrected Public Groups listing ages and timestamps.

## Create Listing

- Added Random Dungeon Finder, Random Heroic Dungeon Finder, and Random Mythic Dungeon Finder options for Ascension.
- Random finder activities no longer display an unnecessary dungeon selector.
- Random finder difficulty is selected automatically for Normal, Heroic, or Mythic+.
- Preserved existing Dungeon, Mythic+, Raid, World Boss, Ascended, and Custom Event listing behavior.

## Network and Profiles

- Corrected custom Ascension class names in Network and Full Roster.
- Improved batching of Network presence responses and visible-panel updates.
- Hidden Network, roster, and listing panels no longer rebuild for every incoming response.
- Preserved separate Ascension and Triumvirate settings and profile-specific module behavior.

## Performance and Stability

- Invasion combat and target listeners now run only on Triumvirate while the Invasions module is enabled.
- Removed recurring UI-tree scans and unnecessary hidden-panel polling.
- Reduced background Event Alert, listing-preview, and maintenance work.
- Consolidated repeated refresh requests and protected hot UI paths from nested rebuilds.
- Bounded chat caches and deferred heavier parsing outside immediate chat rendering.
- Developer chat profiling is disabled during normal play.
- Expanded the parser regression suite to 33 cases.

## Installation

1. Fully exit World of Warcraft.
2. Delete the existing `Interface\AddOns\SignalFire` folder.
3. Extract the new SignalFire folder into `Interface\AddOns`.
4. Confirm the final path is `Interface\AddOns\SignalFire\SignalFire.toc`.
5. Launch the game and use `/sf` to open SignalFire.

Do not overwrite an older SignalFire folder.

## Known Limitation

Some Ascension / CoA clients may still experience intermittent micro-stutter while custom SignalFire links are visible during very busy public chat. SignalFire now caches parsing and hyperlink construction, but part of the remaining cost appears to occur inside Ascension's chat-link rendering path.

Players can reduce the impact by selecting **Main Chat Only** or **Visible Chat Frames**, or by disabling visible SignalFire links while keeping Public Groups parsing enabled.

**SignalFire. Lighting the Path to Adventure.**
