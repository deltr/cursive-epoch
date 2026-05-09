Cursive = Cursive or {}
local addon = Cursive

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
    dispelSpell = "Remove Lesser Curse",
}

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = v
        end
    end
end

local frame = CreateFrame("Frame", "CursiveEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Cursive" then
        CursiveDB = CursiveDB or {}
        applyDefaults(CursiveDB, addon.defaults)
        addon.db = CursiveDB
    elseif event == "PLAYER_LOGIN" then
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
