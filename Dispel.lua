Cursive = Cursive or {}
local addon = Cursive
local Dispel = {}
addon.Dispel = Dispel

local btn

local function chat(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8888ffCursive:|r " .. msg)
    end
end

-- Single-button pattern using SecureHandlerWrapScript: a pre-snippet runs in
-- secure context before SecureActionButton's cast handler, sets the unit and
-- spell attributes from our published queue, then the unmodified cast handler
-- fires using those attributes. Avoids the inner-button hop that loses the
-- hardware-event flag in 3.3.5a.
local PRE_SNIPPET = [[
    local q = self:GetAttribute("cursive-queue") or ""
    local s = self:GetAttribute("cursive-spell") or ""
    if q == "" or s == "" then
        self:SetAttribute("type", nil)
        return
    end
    local unit = strsplit(",", q)
    if not unit or unit == "" then
        self:SetAttribute("type", nil)
        return
    end
    self:SetAttribute("type", "spell")
    self:SetAttribute("spell", s)
    self:SetAttribute("unit", unit)
]]

function Dispel.Init()
    if btn then return end

    btn = CreateFrame(
        "Button",
        "CursiveDispelButton",
        UIParent,
        "SecureActionButtonTemplate, SecureHandlerBaseTemplate"
    )
    btn:RegisterForClicks("AnyUp")
    btn:SetWidth(1)
    btn:SetHeight(1)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -1000, 1000)

    SecureHandlerWrapScript(btn, "OnClick", btn, PRE_SNIPPET)

    if addon.db then
        Dispel.UpdateSpell(addon.db.dispelSpell)
    end
    Dispel.UpdateQueue({})
end

function Dispel.UpdateQueue(units)
    if not btn then return end
    local s = ""
    if units and #units > 0 then
        s = table.concat(units, ",")
    end
    btn:SetAttribute("cursive-queue", s)
end

function Dispel.UpdateSpell(spell)
    if not btn then return end
    btn:SetAttribute("cursive-spell", spell or "")
end

function Dispel.CastNext()
    if not btn then
        chat("dispel button not initialized.")
        return
    end
    local q = btn:GetAttribute("cursive-queue") or ""
    local s = btn:GetAttribute("cursive-spell") or ""
    if q == "" then
        chat("queue empty (no cursed targets seen).")
        return
    end
    chat("dispelling " .. q:match("^[^,]+") .. " with [" .. s .. "]")
    btn:Click()
end

function Dispel.PrintState()
    if not btn then chat("not initialized."); return end

    local db = addon.db
    chat("enabled=" .. tostring(db and db.enabled)
        .. " watchSelf=" .. tostring(db and db.watchSelf)
        .. " watchGroup=" .. tostring(db and db.watchGroup))

    local q = btn:GetAttribute("cursive-queue") or "(none)"
    local s = btn:GetAttribute("cursive-spell") or "(none)"
    chat("published queue=[" .. q .. "] spell=[" .. s .. "]")

    if addon.Detector then
        local raw = table.concat(addon.Detector.curseQueue or {}, ", ")
        chat("raw queue: [" .. raw .. "]")
        local watched = {}
        for unit in pairs(addon.Detector.watched or {}) do
            table.insert(watched, unit)
        end
        chat("watched units: " .. table.concat(watched, ", "))
    end

    chat("--- player debuffs (name | debuffType) ---")
    local found = false
    for i = 1, 40 do
        local name, _, _, _, debuffType = UnitDebuff("player", i)
        if not name then break end
        found = true
        chat("  " .. i .. ": " .. name .. " | " .. tostring(debuffType))
    end
    if not found then chat("  (none)") end
end
