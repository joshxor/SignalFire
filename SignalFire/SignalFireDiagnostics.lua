-- SignalFire 1.5.2 developer-only runtime diagnostics.
do
  local B = _G.BronzeLFG
  if not B then return end

  local P = _G.SignalFirePerf151 or {}
  _G.SignalFirePerf151 = P
  P.generation = "1.5.1-perf-phase1"
  P.enabled = false
  P.historyMaximum = 32
  P.receiverMaximum = 128
  P.receiverTTL = 30
  P.methodBindings = P.methodBindings or {}
  P.onUpdateBindings = P.onUpdateBindings or {}

  -- Diagnostics caches are session-only and are never stored in BronzeLFG_DB.
  -- P.stats: owner=performance diagnostics; key=category/field; max=fixed fields;
  -- TTL=session; eviction=/sf perf reset or reload; cleanup=explicit reset.
  -- P.history: owner=performance diagnostics; key=ring slot; max=32; TTL=session;
  -- eviction=oldest ring slot; cleanup=record insertion/reset.
  -- P.chatReceivers: owner=chat diagnostics; key=normalized message key; max=128;
  -- TTL=30 seconds; eviction=expired or oldest ring slot; cleanup=message receipt/reset.
  -- P.cacheMaximums: owner=cache diagnostics; key=documented cache path;
  -- max=fixed descriptor count; TTL=session; eviction=reset; cleanup=explicit reset.
  -- P.methodBindings/P.onUpdateBindings: owner=diagnostic installer; key=known
  -- owner name; max=32 each; TTL=session; eviction=replaced owner binding;
  -- cleanup=reload. These are session-only and never persisted.

  local function perf_now()
    if GetTime then return GetTime() end
    if time then return time() end
    return 0
  end

  local function perf_clock_ms()
    if debugprofilestop then return debugprofilestop() end
    return perf_now() * 1000
  end

  local function perf_pack(...)
    return {n=select("#", ...), ...}
  end

  local function perf_count(values)
    if type(values) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
  end

  local function perf_shown(frame)
    if not frame then return false end
    if frame.IsVisible then return frame:IsVisible() and true or false end
    if frame.IsShown then return frame:IsShown() and true or false end
    return false
  end

  local function perf_emit(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""))
    end
  end

  function P:Reset()
    self.stats = {}
    self.history = {}
    self.historyCursor = 0
    self.chatReceivers = {}
    self.receiverSlots = {}
    self.receiverCursor = 0
    self.cacheMaximums = {}
    if B.SF151_ResetChatRuntimeStats then B:SF151_ResetChatRuntimeStats() end
    if B.SF151_ResetRefreshStats then B:SF151_ResetRefreshStats() end
    if B.SF151_ResetTimerStats then B:SF151_ResetTimerStats() end
    if B.SF151_ResetHotPathStats then B:SF151_ResetHotPathStats() end
    if B.SF151_ResetRosterSnapshotStats then B:SF151_ResetRosterSnapshotStats() end
    if B.SF151_ResetPublicGroupsViewStats then B:SF151_ResetPublicGroupsViewStats() end
    if B.SF151_ResetLazyPanelStats then B:SF151_ResetLazyPanelStats() end
    if B.SF151_ResetBrowseViewStats then B:SF151_ResetBrowseViewStats() end
    return true
  end

  function P:Note(category, field, amount)
    if not self.enabled then return nil end
    local stats = self.stats
    if not stats then stats = {}; self.stats = stats end
    local section = stats[category]
    if not section then section = {}; stats[category] = section end
    section[field] = (section[field] or 0) + (amount or 1)
    return section[field]
  end

  function P:Maximum(category, field, value)
    if not self.enabled then return nil end
    local stats = self.stats
    if not stats then stats = {}; self.stats = stats end
    local section = stats[category]
    if not section then section = {}; stats[category] = section end
    value = tonumber(value or 0) or 0
    if value > (tonumber(section[field] or 0) or 0) then section[field] = value end
    return section[field] or 0
  end

  function P:AddHistory(owner, elapsed)
    if not self.enabled then return end
    elapsed = tonumber(elapsed or 0) or 0
    if elapsed < 0.25 then return end
    self.history = self.history or {}
    self.historyCursor = ((tonumber(self.historyCursor or 0) or 0) % self.historyMaximum) + 1
    self.history[self.historyCursor] = {owner=owner, elapsed=elapsed, at=perf_now()}
  end

  function P:RecordCall(owner, elapsed)
    if not self.enabled then return end
    local stats = self.stats
    if not stats then stats = {}; self.stats = stats end
    local calls = stats.calls
    if not calls then calls = {}; stats.calls = calls end
    local row = calls[owner]
    if not row then row = {calls=0, totalMs=0, maxMs=0}; calls[owner] = row end
    elapsed = math.max(0, tonumber(elapsed or 0) or 0)
    row.calls = row.calls + 1
    row.totalMs = row.totalMs + elapsed
    if elapsed > row.maxMs then row.maxMs = elapsed end
    self:AddHistory(owner, elapsed)
  end

  function P:NoteChatReceiver(key, frameName)
    if not self.enabled then return end
    key = tostring(key or "")
    frameName = tostring(frameName or "<unknown>")
    if key == "" then return end
    local now = perf_now()
    self.chatReceivers = self.chatReceivers or {}
    self.receiverSlots = self.receiverSlots or {}
    local entry = self.chatReceivers[key]
    if entry and now - (tonumber(entry.at or 0) or 0) > self.receiverTTL then
      self.chatReceivers[key] = nil
      entry = nil
    end
    if not entry then
      self.receiverCursor = ((tonumber(self.receiverCursor or 0) or 0) % self.receiverMaximum) + 1
      local old = self.receiverSlots[self.receiverCursor]
      if old and self.chatReceivers[old] then self.chatReceivers[old] = nil end
      entry = {at=now, frames={}, count=0}
      self.chatReceivers[key] = entry
      self.receiverSlots[self.receiverCursor] = key
      self:Note("chat", "messagesObserved", 1)
    end
    entry.at = now
    if not entry.frames[frameName] then
      entry.frames[frameName] = true
      entry.count = entry.count + 1
      self:Note("chat", "receivingFrameObservations", 1)
      self:Maximum("chat", "maximumReceivingFrames", entry.count)
    end
  end

  function P:RegisterOnUpdate(owner, frame, visibleFn, idleFn)
    if not frame or not frame.GetScript or not frame.SetScript then return false end
    local current = frame:GetScript("OnUpdate")
    if type(current) ~= "function" then return false end
    local oldBinding = self.onUpdateBindings[owner]
    if oldBinding and oldBinding.frame == frame and oldBinding.wrapper == current then return true end

    local binding = {frame=frame, original=current, visibleFn=visibleFn, idleFn=idleFn}
    local function wrapper(self, elapsed, ...)
      if not P.enabled then return binding.original(self, elapsed, ...) end
      local visible = perf_shown(self)
      if binding.visibleFn then
        local ok, value = pcall(binding.visibleFn, self)
        if ok then visible = value and true or false end
      end
      local idle = not visible
      if binding.idleFn then
        local ok, value = pcall(binding.idleFn, self)
        if ok then idle = value and true or false end
      end
      local started = perf_clock_ms()
      local results = perf_pack(pcall(binding.original, self, elapsed, ...))
      local spent = math.max(0, perf_clock_ms() - started)
      local stats = P.stats
      if not stats then stats = {}; P.stats = stats end
      local all = stats.onUpdate
      if not all then all = {}; stats.onUpdate = all end
      local row = all[owner]
      if not row then
        row = {calls=0, idleCalls=0, visibleCalls=0, hiddenCalls=0, activeDuration=0, totalMs=0, maxMs=0}
        all[owner] = row
      end
      row.calls = row.calls + 1
      if idle then row.idleCalls = row.idleCalls + 1 else row.activeDuration = row.activeDuration + (tonumber(elapsed or 0) or 0) end
      if visible then row.visibleCalls = row.visibleCalls + 1 else row.hiddenCalls = row.hiddenCalls + 1 end
      row.totalMs = row.totalMs + spent
      if spent > row.maxMs then row.maxMs = spent end
      P:AddHistory("OnUpdate." .. owner, spent)
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end
    binding.wrapper = wrapper
    self.onUpdateBindings[owner] = binding
    frame:SetScript("OnUpdate", wrapper)
    return true
  end

  function P:WrapMethod(owner, target, methodName, beforeFn, afterFn)
    if not target or type(target[methodName]) ~= "function" then return false end
    local current = target[methodName]
    local oldBinding = self.methodBindings[owner]
    if oldBinding and oldBinding.wrapper == current then return true end
    local binding = {original=current}
    local function wrapper(self, ...)
      if not P.enabled then return binding.original(self, ...) end
      local beforeValue = nil
      if beforeFn then
        local beforeOK, value = pcall(beforeFn, self, ...)
        if beforeOK then beforeValue = value end
      end
      local started = perf_clock_ms()
      local results = perf_pack(pcall(binding.original, self, ...))
      local spent = math.max(0, perf_clock_ms() - started)
      P:RecordCall(owner, spent)
      if afterFn then pcall(afterFn, self, results, beforeValue) end
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end
    binding.wrapper = wrapper
    self.methodBindings[owner] = binding
    target[methodName] = wrapper
    return true
  end

  local function perf_cache_descriptors()
    local db = _G.BronzeLFG_DB or {}
    local network = db.network or {}
    local shared = db.signalFireNetwork or {}
    local p3 = _G.SignalFireChatRuntime151 or {}
    local roster = _G.SignalFireRosterSnapshot151 or {}
    local publicView = _G.SignalFirePublicGroupsView151 or {}
    local browseView = _G.SignalFireBrowseView151 or {}
    return {
      {"session.publicGroups", B.publicGroups, false},
      {"session.listings", B.listings, false},
      {"session.applicants", B.applicants, false},
      {"session.onlineUsers", B.onlineUsers, false},
      {"session.sfnStatuses", B.sfnStatuses, false},
      {"session.chatGuildListings", B.chatGuildListings, false},
      {"session.guilds", B.guilds, false},
      {"session.guildPosts", B.guildPosts, false},
      {"session.invasionUsers", B.invasionUsers, false},
      {"session.invasionOtherPlayers", B.invasionOtherPlayers, false},
      {"session.invasionBeacons", B.invasionBeacons, false},
      {"session.knownClassNames", B._sf151KnownClassNames, false},
      {"session.chatSeen", B._sfP3Seen, false},
      {"session.chatSeenSlots", B._sfP3SeenSlots, false},
      {"session.chatRecords", B._sfP3Records, false},
      {"session.chatRecordSlots", B._sfP3RecordSlots, false},
      {"session.chatActiveRecords", B._sfP3ActiveRecords, false},
      {"session.chatQueue", B._sfP3Queue, false},
      {"session.chatParseSeen", B._sfChatParseSeen, false},
      {"session.chatParseQueue", B._sfChatParseQueue, false},
      {"session.inlineChatCache", B._inlinePublicChatCache, false},
      {"session.inlineChatSeen", B._inlinePublicChatEventSeen, false},
      {"session.inlineChatSeenSlots", B._sfP3InlineSeenSlots, false},
      {"session.directLinkCache", B._sfDirectLinkCache, false},
      {"session.fastLinkSeen", B._sffclSeen, false},
      {"session.fastLinkFilterCache", B._sffclFilterCache, false},
      {"session.fastLinkDisplayCache", B._sffclDisplayCache, false},
      {"session.publicRefreshQueue", B._publicRefreshQueue, false},
      {"session.notificationSeen", B._notifySeen569, false},
      {"session.publicWhoLastQuery", B.publicPlayerWho and B.publicPlayerWho.lastQuery, false},
      {"session.publicWhoFinalResult", B.publicPlayerWho and B.publicPlayerWho.finalResult, false},
      {"session.alertSeen", B._sf151AlertSeen, false},
      {"session.chatDecisionCache", p3._decisionCache, false},
      {"session.chatDecisionSlots", p3._decisionSlots, false},
      {"session.chatRenderDecisions", p3._renderDecisionCache, false},
      {"session.chatRenderDecisionSlots", p3._renderDecisionSlots, false},
      {"session.chatPendingLinkTargets", p3._pendingByStableId, false},
      {"session.publicCanonicalIndex", p3._publicIndex, false},
      {"session.publicCanonicalIds", p3._publicIndexById, false},
      {"session.publicCanonicalSlots", p3._publicIndexSlots, false},
      {"session.rosterSnapshot", roster.snapshot, false},
      {"session.rosterViews", roster.viewCache, false},
      {"session.rosterClassCache", roster.classCache, false},
      {"session.rosterStatusMap", roster.statusByNameKey, false},
      {"session.rosterUnitMap", roster.unitByNameKey, false},
      {"session.publicDisplaySnapshot", publicView.snapshot and publicView.snapshot.rows, false},
      {"session.publicDisplayViews", publicView.viewCache, false},
      {"session.browseDisplaySnapshot", browseView.snapshot and browseView.snapshot.rows, false},
      {"session.browseDisplayViews", browseView.viewCache, false},
      {"session.seenPublic", B.sfamSeenPublic, false},
      {"session.seenApplicants", B.sfamSeenApplicants, false},
      {"db.chatGuildListings", db.chatGuildListings, true},
      {"db.whoGuilds", db.whoGuilds, true},
      {"db.whoPlayers", db.whoPlayers, true},
      {"db.favorites", db.favorites, true},
      {"db.favoriteGuilds", db.favoriteGuilds, true},
      {"db.parserStats", db.parserStats, true},
      {"db.publicHiddenTypes", db.publicHiddenTypes, true},
      {"db.recruitmentTemplates", db.recruitmentCreator and db.recruitmentCreator.templates, true},
      {"db.suppressedGuilds", db.suppressedGuilds, true},
      {"db.favoriteAlertCooldowns", network.favoriteAlertCooldowns, true},
      {"db.favoriteAlertSeenListings", network.favoriteAlertSeenListings, true},
      {"db.favoriteOnlineSeen", network.favoriteOnlineSeen, true},
      {"db.events", shared.events, true},
      {"db.notices", shared.notices, true},
      {"db.eventAlertSeen", shared.eventAlertSeen, true},
      {"db.eventAlertKnown", shared.eventAlertKnown, true},
      {"db.eventAlertCooldowns", shared.eventAlertCooldowns, true},
      {"db.eventDismissed", shared.eventDismissed, true},
      {"db.noticeSeen", shared.noticeSeen, true},
      {"db.noticeDismissed", network.noticeDismissed, true},
      {"db.networkNoticeSeen", network.noticeSeen, true},
    }
  end

  function P:SnapshotCaches()
    local rows = {}
    self.cacheMaximums = self.cacheMaximums or {}
    for _, item in ipairs(perf_cache_descriptors()) do
      local count = perf_count(item[2])
      if count > (self.cacheMaximums[item[1]] or 0) then self.cacheMaximums[item[1]] = count end
      table.insert(rows, {name=item[1], count=count, maximum=self.cacheMaximums[item[1]], persisted=item[3]})
    end
    return rows
  end

  local function perf_register_known_updates()
    P:RegisterOnUpdate("core.pulse", B._sfPerfCorePulseFrame,
      function() return B.frame and B.frame:IsShown() end,
      function() return not (B.frame and B.frame:IsShown()) and not B.myListing end)
    P:RegisterOnUpdate("network.pulse", B._sfPerfNetworkPulseFrame,
      function() return B.sfnPanel and B.sfnPanel:IsVisible() end)
    P:RegisterOnUpdate("presence.scheduler", B._sfPerfPresencePulseFrame,
      function() return (B.sfnPanel and B.sfnPanel:IsVisible()) or (B.onlinePanel and B.onlinePanel:IsVisible()) end)
    P:RegisterOnUpdate("who.discovery", B.whoDiscoveryFrame,
      function(frame) return frame:IsShown() end)
    P:RegisterOnUpdate("invasion.who", B.invasionWhoFrame,
      function(frame) return frame:IsShown() end)
    local p4 = _G.SignalFireRefresh151
    if p4 then P:RegisterOnUpdate("refresh.scheduler", p4.frame, function() return p4.pending == true end) end
    P:RegisterOnUpdate("chat.queue", B._sfP3Frame, function() return #(B._sfP3Queue or {}) > 0 end)
    local timer = _G.SignalFireTimer151
    if timer then
      P:RegisterOnUpdate("timer.delayed", timer.delayFrame, function() return #(timer.tasks or {}) > 0 end)
      P:RegisterOnUpdate("timer.network-visible", timer.networkFrame,
        function() return (B.sfnPanel and B.sfnPanel:IsVisible()) or (B.onlinePanel and B.onlinePanel:IsVisible()) end)
      P:RegisterOnUpdate("timer.applicant", timer.applicantFrame, function() return B.newApplicantAlert == true end)
      P:RegisterOnUpdate("timer.minimap-drag", timer.dragFrame, function() return B.mm and B.mm.dragging == true end)
    end
    P:RegisterOnUpdate("ui.publicRefresh", B._publicRefreshFrame, function(frame) return frame:IsShown() end)
    P:RegisterOnUpdate("ui.invasionPlayers", B.invasionPlayerPanel, function(frame) return frame:IsShown() end)
    P:RegisterOnUpdate("ui.toast", B.sfamToast, function(frame) return frame:IsShown() end)
  end

  local function perf_wrap_refresh_owners()
    local p4 = _G.SignalFireRefresh151
    if not p4 or not p4.original then return end
    for _, panel in ipairs({"network", "roster", "publicGroups", "guildBrowser", "browse", "applicants", "myListing"}) do
      local owner = "refresh." .. panel
      local old = p4.original[panel]
      if type(old) == "function" and not P.methodBindings[owner] then
        local binding = {original=old}
        local function wrapper(self, ...)
          if not P.enabled then return binding.original(self, ...) end
          local started = perf_clock_ms()
          local results = perf_pack(pcall(binding.original, self, ...))
          P:RecordCall(owner, math.max(0, perf_clock_ms() - started))
          P:Note("network", "actualPanelRebuilds", (panel == "network" or panel == "roster") and 1 or 0)
          if not results[1] then error(results[2], 0) end
          return unpack(results, 2, results.n)
        end
        binding.wrapper = wrapper
        P.methodBindings[owner] = binding
        p4.original[panel] = wrapper
      end
    end
  end

  local function perf_install_methods()
    P:WrapMethod("ui.CreateUI", B, "CreateUI", nil, perf_register_known_updates)
    local buildOwners = {
      {"BuildOptions", "optionsPanel"}, {"BuildCreate", "create"}, {"BuildBrowse", "browse"},
      {"BuildPublicGroups", "publicPanel"}, {"BuildGuildBrowser", "guildPanel"},
      {"BuildSFNetworkPanel", "sfnPanel"}, {"BuildOnlinePanel", "onlinePanel"},
      {"BuildFullRoster", "onlinePanel"}, {"BuildInvasions", "invasionPanel"},
      {"SFE_BuildEventBoard", "sfeEventPanel"},
    }
    for _, item in ipairs(buildOwners) do
      local name, field = item[1], item[2]
      P:WrapMethod("ui." .. name, B, name,
        function(self)
          P:Note("ui", "panelBuilds", 1)
          P:Note("ui", "panelBuildRequests", 1)
          return not self[field]
        end,
        function(self, results, wasMissing)
          if results and results[1] and wasMissing and self[field] then P:Note("ui", "actualPanelBuilds", 1) end
        end)
    end
    for _, name in ipairs({"SF143_ApplyProfileToCreate", "SF143_SetServerProfile", "SFModulesApply"}) do
      P:WrapMethod("ui." .. name, B, name,
        function() P:Note("ui", "profileApplications", 1) end)
    end
    P:WrapMethod("ui.CreateListingPreview", B, "SFAM_UpdateCreatePreview",
      function() P:Note("ui", "createPreviewUpdates", 1) end)
    P:WrapMethod("network.HandlePresence", B, "HandlePresence",
      function() P:Note("network", "presencePackets", 1) end)
    P:WrapMethod("network.GetOnlineUserRows", B, "GetOnlineUserRows", nil,
      function(_, results)
        local rows = results and results[1] and results[2] or nil
        P:Note("network", "rosterRowsScanned", perf_count(rows))
        P:Maximum("network", "maximumRosterRows", perf_count(rows))
      end)
    P:WrapMethod("ui.BuildInvasionPlayerPanel", B, "BuildInvasionPlayerPanel", nil, perf_register_known_updates)
    P:WrapMethod("ui.ShowToast", B, "SFAM_ShowToast", nil, perf_register_known_updates)
    P:WrapMethod("ui.RequestPublicGroupsRefresh", B, "RequestPublicGroupsRefresh", nil, perf_register_known_updates)
    perf_wrap_refresh_owners()
    perf_register_known_updates()
  end

  function P:GetReport()
    local p3 = B._sfP3Stats or {}
    local p4 = _G.SignalFireRefresh151
    local p4stats = p4 and p4.stats or {}
    local p5 = _G.SignalFireTimer151
    return {
      generation=self.generation,
      enabled=self.enabled == true,
      stats=self.stats or {},
      chat=p3,
      refresh=p4stats,
      timer=p5 and p5.stats or {},
      publicGroupsView=B.SF151_GetPublicGroupsViewDiagnostics and B:SF151_GetPublicGroupsViewDiagnostics() or {},
      lazyPanels=B.SF151_GetLazyPanelDiagnostics and B:SF151_GetLazyPanelDiagnostics() or {},
      browseView=B.SF151_GetBrowseViewDiagnostics and B:SF151_GetBrowseViewDiagnostics() or {},
      caches=self:SnapshotCaches(),
    }
  end

  function P:Print()
    local report = self:GetReport()
    local stats = report.stats or {}
    local chat = report.chat or {}
    local refresh = report.refresh or {}
    local chatStats = stats.chat or {}
    local network = stats.network or {}
    local ui = stats.ui or {}
    local calls = stats.calls or {}
    local memory = stats.memory or {}
    local timer = report.timer or {}
    local roster = B.SF151_GetRosterSnapshotDiagnostics and B:SF151_GetRosterSnapshotDiagnostics() or {}
    local publicView = report.publicGroupsView or {}
    local lazy = report.lazyPanels or {}
    local browse = report.browseView or {}
    perf_emit("perf owner " .. tostring(report.generation) .. ", enabled=" .. tostring(report.enabled))
    if self.installError then perf_emit("instrumentation error: " .. tostring(self.installError)) end
    perf_emit("chat: filters=" .. tostring(chat.filterCalls or 0) .. ", wrappers=" .. tostring(chat.wrapperCalls or 0)
      .. ", classified=" .. tostring(chatStats.uniqueMessagesClassified or 0)
      .. ", avoided=" .. tostring(chatStats.duplicateClassificationsAvoided or 0)
      .. ", testParse=" .. tostring(chat.testParseCalls or 0) .. ", queued=" .. tostring(chat.enqueued or 0)
      .. ", processed=" .. tostring(chat.processed or 0) .. ", drops=" .. tostring(chat.queueDrops or 0)
      .. ", maxDepth=" .. tostring(chat.maxDepth or 0) .. ", rowsScanned=" .. tostring(chat.consolidationRowsScanned or 0))
    perf_emit("chat frames: messages=" .. tostring(chatStats.messagesObserved or 0)
      .. ", receipts=" .. tostring(chatStats.receivingFrameObservations or 0)
      .. ", maxPerMessage=" .. tostring(chatStats.maximumReceivingFrames or 0))
    perf_emit("chat decisions: source=" .. tostring(chat.sourceEvents or 0)
      .. ", sourceHits=" .. tostring(chat.sourceDecisionHits or 0)
      .. ", sourceMisses=" .. tostring(chat.sourceDecisionMisses or 0)
      .. ", render=" .. tostring(chat.renderDecisionHits or 0) .. "/" .. tostring(chat.renderDecisionMisses or 0)
      .. ", addMessageParses=" .. tostring(chat.addMessageParseCalls or 0)
      .. ", protocols=" .. tostring(chat.protocolRejected or 0))
    perf_emit("public index: lookup=" .. tostring(chat.indexLookups or 0)
      .. ", hit=" .. tostring(chat.indexHits or 0) .. ", miss=" .. tostring(chat.indexMisses or 0)
      .. ", insert=" .. tostring(chat.indexInserts or 0) .. ", update=" .. tostring(chat.indexUpdates or 0)
      .. ", remove=" .. tostring(chat.indexRemovals or 0) .. ", rebuild=" .. tostring(chat.indexRebuilds or 0)
      .. ", collisions=" .. tostring(chat.indexCollisions or 0)
      .. ", stale=" .. tostring(chat.indexStaleRepairs or 0)
      .. ", fullScans=" .. tostring(chat.indexFullScans or 0)
      .. ", rows=" .. tostring(chat.indexRowsScanned or 0))
    perf_emit("public mutations: dirty=" .. tostring(chat.refreshDirtyRequests or 0)
      .. ", alerts=" .. tostring(chat.alertsEmitted or 0)
      .. ", linksBuilt=" .. tostring(chat.linksBuilt or 0)
      .. ", wrapperDuplicates=" .. tostring(chat.wrapperDuplicateSkips or 0)
      .. ", errors=" .. tostring(chat.processingErrors or 0))
    perf_emit("public view: gen=" .. tostring(publicView.dataGeneration or 0)
      .. ", snapshot=" .. tostring(publicView.snapshotRequests or 0) .. "/" .. tostring(publicView.snapshotsBuilt or 0)
      .. ", snapshotHits=" .. tostring(publicView.snapshotCacheHits or 0)
      .. ", views=" .. tostring(publicView.viewRequests or 0) .. "/" .. tostring(publicView.viewsBuilt or 0)
      .. ", viewHits=" .. tostring(publicView.viewCacheHits or 0)
      .. ", viewSorts=" .. tostring(publicView.viewSorts or 0))
    perf_emit("public renderer: requests=" .. tostring(publicView.visibleRenderRequests or 0)
      .. ", rendered=" .. tostring(publicView.visibleRendersExecuted or 0)
      .. ", hidden=" .. tostring(publicView.hiddenRendersSkipped or 0)
      .. ", considered=" .. tostring(publicView.rowsConsidered or 0)
      .. ", written=" .. tostring(publicView.rowsFullyWritten or 0)
      .. ", signatureHits=" .. tostring(publicView.rowRenderSignatureHits or 0)
      .. ", setText=" .. tostring(publicView.setTextCalls or 0)
      .. ", backdrop=" .. tostring(publicView.backdropWrites or 0)
      .. ", offPage=" .. tostring(publicView.offPageRowsFormatted or 0))
    local snapshotAverage = (publicView.snapshotsBuilt or 0) > 0 and (publicView.snapshotBuildMsTotal or 0) / publicView.snapshotsBuilt or 0
    local viewAverage = (publicView.viewsBuilt or 0) > 0 and (publicView.viewBuildMsTotal or 0) / publicView.viewsBuilt or 0
    local renderAverage = (publicView.visibleRendersExecuted or 0) > 0 and (publicView.rowRenderMsTotal or 0) / publicView.visibleRendersExecuted or 0
    local totalAverage = (publicView.visibleRendersExecuted or 0) > 0 and (publicView.totalRefreshMsTotal or 0) / publicView.visibleRendersExecuted or 0
    perf_emit("public timing: snapshot=" .. string.format("%.3f/%.3fms", snapshotAverage, publicView.snapshotBuildMsMax or 0)
      .. ", view=" .. string.format("%.3f/%.3fms", viewAverage, publicView.viewBuildMsMax or 0)
      .. ", rows=" .. string.format("%.3f/%.3fms", renderAverage, publicView.rowRenderMsMax or 0)
      .. ", total=" .. string.format("%.3f/%.3fms", totalAverage, publicView.totalRefreshMsMax or 0))
    perf_emit("browse view: gen=" .. tostring(browse.dataGeneration or 0)
      .. ", snapshot=" .. tostring(browse.snapshotRequests or 0) .. "/" .. tostring(browse.snapshotsBuilt or 0)
      .. ", snapshotHits=" .. tostring(browse.snapshotCacheHits or 0)
      .. ", views=" .. tostring(browse.viewRequests or 0) .. "/" .. tostring(browse.viewsBuilt or 0)
      .. ", viewHits=" .. tostring(browse.viewCacheHits or 0)
      .. ", sorts=" .. tostring(browse.canonicalSorts or 0) .. "/" .. tostring(browse.viewSorts or 0))
    perf_emit("browse renderer: requests=" .. tostring(browse.refreshWrapperCalls or 0)
      .. ", executed=" .. tostring(browse.authoritativeRefreshes or 0)
      .. ", visible=" .. tostring(browse.visibleRenders or 0)
      .. ", hidden=" .. tostring(browse.hiddenRendersSkipped or 0)
      .. ", considered=" .. tostring(browse.rowsConsidered or 0)
      .. ", written=" .. tostring(browse.rowsMateriallyWritten or 0)
      .. ", signatureHits=" .. tostring(browse.rowSignatureHits or 0)
      .. ", offPage=" .. tostring(browse.offPageRowsFormatted or 0))
    local browseSnapshotAverage = (browse.snapshotsBuilt or 0) > 0 and (browse.snapshotBuildMsTotal or 0) / browse.snapshotsBuilt or 0
    local browseViewAverage = (browse.viewsBuilt or 0) > 0 and (browse.viewBuildMsTotal or 0) / browse.viewsBuilt or 0
    local browseRowsAverage = (browse.visibleRenders or 0) > 0 and (browse.rowRenderMsTotal or 0) / browse.visibleRenders or 0
    local browseDetailAverage = (browse.detailRenders or 0) > 0 and (browse.detailRenderMsTotal or 0) / browse.detailRenders or 0
    local browseTotalAverage = (browse.visibleRenders or 0) > 0 and (browse.totalRefreshMsTotal or 0) / browse.visibleRenders or 0
    perf_emit("browse timing: snapshot=" .. string.format("%.3f/%.3fms", browseSnapshotAverage, browse.snapshotBuildMsMax or 0)
      .. ", view=" .. string.format("%.3f/%.3fms", browseViewAverage, browse.viewBuildMsMax or 0)
      .. ", rows=" .. string.format("%.3f/%.3fms", browseRowsAverage, browse.rowRenderMsMax or 0)
      .. ", detail=" .. string.format("%.3f/%.3fms", browseDetailAverage, browse.detailRenderMsMax or 0)
      .. ", total=" .. string.format("%.3f/%.3fms", browseTotalAverage, browse.totalRefreshMsMax or 0))
    perf_emit("network: presence=" .. tostring(network.presencePackets or refresh.incomingPresence or 0)
      .. ", requests=" .. tostring(refresh.requests or 0) .. ", merged=" .. tostring(refresh.merged or 0)
      .. ", rebuilds=" .. tostring(network.actualPanelRebuilds or 0) .. ", hidden=" .. tostring(refresh.hiddenSkipped or 0)
      .. ", rows=" .. tostring(network.rosterRowsScanned or 0) .. ", statuses=" .. tostring(network.statusesScanned or 0)
      .. ", units=" .. tostring(network.unitTokensScanned or 0) .. ", sorts=" .. tostring(network.sorts or 0))
    perf_emit("roster snapshot: gen=" .. tostring(roster.generation or 0)
      .. ", requests=" .. tostring(roster.canonicalSnapshotRequests or 0)
      .. ", built=" .. tostring(roster.canonicalSnapshotsBuilt or 0)
      .. ", hits=" .. tostring(roster.snapshotCacheHits or 0)
      .. ", statusMaps=" .. tostring(roster.statusMapBuilds or 0)
      .. ", statusChecks=" .. tostring(roster.statusComparisons or 0)
      .. ", unitMaps=" .. tostring(roster.unitMapBuilds or 0)
      .. ", unitTokens=" .. tostring(roster.unitTokensInspected or 0)
      .. ", canonicalSorts=" .. tostring(roster.canonicalSorts or 0))
    perf_emit("roster views: built=" .. tostring(roster.filteredViewsBuilt or 0)
      .. ", hits=" .. tostring(roster.filteredViewCacheHits or 0)
      .. ", scansAvoided=" .. tostring(roster.fullRosterScansAvoided or 0)
      .. ", favoriteChecks=" .. tostring(roster.favoriteTransitionChecks or 0)
      .. ", hoverRefresh=" .. tostring(roster.hoverTriggeredRefreshRequests or 0)
      .. ", hiddenBuilds=" .. tostring(roster.hiddenPanelUIBuilds or 0)
      .. ", networkEvents=" .. tostring(roster.networkEventRefreshes or 0))
    perf_emit("ui: create=" .. tostring(((stats.calls or {})["ui.CreateUI"] or {}).calls or 0)
      .. ", full=" .. tostring(ui.createUIFullExecutions or 0) .. ", fast=" .. tostring(ui.createUIFastPath or 0)
      .. ", builds=" .. tostring(ui.panelBuildRequests or ui.panelBuilds or 0) .. "/" .. tostring(ui.actualPanelBuilds or 0)
      .. ", treeScans=" .. tostring(ui.recursiveTreeScans or 0) .. ", framesVisited=" .. tostring(ui.treeFramesVisited or 0))
    perf_emit("ui lifecycle: dropdowns=" .. tostring(ui.dropdownsRegistered or 0) .. "/" .. tostring(ui.dropdownsPatched or 0)
      .. ", patchSkips=" .. tostring(ui.dropdownPatchSkips or 0)
      .. ", profiles=" .. tostring(ui.profileApplicationsRequested or 0) .. "/" .. tostring(ui.profileApplicationsExecuted or 0)
      .. ", profileSkips=" .. tostring(ui.profileApplicationsSkipped or 0)
      .. ", previews=" .. tostring(ui.previewUpdatesRequested or 0) .. "/" .. tostring(ui.previewUpdatesExecuted or 0)
      .. ", previewSkips=" .. tostring(ui.previewUpdatesSkipped or 0))
    perf_emit("lazy panels: owner=" .. tostring(lazy.generation or "unavailable")
      .. ", shell=" .. tostring(lazy.shellBuilt) .. ", shellBuilds=" .. tostring(lazy.shellBuildCount or 0)
      .. ", prevented=" .. tostring(lazy.backgroundBuildsPrevented or 0)
      .. ", deferred=" .. tostring(lazy.refreshesConvertedToDirty or 0)
      .. ", beforeOpen=" .. tostring(lazy.panelsBuiltBeforeFirstOpen or 0)
      .. ", failures=" .. tostring(lazy.errors and #lazy.errors or 0))
    for _, owner in ipairs({"refresh.network", "refresh.roster", "refresh.publicGroups", "ui.CreateUI"}) do
      local row = calls[owner]
      if row and (row.calls or 0) > 0 then
        perf_emit(owner .. ": calls=" .. tostring(row.calls) .. ", avg="
          .. string.format("%.3fms", row.totalMs / row.calls) .. ", max=" .. string.format("%.3fms", row.maxMs or 0))
      end
    end
    perf_emit("memory: pruned=" .. tostring((memory.entriesPruned or 0) + (timer.cacheEntriesRemoved or 0))
      .. ", cacheSamples=" .. tostring(perf_count(self.cacheMaximums)))
    perf_emit("timers: delayed=" .. tostring(timer.delayedTicks or 0) .. "/" .. tostring(timer.tasksExecuted or 0)
      .. ", network=" .. tostring(timer.networkTicks or 0) .. ", hidden=" .. tostring(timer.networkHiddenTicks or 0)
      .. ", applicant=" .. tostring(timer.applicantTicks or 0) .. ", drag=" .. tostring(timer.dragTicks or 0)
      .. ", dragWrites=0, callbackErrors=" .. tostring(timer.callbackErrors or 0))
    local names = {}
    for name in pairs(stats.onUpdate or {}) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
      local row = stats.onUpdate[name]
      local average = row.calls > 0 and row.totalMs / row.calls or 0
      perf_emit("OnUpdate " .. name .. ": calls=" .. tostring(row.calls) .. ", idle=" .. tostring(row.idleCalls)
        .. ", visible=" .. tostring(row.visibleCalls) .. ", hidden=" .. tostring(row.hiddenCalls)
        .. ", active=" .. string.format("%.2fs", row.activeDuration or 0)
        .. ", avg=" .. string.format("%.3fms", average) .. ", max=" .. string.format("%.3fms", row.maxMs or 0))
    end
    return report
  end

  function B:SF151_HandlePerfSlash(command)
    local cmd = tostring(command or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if cmd == "perf on" then
      P.enabled = true
      P:Reset()
      perf_emit("Performance diagnostics enabled for this session.")
      return true
    elseif cmd == "perf off" then
      P.enabled = false
      perf_emit("Performance diagnostics disabled.")
      return true
    elseif cmd == "perf reset" then
      P:Reset()
      perf_emit("Performance diagnostics reset.")
      return true
    elseif cmd == "perf print" then
      P:Print()
      return true
    elseif cmd == "perf memory" then
      local kb = collectgarbage and collectgarbage("count") or 0
      perf_emit("Lua memory: " .. string.format("%.1f KB", tonumber(kb or 0) or 0) .. " (explicit sample)")
      return true
    elseif cmd == "perf caches" then
      for _, row in ipairs(P:SnapshotCaches()) do
        perf_emit(row.name .. "=" .. tostring(row.count) .. ", max=" .. tostring(row.maximum)
          .. ", persisted=" .. tostring(row.persisted))
      end
      return true
    elseif cmd == "perf" then
      perf_emit("Performance diagnostics are " .. (P.enabled and "enabled" or "disabled") .. ".")
      if P.installError then perf_emit("Instrumentation error: " .. tostring(P.installError)) end
      perf_emit("Commands: /sf perf on, off, reset, print, memory, caches")
      return true
    end
    return false
  end

  function P:InstallSlash()
    if not SlashCmdList then return false end
    local current = SlashCmdList["SIGNALFIRE"]
    if current and current ~= self.slashWrapper then self.oldSignalFireSlash = current end

    if not self.slashWrapper then
      self.slashWrapper = function(input)
        if B:SF151_HandlePerfSlash(input) then return true end
        local old = P.oldSignalFireSlash
        if old and old ~= P.slashWrapper then return old(input) end
        return nil
      end
    end

    SLASH_SIGNALFIRE1 = "/sf"
    SLASH_SIGNALFIRE2 = "/signalfire"
    SLASH_SIGNALFIRE3 = "/sfo"
    SlashCmdList["SIGNALFIRE"] = self.slashWrapper

    SLASH_SIGNALFIREPERF1 = "/sfperf"
    SlashCmdList["SIGNALFIREPERF"] = function(input)
      local suffix = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
      return B:SF151_HandlePerfSlash(suffix == "" and "perf" or ("perf " .. suffix))
    end

    if ChatFrame_ImportListToHash then
      pcall(ChatFrame_ImportListToHash, "SIGNALFIRE")
      pcall(ChatFrame_ImportListToHash, "SIGNALFIREPERF")
    end
    if hash_SlashCmdList then
      hash_SlashCmdList["/sf"] = self.slashWrapper
      hash_SlashCmdList["/SF"] = self.slashWrapper
      hash_SlashCmdList["/signalfire"] = self.slashWrapper
      hash_SlashCmdList["/SIGNALFIRE"] = self.slashWrapper
      hash_SlashCmdList["/sfo"] = self.slashWrapper
      hash_SlashCmdList["/SFO"] = self.slashWrapper
      hash_SlashCmdList["/sfperf"] = SlashCmdList["SIGNALFIREPERF"]
      hash_SlashCmdList["/SFPERF"] = SlashCmdList["SIGNALFIREPERF"]
    end
    if hash_SecureCmdList then
      hash_SecureCmdList["/sf"] = self.slashWrapper
      hash_SecureCmdList["/SF"] = self.slashWrapper
      hash_SecureCmdList["/signalfire"] = self.slashWrapper
      hash_SecureCmdList["/SIGNALFIRE"] = self.slashWrapper
      hash_SecureCmdList["/sfo"] = self.slashWrapper
      hash_SecureCmdList["/SFO"] = self.slashWrapper
      hash_SecureCmdList["/sfperf"] = SlashCmdList["SIGNALFIREPERF"]
      hash_SecureCmdList["/SFPERF"] = SlashCmdList["SIGNALFIREPERF"]
    end
    return true
  end

  function B:SF151_GetPerformanceDiagnostics()
    return P:GetReport()
  end

  function B:SF151_PerfEnabled()
    return P.enabled == true
  end

  P.stats = P.stats or {}
  P.history = P.history or {}
  P.chatReceivers = P.chatReceivers or {}
  P.receiverSlots = P.receiverSlots or {}
  P.cacheMaximums = P.cacheMaximums or {}

  local slashOK, slashError = pcall(function() P:InstallSlash() end)
  if not slashOK then P.slashInstallError = tostring(slashError) end

  local eventFrame = CreateFrame("Frame")
  P.eventFrame = eventFrame
  eventFrame:RegisterEvent("PLAYER_LOGIN")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", function()
    local ok, err = pcall(perf_install_methods)
    if ok then
      P.installError = nil
    else
      P.installError = tostring(err)
      perf_emit("Performance instrumentation could not attach: " .. tostring(err))
    end
    local slashAttached, slashErr = pcall(function() P:InstallSlash() end)
    if not slashAttached then P.slashInstallError = tostring(slashErr) end
  end)
end

-- Phase 9 general cache and memory lifecycle ownership.
-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_BEGIN
do
  local B = _G.BronzeLFG
  local P = _G.SignalFirePerf151
  if B and P and CreateFrame then
    local CL = _G.SignalFireCacheLifecycle151 or {}
    _G.SignalFireCacheLifecycle151 = CL
    CL.generation = "1.5.2-phase12a"
    CL.minimumAutomaticInterval = 30
    CL.maximumErrors = 12
    -- Diagnostics owner: Phase 9. Counter/peak keys are the fixed fields
    -- emitted by this block (maximum 48/35); values are numbers or one cache
    -- name. Error history is FIFO-capped at 12. All are session-only and are
    -- cleared by /sf perf reset or reload. No diagnostic table is persisted.
    CL.stats = CL.stats or {}
    CL.peaks = CL.peaks or {}
    CL.errors = CL.errors or {}
    CL.chatEvents = tonumber(CL.chatEvents or 0) or 0
    CL.running = false

    -- Phase 9 owns cleanup only for the mutable stores listed below. Snapshot,
    -- view, queue, index, timer, lazy-panel, wrapper, selection, search, and
    -- filter state remain bounded by their original Phase 2-8 owners.
    -- All Phase 9 session caches are cleared on reload and are never persisted.
    CL.maximums = {
      publicGroups=512, listings=256, applicants=128, chatGuildListings=256,
      guilds=256, guildPosts=256, onlineUsers=512, sfnStatuses=512,
      knownClassNames=256,
      notificationSeen=256, seenPublic=512, seenApplicants=128,
      invasionUsers=256, invasionOtherPlayers=256, invasionBeacons=256,
      whoGuilds=256, whoPlayers=1024, whoMembers=128, publicWho=128,
      favoriteAlertState=256,
    }
    CL.ttls = {
      listings=900, applicants=7200, chatGuildListings=21600,
      guilds=1209600, guildPosts=21600, onlineUsers=300, sfnStatuses=300,
      notificationSeen=120, publicWho=120, favoriteAlertCooldowns=7200,
      favoriteAlertSeenListings=7200, favoriteOnlineSeen=3600,
    }

    local function cl_now()
      return (time and time()) or 0
    end

    local function cl_clock()
      if debugprofilestop then return debugprofilestop() end
      return ((GetTime and GetTime()) or 0) * 1000
    end

    local function cl_automatic_now()
      return (GetTime and GetTime()) or cl_now()
    end

    local function cl_enabled()
      return P.enabled == true
    end

    local function cl_note(field, amount)
      if not cl_enabled() then return end
      CL.stats[field] = (tonumber(CL.stats[field] or 0) or 0) + (amount or 1)
    end

    local function cl_max(field, value)
      if not cl_enabled() then return end
      value = tonumber(value or 0) or 0
      if value > (tonumber(CL.stats[field] or 0) or 0) then CL.stats[field] = value end
    end

    local function cl_count(values)
      if type(values) ~= "table" then return 0 end
      local count = 0
      for _ in pairs(values) do count = count + 1 end
      return count
    end

    local function cl_stamp(record, ...)
      if type(record) == "number" then return record end
      if type(record) ~= "table" then return 0 end
      for index = 1, select("#", ...) do
        local value = tonumber(record[select(index, ...)] or 0) or 0
        if value > 0 then return value end
      end
      return 0
    end

    local function cl_record_error(scope, value)
      table.insert(CL.errors, {scope=tostring(scope or "cleanup"), error=tostring(value or "unknown"), at=cl_now()})
      while #CL.errors > CL.maximumErrors do table.remove(CL.errors, 1) end
    end

    local function cl_observe(name, values)
      if not cl_enabled() then return end
      local count = cl_count(values)
      if count > (tonumber(CL.peaks[name] or 0) or 0) then CL.peaks[name] = count end
      if count > (tonumber(CL.stats.largestCacheSize or 0) or 0) then
        CL.stats.largestCacheSize = count
        CL.stats.largestCacheName = name
      end
    end

    local function cl_remove_oldest(name, values, maximum, stampReader, protected)
      if type(values) ~= "table" then return 0 end
      local count = cl_count(values)
      cl_max("maximumEntriesObserved", count)
      if count <= maximum then return 0 end
      local rows = {}
      for key, value in pairs(values) do
        if not protected or not protected(key, value) then
          table.insert(rows, {key=key, stamp=stampReader and stampReader(value) or 0})
        end
      end
      table.sort(rows, function(left, right)
        if left.stamp ~= right.stamp then return left.stamp < right.stamp end
        return tostring(left.key) < tostring(right.key)
      end)
      local removed = 0
      local needed = count - maximum
      for index = 1, math.min(needed, #rows) do
        local row = rows[index]
        if row and values[row.key] ~= nil then
          values[row.key] = nil
          removed = removed + 1
        end
      end
      if removed > 0 then cl_note("boundedEvictions", removed) end
      cl_observe(name, values)
      return removed
    end

    local function cl_prune_timed(name, values, ttl, maximum, stamp, stampReader, protected)
      if type(values) ~= "table" then return 0, 0 end
      local expired = 0
      for key, value in pairs(values) do
        local itemStamp = stampReader and stampReader(value) or 0
        if (not protected or not protected(key, value)) and itemStamp > 0 and (stamp - itemStamp) > ttl then
          values[key] = nil
          expired = expired + 1
        end
      end
      if expired > 0 then cl_note("ttlRemovals", expired) end
      local capped = cl_remove_oldest(name, values, maximum, stampReader, protected)
      cl_observe(name, values)
      return expired, capped
    end

    local function cl_reconcile(name, values, live, maximum)
      if type(values) ~= "table" then return 0 end
      local removed = 0
      for key in pairs(values) do
        if type(live) ~= "table" or live[key] == nil then
          values[key] = nil
          removed = removed + 1
        end
      end
      if removed > 0 then cl_note("orphanedReferencesRemoved", removed) end
      local capped = cl_remove_oldest(name, values, maximum, nil, nil)
      cl_observe(name, values)
      return removed + capped
    end

    local function cl_active_ids(rows)
      local active = {}
      for _, row in ipairs(rows or {}) do
        local id = tostring(row and row.id or "")
        if id ~= "" then active[id] = true end
      end
      return active
    end

    local function cl_cleanup_dead_compatibility()
      local removed = 0
      for _, name in ipairs({
        "_inlinePublicChatCache", "_sfDirectLinkCache",
        "_sffclSeen", "_sffclLastRow", "_sffclFilterCache", "_sffclDisplayCache",
      }) do
        local value = B[name]
        if value ~= nil then
          removed = removed + cl_count(value)
          B[name] = nil
        end
      end
      if removed > 0 then cl_note("deadCacheEntriesRemoved", removed) end
      return removed
    end

    local function cl_cleanup_public(stamp)
      local removed = 0
      if B.ExpirePublicGroups then
        local before = cl_count(B.publicGroups)
        local ok, value = pcall(B.ExpirePublicGroups, B)
        if ok then removed = removed + math.max(0, before - cl_count(B.publicGroups))
        else cl_record_error("public.expire", value) end
      end
      local capped = cl_remove_oldest("session.publicGroups", B.publicGroups or {}, CL.maximums.publicGroups,
        function(row) return cl_stamp(row, "seen", "created", "firstSeen") end)
      removed = removed + capped
      if capped > 0 then
        if B.selectedPublic and not B.publicGroups[B.selectedPublic] then B.selectedPublic = nil end
        if B.SF151_InvalidatePublicGroupsData then B:SF151_InvalidatePublicGroupsData("cache-capacity") end
        -- The Phase 5 expiry wrapper owns canonical-index reconciliation.
        -- Re-enter it after capacity eviction so no index points at a removed row.
        local ok, value = pcall(B.ExpirePublicGroups, B)
        if not ok then cl_record_error("public.index-reconcile", value) end
      end
      removed = removed + cl_reconcile("session.seenPublic", B.sfamSeenPublic, B.publicGroups, CL.maximums.seenPublic)
      return removed
    end

    local function cl_cleanup_browse(stamp)
      local listingId = B.myListing and tostring(B.myListing.id or "") or ""
      local protected = function(key, row)
        return listingId ~= "" and (tostring(key or "") == listingId or tostring(row and row.id or "") == listingId)
      end
      local expired, capped = cl_prune_timed("session.listings", B.listings, CL.ttls.listings,
        CL.maximums.listings, stamp, function(row) return cl_stamp(row, "seen", "created") end, protected)
      local removed = expired + capped
      if removed > 0 then
        if B.selectedListing and not B.listings[B.selectedListing] then B.selectedListing = nil end
        if B.SF151_InvalidateBrowseData then B:SF151_InvalidateBrowseData("cache-lifecycle", true) end
      end
      local appExpired, appCapped = cl_prune_timed("session.applicants", B.applicants,
        CL.ttls.applicants, CL.maximums.applicants, stamp,
        function(row) return cl_stamp(row, "applied", "seen", "created") end)
      if appExpired + appCapped > 0 then
        if B.selectedApplicant and not B.applicants[B.selectedApplicant] then B.selectedApplicant = nil end
        if B.SF151_InvalidateBrowseData then B:SF151_InvalidateBrowseData("applicant-cache-lifecycle", true) end
      end
      local seenRemoved = cl_reconcile("session.seenApplicants", B.sfamSeenApplicants, B.applicants, CL.maximums.seenApplicants)
      return removed + appExpired + appCapped + seenRemoved
    end

    local function cl_cleanup_network(stamp)
      local expiredOnline, cappedOnline = cl_prune_timed("session.onlineUsers", B.onlineUsers,
        CL.ttls.onlineUsers, CL.maximums.onlineUsers, stamp,
        function(row) return cl_stamp(row, "seen", "created") end)
      local expiredStatus, cappedStatus = cl_prune_timed("session.sfnStatuses", B.sfnStatuses,
        CL.ttls.sfnStatuses, CL.maximums.sfnStatuses, stamp,
        function(row) return cl_stamp(row, "seen", "created") end)
      local removed = expiredOnline + cappedOnline + expiredStatus + cappedStatus
      if removed > 0 and B.SF151_InvalidateRosterData then B:SF151_InvalidateRosterData("cache-lifecycle") end
      removed = removed + cl_remove_oldest("session.invasionUsers", B.invasionUsers or {}, CL.maximums.invasionUsers,
        function(row) return cl_stamp(row, "seen", "lastSeen", "created") end)
      removed = removed + cl_remove_oldest("session.invasionOtherPlayers", B.invasionOtherPlayers or {}, CL.maximums.invasionOtherPlayers,
        function(row) return cl_stamp(row, "seen", "lastSeen", "created") end)
      removed = removed + cl_remove_oldest("session.invasionBeacons", B.invasionBeacons or {}, CL.maximums.invasionBeacons,
        function(row) return cl_stamp(row, "seen", "lastSeen", "created") end)
      removed = removed + cl_remove_oldest("session.knownClassNames", B._sf151KnownClassNames or {}, CL.maximums.knownClassNames)
      return removed
    end

    local function cl_cleanup_guilds(stamp)
      local runtime = B.chatGuildListings
      local persisted = BronzeLFG_DB and BronzeLFG_DB.chatGuildListings or nil
      local expired, capped = cl_prune_timed("session.chatGuildListings", runtime,
        CL.ttls.chatGuildListings, CL.maximums.chatGuildListings, stamp,
        function(row) return cl_stamp(row, "lastPostSeen", "seen", "created", "firstSeen") end)
      if persisted and persisted ~= runtime then
        local dbExpired, dbCapped = cl_prune_timed("db.chatGuildListings", persisted,
          CL.ttls.chatGuildListings, CL.maximums.chatGuildListings, stamp,
          function(row) return cl_stamp(row, "lastPostSeen", "seen", "created", "firstSeen") end)
        expired = expired + dbExpired
        capped = capped + dbCapped
      end
      local guildExpired, guildCapped = cl_prune_timed("session.guilds", B.guilds, CL.ttls.guilds, CL.maximums.guilds, stamp,
        function(row) return cl_stamp(row, "lastPostSeen", "lastSeen", "seen", "created", "firstSeen") end)
      local postExpired, postCapped = cl_prune_timed("session.guildPosts", B.guildPosts, CL.ttls.guildPosts, CL.maximums.guildPosts, stamp,
        function(row) return cl_stamp(row, "lastPostSeen", "seen", "created") end)
      return expired + capped + guildExpired + guildCapped + postExpired + postCapped
    end

    local function cl_cleanup_who(stamp)
      local removed = 0
      if B.PruneWhoGuilds then
        local ok, value = pcall(B.PruneWhoGuilds, B)
        if not ok then cl_record_error("who.prune", value) end
      end
      local db = BronzeLFG_DB or {}
      local players = db.whoPlayers or B.whoPlayers
      local guilds = db.whoGuilds or B.whoGuilds
      removed = removed + cl_remove_oldest("db.whoPlayers", players or {}, CL.maximums.whoPlayers,
        function(row) return cl_stamp(row, "seen", "lastSeen") end)
      removed = removed + cl_remove_oldest("db.whoGuilds", guilds or {}, CL.maximums.whoGuilds,
        function(row) return cl_stamp(row, "lastSeen", "seen", "firstSeen") end)
      for _, guild in pairs(guilds or {}) do
        removed = removed + cl_remove_oldest("db.whoGuildMembers", guild and guild.members or nil, CL.maximums.whoMembers,
          function(row) return cl_stamp(row, "seen", "lastSeen") end)
      end
      local lookup = B.publicPlayerWho
      if type(lookup) == "table" then
        local queryExpired, queryCapped = cl_prune_timed("session.publicWhoLastQuery", lookup.lastQuery, CL.ttls.publicWho,
          CL.maximums.publicWho, stamp, function(value) return tonumber(value or 0) or 0 end)
        local resultExpired, resultCapped = cl_prune_timed("session.publicWhoFinalResult", lookup.finalResult, CL.ttls.publicWho,
          CL.maximums.publicWho, stamp, function(value) return tonumber(value or 0) or 0 end)
        removed = removed + queryExpired + queryCapped + resultExpired + resultCapped
      end
      return removed
    end

    local function cl_cleanup_alerts(stamp)
      local removed = 0
      local notifyExpired, notifyCapped = cl_prune_timed("session.notificationSeen", B._notifySeen569, CL.ttls.notificationSeen,
        CL.maximums.notificationSeen, stamp, function(value) return tonumber(value or 0) or 0 end)
      removed = removed + notifyExpired + notifyCapped
      local network = BronzeLFG_DB and BronzeLFG_DB.network or nil
      if network then
        local cooldownExpired, cooldownCapped = cl_prune_timed("db.favoriteAlertCooldowns", network.favoriteAlertCooldowns,
          CL.ttls.favoriteAlertCooldowns, CL.maximums.favoriteAlertState, stamp,
          function(value) return tonumber(value or 0) or 0 end)
        local seenExpired, seenCapped = cl_prune_timed("db.favoriteAlertSeenListings", network.favoriteAlertSeenListings,
          CL.ttls.favoriteAlertSeenListings, CL.maximums.favoriteAlertState, stamp,
          function(value) return tonumber(value or 0) or 0 end)
        local onlineExpired, onlineCapped = cl_prune_timed("db.favoriteOnlineSeen", network.favoriteOnlineSeen,
          CL.ttls.favoriteOnlineSeen, CL.maximums.favoriteAlertState, stamp,
          function(value) return tonumber(value or 0) or 0 end)
        removed = removed + cooldownExpired + cooldownCapped + seenExpired + seenCapped + onlineExpired + onlineCapped
      end
      return removed
    end

    local function cl_cleanup_community()
      local removed = 0
      local shared = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
      local network = BronzeLFG_DB and BronzeLFG_DB.network or nil
      if shared then
        local activeEvents = cl_active_ids(shared.events)
        for _, field in ipairs({"eventAlertSeen", "eventAlertKnown", "eventAlertCooldowns", "eventDismissed"}) do
          removed = removed + cl_reconcile("db." .. field, shared[field], activeEvents, 60)
        end
      end
      if shared then
        local activeNotices = cl_active_ids(shared.notices)
        removed = removed + cl_reconcile("db.noticeSeen", shared.noticeSeen, activeNotices, 40)
        removed = removed + cl_reconcile("db.noticeDismissed", shared.noticeDismissed, activeNotices, 40)
        if network then
          removed = removed + cl_reconcile("db.legacyNoticeSeen", network.noticeSeen, activeNotices, 40)
          removed = removed + cl_reconcile("db.legacyNoticeDismissed", network.noticeDismissed, activeNotices, 40)
        end
      end
      return removed
    end

    local function cl_timed_cleanup(field, callback, ...)
      if not cl_enabled() then return callback(...) end
      local started = cl_clock()
      local result = callback(...)
      CL.stats[field] = math.max(0, cl_clock() - started)
      return result
    end

    CL.inventory = {
      {name="session.publicGroups", owner="Phase 5 identity / Phase 9 capacity", key="stable listing id", maximum=512, ttl="publicExpire", cleanup="ExpirePublicGroups plus automatic lifecycle maintenance", persistence="session"},
      {name="session.listings", owner="Phase 9", key="listing id", maximum=256, ttl="900s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.applicants", owner="Phase 9", key="player name", maximum=128, ttl="7200s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.chatGuildListings", owner="Phase 9", key="normalized guild", maximum=256, ttl="21600s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.guilds", owner="Phase 9", key="guild identity", maximum=256, ttl="14d when timestamped", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.onlineUsers", owner="Phase 9", key="player name", maximum=512, ttl="300s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.sfnStatuses", owner="Phase 9", key="player name", maximum=512, ttl="300s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.knownClassNames", owner="Phase 9 capacity / class resolver", key="normalized player", maximum=256, ttl="session capacity", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.notificationSeen", owner="Phase 9", key="listing signature", maximum=256, ttl="120s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.publicWho", owner="Phase 9", key="normalized player", maximum=128, ttl="120s", cleanup="automatic lifecycle maintenance", persistence="session"},
      {name="session.rosterSnapshot", owner="Phase 3", key="generation", maximum=1, ttl="generation/next expiry", cleanup="roster invalidation", persistence="session"},
      {name="session.rosterViews", owner="Phase 3", key="generation/filter/search/guild", maximum=16, ttl="generation", cleanup="FIFO/invalidation", persistence="session"},
      {name="session.rosterClassCache", owner="Phase 3", key="normalized player", maximum=128, ttl="1800s", cleanup="snapshot build", persistence="session"},
      {name="session.publicSnapshot", owner="Phase 6b", key="data generation", maximum=1, ttl="generation", cleanup="Public Groups invalidation", persistence="session"},
      {name="session.publicViews", owner="Phase 6b", key="view signature", maximum=16, ttl="generation", cleanup="FIFO/invalidation", persistence="session"},
      {name="session.browseSnapshot", owner="Phase 8", key="data generation", maximum=1, ttl="generation", cleanup="Browse invalidation", persistence="session"},
      {name="session.browseViews", owner="Phase 8", key="view signature", maximum=16, ttl="generation", cleanup="FIFO/invalidation", persistence="session"},
      {name="session.chatSeen", owner="Phase 5", key="sender/message", maximum=256, ttl="5s", cleanup="ring replacement/prune", persistence="session"},
      {name="session.chatRecords", owner="Phase 5", key="stable record id", maximum=256, ttl="30s", cleanup="ring replacement/prune", persistence="session"},
      {name="session.chatQueue", owner="Phase 5", key="FIFO index", maximum=40, ttl="until processed/dropped", cleanup="queue owner", persistence="session"},
      {name="session.chatDecisions", owner="Phase 5", key="source event", maximum=256, ttl="2-6s", cleanup="ring replacement/lookup", persistence="session"},
      {name="session.chatRenderDecisions", owner="Phase 5", key="sender/message", maximum=256, ttl="2-6s", cleanup="ring replacement/lookup", persistence="session"},
      {name="session.publicCanonicalIndex", owner="Phase 5", key="canonical sender/message", maximum=512, ttl="public expiry + 30s", cleanup="index ring/row expiry", persistence="session"},
      {name="session.timerTasks", owner="Phase 4b", key="task key", maximum=128, ttl="deadline", cleanup="execute/cancel/replace", persistence="session"},
      {name="session.lazyPanels", owner="Phase 7", key="fixed panel id", maximum=13, ttl="session", cleanup="reload", persistence="session"},
      {name="session.wrapperState", owner="final loaded subsystem owners", key="fixed function/frame", maximum=64, ttl="session", cleanup="reload", persistence="session"},
      {name="session.selectionSearchFilters", owner="panel owners", key="fixed scalar state", maximum=24, ttl="session/profile", cleanup="selection repair/profile switch", persistence="session"},
      {name="session.diagnostics", owner="Phase 1", key="fixed category/ring", maximum=128, ttl="session/30s", cleanup="ring/reset/reload", persistence="session"},
      {name="db.whoPlayers", owner="Phase 9 capacity / WHO TTL", key="normalized player", maximum=1024, ttl="3600s", cleanup="WHO prune/Phase 9", persistence="BronzeLFG_DB"},
      {name="db.whoGuilds", owner="Phase 9 capacity / WHO TTL", key="normalized guild", maximum=256, ttl="14d", cleanup="WHO prune/Phase 9", persistence="BronzeLFG_DB"},
      {name="db.events", owner="Community Events", key="event id", maximum=60, ttl="event expiry", cleanup="event read/mutation", persistence="BronzeLFG_DB"},
      {name="db.notices", owner="Notice Board", key="array slot/event id", maximum=40, ttl="notice expiry", cleanup="notice read/mutation", persistence="BronzeLFG_DB"},
      {name="db.eventNoticeState", owner="Phase 9 orphan cleanup", key="event/notice id", maximum=60, ttl="source lifetime", cleanup="automatic lifecycle maintenance", persistence="BronzeLFG_DB"},
      {name="db.favoriteAlertState", owner="Phase 9", key="player/listing signature", maximum=256, ttl="1-2h", cleanup="automatic lifecycle maintenance", persistence="BronzeLFG_DB"},
      {name="db.userSettings", owner="user settings", key="user-selected value", maximum="deterministic fields", ttl="user controlled", cleanup="explicit user action", persistence="BronzeLFG_DB"},
    }

    function CL:Run(reason, force)
      if self.running then
        cl_note("nestedRunsSkipped", 1)
        return false, 0
      end
      self.running = true
      local started = cl_enabled() and cl_clock() or nil
      local results = {pcall(function()
        local stamp = cl_now()
        local removed = 0
        removed = removed + cl_timed_cleanup("compatibilityMs", cl_cleanup_dead_compatibility)
        removed = removed + cl_timed_cleanup("publicMs", cl_cleanup_public, stamp)
        removed = removed + cl_timed_cleanup("browseMs", cl_cleanup_browse, stamp)
        removed = removed + cl_timed_cleanup("networkMs", cl_cleanup_network, stamp)
        removed = removed + cl_timed_cleanup("guildMs", cl_cleanup_guilds, stamp)
        removed = removed + cl_timed_cleanup("whoMs", cl_cleanup_who, stamp)
        removed = removed + cl_timed_cleanup("alertsMs", cl_cleanup_alerts, stamp)
        removed = removed + cl_timed_cleanup("communityMs", cl_cleanup_community)
        cl_note("runs", 1)
        if force == true then cl_note("forcedRuns", 1) end
        local runReason = tostring(reason or (force and "manual" or "automatic"))
        if string.find(runReason, "chat", 1, true) then cl_note("chatMaintenanceRuns", 1) end
        if string.find(runReason, "login", 1, true) then cl_note("loginMaintenanceRuns", 1) end
        if string.find(runReason, "world-entry", 1, true) then cl_note("worldEntryMaintenanceRuns", 1) end
        cl_note("entriesRemoved", removed)
        CL.lastReason = runReason
        CL.lastRunAt = stamp
        return removed
      end)}
      self.running = false
      local elapsed = nil
      if started then
        elapsed = math.max(0, cl_clock() - started)
        cl_note("cleanupMsTotal", elapsed)
        cl_max("cleanupMsMaximum", elapsed)
        cl_max("maximumCleanupMs", elapsed)
      end
      if not results[1] then
        cl_record_error("run." .. tostring(reason or "manual"), results[2])
        return false, 0, elapsed
      end
      return true, tonumber(results[2] or 0) or 0, elapsed
    end

    function CL:MaybeRun(reason)
      cl_note("automaticRunRequests", 1)
      if self.running then
        cl_note("nestedRunsSkipped", 1)
        return false, 0
      end
      local now = cl_automatic_now()
      local last = tonumber(self.lastAutomaticRunAt or 0) or 0
      if last > 0 and now >= last and (now - last) < self.minimumAutomaticInterval then
        cl_note("automaticRunsCooldownSkipped", 1)
        return false, 0
      end
      local ok, removed, elapsed = self:Run(reason or "automatic", false)
      if ok then
        self.lastAutomaticRunAt = now
        cl_note("automaticRunsExecuted", 1)
      end
      return ok, removed, elapsed
    end

    function CL:ObserveChat()
      self.chatEvents = (tonumber(self.chatEvents or 0) or 0) + 1
      if cl_enabled() then cl_note("chatEvents", 1) end
      return false, 0
    end

    function CL:GetDiagnostics(includeMemory)
      local result = {
        generation=self.generation, running=self.running == true, lastReason=self.lastReason,
        lastRunAt=self.lastRunAt or 0, chatEvents=self.chatEvents or 0,
        minimumAutomaticInterval=self.minimumAutomaticInterval,
        automaticRunRequests=self.stats.automaticRunRequests or 0,
        automaticRunsExecuted=self.stats.automaticRunsExecuted or 0,
        automaticRunsCooldownSkipped=self.stats.automaticRunsCooldownSkipped or 0,
        forcedRuns=self.stats.forcedRuns or 0,
        chatMaintenanceRuns=self.stats.chatMaintenanceRuns or 0,
        loginMaintenanceRuns=self.stats.loginMaintenanceRuns or 0,
        worldEntryMaintenanceRuns=self.stats.worldEntryMaintenanceRuns or 0,
        maximumCleanupMs=self.stats.maximumCleanupMs or 0,
        inventoryEntries=#self.inventory,
        errors=self.errors, peaks=self.peaks,
      }
      for key, value in pairs(self.stats or {}) do result[key] = value end
      if includeMemory and collectgarbage then result.memoryKB = tonumber(collectgarbage("count") or 0) or 0 end
      return result
    end

    function B:SF151_RunCacheMaintenance(reason)
      return CL:Run(reason or "explicit", true)
    end

    function B:SF151_GetCacheLifecycleDiagnostics(includeMemory)
      return CL:GetDiagnostics(includeMemory == true)
    end

    function B:SF151_GetCacheLifecycleInventory()
      local rows = {}
      for _, item in ipairs(CL.inventory) do
        local copy = {}
        for key, value in pairs(item) do copy[key] = value end
        table.insert(rows, copy)
      end
      return rows
    end

    function B:SF151_ResetCacheLifecycleStats()
      CL.stats = {}
      CL.peaks = {}
      CL.errors = {}
      return true
    end

    local oldSlowMaintenance = B.SF151_RunSlowMaintenance
    if type(oldSlowMaintenance) == "function" and not CL.oldSlowMaintenance then
      CL.oldSlowMaintenance = oldSlowMaintenance
      B.SF151_RunSlowMaintenance = function(self, reason, ...)
        local results = {pcall(CL.oldSlowMaintenance, self, reason, ...)}
        if not results[1] then error(results[2], 0) end
        local cleanup = {pcall(CL.MaybeRun, CL, reason or "slow-maintenance")}
        if not cleanup[1] then error(cleanup[2], 0) end
        return unpack(results, 2)
      end
    end

    local oldReset = P.Reset
    P.Reset = function(self, ...)
      local results = {pcall(oldReset, self, ...)}
      B:SF151_ResetCacheLifecycleStats()
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2)
    end

    local oldGetReport = P.GetReport
    P.GetReport = function(self, ...)
      local report = oldGetReport(self, ...)
      report.cacheLifecycle = CL:GetDiagnostics(false)
      return report
    end

    local oldPrint = P.Print
    P.Print = function(self, ...)
      local report = oldPrint(self, ...)
      local row = CL:GetDiagnostics(false)
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r cache lifecycle: owner=" .. tostring(row.generation)
          .. ", runs=" .. tostring(row.runs or 0) .. ", removed=" .. tostring(row.entriesRemoved or 0)
          .. ", auto=" .. tostring(row.automaticRunsExecuted or 0) .. "/" .. tostring(row.automaticRunRequests or 0)
          .. ", skipped=" .. tostring(row.automaticRunsCooldownSkipped or 0)
          .. ", forced=" .. tostring(row.forcedRuns or 0)
          .. ", chatRuns=" .. tostring(row.chatMaintenanceRuns or 0)
          .. ", ttl=" .. tostring(row.ttlRemovals or 0) .. ", evicted=" .. tostring(row.boundedEvictions or 0)
          .. ", orphans=" .. tostring(row.orphanedReferencesRemoved or 0)
          .. ", largest=" .. tostring(row.largestCacheName or "none") .. "/" .. tostring(row.largestCacheSize or 0)
          .. ", maxMs=" .. string.format("%.3f", tonumber(row.cleanupMsMaximum or 0) or 0))
      end
      return report
    end

    local oldPerfSlash = B.SF151_HandlePerfSlash
    B.SF151_HandlePerfSlash = function(self, command)
      local cmd = tostring(command or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if cmd == "perf cleanup" then
        local ok, removed, elapsed = CL:Run("slash", true)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r cache cleanup "
            .. (ok and "complete" or "failed") .. ": removed " .. tostring(removed or 0) .. " entries"
            .. (cl_enabled() and elapsed and (" in " .. string.format("%.3f", elapsed) .. " ms") or "") .. ".")
        end
        return true
      elseif cmd == "perf cachelife" or cmd == "perf cachelife memory" then
        local row = CL:GetDiagnostics(cmd == "perf cachelife memory")
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r cache lifecycle " .. tostring(row.generation)
            .. ": runs=" .. tostring(row.runs or 0) .. ", removed=" .. tostring(row.entriesRemoved or 0)
            .. ", auto=" .. tostring(row.automaticRunsExecuted or 0) .. "/" .. tostring(row.automaticRunRequests or 0)
            .. ", skipped=" .. tostring(row.automaticRunsCooldownSkipped or 0)
            .. ", forced=" .. tostring(row.forcedRuns or 0)
            .. ", chatRuns=" .. tostring(row.chatMaintenanceRuns or 0)
            .. ", ttl=" .. tostring(row.ttlRemovals or 0) .. ", evicted=" .. tostring(row.boundedEvictions or 0)
            .. ", errors=" .. tostring(#(row.errors or {})))
          if row.memoryKB then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r Lua memory: "
            .. string.format("%.1f KB", row.memoryKB) .. " (explicit sample)") end
        end
        return true
      end
      return oldPerfSlash(self, command)
    end

    cl_cleanup_dead_compatibility()
    -- Phase 4 owns lifecycle events. Its slow-maintenance call reaches the
    -- throttled Phase 9 wrapper above, so this subsystem needs no event frame.
    CL.eventFrame = nil
  end
end
-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_END

-- Phase 10 opt-in integrated stability and conflict diagnostics.
-- SIGNALFIRE_PHASE10_STABILITY_BEGIN
do
  local B = _G.BronzeLFG
  if B and CreateFrame then
    local S = _G.SignalFireStability151 or {}
    _G.SignalFireStability151 = S
    S.generation = "1.5.1-phase10b"
    S.enabled = false
    S.deep = false
    S.maximumRecent = 32
    S.maximumErrors = 12
    S.maximumSamples = 16
    S.thresholds = {notice=10, warning=25, severe=50}
    S.bindings = S.bindings or {}
    S.signalFireSetItemRef = S.signalFireSetItemRef or _G.SetItemRef
    S.expectedSetItemRef = S.signalFireSetItemRef
    S.expectedTooltipSetHyperlink = S.expectedTooltipSetHyperlink
      or (_G.ItemRefTooltip and _G.ItemRefTooltip.SetHyperlink)

    -- Phase 10 diagnostics are session-only. Method records use fixed audited
    -- owner names (maximum 40). Recent trigger/error/resource histories are
    -- FIFO-capped at 32/12/16. Reset or reload clears them. Nothing is stored in
    -- BronzeLFG_DB, and no raw chat or private message body is captured.
    S.methods = S.methods or {}
    S.recent = S.recent or {}
    S.errors = S.errors or {}
    S.samples = S.samples or {}
    S.active = S.active or {}

    local function s_now()
      if GetTime then return GetTime() end
      if time then return time() end
      return 0
    end

    local function s_clock()
      if debugprofilestop then return debugprofilestop() end
      return s_now() * 1000
    end

    local function s_pack(...)
      return {n=select("#", ...), ...}
    end

    local function s_emit(value)
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. tostring(value or ""))
      end
    end

    local function s_bool(value)
      return value and "true" or "false"
    end

    local function s_source(value)
      if type(value) ~= "string" then return nil end
      value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      value = value:gsub("|H[^|]+|h.-|h", "[link]"):gsub("[%c]", " ")
      value = value:gsub("^%s+", ""):gsub("%s+$", "")
      if #value > 64 then value = string.sub(value, 1, 64) end
      return value ~= "" and value or nil
    end

    local function s_push(list, maximum, value)
      table.insert(list, value)
      while #list > maximum do table.remove(list, 1) end
    end

    local function s_frame_visible(field)
      local frame = field and B[field] or nil
      return frame and frame.IsShown and frame:IsShown() and true or false
    end

    local function s_panel_built(key)
      local lazy = _G.SignalFireLazyPanels151
      local row = lazy and lazy.panels and lazy.panels[key] or nil
      if not row then return nil end
      if row.ready then
        local ok, value = pcall(row.ready, B)
        if ok then return value and true or false end
      end
      return row.built == true
    end

    local function s_numeric_copy(source)
      local result = {}
      for key, value in pairs(source or {}) do
        if type(value) == "number" then result[key] = value end
      end
      return result
    end

    local function s_chat_filter_state()
      return B.SF151_GetChatFilterState and B:SF151_GetChatFilterState() or {}
    end

    local function s_panel_build_map()
      local result = {}
      local lazy = B.SF151_GetLazyPanelDiagnostics and B:SF151_GetLazyPanelDiagnostics() or {}
      for name, panel in pairs(lazy.panels or {}) do result[name] = panel.built == true end
      return result
    end

    local function s_cache_peak_map(rows)
      local result = {}
      for _, row in ipairs(rows or {}) do
        result[tostring(row.name or "unknown")] = tonumber(row.maximum or row.count or 0) or 0
      end
      return result
    end

    -- Phase 10 release migration owns only structural repair. It preserves
    -- valid user values, never constructs UI, and is safe to run repeatedly.
    -- No migration state is cached outside the supplied SavedVariables table.
    function B:SF151_RepairReleaseDatabase(db)
      db = type(db) == "table" and db or BronzeLFG_DB
      if type(db) ~= "table" then return false, {repairs=0} end
      local repairs = 0
      local function ensure_table(owner, key)
        if type(owner[key]) ~= "table" then owner[key] = {}; repairs = repairs + 1 end
        return owner[key]
      end
      local options = ensure_table(db, "options")
      if self.SF151_ApplyChatLinkSafeDefault then self:SF151_ApplyChatLinkSafeDefault(db) end
      if options.publicGroups == nil then options.publicGroups = true; repairs = repairs + 1 end
      if options.publicStrict == nil then options.publicStrict = true; repairs = repairs + 1 end
      if options.parseGuildRecruitment == nil then options.parseGuildRecruitment = true; repairs = repairs + 1 end
      if options.serverProfile ~= "Triumvirate" and options.serverProfile ~= "Ascension" then
        options.serverProfile = "Triumvirate"; repairs = repairs + 1
      end
      local validScale = {[.75]=true, [.85]=true, [.9]=true, [1]=true, [1.1]=true, [1.2]=true, [1.25]=true}
      local scale = tonumber(options.scale)
      if not scale or not validScale[scale] then options.scale = 1; repairs = repairs + 1 end
      if options.chatLinkScope ~= "main" and options.chatLinkScope ~= "visible"
          and options.chatLinkScope ~= "all" then
        options.chatLinkScope = "main"; repairs = repairs + 1
      end
      ensure_table(options, "modules")
      local byProfile = ensure_table(options, "modulesByProfile")
      local saved = ensure_table(options, "moduleSavedSettings")
      for _, profile in ipairs({"Triumvirate", "Ascension"}) do
        ensure_table(byProfile, profile)
        ensure_table(saved, profile)
      end
      local moduleKeys = {"chatParsing", "guildBrowser", "recruitmentCreator", "eventBoard",
        "notices", "invasions", "ascensionListingTools", "raidTools"}
      for _, owner in ipairs({options.modules, byProfile.Triumvirate, byProfile.Ascension}) do
        for _, key in ipairs(moduleKeys) do
          if owner[key] ~= nil and owner[key] ~= true and owner[key] ~= false then
            owner[key] = nil; repairs = repairs + 1
          end
        end
      end
      if byProfile.Ascension.invasions ~= false then
        byProfile.Ascension.invasions = false; repairs = repairs + 1
      end
      for _, key in ipairs({"profile", "favorites", "favoriteGuilds", "parserStats",
          "guildBrowser", "publicHiddenTypes", "recruitmentCreator", "minimap",
          "chatGuildListings", "whoGuilds", "whoPlayers", "network", "signalFireNetwork"}) do
        ensure_table(db, key)
      end
      local network = db.network
      for _, key in ipairs({"favoriteAlertCooldowns", "favoriteAlertSeenListings",
          "favoriteOnlineSeen", "noticeSeen", "noticeDismissed"}) do
        ensure_table(network, key)
      end
      local shared = db.signalFireNetwork
      for _, key in ipairs({"events", "notices", "eventAlertSeen", "eventAlertKnown",
          "eventAlertCooldowns", "eventDismissed", "noticeSeen", "noticeDismissed"}) do
        ensure_table(shared, key)
      end
      options.sf151Phase10ReleaseMigration = true
      return true, {repairs=repairs, profile=options.serverProfile, scale=options.scale,
        chatLinks=options.inlineChatLinks == true}
    end

    function S:Reset()
      self.methods = {}
      self.recent = {}
      self.errors = {}
      self.samples = {}
      self.active = {}
      self.maximumActiveDepth = 0
      self.crossSubsystemEntries = 0
      self.reentrantEntries = 0
      self.cyclicEntries = 0
      self.wrapperReplacements = 0
      self.startedAt = s_now()
      self.baseline = nil
      self.lastSample = nil
      self.chatOwnership = nil
      self.setItemRefOwnership = nil
      self.setItemRefProbe = nil
      self.intervalChatBaseline = s_numeric_copy(s_chat_filter_state())
      self.panelBuildBaseline = s_panel_build_map()
      local perf = _G.SignalFirePerf151
      self.cachePeakBaseline = s_cache_peak_map(perf and perf.SnapshotCaches and perf:SnapshotCaches() or {})
      return true
    end

    function S:Method(owner)
      local row = self.methods[owner]
      if not row then
        row = {requests=0, executions=0, reentrant=0, cyclic=0, hidden=0,
          unbuilt=0, callsThisSecond=0, executionsThisSecond=0,
          maxRequestsPerSecond=0, maxExecutionsPerSecond=0,
          callsThisFrame=0, executionsThisFrame=0, maxRequestsInFrame=0,
          maxExecutionsInFrame=0, totalMs=0, longestMs=0, errors=0}
        self.methods[owner] = row
      end
      return row
    end

    function S:Enter(owner, kind, source, panelField, panelKey)
      local stamp = s_now()
      local row = self:Method(owner)
      local second = math.floor(stamp)
      local frame = math.floor((stamp * 60) + .5)
      if row.second ~= second then
        row.second = second
        row.callsThisSecond = 0
        row.executionsThisSecond = 0
      end
      if row.frame ~= frame then
        row.frame = frame
        row.callsThisFrame = 0
        row.executionsThisFrame = 0
      end
      row.requests = row.requests + 1
      row.callsThisSecond = row.callsThisSecond + 1
      row.callsThisFrame = row.callsThisFrame + 1
      row.maxRequestsPerSecond = math.max(row.maxRequestsPerSecond, row.callsThisSecond)
      row.maxRequestsInFrame = math.max(row.maxRequestsInFrame, row.callsThisFrame)
      if kind ~= "request" then
        row.executions = row.executions + 1
        row.executionsThisSecond = row.executionsThisSecond + 1
        row.executionsThisFrame = row.executionsThisFrame + 1
        row.maxExecutionsPerSecond = math.max(row.maxExecutionsPerSecond, row.executionsThisSecond)
        row.maxExecutionsInFrame = math.max(row.maxExecutionsInFrame, row.executionsThisFrame)
      end
      if panelField and not s_frame_visible(panelField) then row.hidden = row.hidden + 1 end
      if panelKey and s_panel_built(panelKey) == false then row.unbuilt = row.unbuilt + 1 end
      local reentrant = false
      for _, item in ipairs(self.active) do
        if item.owner == owner then reentrant = true; break end
      end
      local parent = self.active[#self.active]
      local cyclic = reentrant or (#self.active >= 24)
      if reentrant then
        row.reentrant = row.reentrant + 1
        self.reentrantEntries = self.reentrantEntries + 1
      end
      if cyclic then
        row.cyclic = row.cyclic + 1
        self.cyclicEntries = self.cyclicEntries + 1
      end
      if parent and tostring(parent.owner):match("^[^.]+") ~= tostring(owner):match("^[^.]+") then
        self.crossSubsystemEntries = self.crossSubsystemEntries + 1
      end
      row.lastSource = s_source(source) or tostring(parent and parent.owner or "direct")
      local panelBuiltBefore
      if panelKey then panelBuiltBefore = s_panel_built(panelKey) end
      local token = {owner=owner, row=row, started=s_clock(), reentrant=reentrant, cyclic=cyclic,
        kind=kind, panelKey=panelKey, panelBuiltBefore=panelBuiltBefore}
      table.insert(self.active, token)
      self.maximumActiveDepth = math.max(self.maximumActiveDepth or 0, #self.active)
      return token
    end

    function S:Leave(token, ok, err)
      local elapsed = math.max(0, s_clock() - token.started)
      local row = token.row
      row.totalMs = row.totalMs + elapsed
      row.longestMs = math.max(row.longestMs, elapsed)
      row.lastMs = elapsed
      if token.kind ~= "request" then
        if row.firstObservedMs == nil then row.firstObservedMs = elapsed end
        if token.panelBuiltBefore == false then
          row.firstOpenExecutions = (row.firstOpenExecutions or 0) + 1
          row.firstOpenMs = math.max(row.firstOpenMs or 0, elapsed)
        elseif token.panelBuiltBefore == true then
          row.steadyExecutions = (row.steadyExecutions or 0) + 1
          row.steadyTotalMs = (row.steadyTotalMs or 0) + elapsed
          row.steadyLongestMs = math.max(row.steadyLongestMs or 0, elapsed)
        end
      end
      if not ok then
        row.errors = row.errors + 1
        s_push(self.errors, self.maximumErrors,
          {owner=token.owner, error=tostring(err or "unknown"), at=s_now()})
      end
      local level = elapsed >= self.thresholds.severe and "severe"
        or elapsed >= self.thresholds.warning and "warning"
        or elapsed >= self.thresholds.notice and "notice" or nil
      if level then row[level] = (row[level] or 0) + 1 end
      if level or token.reentrant or token.cyclic then
        local entry = {owner=token.owner, elapsed=elapsed, level=level,
          reentrant=token.reentrant, cyclic=token.cyclic, at=s_now(), source=row.lastSource}
        if self.deep and debugstack then
          local stackOK, stack = pcall(debugstack, 3, 8, 8)
          if stackOK then entry.stack=string.sub(tostring(stack or ""), 1, 1200) end
        end
        s_push(self.recent, self.maximumRecent, entry)
      end
      for index = #self.active, 1, -1 do
        if self.active[index] == token then table.remove(self.active, index); break end
      end
      return elapsed
    end

    function S:InstallScaleOwner()
      local frame = B.frame
      if not frame or type(frame.SetScale) ~= "function" then return false end
      local binding = self.scaleBinding
      if binding and binding.frame == frame then
        if frame.SetScale == binding.wrapper then return true end
        if not binding.replaced then
          binding.replaced = true
          self.wrapperReplacements = (self.wrapperReplacements or 0) + 1
        end
        return false
      end
      binding = {frame=frame, original=frame.SetScale, installedAt=s_now()}
      binding.wrapper = function(owner, value, ...)
        if not S.enabled then return binding.original(owner, value, ...) end
        local token = S:Enter("ui.scale", "execution", tostring(value or "nil"))
        local results = s_pack(pcall(binding.original, owner, value, ...))
        S:Leave(token, results[1], results[2])
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, results.n)
      end
      self.scaleBinding = binding
      frame.SetScale = binding.wrapper
      return true
    end

    function S:WrapMethod(owner, methodName, kind, panelField, panelKey, captureSource)
      local current = B[methodName]
      if type(current) ~= "function" then return false end
      local binding = self.bindings[owner]
      if binding then
        if B[methodName] == binding.wrapper then return true end
        binding.replaced = true
        binding.replacedBy = tostring(B[methodName])
        self.wrapperReplacements = (self.wrapperReplacements or 0) + 1
        return false
      end
      binding = {owner=owner, method=methodName, original=current, kind=kind,
        panelField=panelField, panelKey=panelKey, installedAt=s_now()}
      binding.wrapper = function(self, ...)
        if not S.enabled then return binding.original(self, ...) end
        local source = captureSource and select(1, ...) or nil
        local token = S:Enter(owner, kind, source, panelField, panelKey)
        local results = s_pack(pcall(binding.original, self, ...))
        if results[1] and (owner == "ui.CreateUI" or owner == "ui.Show"
            or owner == "ui.Toggle" or owner == "ui.ShowOptions") then
          S:InstallScaleOwner()
        end
        S:Leave(token, results[1], results[2])
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, results.n)
      end
      binding.wrapperIdentity = tostring(binding.wrapper)
      self.bindings[owner] = binding
      B[methodName] = binding.wrapper
      return true
    end

    function S:Install()
      local specs = {
        {"ui.CreateUI","CreateUI","execution"}, {"ui.Show","Show","execution"},
        {"ui.Toggle","Toggle","execution"}, {"ui.ShowBrowse","ShowBrowse","execution",nil,"browse"},
        {"ui.ShowPublicGroups","ShowPublicGroups","execution",nil,"publicGroups"}, {"ui.ShowNetwork","ShowSFNetwork","execution",nil,"network"},
        {"ui.ShowRoster","ShowFullRoster","execution",nil,"fullRoster"}, {"ui.ShowGuild","ShowGuildBrowser","execution",nil,"guildBrowser"},
        {"ui.ShowApplicants","ShowApplicants","execution",nil,"applicants"}, {"ui.ShowOptions","ShowOptions","execution",nil,"options"},
        {"ui.ShowCreate","ShowCreate","execution",nil,"create"}, {"ui.ShowProfile","ShowProfile","execution",nil,"profile"},
        {"refresh.request","SF151_RequestPanelRefresh","request",nil,nil,true},
        {"refresh.publicRequest","RequestPublicGroupsRefresh","request",nil,nil,true},
        {"refresh.public","RefreshPublicGroups","execution","publicPanel","publicGroups",true},
        {"refresh.browse","RefreshBrowse","execution","browse","browse",true},
        {"refresh.network","RefreshSFNetwork","execution","sfnPanel","network",true},
        {"refresh.roster","RefreshOnlinePanel","execution","onlinePanel","fullRoster",true},
        {"refresh.guild","RefreshGuildBrowser","execution","guildPanel","guildBrowser",true},
        {"refresh.applicants","RefreshApplicants","execution","apps","applicants",true},
        {"refresh.myListing","RefreshMyListing","execution","myPanel","myListing",true},
        {"refresh.events","SFE_RefreshEventBoard","execution","sfeEventPanel","network",true},
        {"refresh.invasions","RefreshInvasions","execution","invasionPanel","invasions",true},
        {"profile.set","SF143_SetServerProfile","execution",nil,nil,true},
        {"profile.create","SF143_ApplyProfileToCreate","execution"},
        {"profile.options","SF143_ApplyProfileToOptions","execution"},
        {"profile.modules","SFModulesApply","execution"},
        {"create.controls","UpdateCreateControls","execution"},
        {"network.presence","HandlePresence","execution"},
        {"network.message","HandleMessage","execution"},
        {"link.public","OpenPublicGroupLink","execution"},
        {"link.guild","OpenGuildBrowserLink","execution"},
      }
      for _, spec in ipairs(specs) do
        self:WrapMethod(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])
      end
      self:InstallScaleOwner()
      self.installed = true
      return true
    end

    local function s_addon_index()
      if not GetNumAddOns or not GetAddOnInfo then return nil end
      for index = 1, (tonumber(GetNumAddOns() or 0) or 0) do
        local name = GetAddOnInfo(index)
        if tostring(name or ""):lower() == "signalfire" then return index end
      end
      return nil
    end

    local function s_loaded_count()
      if not GetNumAddOns then return nil end
      local total = 0
      for index = 1, (tonumber(GetNumAddOns() or 0) or 0) do
        local loaded = IsAddOnLoaded and IsAddOnLoaded(index)
        if loaded then total = total + 1 end
      end
      return total
    end

    function S:SampleResources(kind)
      local sample = {at=s_now(), kind=tostring(kind or "memory"), loadedAddons=s_loaded_count()}
      if collectgarbage then
        local ok, value = pcall(collectgarbage, "count")
        if ok then sample.totalLuaKB=tonumber(value or 0) end
      end
      local index = s_addon_index()
      sample.addonIndex = index
      if index and UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
        local ok, value = pcall(GetAddOnMemoryUsage, index)
        if ok then sample.signalFireKB=tonumber(value or 0) end
      end
      local profileValue = GetCVar and GetCVar("scriptProfile") or nil
      sample.scriptProfile = tostring(profileValue or "") == "1"
      if kind == "cpu" and sample.scriptProfile and index and UpdateAddOnCPUUsage and GetAddOnCPUUsage then
        pcall(UpdateAddOnCPUUsage)
        local ok, value = pcall(GetAddOnCPUUsage, index)
        if ok then sample.signalFireCPU=tonumber(value or 0) end
      end
      if self.baseline then
        if sample.totalLuaKB and self.baseline.totalLuaKB then sample.totalLuaDeltaKB=sample.totalLuaKB-self.baseline.totalLuaKB end
        if sample.signalFireKB and self.baseline.signalFireKB then sample.signalFireDeltaKB=sample.signalFireKB-self.baseline.signalFireKB end
        if sample.signalFireCPU and self.baseline.signalFireCPU then sample.signalFireCPUDelta=sample.signalFireCPU-self.baseline.signalFireCPU end
      end
      s_push(self.samples, self.maximumSamples, sample)
      if not self.baseline then self.baseline=sample end
      self.lastSample=sample
      return sample
    end

    local knownAddons = {"ElvUI","Prat-3.0","Prat","Chatter","PhanxChat","Glass","WIM",
      "WeakAuras","WeakAuras2","Questie","BugSack","BugGrabber"}

    function S:ObserveSetItemRefProbe(link)
      local probe = self.setItemRefProbe
      if not (probe and probe.active and link == probe.sentinel) then return false end
      probe.depth = (probe.depth or 0) + 1
      probe.maximumDepth = math.max(probe.maximumDepth or 0, probe.depth)
      probe.hits = (probe.hits or 0) + 1
      probe.depth = math.max(0, probe.depth - 1)
      return true
    end

    function S:ProbeSetItemRefOwnership()
      local current = _G.SetItemRef
      local expected = self.signalFireSetItemRef
      local result = {current=tostring(current), signalFire=tostring(expected), hits=0,
        maximumDepth=0, callSucceeded=false}
      if type(expected) ~= "function" or type(current) ~= "function" then
        result.state = "signalFireMissing"
      else
        local probe = {active=true, sentinel="signalfirediag:ownership",
          hits=0, depth=0, maximumDepth=0}
        self.setItemRefProbe = probe
        local ok, err = pcall(current, probe.sentinel, "", "LeftButton", nil)
        self.setItemRefProbe = nil
        result.callSucceeded = ok == true
        result.error = ok and nil or tostring(err or "probe call failed")
        result.hits = probe.hits or 0
        result.maximumDepth = probe.maximumDepth or 0
        if result.hits > 1 or result.maximumDepth > 1 then
          result.state = "signalFireDuplicated"
        elseif current == expected and result.hits == 1 then
          result.state = "signalFireOutermost"
        elseif result.hits == 1 then
          result.state = "signalFireChained"
        elseif ok then
          result.state = "signalFireMissing"
        else
          result.state = "unknown"
        end
      end
      self.setItemRefProbe = nil
      self.setItemRefOwnership = result
      return result
    end

    function S:IdentityChatOwnership()
      local report = {generation="1.5.1-phase10b", frames={}, totals={
        signalFireOutermost=0, signalFireChained=0, signalFireMissing=0,
        signalFireDuplicated=0, unknown=0,
      }, probed=false}
      for index = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. tostring(index)]
        if frame then
          local stored = frame._sfP3CustomAddMessageHook
          local state = type(stored) ~= "function" and "signalFireMissing"
            or frame.AddMessage == stored and "signalFireOutermost" or "unknown"
          report.totals[state] = (report.totals[state] or 0) + 1
          table.insert(report.frames, {name=frame.GetName and frame:GetName() or ("ChatFrame" .. index),
            state=state, generation=frame._sfP3WrapperGeneration, hits=0, maximumDepth=0,
            current=tostring(frame.AddMessage), signalFire=tostring(stored)})
        end
      end
      return report
    end

    function S:ProbeOwnership()
      self.chatOwnership = B.SF151_ProbeChatFrameOwnership and B:SF151_ProbeChatFrameOwnership()
        or self:IdentityChatOwnership()
      self.chatOwnership.probed = B.SF151_ProbeChatFrameOwnership ~= nil
      self:ProbeSetItemRefOwnership()
      return self.chatOwnership, self.setItemRefOwnership
    end

    function S:GetChatFilterReport()
      local current = s_chat_filter_state()
      local baseline = self.intervalChatBaseline or {}
      local result = {
        generation=current.generation,
        expectedSignalFireFilters=current.expectedSignalFireFilters or 3,
        knownSignalFireRegistrations=current.knownSignalFireRegistrations or 0,
        registrationKnown=current.registrationKnown == true,
        introspection=current.introspection or "unavailable",
      }
      for _, key in ipairs({"filterCalls", "messagesClassified", "messagesLinked", "messagesParsed",
          "logicalRecordsQueued", "logicalRecordsProcessed", "drops"}) do
        result[key] = math.max(0, (tonumber(current[key] or 0) or 0)
          - (tonumber(baseline[key] or 0) or 0))
      end
      return result
    end

    function S:GetConflicts()
      local chatOwnership = self.chatOwnership or self:IdentityChatOwnership()
      local setItemRef = self.setItemRefOwnership or {
        state=_G.SetItemRef == self.signalFireSetItemRef and "signalFireOutermost" or "unknown",
        current=tostring(_G.SetItemRef), signalFire=tostring(self.signalFireSetItemRef),
        hits=0, maximumDepth=0, callSucceeded=false,
      }
      local report = {addons={}, frames=chatOwnership.frames or {}, chatOwnership=chatOwnership,
        setItemRef=setItemRef, setItemRefChanged=_G.SetItemRef ~= self.signalFireSetItemRef,
        tooltipChanged=_G.ItemRefTooltip and _G.ItemRefTooltip.SetHyperlink ~= self.expectedTooltipSetHyperlink or false,
        scaleOwnerChanged=self.scaleBinding and self.scaleBinding.frame
          and self.scaleBinding.frame.SetScale ~= self.scaleBinding.wrapper or false,
        filters=self:GetChatFilterReport(),
        filterIntrospection="live filter-list introspection is unavailable on WoW 3.3.5",
        wrapperChainIntrospection="state is based on a one-shot controlled reachability probe"}
      for _, name in ipairs(knownAddons) do
        local loaded = IsAddOnLoaded and IsAddOnLoaded(name) and true or false
        local enabled
        if GetAddOnEnableState then
          local ok, value = pcall(GetAddOnEnableState, UnitName and UnitName("player") or nil, name)
          if ok then enabled=value end
        end
        if loaded or (enabled and enabled > 0) then
          table.insert(report.addons, {name=name, loaded=loaded, enabled=enabled})
        end
      end
      return report
    end

    function S:GetReport()
      local methods = {}
      for owner, row in pairs(self.methods) do
        local copy = {owner=owner}
        for key, value in pairs(row) do copy[key]=value end
        table.insert(methods, copy)
      end
      table.sort(methods, function(left, right) return left.owner < right.owner end)
      local buildVersion, buildNumber, buildDate, tocVersion
      if GetBuildInfo then
        local ok, a, b, c, d = pcall(GetBuildInfo)
        if ok then buildVersion, buildNumber, buildDate, tocVersion=a,b,c,d end
      end
      local timer = B.SF151_GetTimerDiagnostics and B:SF151_GetTimerDiagnostics() or {}
      local chat = B.SF151_GetChatPublicIndexDiagnostics and B:SF151_GetChatPublicIndexDiagnostics() or {}
      local lazy = B.SF151_GetLazyPanelDiagnostics and B:SF151_GetLazyPanelDiagnostics() or {}
      local cache = B.SF151_GetCacheLifecycleDiagnostics and B:SF151_GetCacheLifecycleDiagnostics(false) or {}
      local refresh = B.SF151_GetRefreshStats and B:SF151_GetRefreshStats() or {}
      local chatFrames = B.SF151_GetChatFrameDiagnostics and B:SF151_GetChatFrameDiagnostics() or {}
      local perf = _G.SignalFirePerf151
      local cacheSizes = perf and perf.SnapshotCaches and perf:SnapshotCaches() or {}
      local cachePeakChanges = {}
      for _, row in ipairs(cacheSizes) do
        local name = tostring(row.name or "unknown")
        local peak = tonumber(row.maximum or row.count or 0) or 0
        local delta = peak - (tonumber((self.cachePeakBaseline or {})[name] or 0) or 0)
        if delta ~= 0 then table.insert(cachePeakChanges, {name=name, delta=delta, peak=peak}) end
      end
      table.sort(cachePeakChanges, function(left, right)
        if math.abs(left.delta) ~= math.abs(right.delta) then return math.abs(left.delta) > math.abs(right.delta) end
        return left.name < right.name
      end)
      local newlyBuiltPanels = {}
      for name, panel in pairs(lazy.panels or {}) do
        if panel.built and not (self.panelBuildBaseline or {})[name] then table.insert(newlyBuiltPanels, name) end
      end
      table.sort(newlyBuiltPanels)
      local conflicts = self:GetConflicts()
      return {generation=self.generation, enabled=self.enabled, deep=self.deep,
        version=SignalFire_GetVersion and SignalFire_GetVersion() or tostring(SignalFire_VERSION or "unknown"),
        profile=BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "unknown",
        chatLinks=BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.inlineChatLinks == true,
        client={version=buildVersion, build=buildNumber, date=buildDate, toc=tocVersion},
        loadedAddons=s_loaded_count(), methods=methods, recent=self.recent, errors=self.errors,
        maximumActiveDepth=self.maximumActiveDepth or 0, reentrantEntries=self.reentrantEntries or 0,
        cyclicEntries=self.cyclicEntries or 0, crossSubsystemEntries=self.crossSubsystemEntries or 0,
        wrapperReplacements=self.wrapperReplacements or 0, resources=self.lastSample,
        resourcesStart=self.baseline, resourcesEnd=self.lastSample,
        timers=timer, chat={queueDepth=chat.queueDepth or 0, counters=chat.counters or {}, frames=chatFrames},
        lazy=lazy, newlyBuiltPanels=newlyBuiltPanels, cache=cache, cacheSizes=cacheSizes,
        cachePeakChanges=cachePeakChanges, refresh=refresh, conflicts=conflicts}
    end

    function S:PrintReport()
      self:ProbeOwnership()
      self:SampleResources("memory")
      local report = self:GetReport()
      s_emit("diag owner=" .. report.generation .. ", enabled=" .. s_bool(report.enabled)
        .. ", deep=" .. s_bool(report.deep) .. ", version=" .. tostring(report.version)
        .. ", profile=" .. tostring(report.profile) .. ", chatLinks=" .. s_bool(report.chatLinks))
      s_emit("client=" .. tostring(report.client.version or "unsupported") .. "/" .. tostring(report.client.build or "?")
        .. ", loadedAddons=" .. tostring(report.loadedAddons or "unsupported")
        .. ", queue=" .. tostring(report.chat.queueDepth or 0))
      s_emit("stability: depth=" .. tostring(report.maximumActiveDepth) .. ", reentrant=" .. tostring(report.reentrantEntries)
        .. ", cycles=" .. tostring(report.cyclicEntries) .. ", cross=" .. tostring(report.crossSubsystemEntries)
        .. ", replacements=" .. tostring(report.wrapperReplacements) .. ", recent=" .. tostring(#report.recent)
        .. ", errors=" .. tostring(#report.errors))
      local refresh = report.refresh or {}
      if refresh.generation then
        s_emit("refresh scheduler: requests=" .. tostring(refresh.requests or 0)
          .. ", executed=" .. tostring(refresh.executed or 0)
          .. ", merged=" .. tostring(refresh.merged or 0)
          .. ", hidden=" .. tostring(refresh.hiddenSkipped or 0)
          .. ", nested=" .. tostring(refresh.nestedSuppressed or 0)
          .. ", pending=" .. s_bool(refresh.pending) .. ", dirty=" .. tostring(refresh.dirtyCount or 0))
      end
      local conflicts = report.conflicts or {}
      local ownership = conflicts.chatOwnership or {}
      local totals = ownership.totals or {}
      s_emit("chat ownership: frames=" .. tostring(#(ownership.frames or {}))
        .. ", outermost=" .. tostring(totals.signalFireOutermost or 0)
        .. ", chained=" .. tostring(totals.signalFireChained or 0)
        .. ", missing=" .. tostring(totals.signalFireMissing or 0)
        .. ", duplicated=" .. tostring(totals.signalFireDuplicated or 0)
        .. ", unknown=" .. tostring(totals.unknown or 0)
        .. ", probe=" .. s_bool(ownership.probed))
      local filters = conflicts.filters or {}
      s_emit("chat filters: expected=" .. tostring(filters.expectedSignalFireFilters or 0)
        .. ", known=" .. tostring(filters.knownSignalFireRegistrations or 0)
        .. ", calls=" .. tostring(filters.filterCalls or 0)
        .. ", classified=" .. tostring(filters.messagesClassified or 0)
        .. ", linked=" .. tostring(filters.messagesLinked or 0)
        .. ", parsed=" .. tostring(filters.messagesParsed or 0)
        .. ", queued=" .. tostring(filters.logicalRecordsQueued or 0)
        .. ", processed=" .. tostring(filters.logicalRecordsProcessed or 0)
        .. ", drops=" .. tostring(filters.drops or 0)
        .. ", liveList=unavailable")
      s_emit("chat source: candidates=" .. tostring(filters.candidateGateCalls or 0)
        .. ", accepted=" .. tostring(filters.candidateGateAccepted or 0)
        .. ", rejected=" .. tostring(filters.candidateGateRejected or 0)
        .. ", TestParse=" .. tostring(filters.TestParseCalls or 0)
        .. ", filterReceipts=" .. tostring(filters.filterReceipts or 0)
        .. ", cache=" .. tostring(filters.filterDecisionHits or 0) .. "/" .. tostring(filters.filterDecisionMisses or 0)
        .. ", rewritten=" .. tostring(filters.chatLinesRewritten or 0))
      s_emit("chat worker: frames=" .. tostring(filters.workerFramesActive or 0)
        .. ", records=" .. tostring(filters.workerRecordsProcessed or 0)
        .. ", countStops=" .. tostring(filters.workerBudgetStopsByCount or 0)
        .. ", timeStops=" .. tostring(filters.workerBudgetStopsByTime or 0)
        .. ", historicalScans=" .. tostring(filters.historicalFullTableDuplicateScans or 0))
      local setItemRef = conflicts.setItemRef or {}
      s_emit("SetItemRef ownership: state=" .. tostring(setItemRef.state or "unknown")
        .. ", hits=" .. tostring(setItemRef.hits or 0)
        .. ", maxDepth=" .. tostring(setItemRef.maximumDepth or 0)
        .. ", currentChanged=" .. s_bool(conflicts.setItemRefChanged)
        .. (setItemRef.state == "unknown" and setItemRef.error
          and (", probeError=" .. string.sub(tostring(setItemRef.error), 1, 120)) or ""))
      local lazy = report.lazy or {}
      local built, dirty, panelFailures = {}, {}, 0
      for name, panel in pairs(lazy.panels or {}) do
        if panel.built then table.insert(built, name) end
        if panel.dirty then table.insert(dirty, name) end
        panelFailures = panelFailures + (tonumber(panel.failures or 0) or 0)
      end
      table.sort(built); table.sort(dirty)
      s_emit("panels: shell=" .. s_bool(lazy.shellBuilt) .. ", shellBuilds=" .. tostring(lazy.shellBuildCount or 0)
        .. ", built=" .. (#built > 0 and table.concat(built, ",") or "none")
        .. ", firstBuiltThisInterval=" .. (#(report.newlyBuiltPanels or {}) > 0
          and table.concat(report.newlyBuiltPanels, ",") or "none")
        .. ", dirty=" .. (#dirty > 0 and table.concat(dirty, ",") or "none")
        .. ", background=" .. tostring(lazy.panelsBuiltWhileHidden or 0)
        .. ", failures=" .. tostring(panelFailures + #(lazy.errors or {})))
      local timer = report.timers or {}
      s_emit("timers: delayed=" .. s_bool(timer.delayedActive) .. "/" .. tostring(timer.delayedTasks or 0)
        .. ", network=" .. s_bool(timer.networkActive) .. ", applicant=" .. s_bool(timer.applicantActive)
        .. ", drag=" .. s_bool(timer.dragActive) .. ", legacy="
        .. tostring((timer.oldCoreActive and 1 or 0) + (timer.oldNetworkActive and 1 or 0)
          + (timer.oldPresenceActive and 1 or 0))
        .. ", callbackErrors=" .. tostring(timer.callbackErrorCount or 0))
      local cache = report.cache or {}
      s_emit("cache lifecycle: runs=" .. tostring(cache.runs or 0)
        .. ", removed=" .. tostring(cache.entriesRemoved or 0)
        .. ", ttl=" .. tostring(cache.ttlRemovals or 0)
        .. ", evicted=" .. tostring(cache.boundedEvictions or 0)
        .. ", orphans=" .. tostring(cache.orphanedReferencesRemoved or 0)
        .. ", largest=" .. tostring(cache.largestCacheName or "none") .. "/" .. tostring(cache.largestCacheSize or 0)
        .. ", errors=" .. tostring(#(cache.errors or {})))
      local cacheSizes = report.cacheSizes or {}
      table.sort(cacheSizes, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then return (left.count or 0) > (right.count or 0) end
        return tostring(left.name) < tostring(right.name)
      end)
      for index = 1, math.min(8, #cacheSizes) do
        local row = cacheSizes[index]
        if (row.count or 0) > 0 then
          s_emit("cache " .. tostring(row.name) .. "=" .. tostring(row.count)
            .. ", peak=" .. tostring(row.maximum or row.count)
            .. ", persisted=" .. s_bool(row.persisted))
        end
      end
      local addonNames = {}
      for _, addon in ipairs(conflicts.addons or {}) do table.insert(addonNames, addon.name) end
      s_emit("conflicts: addons=" .. (#addonNames > 0 and table.concat(addonNames, ",") or "none")
        .. ", SetItemRefState=" .. tostring(setItemRef.state or "unknown")
        .. ", tooltipChanged=" .. s_bool(conflicts.tooltipChanged)
        .. ", scaleOwnerChanged=" .. s_bool(conflicts.scaleOwnerChanged)
        .. ", attribution=unproven")
      for _, row in ipairs(report.methods) do
        if (row.requests or 0) > 0 then
          s_emit(row.owner .. ": req=" .. tostring(row.requests) .. ", exec=" .. tostring(row.executions)
            .. ", frame=" .. tostring(row.maxRequestsInFrame) .. "/" .. tostring(row.maxExecutionsInFrame)
            .. ", sec=" .. tostring(row.maxRequestsPerSecond) .. "/" .. tostring(row.maxExecutionsPerSecond)
            .. ", hidden=" .. tostring(row.hidden) .. ", unbuilt=" .. tostring(row.unbuilt)
            .. ", reentrant=" .. tostring(row.reentrant) .. ", maxMs=" .. string.format("%.3f", row.longestMs or 0)
            .. (row.firstOpenExecutions and (", firstOpen=" .. tostring(row.firstOpenExecutions)
              .. "/" .. string.format("%.3fms", row.firstOpenMs or 0)) or "")
            .. (row.steadyExecutions and (", steady=" .. tostring(row.steadyExecutions)
              .. "/" .. string.format("%.3fms", row.steadyLongestMs or 0)) or "")
            .. ", source=" .. tostring(row.lastSource or "direct"))
        end
      end
      local resources = report.resourcesEnd
      local resourcesStart = report.resourcesStart
      if resources then
        s_emit("resources: SignalFireStartKB=" .. tostring(resourcesStart and resourcesStart.signalFireKB or "unsupported")
          .. ", endKB=" .. tostring(resources.signalFireKB or "unsupported")
          .. ", deltaKB=" .. tostring(resources.signalFireDeltaKB or "n/a")
          .. ", totalStartKB=" .. tostring(resourcesStart and resourcesStart.totalLuaKB or "unsupported")
          .. ", totalEndKB=" .. tostring(resources.totalLuaKB or "unsupported")
          .. ", totalDeltaKB=" .. tostring(resources.totalLuaDeltaKB or "n/a")
          .. ", loadedAddons=" .. tostring(resources.loadedAddons or "unsupported")
          .. ", firstPanels=" .. tostring(#(report.newlyBuiltPanels or {})))
      end
      for index = 1, math.min(4, #(report.cachePeakChanges or {})) do
        local row = report.cachePeakChanges[index]
        s_emit("cache peak delta " .. tostring(row.name) .. "=" .. tostring(row.delta)
          .. ", peak=" .. tostring(row.peak))
      end
      local recentStart = math.max(1, #report.recent - 7)
      for index = recentStart, #report.recent do
        local row = report.recent[index]
        s_emit("slow " .. tostring(row.owner) .. ": " .. string.format("%.3fms", row.elapsed or 0)
          .. ", level=" .. tostring(row.level or "none") .. ", reentrant=" .. s_bool(row.reentrant)
          .. ", cyclic=" .. s_bool(row.cyclic) .. ", source=" .. tostring(row.source or "direct"))
      end
      local errorStart = math.max(1, #report.errors - 5)
      for index = errorStart, #report.errors do
        local row = report.errors[index]
        s_emit("error " .. tostring(row.owner) .. ": " .. string.sub(tostring(row.error or "unknown"), 1, 240))
      end
      return report
    end

    function S:PrintConflicts()
      self:ProbeOwnership()
      local report = self:GetConflicts()
      s_emit("conflicts: SetItemRefState=" .. tostring(report.setItemRef and report.setItemRef.state or "unknown")
        .. ", currentChanged=" .. s_bool(report.setItemRefChanged)
        .. ", tooltipChanged=" .. s_bool(report.tooltipChanged)
        .. ", scaleOwnerChanged=" .. s_bool(report.scaleOwnerChanged)
        .. ", attribution=unproven")
      for _, addon in ipairs(report.addons) do
        s_emit("addon " .. addon.name .. ": loaded=" .. s_bool(addon.loaded)
          .. ", enabled=" .. tostring(addon.enabled or "unknown"))
      end
      for _, frame in ipairs(report.frames) do
        s_emit(frame.name .. ": state=" .. tostring(frame.state or "unknown")
          .. ", hits=" .. tostring(frame.hits or 0)
          .. ", maxDepth=" .. tostring(frame.maximumDepth or 0)
          .. ", generation=" .. tostring(frame.generation or "none")
          .. (frame.state == "unknown" and frame.error
            and (", probeError=" .. string.sub(tostring(frame.error), 1, 120)) or ""))
      end
      local filters = report.filters or {}
      s_emit("chat filters: expected=" .. tostring(filters.expectedSignalFireFilters or 0)
        .. ", known=" .. tostring(filters.knownSignalFireRegistrations or 0)
        .. ", calls=" .. tostring(filters.filterCalls or 0)
        .. ", classified=" .. tostring(filters.messagesClassified or 0)
        .. ", linked=" .. tostring(filters.messagesLinked or 0)
        .. ", parsed=" .. tostring(filters.messagesParsed or 0)
        .. ", queued=" .. tostring(filters.logicalRecordsQueued or 0)
        .. ", processed=" .. tostring(filters.logicalRecordsProcessed or 0)
        .. ", drops=" .. tostring(filters.drops or 0))
      s_emit("chat source/filter: candidates=" .. tostring(filters.candidateGateCalls or 0)
        .. ", TestParse=" .. tostring(filters.TestParseCalls or 0)
        .. ", receipts=" .. tostring(filters.filterReceipts or 0)
        .. ", rewritten=" .. tostring(filters.chatLinesRewritten or 0)
        .. ", historicalScans=" .. tostring(filters.historicalFullTableDuplicateScans or 0))
      s_emit("chat filter introspection: " .. report.filterIntrospection)
      s_emit("wrapper chains: " .. report.wrapperChainIntrospection)
      return report
    end

    function S:PrintResources(kind)
      local sample = self:SampleResources(kind)
      s_emit("resource sample: SignalFireKB=" .. tostring(sample.signalFireKB or "unsupported")
        .. ", deltaKB=" .. tostring(sample.signalFireDeltaKB or "n/a")
        .. ", totalLuaKB=" .. tostring(sample.totalLuaKB or "unsupported")
        .. ", totalDeltaKB=" .. tostring(sample.totalLuaDeltaKB or "n/a")
        .. ", loadedAddons=" .. tostring(sample.loadedAddons or "unsupported"))
      if kind == "cpu" then
        s_emit("CPU=" .. tostring(sample.signalFireCPU or "unsupported")
          .. ", delta=" .. tostring(sample.signalFireCPUDelta or "n/a")
          .. ", scriptProfile=" .. s_bool(sample.scriptProfile)
          .. ". Profiling is never enabled automatically and can reduce performance."
          .. (sample.scriptProfile and "" or " To sample CPU: /console scriptProfile 1, reload, then /sf diag cpu."))
      end
      return sample
    end

    function B:SF151_GetStabilityDiagnostics()
      return S:GetReport()
    end

    function B:SF151_GetConflictDiagnostics()
      return S:GetConflicts()
    end

    function B:SF151_HandleDiagnosticSlash(command)
      local cmd = tostring(command or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if cmd == "diag start" or cmd == "diag on" then
        S:Reset(); S.enabled=true
        if B.SF151_SetChatOwnershipDiagnostics then B:SF151_SetChatOwnershipDiagnostics(true) end
        S:Install(); S:SampleResources("memory")
        s_emit("Stability diagnostics enabled for this session. Deep traces remain off.")
        return true
      elseif cmd == "diag stop" or cmd == "diag off" then
        S.enabled=false; S.deep=false
        if B.SF151_SetChatOwnershipDiagnostics then B:SF151_SetChatOwnershipDiagnostics(false) end
        s_emit("Stability diagnostics disabled."); return true
      elseif cmd == "diag deep on" then
        S.deep=true; s_emit("Deep diagnostics enabled. Only slow/reentrant operations capture bounded traces."); return true
      elseif cmd == "diag deep off" then
        S.deep=false; s_emit("Deep diagnostics disabled."); return true
      elseif cmd == "diag reset" then
        local wasEnabled = S.enabled
        S:Reset()
        if wasEnabled then S:SampleResources("memory") end
        s_emit("Stability diagnostics reset."); return true
      elseif cmd == "diag report" then S:PrintReport(); return true
      elseif cmd == "diag conflicts" or cmd == "diag ownership" then S:PrintConflicts(); return true
      elseif cmd == "diag memory" then S:PrintResources("memory"); return true
      elseif cmd == "diag cpu" then S:PrintResources("cpu"); return true
      elseif cmd == "diag" then
        s_emit("Diagnostics are " .. (S.enabled and "enabled" or "disabled")
          .. ". Commands: /sf diag start, stop, report, ownership, conflicts, memory, cpu, reset, deep on, deep off")
        return true
      end
      return false
    end

    local oldPerfSlash = B.SF151_HandlePerfSlash
    B.SF151_HandlePerfSlash = function(self, command)
      if self:SF151_HandleDiagnosticSlash(command) then return true end
      return oldPerfSlash and oldPerfSlash(self, command) or false
    end

    local function s_install_slash()
      if not SlashCmdList then return end
      SLASH_SIGNALFIREDIAG1 = "/sfdiag"
      SlashCmdList["SIGNALFIREDIAG"] = function(input)
        local suffix = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
        return B:SF151_HandleDiagnosticSlash(suffix == "" and "diag" or ("diag " .. suffix))
      end
      if ChatFrame_ImportListToHash then pcall(ChatFrame_ImportListToHash, "SIGNALFIREDIAG") end
      if hash_SlashCmdList then
        hash_SlashCmdList["/sfdiag"] = SlashCmdList["SIGNALFIREDIAG"]
        hash_SlashCmdList["/SFDIAG"] = SlashCmdList["SIGNALFIREDIAG"]
      end
      if hash_SecureCmdList then
        hash_SecureCmdList["/sfdiag"] = SlashCmdList["SIGNALFIREDIAG"]
        hash_SecureCmdList["/SFDIAG"] = SlashCmdList["SIGNALFIREDIAG"]
      end
    end

    if B.SF151_RepairReleaseDatabase then B:SF151_RepairReleaseDatabase(BronzeLFG_DB) end
    s_install_slash()
    local eventFrame = CreateFrame("Frame")
    S.eventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
      if B.SF151_RepairReleaseDatabase then B:SF151_RepairReleaseDatabase(BronzeLFG_DB) end
      s_install_slash()
    end)
  end
end
-- SIGNALFIRE_PHASE10_STABILITY_END

-- Phase 12B affected-player parser safety canary. Session-only state; the
-- temporary timer has no OnUpdate script while inactive and retains one report.
-- SIGNALFIRE_PHASE12B_PARSER_CANARY_BEGIN
do
  local B = _G.BronzeLFG
  local P = _G.SignalFirePerf151
  local P3 = _G.SignalFireChatRuntime151 or {}
  if B and P and CreateFrame then
    local C = _G.SignalFireParserCanary151 or {}
    _G.SignalFireParserCanary151 = C
    C.generation = "1.5.2-phase12b-canary"
    C.maximumDuration = 120
    C.active = false
    C.shuttingDown = false

    local function c_now()
      if GetTime then return tonumber(GetTime() or 0) or 0 end
      if time then return tonumber(time() or 0) or 0 end
      return 0
    end

    local function c_fps()
      if not GetFramerate then return nil end
      local ok, value = pcall(GetFramerate)
      value = ok and tonumber(value) or nil
      return value and value >= 0 and value or nil
    end

    local function c_emit(message)
      local text = "|cffffd100SignalFire>|r " .. tostring(message or "")
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
      elseif print then
        print("SignalFire> " .. tostring(message or ""))
      end
    end

    local function c_number(value)
      return tonumber(value or 0) or 0
    end

    local function c_options()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      return BronzeLFG_DB.options
    end

    local function c_sync_options()
      local options = c_options()
      local function set_checked(control, value)
        if control and control.SetChecked then pcall(control.SetChecked, control, value) end
      end
      set_checked(B.optPublic, options.publicGroups ~= false)
      local panel = B.sfcpPanel
      if panel then
        set_checked(panel.publicGroups, options.publicGroups ~= false)
        set_checked(panel.inlineChatLinks, options.inlineChatLinks == true)
      end
    end

    local function c_stats()
      return B._sfP3Stats or {}
    end

    local function c_runtime_state()
      if type(P3.GetParserRuntimeState) ~= "function" then return {} end
      local ok, state = pcall(P3.GetParserRuntimeState)
      return ok and type(state) == "table" and state or {}
    end

    local function c_installed_filter_count(runtime)
      if type(B.SF151_GetChatFilterState) == "function" then
        local ok, state = pcall(B.SF151_GetChatFilterState, B)
        if ok and type(state) == "table" then
          return c_number(state.knownSignalFireRegistrations)
        end
      end
      return c_number(runtime and runtime.filtersInstalled)
    end

    local function c_forbidden_calls(stats)
      local total = 0
      for _, field in ipairs({
        "inlineCandidateCalls", "inlineParserCalls", "inlineQueueCalls",
        "inlineUpsertCalls", "inlineAddPublicGroupCalls", "inlineRefreshCalls",
        "inlineSavedVariableWrites", "inlineCacheSweepCalls",
      }) do
        total = total + c_number(stats[field])
      end
      return total
    end

    function C:SampleFPS()
      local value = c_fps()
      if not value then return nil end
      if not self.startingFPS then self.startingFPS = value end
      if not self.minimumFPS or value < self.minimumFPS then self.minimumFPS = value end
      self.endingFPS = value
      return value
    end

    function C:CheckSafety()
      if not self.active or self.shuttingDown then return self.active end
      local stats = c_stats()
      if c_number(stats.parserErrors) > 0 then return self:AbortSafety("parser error") end
      if type(B._sfP3Queue) ~= "table" then return self:AbortSafety("queue corruption") end
      if #B._sfP3Queue > 40 then return self:AbortSafety("hard queue bound exceeded") end
      if c_number(stats.workerMaximumFrameMs) > 10 then
        return self:AbortSafety("worker frame exceeded 10 ms")
      end
      if c_forbidden_calls(stats) > 0 then
        return self:AbortSafety("forbidden ChatFrame render work")
      end
      if P3._filterInstalled == true then
        return self:AbortSafety("Public Groups render filters appeared while Chat Links were Off")
      end
      if c_number(self.chatMaintenanceRuns) > 0 then
        return self:AbortSafety("chat-triggered cache maintenance")
      end
      return true
    end

    function C:CheckRuntime(stage)
      if not self.active or self.shuttingDown then return false end
      if c_now() >= c_number(self.deadline) then
        self:Shutdown("completed", "deadline reached")
        return false
      end
      return self:CheckSafety()
    end

    local function c_build_report(self, outcome, reason, stoppedAt)
      local stats = c_stats()
      local runtime = c_runtime_state()
      local actual = math.max(0, c_number(stoppedAt) - c_number(self.startedAt))
      return {
        generation=self.generation,
        runtimeGeneration=P3.generation,
        requestedDuration=c_number(self.requestedDuration),
        actualDuration=actual,
        outcome=tostring(outcome or "aborted"),
        abortReason=tostring(reason or "none"),
        parserEnabled=c_options().publicGroups ~= false,
        chatLinksEnabled=c_options().inlineChatLinks == true,
        sourceEventsReceived=c_number(stats.sourceEventsReceived),
        candidateGateCalls=c_number(stats.candidateGateCalls),
        candidatesAccepted=c_number(stats.candidateGateAccepted),
        candidatesRejected=c_number(stats.candidateGateRejected),
        TestParseCalls=c_number(stats.TestParseCalls),
        queueRecordsCreated=c_number(stats.queueRecordsCreated),
        queueRecordsProcessed=c_number(stats.queueRecordsProcessed),
        queueMaximumDepth=c_number(stats.queueMaximumDepth),
        queueDrops=c_number(stats.queueDrops),
        workerActiveFrames=c_number(stats.workerFramesActive),
        workerBudgetStopsByCount=c_number(stats.workerBudgetStopsByCount),
        workerBudgetStopsByTime=c_number(stats.workerBudgetStopsByTime),
        workerMaximumFrameMs=c_number(stats.workerMaximumFrameMs),
        workerMaximumRecordMs=c_number(stats.workerMaximumRecordMs),
        filtersInstalled=c_number(runtime.filtersInstalled),
        filterReceipts=c_number(stats.filterReceipts),
        forbiddenRenderPathCalls=c_forbidden_calls(stats),
        chatMaintenanceRuns=c_number(self.chatMaintenanceRuns),
        startingFPS=self.startingFPS,
        minimumFPS=self.minimumFPS,
        endingFPS=self.endingFPS,
      }
    end

    function C:Shutdown(outcome, reason)
      if self.shuttingDown then return false end
      if not self.active then return false end
      self.shuttingDown = true
      local stoppedAt = c_now()
      self:SampleFPS()
      local options = c_options()
      options.publicGroups = false
      options.inlineChatLinks = false
      P3._canaryDeadline = nil
      if type(P3.StopParserWork) == "function" then
        pcall(P3.StopParserWork, tostring(reason or outcome or "canary stopped"))
      end
      if type(P3.ReconcileFilterRegistration) == "function" then
        pcall(P3.ReconcileFilterRegistration)
      end
      c_sync_options()
      self.active = false
      if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
      end
      P3._canaryDiagnosticsEnabled = false
      self.lastReport = c_build_report(self, outcome, reason, stoppedAt)
      if outcome == "completed" then
        c_emit("SignalFire parser canary completed.")
        c_emit("Parsing and Chat Links are now Off.")
      else
        self.lastAbortReason = tostring(reason or "manual abort")
        c_emit("SignalFire parser canary aborted" .. (reason and (": " .. tostring(reason)) or "") .. ".")
        c_emit("Parsing and Chat Links are Off.")
      end
      self.shuttingDown = false
      return true
    end

    function C:AbortSafety(reason)
      if not self.active then return false end
      return self:Shutdown("aborted", tostring(reason or "runtime safety trigger"))
    end

    function C:ForceOff(reason, quiet)
      if self.active then return self:Shutdown("aborted", tostring(reason or "parser off")) end
      local options = c_options()
      options.publicGroups = false
      options.inlineChatLinks = false
      P3._canaryDeadline = nil
      P3._canaryDiagnosticsEnabled = false
      if type(P3.StopParserWork) == "function" then
        pcall(P3.StopParserWork, tostring(reason or "parser off"))
      end
      if type(P3.ReconcileFilterRegistration) == "function" then
        pcall(P3.ReconcileFilterRegistration)
      end
      c_sync_options()
      if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
      end
      if not quiet then c_emit("Parsing and Chat Links are Off.") end
      return true
    end

    function C:GetIdentity()
      local runtime = c_runtime_state()
      local stability = _G.SignalFireStability151 or {}
      local version = SignalFire_GetVersion and SignalFire_GetVersion()
        or tostring(SignalFire_VERSION or "missing")
      local row = {
        version=tostring(version or "missing"),
        releaseChannel=tostring(SignalFire_RELEASE_CHANNEL or "missing"),
        releaseName=tostring(SignalFire_RELEASE_NAME or "missing"),
        chatRuntimeGeneration=tostring(P3.generation or "missing"),
        diagnosticGeneration=tostring(stability.generation or "missing"),
        parserWorkerGeneration=tostring(runtime.workerGeneration or P3.workerGeneration or "missing"),
        canaryGeneration=tostring(self.generation or "missing"),
        sourceOwnerActive=runtime.sourceOwnerActive == true,
        workerOwnerActive=runtime.workerOwnerActive == true,
        shutdownOwnerActive=runtime.shutdownOwnerActive == true
          and type(P3.StopParserWork) == "function",
        sourceProcessingActive=runtime.sourceActive == true,
        workerRunning=runtime.workerActive == true or runtime.workerScript == true,
        queueDepth=c_number(runtime.queueDepth),
        parserEnabled=c_options().publicGroups ~= false,
        chatLinksEnabled=c_options().inlineChatLinks == true,
        installedFilters=c_installed_filter_count(runtime),
        mismatches={},
      }
      local function require_match(ok, label)
        if not ok then row.mismatches[#row.mismatches + 1] = label end
      end
      require_match(row.version == "1.5.2", "version")
      require_match(row.releaseChannel == "rc", "release channel")
      require_match(row.releaseName == "SignalFire 1.5.2 Phase 12B Canary RC", "release name")
      require_match(row.diagnosticGeneration == "1.5.1-phase10b", "diagnostic generation")
      require_match(string.find(row.chatRuntimeGeneration, "phase12b", 1, true) ~= nil,
        "chat runtime generation")
      require_match(string.find(row.parserWorkerGeneration, "phase12b", 1, true) ~= nil,
        "parser worker generation")
      require_match(row.canaryGeneration == "1.5.2-phase12b-canary", "canary generation")
      require_match(row.sourceOwnerActive, "source owner")
      require_match(row.workerOwnerActive, "worker owner")
      require_match(row.shutdownOwnerActive, "shutdown owner")
      require_match(not row.sourceProcessingActive, "source processing must be inactive")
      require_match(not row.workerRunning, "worker must be sleeping")
      require_match(row.queueDepth == 0, "parser queue must be empty")
      require_match(not row.parserEnabled, "parser must be Off before start")
      require_match(not row.chatLinksEnabled, "Chat Links must be Off")
      require_match(row.installedFilters == 0, "installed filter count")
      row.matchesExpected = #row.mismatches == 0
      return row
    end

    function C:PrintIdentity(row)
      row = row or self:GetIdentity()
      c_emit("parser identity: version=" .. tostring(row.version)
        .. ", channel=" .. tostring(row.releaseChannel)
        .. ", name=" .. tostring(row.releaseName))
      c_emit("runtime: chat=" .. tostring(row.chatRuntimeGeneration)
        .. ", diagnostics=" .. tostring(row.diagnosticGeneration)
        .. ", worker=" .. tostring(row.parserWorkerGeneration)
        .. ", canary=" .. tostring(row.canaryGeneration))
      c_emit("owners: source=" .. tostring(row.sourceOwnerActive)
        .. ", worker=" .. tostring(row.workerOwnerActive)
        .. ", shutdown=" .. tostring(row.shutdownOwnerActive))
      c_emit("state: parser=" .. (row.parserEnabled and "On" or "Off")
        .. ", Chat Links=" .. (row.chatLinksEnabled and "On" or "Off")
        .. ", filters=" .. tostring(row.installedFilters)
        .. ", queue=" .. tostring(row.queueDepth)
        .. ", identity=" .. (row.matchesExpected and "MATCH" or "MISMATCH"))
      if not row.matchesExpected then
        c_emit("identity mismatches: " .. table.concat(row.mismatches, ", "))
      end
      return row
    end

    function C:Start(duration)
      if self.active then
        c_emit("A parser canary is already running. Use /sf parser status or /sf parser abort.")
        return false
      end
      duration = tonumber(duration)
      if not duration or duration <= 0 or duration > self.maximumDuration or duration ~= math.floor(duration) then
        c_emit("Canary duration must be a whole number from 1 to 120 seconds.")
        return false
      end

      local options = c_options()
      self.previousParserEnabled = options.publicGroups ~= false
      self.previousChatLinksEnabled = options.inlineChatLinks == true
      self:ForceOff("canary identity check", true)
      local identity = self:GetIdentity()
      if not identity.matchesExpected or type(P3.Apply) ~= "function"
        or type(P3.ReconcileFilterRegistration) ~= "function" then
        if type(P3.Apply) ~= "function" then
          identity.mismatches[#identity.mismatches + 1] = "parser apply owner"
          identity.matchesExpected = false
        end
        if type(P3.ReconcileFilterRegistration) ~= "function" then
          identity.mismatches[#identity.mismatches + 1] = "filter reconciliation owner"
          identity.matchesExpected = false
        end
        self:PrintIdentity(identity)
        c_emit("The installed SignalFire files do not match the canary build. Canary not started.")
        return false
      end

      self.requestedDuration = duration
      self.startedAt = c_now()
      self.deadline = self.startedAt + duration
      self.lastAbortReason = nil
      self.chatMaintenanceRuns = 0
      self.startingFPS = nil
      self.minimumFPS = nil
      self.endingFPS = nil
      self.fpsElapsed = 0
      self.active = true
      P3._canaryDeadline = self.deadline
      P3._canaryDiagnosticsEnabled = true
      B._sfP3Stats = {}
      P3._frameDiagnostics = {}
      options.publicGroups = true
      options.inlineChatLinks = false
      P3.Apply()
      P3.ReconcileFilterRegistration()
      c_sync_options()
      self:SampleFPS()
      if P3._filterInstalled == true then
        self:AbortSafety("Public Groups render filters appeared while Chat Links were Off")
        return false
      end

      self.frame:SetScript("OnUpdate", function(frame, elapsed)
        if not C.active then frame:SetScript("OnUpdate", nil); frame:Hide(); return end
        C.fpsElapsed = c_number(C.fpsElapsed) + c_number(elapsed)
        if C.fpsElapsed >= .25 then C.fpsElapsed = 0; C:SampleFPS() end
        C:CheckRuntime("canary timer")
      end)
      self.frame:Show()
      c_emit("SignalFire parser canary started for " .. tostring(duration) .. " seconds.")
      c_emit("Chat Links are Off.")
      c_emit("Use /sf parser abort if performance drops.")
      return true
    end

    function C:GetStatus()
      local runtime = c_runtime_state()
      local now = c_now()
      local elapsed = self.active and math.max(0, now - c_number(self.startedAt)) or 0
      local remaining = self.active and math.max(0, c_number(self.deadline) - now) or 0
      local stats = c_stats()
      return {
        version=SignalFire_GetVersion and SignalFire_GetVersion() or tostring(SignalFire_VERSION or "1.5.2"),
        runtimeGeneration=P3.generation,
        parserEnabled=c_options().publicGroups ~= false,
        chatLinksEnabled=c_options().inlineChatLinks == true,
        canaryActive=self.active == true,
        requestedDuration=c_number(self.requestedDuration),
        elapsedSeconds=elapsed,
        remainingSeconds=remaining,
        sourceActive=runtime.sourceActive == true,
        workerActive=runtime.workerActive == true,
        queueDepth=c_number(runtime.queueDepth),
        filtersInstalled=c_number(runtime.filtersInstalled),
        TestParseCalls=c_number(stats.TestParseCalls),
        processedRecords=c_number(stats.queueRecordsProcessed),
        queueDrops=c_number(stats.queueDrops),
        queueMaximumDepth=c_number(stats.queueMaximumDepth),
        workerMaximumFrameMs=c_number(stats.workerMaximumFrameMs),
        lastAbortReason=self.lastAbortReason or "none",
      }
    end

    function C:PrintStatus()
      local row = self:GetStatus()
      c_emit("parser status: version=" .. tostring(row.version)
        .. ", runtime=" .. tostring(row.runtimeGeneration)
        .. ", parser=" .. (row.parserEnabled and "enabled" or "disabled")
        .. ", links=" .. (row.chatLinksEnabled and "enabled" or "disabled")
        .. ", canary=" .. (row.canaryActive and "active" or "inactive"))
      c_emit("duration=" .. tostring(row.requestedDuration)
        .. ", elapsed=" .. string.format("%.1f", row.elapsedSeconds)
        .. ", remaining=" .. string.format("%.1f", row.remainingSeconds)
        .. ", source=" .. (row.sourceActive and "active" or "inactive")
        .. ", worker=" .. (row.workerActive and "active" or "sleeping"))
      c_emit("queue=" .. tostring(row.queueDepth) .. ", filters=" .. tostring(row.filtersInstalled)
        .. ", TestParse=" .. tostring(row.TestParseCalls)
        .. ", processed=" .. tostring(row.processedRecords)
        .. ", drops=" .. tostring(row.queueDrops)
        .. ", maxDepth=" .. tostring(row.queueMaximumDepth)
        .. ", maxFrameMs=" .. string.format("%.3f", row.workerMaximumFrameMs)
        .. ", lastAbort=" .. tostring(row.lastAbortReason))
      return row
    end

    function C:PrintReport()
      local row = self.lastReport
      if not row then c_emit("No parser canary report is available for this session."); return nil end
      c_emit("parser report: requested=" .. tostring(row.requestedDuration)
        .. "s, actual=" .. string.format("%.1f", row.actualDuration)
        .. "s, outcome=" .. tostring(row.outcome) .. ", reason=" .. tostring(row.abortReason))
      c_emit("afterward: parser=" .. (row.parserEnabled and "On" or "Off")
        .. ", links=" .. (row.chatLinksEnabled and "On" or "Off")
        .. ", filters=" .. tostring(row.filtersInstalled))
      c_emit("source=" .. tostring(row.sourceEventsReceived)
        .. ", candidates=" .. tostring(row.candidateGateCalls)
        .. " (accepted=" .. tostring(row.candidatesAccepted) .. ", rejected=" .. tostring(row.candidatesRejected) .. ")"
        .. ", TestParse=" .. tostring(row.TestParseCalls))
      c_emit("queue=" .. tostring(row.queueRecordsCreated) .. "/" .. tostring(row.queueRecordsProcessed)
        .. ", maxDepth=" .. tostring(row.queueMaximumDepth) .. ", drops=" .. tostring(row.queueDrops)
        .. ", workerFrames=" .. tostring(row.workerActiveFrames)
        .. ", stops=" .. tostring(row.workerBudgetStopsByCount) .. "/" .. tostring(row.workerBudgetStopsByTime))
      c_emit("timing: maxFrameMs=" .. string.format("%.3f", row.workerMaximumFrameMs)
        .. ", maxRecordMs=" .. string.format("%.3f", row.workerMaximumRecordMs)
        .. ", filterReceipts=" .. tostring(row.filterReceipts)
        .. ", forbidden=" .. tostring(row.forbiddenRenderPathCalls)
        .. ", chatMaintenance=" .. tostring(row.chatMaintenanceRuns))
      c_emit("FPS: start=" .. tostring(row.startingFPS or "unavailable")
        .. ", minimum=" .. tostring(row.minimumFPS or "unavailable")
        .. ", end=" .. tostring(row.endingFPS or "unavailable"))
      return row
    end

    function B:SF152_HandleParserSlash(command)
      local cmd = tostring(command or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if cmd == "parser identity" then
        C:PrintIdentity()
        return true
      elseif string.sub(cmd, 1, 13) == "parser canary" then
        local suffix = cmd:gsub("^parser%s+canary", ""):gsub("^%s+", ""):gsub("%s+$", "")
        local duration = suffix == "" and 10 or tonumber(suffix)
        if suffix ~= "" and not duration then
          c_emit("Canary duration must be numeric and no greater than 120 seconds.")
          return true
        end
        C:Start(duration)
        return true
      elseif cmd == "parser abort" then
        if not C:Shutdown("aborted", "manual abort") then
          C:ForceOff("manual abort", true)
          c_emit("No parser canary was active. Parsing and Chat Links are Off.")
        end
        return true
      elseif cmd == "parser off" then
        C:ForceOff("parser off", false)
        return true
      elseif cmd == "parser status" then
        C:PrintStatus()
        return true
      elseif cmd == "parser report" then
        C:PrintReport()
        return true
      elseif cmd == "parser" then
        c_emit("Commands: /sf parser identity, canary [1-120], abort, off, status, report")
        return true
      end
      return false
    end

    C.frame = C.frame or CreateFrame("Frame")
    C.frame:SetScript("OnUpdate", nil)
    C.frame:Hide()
    C:ForceOff("canary build startup", true)

    local lifecycle = _G.SignalFireCacheLifecycle151
    if lifecycle and not C._cacheRunWrapped and type(lifecycle.Run) == "function" then
      C._cacheRunWrapped = true
      C._oldCacheRun = lifecycle.Run
      lifecycle.Run = function(self, reason, ...)
        local why = tostring(reason or "")
        if C.active and string.find(string.lower(why), "chat", 1, true) then
          C.chatMaintenanceRuns = c_number(C.chatMaintenanceRuns) + 1
          C:AbortSafety("chat-triggered cache maintenance")
          return false, 0
        end
        return C._oldCacheRun(self, reason, ...)
      end
    end

    local oldPerfSlash = B.SF151_HandlePerfSlash
    B.SF151_HandlePerfSlash = function(self, command)
      if self:SF152_HandleParserSlash(command) then return true end
      return oldPerfSlash and oldPerfSlash(self, command) or false
    end
    if P.InstallSlash then P:InstallSlash() end
  end
end
-- SIGNALFIRE_PHASE12B_PARSER_CANARY_END
