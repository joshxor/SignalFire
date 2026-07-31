local root, loader = assert(arg[1]), assert(arg[2]); dofile(loader)
local B = assert(BronzeLFG)
local sent, ids = {}, {Ascension=4, Newcomers=7, Global=3}
function GetChannelName(name) return ids[name] or 0 end
function GetChannelList() return 3, "Global", 4, "Ascension", 7, "Newcomers", 9, "BLFG" end
function SendChatMessage(text, kind, _, id) table.insert(sent, {text=text, kind=kind, id=id}) end
BronzeLFG_DB.options.serverProfile = "Ascension"
local available = B:SFDiscoverPublicChannels(); assert(#available == 3 and available[3] == "Newcomers")
B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers", "ascension", "BLFG"}); assert(#B:SFGetPublicBroadcastChannels() == 2)
B.myListing = {activity="Molten Core", tankCount=1, healerCount=1, supportCount=1, dpsCount=2, minLevel=30, maxLevel=40}
assert(B:PostMyListingToChat() and #sent == 2 and sent[1].text == sent[2].text and sent[1].id == 4 and sent[2].id == 7)
assert(B:SFRolePhrase({tankCount=1,dpsCount=2}) == "Need 1 Tank and 2 DPS")
assert(B:SFRolePhrase({tankCount=1,healerCount=1,supportCount=1,dpsCount=2}) == "Need 1 Tank, 1 Healer, 1 Support, and 2 DPS")
assert(B:SFLevelRange(B.myListing) == "Levels 30-40")
assert(B:SFExpandRecruitmentTemplate("{level}/{minLevel}/{maxLevel}/{levelRange}", B.myListing):find("nil", 1, true) == nil)
BronzeLFG_DB.options.serverProfile = "Triumvirate"; B:SFSetPublicBroadcastChannels({"Global"}); BronzeLFG_DB.options.serverProfile = "Ascension"; assert(#B:SFGetPublicBroadcastChannels() == 2)
print("listing broadcast UX harness: PASS")
