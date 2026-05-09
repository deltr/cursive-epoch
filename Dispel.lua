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

-- The pre-snippet runs in secure context before SecureActionButton's cast
-- handler. It walks the published queue (a comma-separated list of
-- "unit:type" pairs in priority order), finds the first entry whose type
-- has a non-empty configured spell, and writes type/spell/unit attributes
-- on self. The cast handler then fires using those attributes. Since this
-- all happens inside secure context, attribute writes are allowed in combat.
local PRE_SNIPPET = [[
    local q = self:GetAttribute("cursive-queue") or ""
    if q == "" then
        self:SetAttribute("type", nil)
        return
    end
    local entries = { strsplit(",", q) }
    for i = 1, #entries do
        local entry = entries[i]
        if entry and entry ~= "" then
            local unit, dtype = strsplit(":", entry)
            if unit and unit ~= "" and dtype and dtype ~= "" then
                local spell = self:GetAttribute("cursive-spell-" .. dtype) or ""
                if spell ~= "" then
                    self:SetAttribute("type", "spell")
                    self:SetAttribute("spell", spell)
                    self:SetAttribute("unit", unit)
                    return
                end
            end
        end
    end
    self:SetAttribute("type", nil)
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
        Dispel.UpdateSpells(addon.db.dispelSpells)
    end
    Dispel.UpdateQueue({})
end

-- Custom (non-protected) attribute -- safe to set in combat.
function Dispel.UpdateQueue(pairs_list)
    if not btn then return end
    local s = ""
    if pairs_list and #pairs_list > 0 then
        s = table.concat(pairs_list, ",")
    end
    btn:SetAttribute("cursive-queue", s)
end

function Dispel.UpdateSpells(spells)
    if not btn then return end
    spells = spells or {}
    for _, dtype in ipairs(addon.DEBUFF_TYPES) do
        btn:SetAttribute("cursive-spell-" .. dtype, spells[dtype] or "")
    end
end

-- Convenience: update one type's spell without rewriting all four. Called
-- from the per-type editbox onChange.
function Dispel.UpdateSpell(dtype, spell)
    if not btn or not dtype then return end
    btn:SetAttribute("cursive-spell-" .. dtype, spell or "")
end

function Dispel.CastNext()
    if not btn then
        chat("dispel button not initialized.")
        return
    end
    local q = btn:GetAttribute("cursive-queue") or ""
    if q == "" then
        chat("queue empty (no targets).")
        return
    end
    local first = strsplit(",", q)
    chat("dispatching " .. first .. " (note: /cdispel is blocked in combat; bind a macro with /click CursiveDispelButton instead).")
    btn:Click()
end

function Dispel.PrintState()
    if not btn then chat("not initialized."); return end

    local db = addon.db
    chat("enabled=" .. tostring(db and db.enabled)
        .. " watchSelf=" .. tostring(db and db.watchSelf)
        .. " watchGroup=" .. tostring(db and db.watchGroup))

    if db and db.watchedTypes then
        local watched = {}
        for _, t in ipairs(addon.DEBUFF_TYPES) do
            if db.watchedTypes[t] then table.insert(watched, t) end
        end
        chat("watched types: " .. table.concat(watched, ", "))
    end

    local q = btn:GetAttribute("cursive-queue") or "(none)"
    chat("published queue=[" .. q .. "]")
    for _, t in ipairs(addon.DEBUFF_TYPES) do
        local s = btn:GetAttribute("cursive-spell-" .. t) or ""
        chat("  spell-" .. t .. "=[" .. s .. "]")
    end

    if addon.Detector then
        local raw = table.concat(addon.Detector.curseQueue or {}, ", ")
        chat("raw queue: [" .. raw .. "]")
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
