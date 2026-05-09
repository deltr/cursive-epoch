Cursive = Cursive or {}
local addon = Cursive

addon.DEBUFF_TYPES = { "Magic", "Curse", "Disease", "Poison" }

-- Per-class auto-defaults. Applied only when the user has no saved choice
-- (fresh install, or a key not yet present). The user can flip any toggle
-- afterward via the config panel; their choices stick.
addon.CLASS_DEFAULTS = {
    DRUID = {
        watch  = { Curse = true, Poison = true },
        spells = { Curse = "Remove Curse", Poison = "Abolish Poison" },
    },
    MAGE = {
        watch  = { Curse = true },
        spells = { Curse = "Remove Lesser Curse" },
    },
    PALADIN = {
        watch  = { Magic = true, Disease = true, Poison = true },
        spells = { Magic = "Cleanse", Disease = "Cleanse", Poison = "Cleanse" },
    },
    PRIEST = {
        watch  = { Magic = true, Disease = true },
        spells = { Magic = "Dispel Magic", Disease = "Cure Disease" },
    },
    SHAMAN = {
        watch  = { Curse = true, Disease = true, Poison = true },
        spells = { Curse = "Cleanse Spirit", Disease = "Cure Disease", Poison = "Cure Poison" },
    },
    -- Warlock, DK, Hunter, Rogue, Warrior: no native dispels. Defaults are
    -- left empty; alerts still fire if the user manually enables a type.
}

-- Generic fallback defaults. These are only the floor: class defaults take
-- precedence when a class entry exists, and existing saved values always
-- take precedence over both.
addon.defaults = {
    enabled = true,
    watchSelf = true,
    watchGroup = true,
    sound = "RaidWarning",
    selfTemplate = "You are CURSED with %spell%!",
    groupTemplate = "%target% has %spell% (from %caster%)",
    cooldown = 3.0,
    popupDuration = 3.0,
    fontSize = 24,
    watchedTypes = {
        Magic = false,
        Curse = false,
        Disease = false,
        Poison = false,
    },
    dispelSpells = {
        Magic = "",
        Curse = "",
        Disease = "",
        Poison = "",
    },
}

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            applyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local function applyClassDefaults(db, classToken)
    local cd = addon.CLASS_DEFAULTS[classToken]
    if not cd then return end

    -- watchedTypes: only fill when the table doesn't yet exist (fresh install
    -- or migrated v1.0). Once any watched-type key is saved, leave alone.
    if not db.watchedTypes then
        db.watchedTypes = {}
        for _, t in ipairs(addon.DEBUFF_TYPES) do
            db.watchedTypes[t] = (cd.watch and cd.watch[t]) and true or false
        end
    end

    -- dispelSpells: per-key fill. Don't overwrite anything the user set.
    db.dispelSpells = db.dispelSpells or {}
    if cd.spells then
        for t, s in pairs(cd.spells) do
            if not db.dispelSpells[t] or db.dispelSpells[t] == "" then
                db.dispelSpells[t] = s
            end
        end
    end
end

local function migrate(db)
    -- v1.0 → v1.1: scalar dispelSpell → dispelSpells.Curse
    if db.dispelSpell and (not db.dispelSpells or not db.dispelSpells.Curse) then
        db.dispelSpells = db.dispelSpells or {}
        db.dispelSpells.Curse = db.dispelSpell
        db.dispelSpell = nil
    end
end

-- Public: build addon.db with migration → class defaults → generic defaults.
-- Idempotent (existing values are never overwritten). Called at PLAYER_LOGIN
-- and after a "Reset to defaults" from the config panel.
function addon.SetupDB()
    CursiveDB = CursiveDB or {}
    migrate(CursiveDB)

    local _, classToken = UnitClass("player")
    applyClassDefaults(CursiveDB, classToken)
    applyDefaults(CursiveDB, addon.defaults)

    addon.db = CursiveDB
    addon.classToken = classToken
end

local frame = CreateFrame("Frame", "CursiveEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Cursive" then
        -- Defer most setup to PLAYER_LOGIN so UnitClass("player") is reliable.
        CursiveDB = CursiveDB or {}
        migrate(CursiveDB)
        addon.db = CursiveDB
    elseif event == "PLAYER_LOGIN" then
        addon.SetupDB()
        if addon.Dispel and addon.Dispel.Init then
            addon.Dispel.Init()
        end
        if addon.Detector and addon.Detector.Init then
            addon.Detector.Init()
        end
        if addon.Config and addon.Config.Init then
            addon.Config.Init()
        end
    end
end)

SLASH_CURSIVE1 = "/cursive"
SLASH_CURSIVE2 = "/curs"
SlashCmdList.CURSIVE = function(msg)
    if addon.Config and addon.Config.Open then
        addon.Config.Open()
    end
end

SLASH_CURSIVEDISPEL1 = "/cdispel"
SlashCmdList.CURSIVEDISPEL = function(msg)
    if addon.Dispel and addon.Dispel.CastNext then
        addon.Dispel.CastNext()
    end
end

SLASH_CURSIVEDEBUG1 = "/cursivedebug"
SlashCmdList.CURSIVEDEBUG = function(msg)
    if addon.Dispel and addon.Dispel.PrintState then
        addon.Dispel.PrintState()
    end
end
