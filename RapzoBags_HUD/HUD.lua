local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

local HUD = {}
RB.HUD = HUD
RB:RegisterModule("hud", HUD)

HUD.initialized = false
HUD.eventFrame = nil
HUD.cursorFrame = nil
HUD.minimapBorder = nil
HUD.unitDisplays = {}
HUD.config = nil

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local CURSOR_ATLAS = "GarrLanding-CircleGlow"

local COLORS = {
    player = { 0.92, 0.66, 0.10 },
    target = { 0.92, 0.30, 0.09 },
    focus  = { 0.12, 0.72, 0.95 },
    border = { 0.10, 0.78, 0.96 },
    dark   = { 0.015, 0.020, 0.028 },
    power  = { 0.22, 0.28, 0.38 },
}

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function getUnitClassColor(unit, fallback, requirePlayer)
    fallback = fallback or { 0.92, 0.66, 0.10 }

    if requirePlayer and type(UnitIsPlayer) == "function" then
        local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
        if not okPlayer or isSecret(isPlayer) or isPlayer ~= true then
            return fallback
        end
    end

    if type(UnitClass) ~= "function" or type(RAID_CLASS_COLORS) ~= "table" then
        return fallback
    end

    local okClass, _, classFile = pcall(UnitClass, unit)
    if not okClass or not classFile or isSecret(classFile) then
        return fallback
    end

    local classColor = RAID_CLASS_COLORS[classFile]
    if not classColor then
        return fallback
    end

    return {
        classColor.r or fallback[1],
        classColor.g or fallback[2],
        classColor.b or fallback[3],
    }
end

local function getConfig()
    local db = RB:EnsureDB()
    db.settings.hud = type(db.settings.hud) == "table" and db.settings.hud or {}
    local cfg = db.settings.hud

    if cfg.enabled == nil then cfg.enabled = RB:IsFeatureEnabled("hud") end
    if cfg.cursor == nil then cfg.cursor = true end
    if cfg.squareMinimap == nil then cfg.squareMinimap = true end
    if cfg.unitFrames == nil then cfg.unitFrames = true end
    if cfg.cursorSize == nil then cfg.cursorSize = 50 end

    cfg.cursorSize = math.max(36, math.min(90, tonumber(cfg.cursorSize) or 58))
    RB:SetFeatureEnabled("hud", cfg.enabled, true)
    HUD.config = cfg
    return cfg
end

function HUD:IsEnabled()
    local cfg = self.config or getConfig()
    return cfg.enabled ~= false and RB:IsFeatureEnabled("hud")
end

local function setRegionAlpha(region, alpha)
    if region and type(region.SetAlpha) == "function" then
        safeCall(region.SetAlpha, region, alpha)
    end
end

local function setSecretSafeText(fontString, value)
    if not fontString then return end

    if isSecret(value) then
        -- FontString:SetText can consume secret strings directly.
        fontString:SetText(value)
        return
    end

    fontString:SetText(value or "")
end

local function createEdges(parent, color, alpha, thickness)
    local edges = {}
    thickness = thickness or 1
    alpha = alpha or 0.72

    for i = 1, 4 do
        local tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(color[1], color[2], color[3], alpha)
        edges[i] = tex
    end

    edges[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
    edges[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    edges[1]:SetHeight(thickness)

    edges[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    edges[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    edges[2]:SetHeight(thickness)

    edges[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
    edges[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    edges[3]:SetWidth(thickness)

    edges[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    edges[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    edges[4]:SetWidth(thickness)

    return edges
end

local function createBar(parent, height, color)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE_TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetHeight(height)
    bar:SetStatusBarColor(color[1], color[2], color[3])

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], 0.96)

    createEdges(bar, color, 0.60, 1)
    return bar
end

local function hidePlayerStaticArt()
    local frame = _G.PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    if container then
        setRegionAlpha(container.PlayerPortrait, 0)
        setRegionAlpha(container.PlayerPortraitMask, 0)
        setRegionAlpha(container.FrameTexture, 0)
        setRegionAlpha(container.VehicleFrameTexture, 0)
        setRegionAlpha(container.AlternatePowerFrameTexture, 0)
        setRegionAlpha(container.FrameFlash, 0)
    end

    local content = frame and frame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    if main then
        setRegionAlpha(_G.PlayerName or main.PlayerName, 0)
        setRegionAlpha(_G.PlayerLevelText or main.PlayerLevelText, 0)

        local healthContainer = main.HealthBarsContainer
        if healthContainer then
            setRegionAlpha(healthContainer, 0)
        end

        local manaArea = main.ManaBarArea
        if manaArea and manaArea.ManaBar then
            setRegionAlpha(manaArea.ManaBar, 0)
        end
    end

    local contextual = content and content.PlayerFrameContentContextual
    if contextual then setRegionAlpha(contextual, 0) end
end

local function hideTargetStaticArt(frame)
    if not frame then return end

    local container = frame.TargetFrameContainer
    if container then
        setRegionAlpha(container.Portrait, 0)
        setRegionAlpha(container.PortraitMask, 0)
        setRegionAlpha(container.FrameTexture, 0)
        setRegionAlpha(container.Flash, 0)
        setRegionAlpha(container.BossPortraitFrameTexture, 0)
    end

    local content = frame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    if main then
        setRegionAlpha(main.ReputationColor, 0)
        setRegionAlpha(main.Name, 0)
        setRegionAlpha(main.LevelText, 0)

        local healthContainer = main.HealthBarsContainer
        if healthContainer then setRegionAlpha(healthContainer, 0) end
        if main.ManaBar then setRegionAlpha(main.ManaBar, 0) end
    end

    local contextual = content and content.TargetFrameContentContextual
    if contextual then
        -- Keep auras and the raid marker functional/visible.
        setRegionAlpha(contextual.PvpIcon, 0)
        setRegionAlpha(contextual.PrestigePortrait, 0)
        setRegionAlpha(contextual.PrestigeBadge, 0)
        setRegionAlpha(contextual.PetBattleIcon, 0)
        setRegionAlpha(contextual.BossIcon, 0)
        setRegionAlpha(contextual.QuestIcon, 0)
    end
end

local function reapplyNativeArtHiding(frame)
    if not frame then return end

    if frame == _G.PlayerFrame then
        hidePlayerStaticArt()
        return
    end

    if frame == _G.TargetFrame or frame == _G.FocusFrame then
        hideTargetStaticArt(frame)
    end
end

local function createUnitDisplay(unit, nativeFrame, color)
    if HUD.unitDisplays[unit] then
        return HUD.unitDisplays[unit]
    end
    if not nativeFrame then return nil end

    -- This frame is owned entirely by RapzoBags. It is only anchored to the
    -- Blizzard frame; it never writes fields into protected Blizzard bars.
    local display = CreateFrame("Frame", nil, UIParent)
    display:SetSize(240, 64)

    if unit == "player" then
        display:SetPoint("TOPLEFT", nativeFrame, "TOPLEFT", -2, -18)
    else
        display:SetPoint("TOPRIGHT", nativeFrame, "TOPRIGHT", 2, -18)
    end

    display:SetFrameStrata("LOW")
    -- Keep our visual panel below Blizzard's aura container. The previous
    -- +15 frame level could cover target/focus buffs.
    display:SetFrameLevel(math.max(1, nativeFrame:GetFrameLevel() - 1))
    display:EnableMouse(false)

    local panel = display:CreateTexture(nil, "BACKGROUND")
    panel:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", 0, 0)
    panel:SetColorTexture(0.005, 0.009, 0.015, 0.93)

    local accent = display:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetColorTexture(color[1], color[2], color[3], 0.95)

    local displayEdges = createEdges(display, color, 0.30, 1)

    local name = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -8)
    name:SetPoint("RIGHT", display, "RIGHT", -6, 0)
    name:SetHeight(14)
    name:SetJustifyH("LEFT")
    name:SetTextColor(0.94, 0.96, 1.00)

    local health = createBar(display, 24, color)
    health:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -25)
    health:SetPoint("RIGHT", display, "RIGHT", -6, 0)

    local power = createBar(display, 10, COLORS.power)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -4)
    power:SetPoint("RIGHT", health, "RIGHT", 0, 0)

    local unitTag = display:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    unitTag:SetPoint("TOPRIGHT", display, "TOPRIGHT", -6, -8)
    unitTag:SetText(string.upper(unit))
    unitTag:SetTextColor(color[1], color[2], color[3])

    display.unit = unit
    display.nativeFrame = nativeFrame
    display.health = health
    display.power = power
    display.nameText = name
    display.unitTag = unitTag
    display.accent = accent
    display.edges = displayEdges
    display.color = color

    HUD.unitDisplays[unit] = display
    return display
end

local function applyDisplayColor(display, color)
    if not display or not color then return end

    display.color = color
    display.health:SetStatusBarColor(color[1], color[2], color[3])

    if display.accent then
        display.accent:SetColorTexture(color[1], color[2], color[3], 0.95)
    end

    if display.unitTag then
        display.unitTag:SetTextColor(color[1], color[2], color[3])
    end

    for _, edge in ipairs(display.edges or {}) do
        edge:SetColorTexture(color[1], color[2], color[3], 0.30)
    end
end

local function updateUnitDisplay(display)
    if not display or not display.nativeFrame then return end

    local nativeShown = display.nativeFrame:IsShown()
    if not nativeShown then
        display:Hide()
        return
    end

    display:Show()

    local unit = display.unit

    local fallback = COLORS[unit] or COLORS.target
    local color
    if unit == "player" then
        color = getUnitClassColor(unit, fallback, false)
    else
        color = getUnitClassColor(unit, fallback, true)
    end
    applyDisplayColor(display, color)

    local name = UnitName and UnitName(unit)
    setSecretSafeText(display.nameText, name)

    -- Midnight secret-safe path: do not inspect, compare, stringify, divide or
    -- branch on health/power values. StatusBar consumes them directly C-side.
    if UnitHealthMax and UnitHealth then
        local maxHealth = UnitHealthMax(unit)
        local health = UnitHealth(unit)
        display.health:SetMinMaxValues(0, maxHealth)
        display.health:SetValue(health)
    end

    if UnitPowerMax and UnitPower then
        local maxPower = UnitPowerMax(unit)
        local power = UnitPower(unit)
        display.power:SetMinMaxValues(0, maxPower)
        display.power:SetValue(power)
    end
end

function HUD:CreateUnitDisplays()
    local cfg = getConfig()
    if not self:IsEnabled() or not cfg.unitFrames then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end

    if _G.PlayerFrame then
        hidePlayerStaticArt()
        createUnitDisplay("player", _G.PlayerFrame, getUnitClassColor("player", COLORS.player, false))
    end

    if _G.TargetFrame then
        hideTargetStaticArt(_G.TargetFrame)
        createUnitDisplay("target", _G.TargetFrame, getUnitClassColor("target", COLORS.target, true))
    end

    if _G.FocusFrame then
        hideTargetStaticArt(_G.FocusFrame)
        createUnitDisplay("focus", _G.FocusFrame, getUnitClassColor("focus", COLORS.focus, true))
    end
end

function HUD:UpdateUnitFrames(unit)
    local cfg = self.config or getConfig()
    if not self:IsEnabled() or not cfg.unitFrames then return end

    if unit then
        local display = self.unitDisplays[unit]
        if display then updateUnitDisplay(display) end
        return
    end

    updateUnitDisplay(self.unitDisplays.player)
    updateUnitDisplay(self.unitDisplays.target)
    updateUnitDisplay(self.unitDisplays.focus)
end

function HUD:StyleUnitFrames()
    local cfg = getConfig()
    if not self:IsEnabled() or not cfg.unitFrames then return end

    if type(InCombatLockdown) ~= "function" or not InCombatLockdown() then
        self:CreateUnitDisplays()
    end
    self:UpdateUnitFrames()
end

function HUD:CreateCursorRing()
    if self.cursorFrame then return self.cursorFrame end

    local frame = CreateFrame("Frame", "RapzoBagsCursorRing", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(10000)
    frame:EnableMouse(false)

    local outer = frame:CreateTexture(nil, "OVERLAY")
    outer:SetAllPoints(frame)
    outer:SetAtlas(CURSOR_ATLAS, false)
    outer:SetBlendMode("ADD")
    outer:SetVertexColor(0.05, 0.88, 1.00, 0.95)
    frame.outer = outer

    frame:SetScript("OnUpdate", function(self)
        local cfg = HUD.config or getConfig()
        if cfg.enabled == false or not cfg.cursor then
            self:Hide()
            return
        end

        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        if not x or not y or not scale or scale == 0 then return end

        local size = cfg.cursorSize
        self:SetSize(size, size)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        if not self:IsShown() then self:Show() end
    end)

    self.cursorFrame = frame
    return frame
end

local function createMinimapBorder()
    if not _G.Minimap then return end
    if HUD.minimapBorder then return HUD.minimapBorder end

    HUD.minimapBorder = createEdges(_G.Minimap, COLORS.border, 0.72, 2)
    return HUD.minimapBorder
end

function HUD:StyleMinimap()
    local cfg = getConfig()
    if not self:IsEnabled() or not cfg.squareMinimap or not _G.Minimap then return end

    safeCall(_G.Minimap.SetMaskTexture, _G.Minimap, WHITE_TEXTURE)
    setRegionAlpha(_G.MinimapCompassTexture, 0)

    if _G.MinimapBackdrop and _G.MinimapBackdrop.StaticOverlayTexture then
        setRegionAlpha(_G.MinimapBackdrop.StaticOverlayTexture, 0)
    end

    createMinimapBorder()
end

function HUD:Apply()
    local cfg = getConfig()
    if not self:IsEnabled() then
        if self.cursorFrame then self.cursorFrame:Hide() end
        for _, display in pairs(self.unitDisplays) do
            display:Hide()
        end
        return
    end

    if cfg.cursor then
        local cursor = self:CreateCursorRing()
        if cursor and not cursor:IsShown() then cursor:Show() end
    end

    if cfg.squareMinimap then self:StyleMinimap() end
    if cfg.unitFrames then self:StyleUnitFrames() end
end

function HUD:SetEnabled(enabled)
    local cfg = getConfig()
    cfg.enabled = enabled and true or false
    RB:SetFeatureEnabled("hud", cfg.enabled, true)

    if not cfg.enabled then
        if self.cursorFrame then self.cursorFrame:Hide() end
        for _, display in pairs(self.unitDisplays) do
            display:Hide()
        end
        RB:Print("HUD visual: OFF. /reload restaura completamente minimapa y unit frames.")
    else
        self:Apply()
        RB:Print("HUD visual: ON")
    end
end

function HUD:SetPart(part, enabled)
    local cfg = getConfig()

    if part == "cursor" then
        cfg.cursor = enabled and true or false
        if not cfg.cursor and self.cursorFrame then self.cursorFrame:Hide() end
    elseif part == "minimap" then
        cfg.squareMinimap = enabled and true or false
        if not cfg.squareMinimap then
            RB:Print("Minimapa cuadrado OFF; usa /reload para restaurar la mascara redonda.")
        end
    elseif part == "frames" then
        cfg.unitFrames = enabled and true or false
        if not cfg.unitFrames then
            for _, display in pairs(self.unitDisplays) do display:Hide() end
            RB:Print("Unit frames minimalistas OFF; usa /reload para restaurar el arte original.")
        end
    else
        return false
    end

    if enabled then self:Apply() end
    return true
end

function HUD:HandleSlash(rest)
    rest = tostring(rest or "")
    local part, value = rest:match("^(%S+)%s*(%S*)$")
    part = string.lower(part or "status")
    value = string.lower(value or "")

    if part == "on" then
        self:SetEnabled(true)
        return
    elseif part == "off" then
        self:SetEnabled(false)
        return
    elseif part == "status" or part == "" then
        local cfg = getConfig()
        RB:Print(string.format(
            "HUD %s | cursor:%s | minimapa:%s | frames:%s",
            self:IsEnabled() and "ON" or "OFF",
            cfg.cursor and "ON" or "OFF",
            cfg.squareMinimap and "ON" or "OFF",
            cfg.unitFrames and "ON" or "OFF"
        ))
        return
    end

    if part == "cursor" or part == "minimap" or part == "frames" then
        if value ~= "on" and value ~= "off" then
            RB:Print("Uso: /rbags hud " .. part .. " on|off")
            return
        end

        self:SetPart(part, value == "on")
        RB:Print(string.format("HUD %s: %s", part, value:upper()))
        return
    end

    RB:Print("Uso: /rbags hud [status|on|off|cursor on|off|minimap on|off|frames on|off]")
end

function HUD:ScheduleApply(delay)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or 0, function()
            HUD:Apply()
        end)
    else
        self:Apply()
    end
end

function HUD:Initialize()
    if self.initialized then return end
    self.initialized = true

    getConfig()
    self:CreateCursorRing()

    local events = CreateFrame("Frame")
    self.eventFrame = events

    local function register(event)
        pcall(events.RegisterEvent, events, event)
    end

    register("PLAYER_LOGIN")
    register("PLAYER_ENTERING_WORLD")
    register("PLAYER_REGEN_ENABLED")
    register("PLAYER_TARGET_CHANGED")
    register("PLAYER_FOCUS_CHANGED")
    register("UNIT_HEALTH")
    register("UNIT_MAXHEALTH")
    register("UNIT_POWER_UPDATE")
    register("UNIT_MAXPOWER")
    register("UNIT_DISPLAYPOWER")
    register("UNIT_NAME_UPDATE")

    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            reapplyNativeArtHiding(_G.PlayerFrame)
            reapplyNativeArtHiding(_G.TargetFrame)
            reapplyNativeArtHiding(_G.FocusFrame)
            HUD:StyleUnitFrames()
            return
        end

        if event == "PLAYER_TARGET_CHANGED" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    reapplyNativeArtHiding(_G.TargetFrame)
                    HUD:UpdateUnitFrames("target")
                end)
            else
                reapplyNativeArtHiding(_G.TargetFrame)
                HUD:UpdateUnitFrames("target")
            end
            return
        elseif event == "PLAYER_FOCUS_CHANGED" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    reapplyNativeArtHiding(_G.FocusFrame)
                    HUD:UpdateUnitFrames("focus")
                end)
            else
                reapplyNativeArtHiding(_G.FocusFrame)
                HUD:UpdateUnitFrames("focus")
            end
            return
        elseif event == "UNIT_HEALTH"
            or event == "UNIT_MAXHEALTH"
            or event == "UNIT_POWER_UPDATE"
            or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER"
            or event == "UNIT_NAME_UPDATE"
        then
            if unit == "player" or unit == "target" or unit == "focus" then
                HUD:UpdateUnitFrames(unit)
            end
            return
        end

        HUD:ScheduleApply(event == "PLAYER_ENTERING_WORLD" and 0.5 or 0.05)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            HUD:ScheduleApply(2.0)
        end
    end)

    if type(hooksecurefunc) == "function" and type(TargetFrameMixin) == "table" and type(TargetFrameMixin.Update) == "function" then
        hooksecurefunc(TargetFrameMixin, "Update", function(frame)
            if frame == _G.TargetFrame or frame == _G.FocusFrame then
                reapplyNativeArtHiding(frame)
            end
        end)
    end

    self:ScheduleApply(0.5)
end

RB:RegisterCommand("hud", function(rest) HUD:HandleSlash(rest) end, "/rbags hud - cursor, minimapa y unit frames")
HUD:Initialize()
