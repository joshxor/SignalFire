local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local LP = assert(SignalFireLazyPanels151, "Phase 7 lazy owner did not load")
assert(LP.generation == "1.5.1-perf-phase7", "unexpected lazy-panel generation")

-- Loading the full TOC must not create the shell or feature pages.
assert(not B.frame, "full addon load constructed the main shell")
for _, key in ipairs(LP.order) do
  assert(not LP.panels[key].built, "full addon load constructed " .. key)
end

-- Profile/scale state can change before any panel exists.
if B.SF143_SetServerProfile then B:SF143_SetServerProfile("Ascension", true) end
BronzeLFG_DB.options.scale = 1.2
assert(not B.frame and not B.create and not B.optionsPanel, "pre-open profile/scale state constructed UI")

-- The login CreateUI owner is now startup-only.
B:CreateUI()
assert(B.mm, "startup owner did not construct the minimap launcher")
assert(not B.frame, "startup owner constructed the main shell")
for _, key in ipairs(LP.order) do
  assert(not LP.panels[key].built, "startup owner constructed " .. key)
end

-- Incoming chat updates the canonical model before Public Groups exists.
local chat = assert(SignalFireChatRuntime151, "chat owner missing")
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
chat.Apply()
chat.IngestSource("LazyTester", "LFM MC 1 HEALER", "3. Newcomers", "CHAT_MSG_CHANNEL")
local _, rendered = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", "LFM MC 1 HEALER", "LazyTester",
  nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
assert(string.find(rendered or "", "Molten Core - Need H", 1, true),
  "first display missed the exact contextual link")
local immediateId = string.match(rendered or "", "bronzelfgpub:([^|]+)")
assert(immediateId and B.publicGroups and B.publicGroups[immediateId],
  "exact resolver did not create canonical data before display")
local queueFrame = assert(B._sfP3Frame, "chat queue frame missing")
local update = assert(queueFrame:GetScript("OnUpdate"), "chat queue owner missing")
local guard = 0
while #(B._sfP3Queue or {}) > 0 do
  update(queueFrame, .07)
  guard = guard + 1
  assert(guard < 100, "chat queue did not drain")
end
_, rendered = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", "LFM MC 1 HEALER", "LazyTester",
  nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
local linkedId = string.match(rendered or "", "bronzelfgpub:([^|]+)")
assert(linkedId == immediateId, "deferred worker changed the canonical link identity")
assert(B.publicGroups and B.publicGroups[linkedId], "canonical chat data disappeared after deferred work")
assert(not B.publicPanel, "chat traffic constructed Public Groups")

-- First main open builds only shell and Browse.
local ok, err = pcall(B.Show, B)
local lastLazyError = LP.errors[#LP.errors]
assert(ok and err ~= false, "first main open failed: " .. tostring(err) .. " / "
  .. tostring(lastLazyError and lastLazyError.scope) .. ":" .. tostring(lastLazyError and lastLazyError.error)
  .. " fields=" .. tostring(B.frame) .. "/" .. tostring(B.side) .. "/" .. tostring(B.content)
  .. " legacy=" .. tostring(B.sf135nLastError))
assert(B.frame and B.browse, "first main open missed shell or Browse")
assert(math.abs((B.frame:GetScale() or 0) - 1.2) < .001, "deferred shell missed the current scale")
for _, key in ipairs({"create","profile","applicants","publicGroups","guildBrowser","myListing","options","network","fullRoster","invasions"}) do
  assert(not LP.panels[key].built, "first main open constructed " .. key)
end

-- Public Groups consumes the existing canonical data on first open.
local opened, result = pcall(B.ShowPublicGroups, B)
assert(opened and result ~= false, "Public Groups first open failed: " .. tostring(result))
assert(B.publicPanel and LP.panels.publicGroups.buildCount == 1, "Public Groups was not built once")
local index = B:SF151_GetChatPublicIndexDiagnostics()
assert((index.indexEntries or 0) > 0, "canonical index lost active entries")
assert((index.counters.indexRowsScanned or 0) == 0, "lazy construction caused a canonical full-row scan")

local d = B:SF151_GetLazyPanelDiagnostics()
assert(d.shellBuildCount == 1, "main shell build count changed")
assert(d.panels.browse.buildCount == 1 and d.panels.publicGroups.buildCount == 1, "first-use panel counts are incorrect")
assert(d.panelsBuiltBeforeFirstOpen == 0, "a feature panel built before first open")

print("lazy full runtime harness: PASS (shell=" .. tostring(d.shellBuildCount)
  .. ", browse=" .. tostring(d.panels.browse.buildCount)
  .. ", public=" .. tostring(d.panels.publicGroups.buildCount)
  .. ", index=" .. tostring(index.indexEntries) .. ")")
