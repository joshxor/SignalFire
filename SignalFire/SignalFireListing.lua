-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Ascension listing tools
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireAscensionListingPolish = SignalFireAscensionListingPolish or {}
    local SFALP = SignalFireAscensionListingPolish

    SFALP.ASC_STANDARD = "Standard Dungeons"
    SFALP.ASC_SPLIT = "Split Wings"
    SFALP.ASC_CUSTOM = "Ascension Custom"
    SFALP.ASC_MYTHIC = "Mythic+ Pool"
    SFALP.RDF = "Random Dungeon Finder"
    SFALP.RDF_HEROIC = "Random Heroic Dungeon Finder"
    SFALP.RDF_MYTHIC = "Random Mythic Dungeon Finder"

    local function sfalp_copy(src)
      local out = {}
      for i, v in ipairs(src or {}) do out[i] = v end
      return out
    end

    local function sfalp_contains(list, value)
      for _, v in ipairs(list or {}) do
        if v == value then return true end
      end
      return false
    end

    local function sfalp_is_rdf_activity(value)
      return value == SFALP.RDF or value == SFALP.RDF_HEROIC or value == SFALP.RDF_MYTHIC
    end

    local function sfalp_rdf_difficulty(value)
      if value == SFALP.RDF_HEROIC then return "Heroic" end
      if value == SFALP.RDF_MYTHIC then return "Mythic+" end
      return "Normal"
    end

    local function sfalp_append_unique(dst, src)
      for _, v in ipairs(src or {}) do
        if not sfalp_contains(dst, v) then table.insert(dst, v) end
      end
    end

    local function sfalp_profile_id()
      if BLFG and BLFG.SF143_GetProfileId then
        local ok, id = pcall(function() return BLFG:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sfalp_profile()
      local id = sfalp_profile_id()
      if SignalFireProfiles and SignalFireProfiles[id] then return SignalFireProfiles[id] end
      return SignalFireProfiles and SignalFireProfiles.Triumvirate or nil
    end

    local function sfalp_is_ascension()
      return sfalp_profile_id() == "Ascension"
    end

    local function sfalp_dd(d)
      if not d then return "" end
      if BLFG_DropdownText then return tostring(BLFG_DropdownText(d) or "") end
      if UIDropDownMenu_GetText then return tostring(UIDropDownMenu_GetText(d) or "") end
      return ""
    end

    local function sfalp_set_dd(d, value)
      if not d then return end
      value = tostring(value or "")
      if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(d, value) end
      if UIDropDownMenu_SetText then UIDropDownMenu_SetText(d, value) end
    end

    local function sfalp_text(box)
      if box and box.GetText then return tostring(box:GetText() or "") end
      return ""
    end

    local function sfalp_set_text(box, value)
      if box and box.SetText then box:SetText(tostring(value or "")) end
    end

    local function sfalp_force_values(d, values, selected)
      if not d then return selected or "" end
      d.values = values or {}
      selected = tostring(selected or sfalp_dd(d) or "")
      if not sfalp_contains(d.values, selected) then selected = d.values[1] or "" end
      sfalp_set_dd(d, selected)
      return selected
    end

    local function sfalp_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfalp_ascension_lists()
      local p = sfalp_profile()
      local modes = p and p.dungeonModeLists or {}
      local standard = sfalp_copy(modes and modes["Ascension: Standard Dungeons"] or {})
      local custom = sfalp_copy(modes and modes["Ascension: Custom Dungeons"] or {})
      local split = {}

      if p and p.dungeonActivityModes then
        for _, mode in ipairs(p.dungeonActivityModes) do
          local name = tostring(mode or "")
          if string.find(name, "Wings", 1, true) then sfalp_append_unique(split, modes and modes[mode] or {}) end
        end
      else
        for mode, list in pairs(modes or {}) do
          local name = tostring(mode or "")
          if string.find(name, "Wings", 1, true) then sfalp_append_unique(split, list) end
        end
      end

      local mythic = sfalp_copy((p and p.keys) or (p and p.dungeons) or {})
      if #standard == 0 and p then standard = sfalp_copy(p.dungeons or {}) end
      if #mythic == 0 then
        sfalp_append_unique(mythic, standard)
        sfalp_append_unique(mythic, split)
        sfalp_append_unique(mythic, custom)
      end

      return standard, split, custom, mythic
    end

    local function sfalp_ascension_list_for_mode(mode)
      local standard, split, custom, mythic = sfalp_ascension_lists()
      if mode == SFALP.ASC_STANDARD then return standard end
      if mode == SFALP.ASC_SPLIT then return split end
      if mode == SFALP.ASC_CUSTOM then return custom end
      if mode == SFALP.ASC_MYTHIC then return mythic end
      return nil
    end

    local function sfalp_category_for_dungeon(dungeon)
      if not dungeon or dungeon == "" then return SFALP.ASC_STANDARD end
      local standard, split, custom = sfalp_ascension_lists()
      if sfalp_contains(custom, dungeon) then return SFALP.ASC_CUSTOM end
      if sfalp_contains(split, dungeon) then return SFALP.ASC_SPLIT end
      if sfalp_contains(standard, dungeon) then return SFALP.ASC_STANDARD end
      return SFALP.ASC_STANDARD
    end

    local function sfalp_map_old_category(value)
      value = tostring(value or "")
      if value == SFALP.ASC_STANDARD or value == SFALP.ASC_SPLIT or value == SFALP.ASC_CUSTOM or value == SFALP.ASC_MYTHIC then
        return value
      end
      if value == "Ascension: Standard Dungeons" then return SFALP.ASC_STANDARD end
      if value == "Ascension: Custom Dungeons" then return SFALP.ASC_CUSTOM end
      if string.find(value, "Ascension:", 1, true) and string.find(value, "Wings", 1, true) then return SFALP.ASC_SPLIT end
      return value
    end

    local function sfalp_ensure_store()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.createByProfile = BronzeLFG_DB.createByProfile or {}
      BronzeLFG_DB.create = BronzeLFG_DB.create or {}
      return BronzeLFG_DB.createByProfile
    end

    local function sfalp_default_state(id)
      if id == "Ascension" then
        local standard = sfalp_ascension_list_for_mode(SFALP.ASC_STANDARD) or {}
        return {
          type = "Dungeon",
          activity = SFALP.ASC_STANDARD,
          specificDungeon = standard[1] or "Deadmines",
          difficulty = "Normal",
          key = "",
          minItemLevel = "",
          maxMembers = "5",
          voice = "None",
          loot = "Group Loot",
          note = "",
          needTank = true,
          needHealer = true,
          needDPS = true,
        }
      end
      return {
        type = "Dungeon",
        activity = "Random Dungeon Finder",
        specificDungeon = "",
        difficulty = "Normal",
        key = "",
        minItemLevel = "",
        maxMembers = "5",
        voice = "None",
        loot = "Group Loot",
        note = "",
        needTank = true,
        needHealer = true,
        needDPS = true,
      }
    end

    local function sfalp_migrate_state(id)
      local store = sfalp_ensure_store()
      if type(store[id]) == "table" then return store[id] end

      local c = BronzeLFG_DB.create or {}
      local state = sfalp_default_state(id)
      state.type = tostring(c.type or state.type)
      state.activity = tostring(c.activity or state.activity)
      state.specificDungeon = tostring(c.specificDungeon or "")
      state.difficulty = tostring(c.difficulty or state.difficulty)
      state.key = tostring(c.key or "")
      state.minItemLevel = tostring(c.minItemLevel or "")
      state.maxMembers = tostring(c.maxMembers or state.maxMembers)
      state.voice = tostring(c.voice or state.voice)
      state.loot = tostring(c.loot or state.loot)
      state.note = tostring(c.note or "")

      if id == "Ascension" then
        local dungeon = state.specificDungeon
        if dungeon == "" and sfalp_ascension_list_for_mode(state.activity) == nil then dungeon = state.activity end
        if state.type == "Mythic+" or (state.type == "Dungeon" and state.difficulty == "Mythic+") then
          state.type = "Mythic+"
          state.activity = SFALP.ASC_MYTHIC
          state.difficulty = "Mythic+"
        elseif state.type == "Dungeon" then
          local mapped = sfalp_map_old_category(state.activity)
          if sfalp_is_rdf_activity(mapped) then
            state.activity = mapped
          elseif sfalp_ascension_list_for_mode(mapped) then
            state.activity = mapped
          else
            state.activity = sfalp_category_for_dungeon(dungeon)
          end
          if sfalp_is_rdf_activity(state.activity) then
            state.difficulty = sfalp_rdf_difficulty(state.activity)
            state.specificDungeon = ""
          elseif state.difficulty ~= "Heroic" then
            state.difficulty = "Normal"
          end
        end
        if dungeon ~= "" and not sfalp_is_rdf_activity(state.activity) then state.specificDungeon = dungeon end
      elseif state.type == "Mythic+" then
        state.type = "Dungeon"
      end

      store[id] = state
      return state
    end

    function SFALP.SaveCurrent(self, id)
      self = self or BLFG
      if SFALP.loading or not self or not self.typeDrop then return end
      id = tostring(id or sfalp_profile_id())
      local store = sfalp_ensure_store()
      local state = store[id] or sfalp_default_state(id)

      state.type = sfalp_dd(self.typeDrop)
      state.activity = sfalp_dd(self.activityDrop)
      state.specificDungeon = sfalp_dd(self.specificDungeonDrop)
      state.difficulty = sfalp_dd(self.diffDrop)
      state.key = sfalp_text(self.keyBox)
      state.minItemLevel = sfalp_text(self.minIlvlBox)
      state.maxMembers = sfalp_text(self.maxBox)
      state.voice = sfalp_dd(self.voiceDrop)
      state.loot = sfalp_dd(self.lootDrop)
      state.note = sfalp_text(self.noteBox)
      state.needTank = self.needTank and self.needTank:GetChecked() and true or false
      state.needHealer = self.needHealer and self.needHealer:GetChecked() and true or false
      state.needDPS = self.needDPS and self.needDPS:GetChecked() and true or false

      if id == "Ascension" then
        if state.type == "Mythic+" then
          state.activity = SFALP.ASC_MYTHIC
          state.difficulty = "Mythic+"
        elseif state.type == "Dungeon" then
          state.activity = sfalp_map_old_category(state.activity)
          if sfalp_is_rdf_activity(state.activity) then
            state.specificDungeon = ""
            state.difficulty = sfalp_rdf_difficulty(state.activity)
          elseif not sfalp_ascension_list_for_mode(state.activity) then
            state.activity = sfalp_category_for_dungeon(state.specificDungeon)
          end
          if not sfalp_is_rdf_activity(state.activity) and state.difficulty ~= "Heroic" then state.difficulty = "Normal" end
          state.key = ""
        end
      end

      store[id] = state
    end

    local function sfalp_role_text(self)
      local roles = {}
      if self.needTank and self.needTank:GetChecked() then table.insert(roles, "T") end
      if self.needHealer and self.needHealer:GetChecked() then table.insert(roles, "H") end
      if self.needDPS and self.needDPS:GetChecked() then table.insert(roles, "D") end
      if #roles == 0 then return "Flexible" end
      return table.concat(roles, "/")
    end

    local function sfalp_final_activity(self)
      local mode = sfalp_dd(self.activityDrop)
      local list = BLFG_DungeonListForMode and BLFG_DungeonListForMode(mode) or nil
      if list and self.specificDungeonDrop then
        local specific = sfalp_dd(self.specificDungeonDrop)
        if specific ~= "" then return specific end
      end
      return mode
    end

    function SFALP.UpdatePreview(self)
      self = self or BLFG
      if not self or not self.sf1429Preview then return end

      local typeName = sfalp_dd(self.typeDrop)
      local activity = sfalp_final_activity(self)
      local difficulty = sfalp_dd(self.diffDrop)
      local key = sfalp_text(self.keyBox)
      local text

      if typeName == "Mythic+" then
        local level = key ~= "" and key or "?"
        text = "LFM Mythic+ " .. level .. " " .. tostring(activity ~= "" and activity or "Dungeon")
      elseif typeName == "Dungeon" then
        local prefix = difficulty == "Heroic" and not sfalp_is_rdf_activity(activity) and "Heroic " or ""
        text = "LFM " .. prefix .. tostring(activity ~= "" and activity or "Dungeon")
      elseif typeName == "Raid" then
        local prefix = (difficulty ~= "" and difficulty ~= "Normal") and (difficulty .. " ") or ""
        text = "LFM " .. prefix .. tostring(activity ~= "" and activity or "Raid")
      elseif typeName == "World Boss" then
        text = "LFM " .. tostring(activity ~= "" and activity or "World Boss")
      else
        text = "LFM " .. tostring(activity ~= "" and activity or "Custom Activity")
      end

      text = text .. " - Need " .. sfalp_role_text(self)
      self.sf1429Preview:SetText("|cffffcc00Preview:|r |cffffffff" .. text .. "|r")
    end

    local function sfalp_set_key_visibility(self, visible)
      if self.keyLabel then if visible then self.keyLabel:Show() else self.keyLabel:Hide() end end
      if self.keyBox then
        if visible then
          self.keyBox:Show()
          self.keyBox:EnableMouse(true)
          self.keyBox:SetTextColor(1, 1, 1)
        else
          self.keyBox:Hide()
          self.keyBox:EnableMouse(false)
          self.keyBox:SetTextColor(.45, .45, .45)
        end
      end
      if self.useKeystoneButton then
        if visible then
          self.useKeystoneButton:Show()
          self.useKeystoneButton:Enable()
        else
          self.useKeystoneButton:Hide()
          self.useKeystoneButton:Disable()
        end
      end
    end

    function SFALP.ApplyUI(self)
      self = self or BLFG
      if not self or not self.typeDrop then return end

      local isAsc = sfalp_is_ascension()
      local typeName = sfalp_dd(self.typeDrop)
      local activity = sfalp_dd(self.activityDrop)

      if isAsc then
        if SignalFireProfiles and SignalFireProfiles.Ascension then
          SignalFireProfiles.Ascension.activityTypes = {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"}
        end

        typeName = sfalp_force_values(self.typeDrop, {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"}, typeName)

        local activities = self:SF143_ListForType(typeName)
        activity = sfalp_force_values(self.activityDrop, activities, activity)

        local dungeonList = BLFG_DungeonListForMode and BLFG_DungeonListForMode(activity) or nil
        if dungeonList and self.specificDungeonDrop then
          sfalp_force_values(self.specificDungeonDrop, dungeonList, sfalp_dd(self.specificDungeonDrop))
          if self.specificDungeonLabel then self.specificDungeonLabel:Show(); self.specificDungeonLabel:SetText("Dungeon") end
          self.specificDungeonDrop:Show()
        elseif self.specificDungeonLabel and self.specificDungeonDrop then
          self.specificDungeonLabel:Hide()
          self.specificDungeonDrop:Hide()
        end

        local diffs = BLFG_CreateDifficultyListFor and BLFG_CreateDifficultyListFor(typeName, activity) or {"Normal"}
        local chosenDiff = sfalp_dd(self.diffDrop)
        if typeName == "Mythic+" then chosenDiff = "Mythic+" end
        chosenDiff = sfalp_force_values(self.diffDrop, diffs, chosenDiff)

        if typeName == "Mythic+" then
          if activity ~= SFALP.ASC_MYTHIC then
            activity = sfalp_force_values(self.activityDrop, {SFALP.ASC_MYTHIC}, SFALP.ASC_MYTHIC)
            local mythicList = BLFG_DungeonListForMode and BLFG_DungeonListForMode(activity) or nil
            if mythicList and self.specificDungeonDrop then
              sfalp_force_values(self.specificDungeonDrop, mythicList, sfalp_dd(self.specificDungeonDrop))
              self.specificDungeonDrop:Show()
              if self.specificDungeonLabel then self.specificDungeonLabel:Show() end
            end
          end
          sfalp_set_key_visibility(self, true)
        else
          sfalp_set_key_visibility(self, false)
        end
      end

      if self.maxBox then
        local max = tonumber(sfalp_text(self.maxBox) or "")
        if not max or max < 2 or max > 40 then
          local defaultMax = BLFG_DefaultMaxMembersFor and BLFG_DefaultMaxMembersFor(typeName, activity, sfalp_dd(self.diffDrop)) or 5
          self.maxBox:SetText(tostring(defaultMax or 5))
        end
      end

      SFALP.UpdatePreview(self)
    end

    local function sfalp_find_create_box(self)
      if self and self.typeDrop and self.typeDrop.GetParent then return self.typeDrop:GetParent() end
      return nil
    end

    function SFALP.EnsurePreview(self)
      self = self or BLFG
      if not self then return end
      -- SignalFireAmazingness already owns the visible Posting Preview panel.
      -- Reuse it rather than adding a second preview string near the bottom buttons.
      if self.SFAM_UpdateCreatePreview then self:SFAM_UpdateCreatePreview() end
    end

    local function sfalp_hook_script(frame, script, fn, marker)
      if not frame or frame[marker] then return end
      frame[marker] = true
      if frame.HookScript then
        frame:HookScript(script, fn)
      else
        local old = frame.GetScript and frame:GetScript(script) or nil
        frame:SetScript(script, function(...)
          if old then old(...) end
          fn(...)
        end)
      end
    end

    function SFALP.HookCreateControls(self)
      self = self or BLFG
      if not self or self.sf1429ControlsHooked then return end
      if not self.typeDrop then return end
      self.sf1429ControlsHooked = true

      local function changed()
        if SFALP.loading then return end
        SFALP.SaveCurrent(self)
        SFALP.UpdatePreview(self)
      end

      sfalp_hook_script(self.keyBox, "OnTextChanged", changed, "_sf1429KeyHook")
      sfalp_hook_script(self.minIlvlBox, "OnTextChanged", changed, "_sf1429MinHook")
      sfalp_hook_script(self.maxBox, "OnTextChanged", changed, "_sf1429MaxHook")
      sfalp_hook_script(self.noteBox, "OnTextChanged", changed, "_sf1429NoteHook")
      sfalp_hook_script(self.needTank, "OnClick", changed, "_sf1429TankHook")
      sfalp_hook_script(self.needHealer, "OnClick", changed, "_sf1429HealerHook")
      sfalp_hook_script(self.needDPS, "OnClick", changed, "_sf1429DPSHook")
      sfalp_hook_script(self.create, "OnHide", function() SFALP.SaveCurrent(self) end, "_sf1429HideHook")
    end

    function SFALP.LoadState(self, id)
      self = self or BLFG
      if not self or not self.typeDrop then return end
      id = tostring(id or sfalp_profile_id())
      local state = sfalp_migrate_state(id)
      local p = sfalp_profile()
      local typeValues = (p and p.activityTypes) or {"Dungeon", "Raid", "World Boss", "Custom Event"}

      if id ~= "Ascension" and state.type == "Mythic+" then state.type = "Dungeon" end
      if not sfalp_contains(typeValues, state.type) then state.type = typeValues[1] or "Dungeon" end
      if id == "Ascension" and state.type == "Dungeon" then state.activity = sfalp_map_old_category(state.activity) end
      if id == "Ascension" and state.type == "Mythic+" then state.activity = SFALP.ASC_MYTHIC end

      local activityValues = self:SF143_ListForType(state.type)
      if not sfalp_contains(activityValues, state.activity) then state.activity = activityValues[1] or "Custom Activity" end

      local dungeonList = BLFG_DungeonListForMode and BLFG_DungeonListForMode(state.activity) or nil
      if dungeonList and not sfalp_contains(dungeonList, state.specificDungeon) then
        state.specificDungeon = dungeonList[1] or ""
      end

      local difficulties = BLFG_CreateDifficultyListFor and BLFG_CreateDifficultyListFor(state.type, state.activity) or {"Normal"}
      if not sfalp_contains(difficulties, state.difficulty) then state.difficulty = difficulties[1] or "Normal" end
      if id == "Ascension" and state.type == "Mythic+" then
        state.difficulty = "Mythic+"
        state.maxMembers = "5"
      elseif id == "Ascension" and state.type == "Dungeon" then
        state.key = ""
      end

      SFALP.loading = true

      sfalp_set_dd(self.typeDrop, state.type)
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end

      sfalp_set_dd(self.activityDrop, state.activity)
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end

      sfalp_set_dd(self.diffDrop, state.difficulty)
      sfalp_set_dd(self.specificDungeonDrop, state.specificDungeon)
      sfalp_set_text(self.keyBox, state.key)
      sfalp_set_text(self.minIlvlBox, state.minItemLevel)
      sfalp_set_text(self.maxBox, state.maxMembers)
      sfalp_set_dd(self.voiceDrop, state.voice)
      sfalp_set_dd(self.lootDrop, state.loot)
      sfalp_set_text(self.noteBox, state.note)

      if self.needTank then self.needTank:SetChecked(state.needTank ~= false) end
      if self.needHealer then self.needHealer:SetChecked(state.needHealer ~= false) end
      if self.needDPS then self.needDPS:SetChecked(state.needDPS ~= false) end

      SFALP.ApplyUI(self)
      SFALP.loading = false
    end

    -- Add the dedicated pseudo-type only to Ascension. Listings are normalized back
    -- to type Dungeon at broadcast time so existing network/browse consumers remain compatible.
    if SignalFireProfiles and SignalFireProfiles.Ascension then
      SignalFireProfiles.Ascension.activityTypes = {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"}
    end

    local SFALP_OldListForType = BLFG.SF143_ListForType
    function BLFG:SF143_ListForType(typeName)
      if sfalp_is_ascension() then
        if typeName == "Dungeon" then
          return {SFALP.RDF, SFALP.RDF_HEROIC, SFALP.RDF_MYTHIC, SFALP.ASC_STANDARD, SFALP.ASC_SPLIT, SFALP.ASC_CUSTOM}
        end
        if typeName == "Mythic+" then return {SFALP.ASC_MYTHIC} end
      end
      return SFALP_OldListForType and SFALP_OldListForType(self, typeName) or {}
    end

    local SFALP_OldDungeonListForMode = _G.BLFG_DungeonListForMode
    function BLFG_DungeonListForMode(activity)
      if sfalp_is_ascension() then
        local list = sfalp_ascension_list_for_mode(activity)
        if list then return list end
      end
      return SFALP_OldDungeonListForMode and SFALP_OldDungeonListForMode(activity) or nil
    end

    local SFALP_OldDungeonModeForActivity = _G.BLFG_DungeonModeForActivity
    function BLFG_DungeonModeForActivity(activity)
      if sfalp_is_ascension() then
        if sfalp_is_rdf_activity(activity) then return nil end
        return sfalp_category_for_dungeon(activity)
      end
      return SFALP_OldDungeonModeForActivity and SFALP_OldDungeonModeForActivity(activity) or nil
    end

    local SFALP_OldActivitySupportsKey = _G.BLFG_ActivitySupportsKeyLevel
    function BLFG_ActivitySupportsKeyLevel(activity)
      if sfalp_is_ascension() then return activity == SFALP.ASC_MYTHIC end
      return SFALP_OldActivitySupportsKey and SFALP_OldActivitySupportsKey(activity) or false
    end

    local SFALP_OldDifficultyList = _G.BLFG_DifficultyListForType
    function BLFG_DifficultyListForType(typeName)
      if sfalp_is_ascension() then
        if typeName == "Mythic+" then return {"Mythic+"} end
        if typeName == "Dungeon" then return {"Normal", "Heroic"} end
        if typeName == "Raid" then return {"Normal", "Heroic", "Ascended"} end
        if typeName == "World Boss" then return {"Normal", "Custom"} end
        if typeName == "Custom Event" then return {"Custom"} end
      end
      return SFALP_OldDifficultyList and SFALP_OldDifficultyList(typeName) or {"Normal"}
    end

    local SFALP_OldCreateDifficultyList = _G.BLFG_CreateDifficultyListFor
    function BLFG_CreateDifficultyListFor(typeName, activity)
      if sfalp_is_ascension() then
        if typeName == "Mythic+" then return {"Mythic+"} end
        if typeName == "Dungeon" and activity == SFALP.RDF then return {"Normal"} end
        if typeName == "Dungeon" and activity == SFALP.RDF_HEROIC then return {"Heroic"} end
        if typeName == "Dungeon" and activity == SFALP.RDF_MYTHIC then return {"Mythic+"} end
        if typeName == "Dungeon" then return {"Normal", "Heroic"} end
        if typeName == "Raid" then return {"Normal", "Heroic", "Ascended"} end
        if typeName == "World Boss" then return {"Normal", "Custom"} end
        if typeName == "Custom Event" then return {"Custom"} end
      end
      return SFALP_OldCreateDifficultyList and SFALP_OldCreateDifficultyList(typeName, activity) or {"Normal"}
    end

    local SFALP_OldDefaultMax = _G.BLFG_DefaultMaxMembersFor
    function BLFG_DefaultMaxMembersFor(typeName, activity, difficulty)
      if sfalp_is_ascension() and typeName == "Mythic+" then return 5 end
      return SFALP_OldDefaultMax and SFALP_OldDefaultMax(typeName, activity, difficulty) or 5
    end

    local SFALP_OldApplyProfileToCreate = BLFG.SF143_ApplyProfileToCreate
    function BLFG:SF143_ApplyProfileToCreate(...)
      local preserveKey = sfalp_is_ascension() and sfalp_dd(self.typeDrop) == "Mythic+" and sfalp_text(self.keyBox) or nil
      local r = SFALP_OldApplyProfileToCreate and SFALP_OldApplyProfileToCreate(self, ...)
      if preserveKey ~= nil and self.keyBox then self.keyBox:SetText(preserveKey) end
      SFALP.EnsurePreview(self)
      SFALP.HookCreateControls(self)
      SFALP.ApplyUI(self)
      return r
    end

    local SFALP_OldUpdateCreateControls = BLFG.UpdateCreateControls
    function BLFG:UpdateCreateControls(...)
      local preserveKey = sfalp_is_ascension() and sfalp_dd(self.typeDrop) == "Mythic+" and sfalp_text(self.keyBox) or nil
      local r = SFALP_OldUpdateCreateControls and SFALP_OldUpdateCreateControls(self, ...)
      if preserveKey ~= nil and self.keyBox then self.keyBox:SetText(preserveKey) end
      SFALP.EnsurePreview(self)
      SFALP.HookCreateControls(self)
      SFALP.ApplyUI(self)
      if not SFALP.loading then SFALP.SaveCurrent(self) end
      return r
    end

    local SFALP_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local r = SFALP_OldCreateUI and SFALP_OldCreateUI(self, ...)
      SFALP.EnsurePreview(self)
      SFALP.HookCreateControls(self)
      return r
    end

    local SFALP_OldShowCreate = BLFG.ShowCreate
    function BLFG:ShowCreate(...)
      local r = SFALP_OldShowCreate and SFALP_OldShowCreate(self, ...)
      SFALP.EnsurePreview(self)
      SFALP.HookCreateControls(self)
      SFALP.LoadState(self, sfalp_profile_id())
      if self.create then self.create:Show() end
      if self.frame then self.frame:Show() end
      return r
    end

    local SFALP_OldSetServerProfile = BLFG.SF143_SetServerProfile
    function BLFG:SF143_SetServerProfile(id, manual)
      local before = sfalp_profile_id()
      SFALP.SaveCurrent(self, before)
      local r = SFALP_OldSetServerProfile and SFALP_OldSetServerProfile(self, id, manual)
      if self.typeDrop then SFALP.LoadState(self, sfalp_profile_id()) end
      return r
    end


    local SFALP_OldUseInventoryKeystone = BLFG.UseInventoryKeystoneForCreate
    function BLFG:UseInventoryKeystoneForCreate(...)
      if not sfalp_is_ascension() then
        return SFALP_OldUseInventoryKeystone and SFALP_OldUseInventoryKeystone(self, ...)
      end

      local dungeon, level = self:FindInventoryKeystone()
      if not dungeon then
        sfalp_msg("No Mythic Keystone found in your bags.", 1, .82, .35)
        return
      end
      local mythicList = sfalp_ascension_list_for_mode(SFALP.ASC_MYTHIC) or {}
      if not sfalp_contains(mythicList, dungeon) then
        sfalp_msg("Found keystone for " .. tostring(dungeon) .. ", but that dungeon is not in the Ascension Mythic+ pool.", 1, .35, .35)
        return
      end

      SFALP.loading = true
      sfalp_set_dd(self.typeDrop, "Mythic+")
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      sfalp_set_dd(self.activityDrop, SFALP.ASC_MYTHIC)
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      sfalp_set_dd(self.specificDungeonDrop, dungeon)
      sfalp_set_dd(self.diffDrop, "Mythic+")
      sfalp_set_text(self.keyBox, tostring(level or ""))
      sfalp_set_text(self.maxBox, "5")
      SFALP.loading = false
      SFALP.ApplyUI(self)
      SFALP.SaveCurrent(self, sfalp_profile_id())
      sfalp_msg("Loaded keystone: " .. tostring(dungeon) .. " +" .. tostring(level) .. ".", .55, .9, 1)
    end

    local SFALP_OldValidateCreateListing = BLFG.ValidateCreateListing
    function BLFG:ValidateCreateListing(...)
      if sfalp_is_ascension() and sfalp_dd(self.typeDrop) == "Mythic+" then
        local oldType = sfalp_dd(self.typeDrop)
        sfalp_set_dd(self.typeDrop, "Dungeon")
        local ok = SFALP_OldValidateCreateListing and SFALP_OldValidateCreateListing(self, ...)
        sfalp_set_dd(self.typeDrop, oldType)
        SFALP.ApplyUI(self)
        return ok
      end
      return SFALP_OldValidateCreateListing and SFALP_OldValidateCreateListing(self, ...)
    end

    local SFALP_OldCreateListing = BLFG.CreateListing
    function BLFG:CreateListing(...)
      local pseudoMythic = sfalp_is_ascension() and sfalp_dd(self.typeDrop) == "Mythic+"
      SFALP.SaveCurrent(self, sfalp_profile_id())
      if pseudoMythic then sfalp_set_dd(self.typeDrop, "Dungeon") end
      local r = SFALP_OldCreateListing and SFALP_OldCreateListing(self, ...)
      if pseudoMythic then sfalp_set_dd(self.typeDrop, "Mythic+") end
      SFALP.SaveCurrent(self, sfalp_profile_id())
      SFALP.ApplyUI(self)
      return r
    end

    -- Migrate the current profile now; the UI state itself is applied when Create Listing opens.
    sfalp_migrate_state(sfalp_profile_id())

    local sfalpLogin = CreateFrame("Frame")
    sfalpLogin:RegisterEvent("PLAYER_LOGIN")
    sfalpLogin:RegisterEvent("PLAYER_ENTERING_WORLD")
    sfalpLogin:SetScript("OnEvent", function()
      if SignalFireProfiles and SignalFireProfiles.Ascension then
        SignalFireProfiles.Ascension.activityTypes = {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"}
      end
      if BLFG and BLFG.typeDrop then
        SFALP.EnsurePreview(BLFG)
        SFALP.HookCreateControls(BLFG)
        SFALP.ApplyUI(BLFG)
      end
    end)



    -- SignalFire 1.4.30j: transparent, explicitly clickable compact dungeon selector.
    --
    -- The 1.4.30i selector successfully removed the giant native CoA dropdown, but
    -- its visible button inherited CoA's red UIPanelButton skin and the popup rows
    -- could sit below an invisible high-level UI hit region. This version uses only
    -- custom backdrop buttons, puts the popup on TOOLTIP strata, gives every row an
    -- explicit high frame level and LeftButtonDown handler, and stores the selected
    -- dungeon directly before refreshing the listing UI.
    do
      local SFALP1430J_ROWS = 8

      local function sfalp1430j_apply_backdrop(frame, alpha, borderR, borderG, borderB)
        if not frame or not frame.SetBackdrop then return end
        frame:SetBackdrop({
          bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true,
          tileSize = 16,
          edgeSize = 12,
          insets = {left = 3, right = 3, top = 3, bottom = 3},
        })
        frame:SetBackdropColor(0.01, 0.01, 0.01, alpha or 0.82)
        frame:SetBackdropBorderColor(borderR or 0.42, borderG or 0.31, borderB or 0.08, 1)
      end

      local function sfalp1430j_hide_native(dropdown)
        if not dropdown then return end
        if CloseDropDownMenus then CloseDropDownMenus() end
        dropdown.SFDisableNativeMenu = true
        if BLFG_SF1430H_SuppressNativeDropdown then
          BLFG_SF1430H_SuppressNativeDropdown(dropdown)
        else
          if dropdown.EnableMouse then dropdown:EnableMouse(false) end
          if dropdown.SetAlpha then dropdown:SetAlpha(0) end
        end

        if dropdown.HookScript and not dropdown.SF1430JSuppressOnShow then
          dropdown.SF1430JSuppressOnShow = true
          dropdown:HookScript("OnShow", function(self)
            if BLFG_SF1430H_SuppressNativeDropdown then
              BLFG_SF1430H_SuppressNativeDropdown(self)
            else
              if self.EnableMouse then self:EnableMouse(false) end
              if self.SetAlpha then self:SetAlpha(0) end
            end
          end)
        end
      end

      local function sfalp1430j_values(dropdown)
        local values = {}
        for _, value in ipairs((dropdown and dropdown.values) or {}) do
          local text = tostring(value or "")
          if text ~= "" and text ~= "Select Dungeon" then
            table.insert(values, text)
          end
        end
        return values
      end

      local function sfalp1430j_should_show(dropdown)
        if not BLFG or not dropdown then return false end
        local typeName = sfalp_dd(BLFG.typeDrop)
        if typeName ~= "Dungeon" and typeName ~= "Mythic+" then return false end
        local activity = sfalp_dd(BLFG.activityDrop)
        local values = BLFG_DungeonListForMode and BLFG_DungeonListForMode(activity) or nil
        return values and #values > 0 or false
      end

      local function sfalp1430j_set_row_visual(row, selected, hovered)
        if not row then return end
        if hovered then
          row:SetBackdropColor(0.20, 0.14, 0.03, 0.96)
          row:SetBackdropBorderColor(0.95, 0.68, 0.10, 1)
        elseif selected then
          row:SetBackdropColor(0.10, 0.075, 0.015, 0.88)
          row:SetBackdropBorderColor(0.62, 0.45, 0.08, 0.95)
        else
          row:SetBackdropColor(0.01, 0.01, 0.01, 0.40)
          row:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.75)
        end
        if row.text then
          if selected then row.text:SetTextColor(1, 0.82, 0) else row.text:SetTextColor(0.95, 0.95, 0.95) end
        end
      end

      local function sfalp1430j_make_small_button(parent, width, label)
        local button = CreateFrame("Button", nil, parent)
        button:SetWidth(width)
        button:SetHeight(24)
        button:RegisterForClicks("LeftButtonDown")
        button:EnableMouse(true)
        sfalp1430j_apply_backdrop(button, 0.86, 0.42, 0.31, 0.08)

        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.text:SetText(label or "")

        button:SetScript("OnEnter", function(self)
          self:SetBackdropColor(0.18, 0.12, 0.02, 0.96)
          self:SetBackdropBorderColor(0.95, 0.68, 0.10, 1)
        end)
        button:SetScript("OnLeave", function(self)
          self:SetBackdropColor(0.01, 0.01, 0.01, 0.86)
          self:SetBackdropBorderColor(0.42, 0.31, 0.08, 1)
        end)
        return button
      end

      local function sfalp1430j_make_popup()
        if SFALP.dungeonSelectorPopup1430j then return SFALP.dungeonSelectorPopup1430j end

        local popup = CreateFrame("Frame", "SignalFireDungeonSelectorPopup1430j", UIParent)
        SFALP.dungeonSelectorPopup1430j = popup
        popup:SetWidth(300)
        popup:SetHeight(266)
        popup:SetFrameStrata("TOOLTIP")
        popup:SetFrameLevel(9000)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:EnableMouseWheel(true)
        if popup.SetToplevel then popup:SetToplevel(true) end
        sfalp1430j_apply_backdrop(popup, 0.90, 0.62, 0.45, 0.08)
        popup:Hide()

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -13)
        popup.title:SetText("Select Dungeon")
        popup.title:SetTextColor(1, 0.82, 0)

        popup.close = sfalp1430j_make_small_button(popup, 28, "X")
        popup.close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -10, -8)
        popup.close:SetFrameLevel(popup:GetFrameLevel() + 40)
        popup.close:SetScript("OnClick", function() popup:Hide() end)

        popup.rows = {}
        for index = 1, SFALP1430J_ROWS do
          local row = CreateFrame("Button", nil, popup)
          popup.rows[index] = row
          row:SetHeight(22)
          row:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, -38 - ((index - 1) * 23))
          row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -11, -38 - ((index - 1) * 23))
          row:SetFrameLevel(popup:GetFrameLevel() + 50 + index)
          row:RegisterForClicks("LeftButtonDown")
          row:EnableMouse(true)
          if row.SetHitRectInsets then row:SetHitRectInsets(-2, -2, -1, -1) end
          sfalp1430j_apply_backdrop(row, 0.40, 0.18, 0.18, 0.18)

          row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
          row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
          row.text:SetJustifyH("LEFT")

          row:SetScript("OnEnter", function(self)
            sfalp1430j_set_row_visual(self, self._sfSelected, true)
          end)
          row:SetScript("OnLeave", function(self)
            sfalp1430j_set_row_visual(self, self._sfSelected, false)
          end)
          row:SetScript("OnClick", function(self)
            local value = self._sfValue
            local dropdown = popup.dropdown
            if not value or not dropdown then return end

            -- Commit the value before any UI refresh can restore the old dungeon.
            sfalp_set_dd(dropdown, value)
            if BronzeLFG_DB and BronzeLFG_DB.create then
              BronzeLFG_DB.create.specificDungeon = value
            end
            if popup.selector and popup.selector.text then
              popup.selector.text:SetText(value)
            end
            popup:Hide()

            if BLFG and BLFG.UpdateCreateControls then BLFG:UpdateCreateControls() end
            if SFALP and SFALP.SaveCurrent then SFALP.SaveCurrent(BLFG, sfalp_profile_id()) end
            if SFALP and SFALP.UpdatePreview then SFALP.UpdatePreview(BLFG) end
          end)
        end

        popup.previous = sfalp1430j_make_small_button(popup, 78, "Previous")
        popup.previous:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 11, 11)
        popup.previous:SetFrameLevel(popup:GetFrameLevel() + 40)

        popup.position = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        popup.position:SetPoint("BOTTOM", popup, "BOTTOM", 0, 18)
        popup.position:SetTextColor(0.65, 0.85, 1)

        popup.next = sfalp1430j_make_small_button(popup, 78, "Next")
        popup.next:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -11, 11)
        popup.next:SetFrameLevel(popup:GetFrameLevel() + 40)

        function popup:ClampOffset()
          local count = #(self.values or {})
          local maxOffset = math.max(0, count - SFALP1430J_ROWS)
          self.offset = math.max(0, math.min(tonumber(self.offset) or 0, maxOffset))
          return count, maxOffset
        end

        function popup:Refresh()
          local count, maxOffset = self:ClampOffset()
          local selected = self.dropdown and sfalp_dd(self.dropdown) or ""

          for index = 1, SFALP1430J_ROWS do
            local row = self.rows[index]
            local value = self.values[(self.offset or 0) + index]
            if value then
              row._sfValue = value
              row._sfSelected = value == selected
              row.text:SetText(value)
              sfalp1430j_set_row_visual(row, row._sfSelected, false)
              row:Enable()
              row:Show()
              if row.Raise then row:Raise() end
            else
              row._sfValue = nil
              row._sfSelected = false
              row:Hide()
            end
          end

          if count > 0 then
            local first = (self.offset or 0) + 1
            local last = math.min((self.offset or 0) + SFALP1430J_ROWS, count)
            self.position:SetText(tostring(first) .. "-" .. tostring(last) .. " of " .. tostring(count))
          else
            self.position:SetText("No dungeons")
          end

          if (self.offset or 0) <= 0 then self.previous:Disable() else self.previous:Enable() end
          if (self.offset or 0) >= maxOffset then self.next:Disable() else self.next:Enable() end
          self.previous:SetAlpha(self.previous:IsEnabled() and 1 or 0.45)
          self.next:SetAlpha(self.next:IsEnabled() and 1 or 0.45)
        end

        function popup:Scroll(delta)
          local count, maxOffset = self:ClampOffset()
          if count <= SFALP1430J_ROWS then return end
          local nextOffset = math.max(0, math.min((self.offset or 0) + delta, maxOffset))
          if nextOffset ~= self.offset then
            self.offset = nextOffset
            self:Refresh()
          end
        end

        popup.previous:SetScript("OnClick", function() popup:Scroll(-SFALP1430J_ROWS) end)
        popup.next:SetScript("OnClick", function() popup:Scroll(SFALP1430J_ROWS) end)
        popup:SetScript("OnMouseWheel", function(_, delta)
          if delta > 0 then popup:Scroll(-1) else popup:Scroll(1) end
        end)
        popup:SetScript("OnShow", function(self)
          self:SetFrameStrata("TOOLTIP")
          self:SetFrameLevel(9000)
          if self.Raise then self:Raise() end
          for _, row in ipairs(self.rows or {}) do
            row:SetFrameLevel(self:GetFrameLevel() + 50)
            if row.Raise then row:Raise() end
          end
        end)

        local found = false
        for _, frameName in ipairs(UISpecialFrames or {}) do
          if frameName == "SignalFireDungeonSelectorPopup1430j" then found = true break end
        end
        if not found and UISpecialFrames then
          table.insert(UISpecialFrames, "SignalFireDungeonSelectorPopup1430j")
        end

        return popup
      end

      local function sfalp1430j_open(dropdown, selector)
        if not dropdown or not selector then return end
        if CloseDropDownMenus then CloseDropDownMenus() end

        local popup = sfalp1430j_make_popup()
        if popup:IsShown() and popup.dropdown == dropdown then
          popup:Hide()
          return
        end

        popup.dropdown = dropdown
        popup.selector = selector
        popup.values = sfalp1430j_values(dropdown)

        local selected = sfalp_dd(dropdown)
        local selectedIndex = 1
        for index, value in ipairs(popup.values) do
          if value == selected then selectedIndex = index break end
        end
        popup.offset = math.max(0, selectedIndex - math.ceil(SFALP1430J_ROWS / 2))
        popup:ClampOffset()
        popup:Refresh()

        popup:ClearAllPoints()
        popup:SetPoint("TOPRIGHT", selector, "BOTTOMRIGHT", 0, -3)
        popup:Show()
        if popup.Raise then popup:Raise() end
      end

      local function sfalp1430j_create_selector(dropdown)
        if dropdown._sf1430jSelector then return dropdown._sf1430jSelector end

        local parent = dropdown:GetParent() or UIParent
        local selector = CreateFrame("Button", "SignalFireDungeonSelectorButton1430j", parent)
        dropdown._sf1430jSelector = selector
        selector:SetWidth(260)
        selector:SetHeight(26)
        selector:ClearAllPoints()
        selector:SetPoint("TOPLEFT", parent, "TOPLEFT", 550, -64)
        selector:SetFrameStrata(parent:GetFrameStrata() or "DIALOG")
        selector:SetFrameLevel((parent:GetFrameLevel() or 1) + 100)
        selector:RegisterForClicks("LeftButtonDown")
        selector:EnableMouse(true)
        selector:SetAlpha(1)
        sfalp1430j_apply_backdrop(selector, 0.72, 0.32, 0.32, 0.32)

        selector.text = selector:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        selector.text:SetPoint("LEFT", selector, "LEFT", 12, 0)
        selector.text:SetPoint("RIGHT", selector, "RIGHT", -31, 0)
        selector.text:SetJustifyH("RIGHT")
        selector.text:SetTextColor(0.95, 0.95, 0.95)

        selector.arrow = selector:CreateTexture(nil, "OVERLAY")
        selector.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        selector.arrow:SetWidth(18)
        selector.arrow:SetHeight(18)
        selector.arrow:SetPoint("RIGHT", selector, "RIGHT", -7, 0)

        selector:SetScript("OnEnter", function(self)
          self:SetBackdropColor(0.03, 0.03, 0.03, 0.86)
          self:SetBackdropBorderColor(0.75, 0.53, 0.08, 1)
        end)
        selector:SetScript("OnLeave", function(self)
          self:SetBackdropColor(0.01, 0.01, 0.01, 0.72)
          self:SetBackdropBorderColor(0.32, 0.32, 0.32, 1)
        end)
        selector:SetScript("OnClick", function()
          sfalp1430j_hide_native(dropdown)
          sfalp1430j_open(dropdown, selector)
        end)
        selector:EnableMouseWheel(true)
        selector:SetScript("OnMouseWheel", function(_, delta)
          local popup = SFALP.dungeonSelectorPopup1430j
          if popup and popup:IsShown() and popup.dropdown == dropdown then
            if delta > 0 then popup:Scroll(-1) else popup:Scroll(1) end
          end
        end)

        return selector
      end

      local function sfalp1430j_sync(dropdown)
        if not dropdown then return end

        local selector = sfalp1430j_create_selector(dropdown)
        selector.text:SetText(sfalp_dd(dropdown))

        if sfalp1430j_should_show(dropdown) then
          dropdown:Show()
          sfalp1430j_hide_native(dropdown)
          selector:SetAlpha(1)
          selector:EnableMouse(true)
          selector:Show()
          if selector.Raise then selector:Raise() end
        else
          selector:Hide()
          dropdown:Hide()
          local popup = SFALP.dungeonSelectorPopup1430j
          if popup and popup.dropdown == dropdown then popup:Hide() end
        end
      end

      SFALP.InstallDungeonPicker = sfalp1430j_sync

      local sfalp1430jOldApplyUI = SFALP.ApplyUI
      function SFALP.ApplyUI(self)
        local result = sfalp1430jOldApplyUI and sfalp1430jOldApplyUI(self)
        self = self or BLFG
        if self and self.specificDungeonDrop then sfalp1430j_sync(self.specificDungeonDrop) end
        return result
      end

      local sfalp1430jOldUpdateCreateControls = BLFG.UpdateCreateControls
      function BLFG:UpdateCreateControls(...)
        local result = sfalp1430jOldUpdateCreateControls and sfalp1430jOldUpdateCreateControls(self, ...)
        if self and self.specificDungeonDrop then sfalp1430j_sync(self.specificDungeonDrop) end
        return result
      end

      local sfalp1430jOldShowCreate = BLFG.ShowCreate
      function BLFG:ShowCreate(...)
        local result = sfalp1430jOldShowCreate and sfalp1430jOldShowCreate(self, ...)
        if self and self.specificDungeonDrop then sfalp1430j_sync(self.specificDungeonDrop) end
        return result
      end

      if BLFG and BLFG.specificDungeonDrop then sfalp1430j_sync(BLFG.specificDungeonDrop) end
    end
  until true
end
