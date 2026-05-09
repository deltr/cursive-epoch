Cursive = Cursive or {}
local addon = Cursive
local Detector = {}
addon.Detector = Detector

Detector.watched = {}
-- unitDebuffs[unit][spellName] = { type = dtype, exp = expirationTime }
Detector.unitDebuffs = {}
Detector.lastAlertAt = {}
Detector.lastGlobalAlertAt = 0
Detector.curseQueue = {}
Detector.inQueue = {}

local GLOBAL_CAP = 1.0

local function inRaid()
    return GetNumRaidMembers() > 0
end

local function inParty()
    return GetNumPartyMembers() > 0
end

local function enqueue(unit)
    if Detector.inQueue[unit] then return end
    table.insert(Detector.curseQueue, unit)
    Detector.inQueue[unit] = true
end

local function dequeue(unit)
    if not Detector.inQueue[unit] then return end
    Detector.inQueue[unit] = nil
    for i = 1, #Detector.curseQueue do
        if Detector.curseQueue[i] == unit then
            table.remove(Detector.curseQueue, i)
            return
        end
    end
end

-- Builds and pushes a filtered list of "<unit>:<type>" pairs to the secure
-- dispel button. The pairs are emitted in queue order (oldest unit first),
-- and within each unit in fixed type priority. Custom attribute writes are
-- safe in combat.
local function publishToDispel()
    if not (addon.Dispel and addon.Dispel.UpdateQueue) then return end
    local out = {}
    for _, unit in ipairs(Detector.curseQueue) do
        if UnitExists(unit)
            and not UnitIsDeadOrGhost(unit)
            and UnitIsConnected(unit) then
            local debuffs = Detector.unitDebuffs[unit]
            if debuffs and next(debuffs) then
                local activeTypes = {}
                for _, d in pairs(debuffs) do
                    activeTypes[d.type] = true
                end
                for _, t in ipairs(addon.DEBUFF_TYPES) do
                    if activeTypes[t] then
                        table.insert(out, unit .. ":" .. t)
                    end
                end
            end
        end
    end
    addon.Dispel.UpdateQueue(out)
end

function Detector.RebuildWatchList()
    local newWatched = {}
    if addon.db and addon.db.watchSelf then
        newWatched["player"] = true
    end
    if addon.db and addon.db.watchGroup then
        if inRaid() then
            local n = GetNumRaidMembers()
            for i = 1, n do
                newWatched["raid" .. i] = true
            end
        elseif inParty() then
            local n = GetNumPartyMembers()
            for i = 1, n do
                newWatched["party" .. i] = true
            end
        end
    end

    for unit in pairs(Detector.unitDebuffs) do
        if not newWatched[unit] then
            Detector.unitDebuffs[unit] = nil
        end
    end
    for key in pairs(Detector.lastAlertAt) do
        local unit = string.match(key, "^([^:]+)::")
        if unit and not newWatched[unit] then
            Detector.lastAlertAt[key] = nil
        end
    end

    local i = 1
    while i <= #Detector.curseQueue do
        local unit = Detector.curseQueue[i]
        if not newWatched[unit] then
            Detector.inQueue[unit] = nil
            table.remove(Detector.curseQueue, i)
        else
            i = i + 1
        end
    end

    Detector.watched = newWatched
    publishToDispel()
end

function Detector.ScanUnit(unit)
    local db = addon.db
    if not db or not db.enabled then return end
    if not Detector.watched[unit] then return end

    local now = GetTime()
    local cooldown = db.cooldown or 3.0
    local seen = Detector.unitDebuffs[unit] or {}
    local stillPresent = {}

    for i = 1, 40 do
        local name, _, _, _, dtype, _, expirationTime, unitCaster = UnitDebuff(unit, i)
        if not name then break end
        if dtype and dtype ~= "" and db.watchedTypes and db.watchedTypes[dtype] then
            stillPresent[name] = true
            local prev = seen[name]
            local prevExp = prev and prev.exp
            local key = unit .. "::" .. name
            local lastFiredAt = Detector.lastAlertAt[key] or 0

            local isNew = (prevExp ~= expirationTime)
            local cooldownOK = (now - lastFiredAt) >= cooldown
            local globalOK = (now - Detector.lastGlobalAlertAt) >= GLOBAL_CAP

            if isNew and cooldownOK and globalOK then
                local casterName = unitCaster and UnitName(unitCaster) or "Unknown"
                Detector.lastAlertAt[key] = now
                Detector.lastGlobalAlertAt = now
                addon.Alert.Fire(unit, name, casterName, dtype)
            end
            seen[name] = { type = dtype, exp = expirationTime }
        end
    end

    for name in pairs(seen) do
        if not stillPresent[name] then
            seen[name] = nil
        end
    end

    Detector.unitDebuffs[unit] = seen

    local hasAny = next(seen) ~= nil
    if hasAny then
        enqueue(unit)
    else
        dequeue(unit)
    end

    publishToDispel()
end

-- Re-scan every watched unit. Call this after the user toggles a watchedType
-- so existing debuffs of newly-enabled types get picked up immediately, and
-- entries for newly-disabled types get cleaned out.
function Detector.RescanAll()
    for unit in pairs(Detector.watched) do
        Detector.ScanUnit(unit)
    end
end

local frame = CreateFrame("Frame", "CursiveDetectorFrame")

local function onEvent(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD"
        or event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE" then
        Detector.RebuildWatchList()
    elseif event == "UNIT_AURA" then
        Detector.ScanUnit(arg1)
    end
end

function Detector.Init()
    frame:SetScript("OnEvent", onEvent)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:RegisterEvent("UNIT_AURA")
    Detector.RebuildWatchList()
end
