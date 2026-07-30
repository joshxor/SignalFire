local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local chat = assert(SignalFireChatRuntime151, "Phase 12 chat owner did not load")
local M = assert(SignalFireMarketplace151, "Marketplace core did not load")
local N = assert(SignalFireMarketplaceNetwork2A, "Marketplace network owner did not load")
local U = assert(SignalFireMarketplaceUI151, "Marketplace UI owner did not load")
local function check(value, message) if not value then error(message, 2) end end

BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
local modules = BronzeLFG_DB.options.modulesByProfile.Ascension

-- Disabled baseline: public chat neither parses nor retains display filters,
-- and Marketplace retains neither a handler nor active UI scripts.
BronzeLFG_DB.options.publicGroups = false
BronzeLFG_DB.options.inlineChatLinks = false
modules.tradeskillMarketplace = false
check(B:SFModulesApply(), "disabled module reconciliation failed")
chat.ClearRuntimeCaches()
B:SF151_ResetChatRuntimeStats()
check(chat.IngestSource("Baseline", "LFM MC need healer", "3. Newcomers", "CHAT_MSG_CHANNEL") == nil,
  "disabled parsing accepted a chat record")
local disabled = B:SF151_GetChatPublicIndexDiagnostics().counters
check((disabled.TestParseCalls or 0) == 0 and (disabled.queueRecordsCreated or 0) == 0,
  "disabled parsing performed parser work")
check(B:SF151_GetChatFilterState().knownSignalFireRegistrations == 0, "links-off filters remained installed")
check(not B.NetworkPacketHandlers2A.MKT2, "disabled Marketplace retained packet handler")
check(U:ActiveScriptCount() == 0, "disabled Marketplace retained scripts")

-- Repeated ownership transitions must be idempotent. The Marketplace panel is
-- deliberately opened once per cycle so close/disable tears down real scripts.
for cycle = 1, 20 do
  modules.tradeskillMarketplace = true
  check(B:SFModulesApply(), "Marketplace enable failed in cycle " .. tostring(cycle))
  check(B.NetworkPacketHandlers2A.MKT2 and B.NetworkPacketHandlers2A.MKT2.owner == N,
    "Marketplace handler missing in cycle " .. tostring(cycle))
  check(B:ShowMarketplace(), "Marketplace open failed in cycle " .. tostring(cycle))
  check(U.panel and U.panel:IsShown(), "Marketplace panel did not become visible")
  U:Hide()
  check(not U.panel:IsShown(), "Marketplace panel did not hide")
  modules.tradeskillMarketplace = false
  check(B:SFModulesApply(), "Marketplace disable failed in cycle " .. tostring(cycle))
  check(not B.NetworkPacketHandlers2A.MKT2, "Marketplace handler leaked in cycle " .. tostring(cycle))
  check(U:ActiveScriptCount() == 0, "Marketplace scripts leaked in cycle " .. tostring(cycle))
  local diagnostic = N:GetDiagnostics()
  check(diagnostic.network == "inactive" and diagnostic.outgoing == 0 and diagnostic.pending == 0
      and diagnostic.dedup == 0 and not diagnostic.handler, "Marketplace runtime retained work in cycle " .. tostring(cycle))
end

print("runtime FPS cleanup harness: PASS")
