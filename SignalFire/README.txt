SignalFire 5.7.13-parser-invasion-unified-flow

SignalFire is rebuilt from the stable BronzeLFG 5.7.0-beta1d core, with internal BronzeLFG globals and SavedVariables preserved for compatibility.

This checkpoint keeps the working public group browser, guild browser, chat links, selection behavior, and SignalFire Network presence, while moving visible content rules toward Triumvirate:
- Ascended removed from visible difficulty/focus options.
- Boss Blitz/HCBB focus output replaced with Triumvirate-neutral World Boss/Keys/Hardcore handling.
- Guild focus filters use Raiding, Dungeons, Keys, World Boss, PvP, Leveling, Social, Casual, Hardcore, Roleplay, Events, and Competitive.
- Recruitment creator popup now uses dialog-level layering so its controls stay clickable.
- Triumvirate content recognition includes TBC/WotLK Mythic+ dungeon names and founder world bosses Xiah, Yuna, and Xyo.
- Public group parsing recognizes all TBC and WotLK normal/heroic dungeons.
- Key alert choices show only confirmed Triumvirate Season 1 Mythic+ dungeons: Utgarde Keep, Drak'Tharon Keep, Gundrak, Nexus, Hellfire Ramparts, The Slave Pens, The Botanica, and Mana-Tombs.
- RDF / random dungeon finder / queue language is recognized for Triumvirate leveling groups.
- Recruiter-style RDF posts are classified as Dungeon with Random Dungeon Finder activity instead of generic LFG.
- Applicant-style LFG posts such as "healer lfg rdf" remain LFG rows and now receive clickable Public Groups chat links.
- Casual conversation about queues is filtered so lines like "I'm a healer sitting in queue lol" do not become Public Groups listings.
- Guild Browser can optionally discover active guilds through silent, throttled /who scans. Discovered guilds are shown as /who Discovery and are not treated as recruitment ads.
- /who discovery now enriches existing guild rows instead of creating duplicates, so a SignalFire Network guild can also show /who Seen counts and members.
- SignalFire Network panel now merges your guild's /who-visible members into the online list and sorts actual SignalFire users above /who-only players.
- /who discovery is manual refresh only: it runs from Guild Browser's Refresh SignalFire Network button or /blfg guildwho, never from automatic background scans.
- /who discovery uses SendWho() with hidden Who UI handling, so the default Who window should not open during SignalFire scans.
- Public Groups top controls were tightened so Sort, Hide Types, Search, and SignalFire Network stay inside the panel.
- Guild Browser v2 adds compact source filters, source tags, and detail-panel tabs for Overview, Recruitment, and Seen Players.
- Options now shows the active Triumvirate profile summary and the /who discovery setting.
- Added SignalFireProfile.lua with separate Triumvirate and Ascension content profiles for keys, dungeons, raids, activity aliases, and feature flags.
- Parser/content tables now load from the active profile while keeping Triumvirate as the default behavior.
- Added /sfparse for quick parser checks without waiting for live chat.
- SignalFireCompat no longer globally hooks chat or tooltip rendering, so normal player chat like "/say Bronzebeard" remains untouched.
- Parser parity pass adds stricter Triumvirate handling for RDF, BC/Wrath heroic queues, role-combo recruiter posts, Icecrown group quests, raids, and Season 1 keys.
- Created listings now mirror into Public Groups, can be posted/rebroadcast from My Listing, and can create a local applicant row through Apply Selected when testing your own listing.
- Added Invasions navigation and Phase 1 Invasion Assist for known hubs, with presence pings, nearby solo player rows, manual invite helper, and Convert to Raid.
- Options now includes compact Invasion Assist controls without overlapping the existing alert dropdowns.
- UI hotfix: Invasion Assist now hides when switching tabs, so its title/status/buttons no longer overlay Applicants, Options, My Listing, Guild Browser, Public Groups, or Profile.
- Invasion Assist settings were moved onto the Invasions page to keep the Options footer clear.
- Guild recruitment parser now recognizes "Guild Recruitment + <guild name> recrute ..." and uses the actual guild name instead of the generic word Guild.
- Options Server Profile now shows only the profile selector; the profile summary helper lines were removed to avoid overlap.
- Guild Browser source filters were clarified: All shows all known guilds, Network shows guilds with SignalFire addon users, and Online shows guilds found through hidden /who discovery.
- Guild Browser footer buttons were re-spaced and "Show SignalFire Network" was shortened to "SignalFire Network".
- Clear Listings now clears recruitment/chat and hidden /who discovery guild data while preserving live SignalFire Network presence.
- SignalFire Network panel title, stats, filters, row names, backdrop, and pager were simplified for the Triumvirate /who-enabled workflow.
- Main window title now displays "SignalFire (Beta)" instead of exposing internal checkpoint versions.

Install folder name: SignalFire

SignalFire 1.3.4a - Hidden Guild Browser Refresh Fix
- Surgical performance fix only.
- Replaced Guild Browser background refresh checks from IsShown() to IsVisible().
- Prevents the hidden Guild Browser panel from repainting after it has been opened once and then closed/hidden.
- Keeps Public Groups, chat-link behavior, recruitment parsing, Guild Browser features, and SignalFire Network behavior unchanged.
- Based on the 1.3.3b code state.

