local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

local AFK = {}
RB.AFK = AFK
RB:RegisterModule("afk", AFK)

AFK.frame = nil
AFK.eventFrame = nil
AFK.ticker = nil
AFK.afkStartedAt = nil
AFK.preview = false
AFK.initialized = false
AFK.lastStateReason = nil

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeAFKState()
    if type(UnitIsAFK) ~= "function" then
        return nil, "unavailable"
    end

    local ok, value = pcall(UnitIsAFK, "player")
    if not ok then
        return nil, "error"
    end
    if isSecret(value) then
        return nil, "secret"
    end

    return value == true, nil
end

local function getConfig()
    local db = RB:EnsureDB()
    db.settings.afk = type(db.settings.afk) == "table" and db.settings.afk or {}
    local cfg = db.settings.afk

    if cfg.enabled == nil then cfg.enabled = RB:IsFeatureEnabled("afk") end
    if cfg.opacity == nil then cfg.opacity = 0.90 end
    if cfg.showTimer == nil then cfg.showTimer = true end
    if cfg.showCharacter == nil then cfg.showCharacter = true end
    if cfg.showZone == nil then cfg.showZone = true end
    if cfg.showClock == nil then cfg.showClock = true end
    if cfg.showMoney == nil then cfg.showMoney = false end
    if cfg.hideInCombat == nil then cfg.hideInCombat = true end

    if cfg.opacity < 0.35 then cfg.opacity = 0.35 end
    if cfg.opacity > 1 then cfg.opacity = 1 end

    RB:SetFeatureEnabled("afk", cfg.enabled, true)
    return cfg
end

local function formatElapsed(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function getSpecName()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return nil
    end

    local okIndex, specIndex = pcall(GetSpecialization)
    if not okIndex or not specIndex or isSecret(specIndex) then
        return nil
    end

    local okInfo, _, specName = pcall(GetSpecializationInfo, specIndex)
    if not okInfo or not specName or isSecret(specName) then
        return nil
    end

    return tostring(specName)
end

local function getClassFile()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classFile = pcall(UnitClass, "player")
    if not ok or not classFile or isSecret(classFile) then return nil end
    return classFile
end

local function getZoneText()
    local zone = type(GetRealZoneText) == "function" and GetRealZoneText() or nil
    local subZone = type(GetSubZoneText) == "function" and GetSubZoneText() or nil

    if isSecret(zone) then zone = nil end
    if isSecret(subZone) then subZone = nil end

    zone = type(zone) == "string" and zone or ""
    subZone = type(subZone) == "string" and subZone or ""

    if subZone ~= "" and subZone ~= zone then
        if zone ~= "" then return subZone .. " · " .. zone end
        return subZone
    end
    if zone ~= "" then return zone end
    return "World of Warcraft"
end

local function getMoneyText()
    if type(GetMoney) ~= "function" then return nil end
    local ok, copper = pcall(GetMoney)
    if not ok or not copper or isSecret(copper) then return nil end

    if type(GetCoinTextureString) == "function" then
        local okText, text = pcall(GetCoinTextureString, copper)
        if okText and text and not isSecret(text) then
            return text
        end
    end

    return string.format("%dg", math.floor((tonumber(copper) or 0) / 10000))
end

function AFK:IsEnabled()
    return getConfig().enabled ~= false and RB:IsFeatureEnabled("afk")
end

function AFK:SetEnabled(enabled)
    local cfg = getConfig()
    cfg.enabled = enabled and true or false
    RB:SetFeatureEnabled("afk", cfg.enabled, true)

    if not cfg.enabled then
        self.preview = false
        self.afkStartedAt = nil
        self:HideScreen(true)
        RB:Print("Pantalla AFK: OFF")
    else
        RB:Print("Pantalla AFK: ON")
        self:RefreshState()
    end
end

function AFK:CreateFrame()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "RapzoBagsAFKFrame", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(900)
    frame:EnableMouse(false)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0.005, 0.009, 0.018, getConfig().opacity)
    frame.background = background

    local glow = frame:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("CENTER", frame, "CENTER", 0, 12)
    glow:SetSize(620, 380)
    glow:SetColorTexture(0.025, 0.08, 0.12, 0.28)
    frame.glow = glow

    local logo = frame:CreateTexture(nil, "OVERLAY")
    logo:SetPoint("CENTER", frame, "CENTER", 0, 150)
    logo:SetSize(78, 78)
    logo:SetTexture("Interface\\AddOns\\RapzoBags_Core\\Media\\RapzoBagsIcon.tga")
    frame.logo = logo

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -14)
    title:SetText("|cff38bdf8RAPZO BAGS|r")
    frame.title = title

    local afkText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    afkText:SetPoint("TOP", title, "BOTTOM", 0, -14)
    local fontPath = STANDARD_TEXT_FONT
    if (not fontPath or fontPath == "") and GameFontNormalHuge and GameFontNormalHuge.GetFont then
        fontPath = select(1, GameFontNormalHuge:GetFont())
    end
    if fontPath then
        pcall(afkText.SetFont, afkText, fontPath, 64, "OUTLINE")
    end
    afkText:SetText("AFK")
    afkText:SetTextColor(0.92, 0.96, 1.00)
    frame.afkText = afkText

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOP", afkText, "BOTTOM", 0, -12)
    accent:SetSize(230, 1)
    accent:SetColorTexture(0.22, 0.74, 0.97, 0.75)
    frame.accent = accent

    local character = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    character:SetPoint("TOP", accent, "BOTTOM", 0, -18)
    character:SetText("Player")
    frame.character = character

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail:SetPoint("TOP", character, "BOTTOM", 0, -7)
    detail:SetTextColor(0.72, 0.78, 0.86)
    frame.detail = detail

    local zone = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zone:SetPoint("TOP", detail, "BOTTOM", 0, -12)
    zone:SetTextColor(0.55, 0.67, 0.78)
    frame.zone = zone

    local timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timer:SetPoint("TOP", zone, "BOTTOM", 0, -20)
    timer:SetTextColor(0.22, 0.83, 0.98)
    frame.timer = timer

    local money = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    money:SetPoint("TOP", timer, "BOTTOM", 0, -10)
    frame.money = money

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 42)
    frame.footer = footer

    local quote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    quote:SetPoint("BOTTOM", footer, "TOP", 0, 8)
    quote:SetText("The inventory never sleeps.")
    frame.quote = quote

    local fadeIn = frame:CreateAnimationGroup()
    local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.35)
    fadeIn:SetScript("OnFinished", function()
        frame:SetAlpha(1)
    end)
    frame.fadeIn = fadeIn

    local fadeOut = frame:CreateAnimationGroup()
    local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.25)
    fadeOut:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)
    frame.fadeOut = fadeOut

    frame:SetScript("OnShow", function()
        AFK:StartTicker()
        AFK:UpdateDisplay()
    end)

    frame:SetScript("OnHide", function()
        AFK:StopTicker()
        if AFK.preview then
            AFK.preview = false
            AFK.afkStartedAt = nil
        end
    end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "RapzoBagsAFKFrame"
    end

    self.frame = frame
    return frame
end

function AFK:UpdateDisplay()
    local frame = self:CreateFrame()
    local cfg = getConfig()

    frame.background:SetColorTexture(0.005, 0.009, 0.018, cfg.opacity)

    local playerName = RB:GetPlayerNameSafe()
    local realmName = RB:GetRealmNameSafe()
    local specName = getSpecName()
    local classFile = getClassFile()

    local r, g, b = 0.92, 0.96, 1.00
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        r, g, b = color.r or r, color.g or g, color.b or b
    end

    frame.character:SetShown(cfg.showCharacter ~= false)
    frame.detail:SetShown(cfg.showCharacter ~= false)
    if cfg.showCharacter ~= false then
        frame.character:SetText(tostring(playerName or "Player"))
        frame.character:SetTextColor(r, g, b)
        local details = {}
        if specName and specName ~= "" then details[#details + 1] = specName end
        if realmName and realmName ~= "" then details[#details + 1] = tostring(realmName) end
        frame.detail:SetText(table.concat(details, " · "))
    end

    frame.zone:SetShown(cfg.showZone ~= false)
    if cfg.showZone ~= false then
        frame.zone:SetText(getZoneText())
    end

    frame.timer:SetShown(cfg.showTimer ~= false)
    if cfg.showTimer ~= false then
        local startedAt = self.afkStartedAt or (type(GetTime) == "function" and GetTime() or 0)
        local now = type(GetTime) == "function" and GetTime() or startedAt
        frame.timer:SetText("AFK · " .. formatElapsed(now - startedAt))
    end

    local moneyText = cfg.showMoney and getMoneyText() or nil
    frame.money:SetShown(moneyText ~= nil)
    if moneyText then frame.money:SetText(moneyText) end

    local footerParts = {}
    if cfg.showClock ~= false and type(date) == "function" then
        footerParts[#footerParts + 1] = date("%H:%M")
    end
    footerParts[#footerParts + 1] = "RapzoBags " .. tostring(RB.version or "")
    frame.footer:SetText(table.concat(footerParts, "   ·   "))
end

function AFK:StartTicker()
    if self.ticker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end

    self.ticker = C_Timer.NewTicker(1, function()
        if AFK.frame and AFK.frame:IsShown() then
            AFK:UpdateDisplay()
        end
    end)
end

function AFK:StopTicker()
    if self.ticker and type(self.ticker.Cancel) == "function" then
        self.ticker:Cancel()
    end
    self.ticker = nil
end

function AFK:ShowScreen()
    if not self:IsEnabled() then return end

    local cfg = getConfig()
    if cfg.hideInCombat and type(InCombatLockdown) == "function" and InCombatLockdown() then
        return
    end

    local frame = self:CreateFrame()
    if frame.fadeOut and frame.fadeOut:IsPlaying() then frame.fadeOut:Stop() end

    if not frame:IsShown() then
        frame:SetAlpha(1)
        frame:Show()
        if frame.fadeIn then
            frame.fadeIn:Stop()
            frame.fadeIn:Play()
        end
    else
        self:UpdateDisplay()
    end
end

function AFK:HideScreen(immediate)
    local frame = self.frame
    if not frame or not frame:IsShown() then
        self:StopTicker()
        return
    end

    if frame.fadeIn and frame.fadeIn:IsPlaying() then frame.fadeIn:Stop() end

    if immediate then
        if frame.fadeOut and frame.fadeOut:IsPlaying() then frame.fadeOut:Stop() end
        frame:Hide()
        frame:SetAlpha(1)
        return
    end

    if frame.fadeOut and not frame.fadeOut:IsPlaying() then
        frame.fadeOut:Play()
    else
        frame:Hide()
    end
end

function AFK:RefreshState()
    if self.preview then
        return
    end

    if not self:IsEnabled() then
        self.afkStartedAt = nil
        self:HideScreen(true)
        return
    end

    local cfg = getConfig()
    if cfg.hideInCombat and type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.lastStateReason = "combat"
        self:HideScreen(true)
        return
    end

    local isAFK, reason = safeAFKState()
    self.lastStateReason = reason

    -- Retail 12.x can return a secret value for UnitIsAFK during chat
    -- messaging lockdown. Never branch on that secret: fail closed and wait
    -- for a later unrestricted event/state refresh.
    if isAFK == nil then
        self:HideScreen(true)
        return
    end

    if isAFK then
        if not self.afkStartedAt then
            self.afkStartedAt = type(GetTime) == "function" and GetTime() or 0
        end
        self:ShowScreen()
    else
        self.afkStartedAt = nil
        self:HideScreen(false)
    end
end

function AFK:ScheduleRefresh(delay)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(tonumber(delay) or 0, function()
            AFK:RefreshState()
        end)
    else
        self:RefreshState()
    end
end

function AFK:TogglePreview()
    if self.preview and self.frame and self.frame:IsShown() then
        self.preview = false
        self.afkStartedAt = nil
        self:HideScreen(false)
        return
    end

    if not self:IsEnabled() then
        RB:Print("Pantalla AFK desactivada. Usa /rbags afk on.")
        return
    end

    self.preview = true
    self.afkStartedAt = type(GetTime) == "function" and GetTime() or 0
    self:ShowScreen()
    RB:Print("Vista previa AFK activa. Pulsa ESC o repite /rbags afk preview para salir.")
end

function AFK:HandleSlash(rest)
    rest = tostring(rest or "")
    local command = string.lower(rest:match("^(%S+)") or "")

    if command == "on" then
        self:SetEnabled(true)
        return
    elseif command == "off" then
        self:SetEnabled(false)
        return
    elseif command == "preview" or command == "test" or command == "show" then
        self:TogglePreview()
        return
    elseif command == "hide" then
        self.preview = false
        self.afkStartedAt = nil
        self:HideScreen(false)
        return
    elseif command == "status" or command == "" then
        local state, reason = safeAFKState()
        local stateText
        if state == nil then
            stateText = "RESTRINGIDO (" .. tostring(reason or "unknown") .. ")"
        else
            stateText = state and "AFK" or "ACTIVO"
        end
        RB:Print(string.format(
            "AFK Screen: %s | jugador: %s | visible: %s",
            self:IsEnabled() and "ON" or "OFF",
            stateText,
            self.frame and self.frame:IsShown() and "SI" or "NO"
        ))
        return
    end

    RB:Print("Uso: /rbags afk [status|on|off|preview|hide]")
end

function AFK:Initialize()
    if self.initialized then return end
    self.initialized = true

    getConfig()
    self:CreateFrame()

    local events = CreateFrame("Frame")
    self.eventFrame = events

    local function register(event)
        pcall(events.RegisterEvent, events, event)
    end

    register("PLAYER_LOGIN")
    register("PLAYER_ENTERING_WORLD")
    register("PLAYER_FLAGS_CHANGED")
    register("PLAYER_REGEN_DISABLED")
    register("PLAYER_REGEN_ENABLED")
    register("ZONE_CHANGED_NEW_AREA")

    events:SetScript("OnEvent", function(_, event, unitTarget)
        if event == "PLAYER_FLAGS_CHANGED" then
            if isSecret(unitTarget) then
                AFK.lastStateReason = "secret-event"
                AFK:HideScreen(true)
                return
            end
            if unitTarget ~= "player" then return end
            AFK:RefreshState()
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            if getConfig().hideInCombat then
                AFK.lastStateReason = "combat"
                AFK:HideScreen(true)
            end
            return
        end

        AFK:ScheduleRefresh(event == "PLAYER_ENTERING_WORLD" and 0.35 or 0.05)
    end)

    self:ScheduleRefresh(0.5)
end

RB:RegisterCommand("afk", function(rest) AFK:HandleSlash(rest) end, "/rbags afk [status|on|off|preview|hide] - configura la pantalla AFK")
AFK:Initialize()
