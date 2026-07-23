local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
local mode = tostring(arg and arg[3] or "resolution")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
assert(type(B.SFResolveListingPostDestination) == "function", "listing destination resolver is missing")

local sent = {}
local lookedUp = {}
local messages = {}
local channelIds = {}

function GetChannelName(name)
  table.insert(lookedUp, tostring(name or ""))
  return channelIds[tostring(name or "")] or 0
end

function SendChatMessage(text, chatType, language, channelId)
  table.insert(sent, {text=text, chatType=chatType, language=language, channelId=channelId})
end

DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(messages, tostring(text or "")) end
UIErrorsFrame = UIErrorsFrame or {}
UIErrorsFrame.AddMessage = function(_, text) table.insert(messages, tostring(text or "")) end
B.MirrorListingToPublic = function() return {id="listing-test"} end
B.ListingRecruitmentText = function() return "LFM Molten Core - Need H" end
B.PublicChatLink = function() return "[Molten Core - Need H]" end

local function reset()
  sent, lookedUp, messages, channelIds = {}, {}, {}, {}
end

local function saw_lookup(name)
  for _, value in ipairs(lookedUp) do if value == name then return true end end
  return false
end

local function saw_message(text)
  for _, value in ipairs(messages) do
    if string.find(value, text, 1, true) then return true end
  end
  return false
end

local function set_profile(profile)
  BronzeLFG_DB.options.serverProfile = profile
end

if mode == "ascension" then
  set_profile("Ascension")
  channelIds.Ascension = 4
  B.myListing = {id="ascension-default", activity="Molten Core"}
  B:PostMyListingToChat()
  assert(#sent == 1 and sent[1].chatType == "CHANNEL" and sent[1].channelId == 4,
    "Ascension default did not post to the Ascension channel")
  assert(saw_lookup("Ascension") and not saw_lookup("Global"),
    "Ascension default attempted the Triumvirate Global channel")

  reset()
  channelIds.Ascension = 5
  B.myListing = {id="ascension-legacy-global", activity="Molten Core", postChannel=" global "}
  B:PostMyListingToChat()
  assert(#sent == 1 and sent[1].channelId == 5 and saw_lookup("Ascension")
    and not saw_lookup("Global"), "Ascension legacy Global destination was not remapped")
elseif mode == "triumvirate" then
  set_profile("Triumvirate")
  channelIds.Global = 3
  B.myListing = {id="triumvirate-default", activity="Molten Core"}
  B:PostMyListingToChat()
  assert(#sent == 1 and sent[1].chatType == "CHANNEL" and sent[1].channelId == 3,
    "Triumvirate default did not post to Global")
  assert(saw_lookup("Global") and not saw_lookup("Ascension"),
    "Triumvirate default used the wrong profile channel")
else
  set_profile("Ascension")
  channelIds.Newcomers = 7
  B.myListing = {id="selected-newcomers", activity="Molten Core", postChannel="Newcomers"}
  B:PostMyListingToChat()
  assert(#sent == 1 and sent[1].channelId == 7 and saw_lookup("Newcomers"),
    "selected Newcomers destination was not resolved by name")

  reset()
  B.myListing = {id="missing-newcomers", activity="Molten Core", postChannel="Newcomers"}
  B:PostMyListingToChat()
  assert(#sent == 0 and saw_message("Unable to find Newcomers"),
    "missing custom-channel message did not name Newcomers")
  assert(saw_message("[Molten Core - Need H]"), "local fallback lost the listing link")

  reset()
  B.myListing = {id="guild-destination", activity="Molten Core", postChannel="Guild"}
  B:PostMyListingToChat()
  assert(#sent == 1 and sent[1].chatType == "GUILD" and sent[1].channelId == nil,
    "built-in Guild destination was not preserved")
  assert(#lookedUp == 0, "built-in destination incorrectly performed a numbered-channel lookup")
end

print("listing post channel harness " .. mode .. ": PASS")
