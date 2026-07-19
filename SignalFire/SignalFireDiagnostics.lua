-- SignalFire 1.5.1 developer-only runtime diagnostics.
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
    CL.generation = "1.5.1-perf-phase9"
    CL.chatInterval = 256
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

    CL.inventory = {
      {name="session.publicGroups", owner="Phase 5 identity / Phase 9 capacity", key="stable listing id", maximum=512, ttl="publicExpire", cleanup="ExpirePublicGroups plus Phase 9 chat checkpoint", persistence="session"},
      {name="session.listings", owner="Phase 9", key="listing id", maximum=256, ttl="900s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.applicants", owner="Phase 9", key="player name", maximum=128, ttl="7200s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.chatGuildListings", owner="Phase 9", key="normalized guild", maximum=256, ttl="21600s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.guilds", owner="Phase 9", key="guild identity", maximum=256, ttl="14d when timestamped", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.onlineUsers", owner="Phase 9", key="player name", maximum=512, ttl="300s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.sfnStatuses", owner="Phase 9", key="player name", maximum=512, ttl="300s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.knownClassNames", owner="Phase 9 capacity / class resolver", key="normalized player", maximum=256, ttl="session capacity", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.notificationSeen", owner="Phase 9", key="listing signature", maximum=256, ttl="120s", cleanup="chat checkpoint/world entry", persistence="session"},
      {name="session.publicWho", owner="Phase 9", key="normalized player", maximum=128, ttl="120s", cleanup="chat checkpoint/world entry", persistence="session"},
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
      {name="db.eventNoticeState", owner="Phase 9 orphan cleanup", key="event/notice id", maximum=60, ttl="source lifetime", cleanup="chat checkpoint/world entry", persistence="BronzeLFG_DB"},
      {name="db.favoriteAlertState", owner="Phase 9", key="player/listing signature", maximum=256, ttl="1-2h", cleanup="chat checkpoint/world entry", persistence="BronzeLFG_DB"},
      {name="db.userSettings", owner="user settings", key="user-selected value", maximum="deterministic fields", ttl="user controlled", cleanup="explicit user action", persistence="BronzeLFG_DB"},
    }

    function CL:Run(reason)
      if self.running then
        cl_note("nestedRunsSkipped", 1)
        return false, 0
      end
      self.running = true
      local started = cl_enabled() and cl_clock() or nil
      local results = {pcall(function()
        local stamp = cl_now()
        local removed = 0
        removed = removed + cl_cleanup_dead_compatibility()
        removed = removed + cl_cleanup_public(stamp)
        removed = removed + cl_cleanup_browse(stamp)
        removed = removed + cl_cleanup_network(stamp)
        removed = removed + cl_cleanup_guilds(stamp)
        removed = removed + cl_cleanup_who(stamp)
        removed = removed + cl_cleanup_alerts(stamp)
        removed = removed + cl_cleanup_community()
        cl_note("runs", 1)
        cl_note("entriesRemoved", removed)
        CL.lastReason = tostring(reason or "manual")
        CL.lastRunAt = stamp
        return removed
      end)}
      self.running = false
      if started then
        local elapsed = math.max(0, cl_clock() - started)
        cl_note("cleanupMsTotal", elapsed)
        cl_max("cleanupMsMaximum", elapsed)
      end
      if not results[1] then
        cl_record_error("run." .. tostring(reason or "manual"), results[2])
        return false, 0
      end
      return true, tonumber(results[2] or 0) or 0
    end

    function CL:ObserveChat()
      self.chatEvents = (tonumber(self.chatEvents or 0) or 0) + 1
      if cl_enabled() then cl_note("chatEvents", 1) end
      if self.chatEvents % self.chatInterval == 0 then return self:Run("chat-checkpoint") end
      return false, 0
    end

    function CL:GetDiagnostics(includeMemory)
      local result = {
        generation=self.generation, running=self.running == true, lastReason=self.lastReason,
        lastRunAt=self.lastRunAt or 0, chatEvents=self.chatEvents or 0,
        chatInterval=self.chatInterval, inventoryEntries=#self.inventory,
        errors=self.errors, peaks=self.peaks,
      }
      for key, value in pairs(self.stats or {}) do result[key] = value end
      if includeMemory and collectgarbage then result.memoryKB = tonumber(collectgarbage("count") or 0) or 0 end
      return result
    end

    function B:SF151_RunCacheMaintenance(reason)
      return CL:Run(reason or "explicit")
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
      B.SF151_RunSlowMaintenance = function(self, ...)
        local results = {pcall(CL.oldSlowMaintenance, self, ...)}
        local cleanup = {pcall(CL.Run, CL, "slow-maintenance")}
        if not results[1] then error(results[2], 0) end
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
        local ok, removed = CL:Run("slash")
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r cache cleanup "
            .. (ok and "complete" or "failed") .. ": removed " .. tostring(removed or 0) .. " entries.")
        end
        return true
      elseif cmd == "perf cachelife" or cmd == "perf cachelife memory" then
        local row = CL:GetDiagnostics(cmd == "perf cachelife memory")
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r cache lifecycle " .. tostring(row.generation)
            .. ": runs=" .. tostring(row.runs or 0) .. ", removed=" .. tostring(row.entriesRemoved or 0)
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
    local eventFrame = CreateFrame("Frame")
    CL.eventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
    eventFrame:RegisterEvent("CHAT_MSG_SAY")
    eventFrame:RegisterEvent("CHAT_MSG_YELL")
    eventFrame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CL:Run(string.lower(event))
      else
        CL:ObserveChat()
      end
    end)
  end
end
-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_END
