Cursive = Cursive or {}
local addon = Cursive
local Config = {}
addon.Config = Config

local panel
local widgets = {}
local soundDropdown

local function fmtNum(v)
    return string.format("%g", v)
end

local function makeCheckbox(parent, label, x, y, dbKey, onChange)
    local cb = CreateFrame("CheckButton", "CursiveCheck_" .. dbKey, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self)
        addon.db[dbKey] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    cb.refresh = function()
        cb:SetChecked(addon.db[dbKey])
    end
    return cb
end

local function makeEditBox(parent, label, x, y, width, dbKey, onChange)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(label)

    local eb = CreateFrame("EditBox", "CursiveEdit_" .. dbKey, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", x + 8, y - 22)
    eb:SetWidth(width)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)

    local function commitValue(self)
        addon.db[dbKey] = self:GetText() or ""
        if onChange then onChange(addon.db[dbKey]) end
    end

    eb:SetScript("OnEnterPressed", function(self)
        commitValue(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", commitValue)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(addon.db[dbKey] or "")
        self:ClearFocus()
    end)

    eb.refresh = function()
        eb:SetText(addon.db[dbKey] or "")
    end
    return eb
end

local function makeSlider(parent, label, x, y, minV, maxV, step, dbKey, onChange)
    local s = CreateFrame("Slider", "CursiveSlider_" .. dbKey, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(220)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[s:GetName() .. "Text"]:SetText(label)
    _G[s:GetName() .. "Low"]:SetText(fmtNum(minV))
    _G[s:GetName() .. "High"]:SetText(fmtNum(maxV))

    s:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor((value / step) + 0.5) * step
        addon.db[dbKey] = snapped
        _G[self:GetName() .. "Text"]:SetText(label .. ": " .. fmtNum(snapped))
        if onChange then onChange() end
    end)

    s.refresh = function()
        s:SetValue(addon.db[dbKey])
        _G[s:GetName() .. "Text"]:SetText(label .. ": " .. fmtNum(addon.db[dbKey]))
    end
    return s
end

local function makeButton(parent, label, x, y, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function buildSoundDropdown(parent, x, y)
    soundDropdown = CreateFrame("Frame", "CursiveSoundDropdown", parent, "UIDropDownMenuTemplate")
    soundDropdown:SetPoint("TOPLEFT", x - 16, y)

    local function onClick(self)
        addon.db.sound = self.value
        UIDropDownMenu_SetSelectedValue(soundDropdown, self.value)
        UIDropDownMenu_SetText(soundDropdown, self:GetText())
    end

    UIDropDownMenu_Initialize(soundDropdown, function()
        for _, s in ipairs(addon.Alert.Sounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = s.label
            info.value = s.key
            info.func = onClick
            info.checked = (addon.db and addon.db.sound == s.key) or nil
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(soundDropdown, 200)

    soundDropdown.refresh = function()
        UIDropDownMenu_SetSelectedValue(soundDropdown, addon.db.sound)
        local s = addon.Alert.GetSoundByKey(addon.db.sound)
        UIDropDownMenu_SetText(soundDropdown, s and s.label or addon.db.sound)
    end

    return soundDropdown
end

function Config.Build()
    panel = CreateFrame("Frame", "CursiveConfigPanel", UIParent)
    panel.name = "Cursive"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Cursive")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(500)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Plays a sound and shows a banner when you or a group member is cursed.")

    table.insert(widgets, makeCheckbox(panel, "Enable Cursive", 16, -64, "enabled"))
    table.insert(widgets, makeCheckbox(panel, "Watch yourself", 16, -90, "watchSelf",
        function() addon.Detector.RebuildWatchList() end))
    table.insert(widgets, makeCheckbox(panel, "Watch party / raid members", 16, -116, "watchGroup",
        function() addon.Detector.RebuildWatchList() end))

    local soundLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", 16, -150)
    soundLabel:SetText("Sound:")

    table.insert(widgets, buildSoundDropdown(panel, 80, -146))

    makeButton(panel, "Test Sound", 310, -150, 100, function()
        if addon.db then addon.Alert.PlayByKey(addon.db.sound) end
    end)

    table.insert(widgets, makeEditBox(panel, "Self message template:", 16, -190, 400, "selfTemplate"))
    table.insert(widgets, makeEditBox(panel, "Group message template:", 16, -240, 400, "groupTemplate"))

    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helpText:SetPoint("TOPLEFT", 16, -286)
    helpText:SetText("Variables: %target%   %spell%   %caster%")

    table.insert(widgets, makeSlider(panel, "Per-spell cooldown (s)", 16, -316, 0.5, 10, 0.5, "cooldown"))
    table.insert(widgets, makeSlider(panel, "Popup duration (s)", 16, -366, 1, 10, 0.5, "popupDuration"))
    table.insert(widgets, makeSlider(panel, "Popup font size", 16, -416, 12, 48, 2, "fontSize",
        function() addon.Alert.RefreshFont() end))

    makeButton(panel, "Test Popup (sound + banner)", 16, -466, 240, function()
        addon.Alert.TestPopup()
    end)

    local dispelHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dispelHeader:SetPoint("TOPLEFT", 16, -504)
    dispelHeader:SetText("Dispel: toggle each type to watch and dispel; defaults are auto-set from your class.")

    local watchOnChange = function()
        if addon.Detector and addon.Detector.RescanAll then
            addon.Detector.RescanAll()
        end
    end
    local spellOnChange = function(dtype, v)
        if addon.Dispel and addon.Dispel.UpdateSpell then
            addon.Dispel.UpdateSpell(dtype, v)
        end
    end

    for i, dtype in ipairs(addon.DEBUFF_TYPES) do
        local rowY = -528 - (i - 1) * 28

        local cb = CreateFrame("CheckButton", "CursiveTypeCheck_" .. dtype, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, rowY)
        _G[cb:GetName() .. "Text"]:SetText(dtype)
        cb:SetScript("OnClick", function(self)
            addon.db.watchedTypes[dtype] = self:GetChecked() and true or false
            watchOnChange()
        end)
        cb.refresh = function()
            cb:SetChecked(addon.db.watchedTypes and addon.db.watchedTypes[dtype])
        end
        table.insert(widgets, cb)

        local eb = CreateFrame("EditBox", "CursiveSpellEdit_" .. dtype, panel, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", 130, rowY - 4)
        eb:SetWidth(260)
        eb:SetHeight(20)
        eb:SetAutoFocus(false)

        local commit = function(self)
            addon.db.dispelSpells = addon.db.dispelSpells or {}
            addon.db.dispelSpells[dtype] = self:GetText() or ""
            spellOnChange(dtype, addon.db.dispelSpells[dtype])
        end
        eb:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", commit)
        eb:SetScript("OnEscapePressed", function(self)
            self:SetText(addon.db.dispelSpells and addon.db.dispelSpells[dtype] or "")
            self:ClearFocus()
        end)
        eb.refresh = function()
            eb:SetText(addon.db.dispelSpells and addon.db.dispelSpells[dtype] or "")
        end
        table.insert(widgets, eb)
    end

    local dispelHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dispelHelp:SetPoint("TOPLEFT", 16, -650)
    dispelHelp:SetWidth(500)
    dispelHelp:SetJustifyH("LEFT")
    dispelHelp:SetText("REQUIRED: macro must contain |cffffffff/click CursiveDispelButton|r (NOT |cffaaaaaa/cdispel|r). Bind that macro to a key. Each press casts the configured spell for the front-of-queue target's debuff type, skipping types that have no spell set. /cdispel is blocked in combat by Blizzard's addon protection; /click is not.")

    panel.refresh = function()
        for _, w in ipairs(widgets) do
            if w.refresh then w.refresh() end
        end
    end

    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function()
        -- Wipe and rebuild via the same path used at PLAYER_LOGIN, so the
        -- reset is class-aware (matches what a fresh install would get).
        for k in pairs(addon.db) do
            addon.db[k] = nil
        end
        addon.SetupDB()
        panel.refresh()
        addon.Alert.RefreshFont()
        addon.Detector.RebuildWatchList()
        addon.Detector.RescanAll()
        if addon.Dispel and addon.Dispel.UpdateSpells then
            addon.Dispel.UpdateSpells(addon.db.dispelSpells)
        end
    end

    InterfaceOptions_AddCategory(panel)
end

function Config.Init()
    if not panel then Config.Build() end
end

function Config.Open()
    if not panel then Config.Build() end
    -- 3.3.5a quirk: must call twice to actually navigate to the right panel
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
