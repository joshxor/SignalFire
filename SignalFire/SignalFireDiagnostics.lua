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
    return {
      {"session.publicGroups", B.publicGroups, false},
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
      {"session.notificationSeen", B._notifySeen, false},
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
