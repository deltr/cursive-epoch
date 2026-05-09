Cursive = Cursive or {}
local addon = Cursive
local Alert = {}
addon.Alert = Alert

Alert.Sounds = {
    { key = "RaidWarning",  label = "Raid Warning",   type = "builtin", id = "RaidWarning" },
    { key = "ReadyCheck",   label = "Ready Check",    type = "builtin", id = "ReadyCheck" },
    { key = "AuctionOpen",  label = "Auction Open",   type = "builtin", id = "AuctionWindowOpen" },
    { key = "LevelUp",      label = "Level Up",       type = "builtin", id = "LevelUp" },
    { key = "MapPing",      label = "Map Ping",       type = "builtin", id = "MapPing" },
    { key = "TellMessage",  label = "Whisper",        type = "builtin", id = "TellMessage" },
    { key = "AlarmClock1",  label = "Alarm 1",        type = "builtin", id = "AlarmClockWarning1" },
    { key = "AlarmClock2",  label = "Alarm 2",        type = "builtin", id = "AlarmClockWarning2" },
    { key = "AlarmClock3",  label = "Alarm 3",        type = "builtin", id = "AlarmClockWarning3" },
    { key = "Alert1",       label = "Custom Alert 1 (file)", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert1.ogg" },
    { key = "Alert2",       label = "Custom Alert 2 (file)", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert2.ogg" },
    { key = "Alert3",       label = "Custom Alert 3 (file)", type = "file", path = "Interface\\AddOns\\Cursive\\Sounds\\alert3.ogg" },
}

function Alert.GetSoundByKey(key)
    for _, s in ipairs(Alert.Sounds) do
        if s.key == key then return s end
    end
    return nil
end

function Alert.PlayByKey(key)
    local s = Alert.GetSoundByKey(key)
    if not s then return end
    if s.type == "builtin" then
        PlaySound(s.id)
    elseif s.type == "file" then
        PlaySoundFile(s.path)
    end
end

local STATE_HIDDEN, STATE_FADEIN, STATE_HOLD, STATE_FADEOUT = 0, 1, 2, 3
local FADE_IN_TIME = 0.15
local FADE_OUT_TIME = 0.5

local banner

local function ensureBanner()
    if banner then return banner end

    banner = CreateFrame("Frame", "CursiveBannerFrame", UIParent)
    banner:SetFrameStrata("DIALOG")
    banner:SetWidth(600)
    banner:SetHeight(60)
    banner:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    banner:Hide()

    banner.text = banner:CreateFontString(nil, "OVERLAY")
    banner.text:SetFont(STANDARD_TEXT_FONT, (addon.db and addon.db.fontSize) or 24, "OUTLINE")
    banner.text:SetPoint("CENTER", banner, "CENTER", 0, 0)
    banner.text:SetTextColor(1, 1, 1, 1)

    banner.state = STATE_HIDDEN
    banner.elapsed = 0

    banner:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.state == STATE_FADEIN then
            local a = self.elapsed / FADE_IN_TIME
            if a >= 1 then
                a = 1
                self.state = STATE_HOLD
                self.elapsed = 0
            end
            self:SetAlpha(a)
        elseif self.state == STATE_HOLD then
            local hold = (addon.db and addon.db.popupDuration) or 3.0
            if self.elapsed >= hold then
                self.state = STATE_FADEOUT
                self.elapsed = 0
            end
        elseif self.state == STATE_FADEOUT then
            local a = 1 - (self.elapsed / FADE_OUT_TIME)
            if a <= 0 then
                a = 0
                self.state = STATE_HIDDEN
                self:Hide()
            end
            self:SetAlpha(a)
        end
    end)

    return banner
end

function Alert.RefreshFont()
    if banner and banner.text then
        banner.text:SetFont(STANDARD_TEXT_FONT, (addon.db and addon.db.fontSize) or 24, "OUTLINE")
    end
end

function Alert.ShowBanner(text)
    ensureBanner()
    banner.text:SetText(text or "")
    if banner.state == STATE_HIDDEN then
        banner:SetAlpha(0)
        banner:Show()
        banner.state = STATE_FADEIN
        banner.elapsed = 0
    else
        banner:SetAlpha(1)
        banner.state = STATE_HOLD
        banner.elapsed = 0
    end
end

function Alert.FormatTemplate(template, target, spell, caster)
    if not template or template == "" then return "" end
    return (string.gsub(template, "%%(%w+)%%", {
        target = target or "",
        spell = spell or "",
        caster = caster or "",
    }))
end

function Alert.Fire(unit, spellName, casterName)
    local db = addon.db
    if not db then return end
    local targetName = UnitName(unit) or unit or "?"
    local template
    if unit == "player" then
        template = db.selfTemplate
    else
        template = db.groupTemplate
    end
    local text = Alert.FormatTemplate(template, targetName, spellName, casterName)
    Alert.PlayByKey(db.sound)
    Alert.ShowBanner(text)
end

function Alert.TestPopup()
    if not addon.db then return end
    Alert.PlayByKey(addon.db.sound)
    local sample = Alert.FormatTemplate(addon.db.groupTemplate, "Bob", "Curse of Agony", "Skeletal Mage")
    Alert.ShowBanner(sample)
end
