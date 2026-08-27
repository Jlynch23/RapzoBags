local addonName = ...
local RB = _G.RapzoBags
if not RB then return end

local HUD = {}
RB.HUD = HUD
RB:RegisterModule("hud", HUD)

HUD.initialized = false
HUD.eventFrame = nil
HUD.cursorFrame = nil

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local CURSOR_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

local COLORS = {
    player = { 0.92, 0.66, 0.10 },
    target = { 0.92, 0.30, 0.09 },
    focus  = { 0.12, 0.72, 0.95 },
    border = { 0.10, 0.78, 0.96 },
    dark   = { 0.015, 0.020, 0.028 },
}

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function getConfig()
    local db = RB:EnsureDB()
    db.settings.hud = type(db.settings.hud) == "table" and db.settings.hud or {}
    local cfg = db.settings.hud

    if cfg.enabled == nil then cfg.enabled = RB:IsFeatureEnabled("hud") end
    if cfg.cursor == nil then cfg.cursor = true end
    if cfg.squareMinimap == nil then cfg.squareMinimap = true end
    if cfg.unitFrames == nil then cfg.unitFrames = true end
    if cfg.cursorSize == nil then cfg.cursorSize = 58 end

    cfg.cursorSize = math.max(36, math.min(90, tonumber(cfg.cursorSize) or 58))
    RB:SetFeatureEnabled("hud", cfg.enabled, true)
    return cfg
end

function HUD:IsEnabled()
    return getConfig().enabled ~= false and RB:IsFeatureEnabled("hud")
end

local function setRegionAlpha(region, alpha)
    if region and type(region.SetAlpha) == "function" then
        safeCall(region.SetAlpha, region, alpha)
    end
end

local function setShown(region, shown)
    if region and type(region.SetShown) == "function" then
        safeCall(region.SetShown, region, shown)
    end
end

local function createBarBackground(bar)
    if not bar or bar.RapzoBagsBackground then return end
    local ok, tex = pcall(bar.CreateTexture, bar, nil, "BACKGROUND")
    if not ok or not tex then return end
    tex:SetAllPoints(bar)
    tex:SetColorTexture(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], 0.94)
    bar.RapzoBagsBackground = tex
end

local function createBarEdges(bar, color)
    if not bar or bar.RapzoBagsEdges then return end
    local edges = {}
    for i = 1, 4 do
        local ok, tex = pcall(bar.CreateTexture, bar, nil, "OVERLAY")
        if not ok or not tex then return end
        tex:SetColorTexture(color[1], color[2], color[3], 0.72)
        edges[i] = tex
    end

    edges[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    edges[1]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    edges[1]:SetHeight(1)

    edges[2]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    edges[2]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    edges[2]:SetHeight(1)

    edges[3]:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    edges[3]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    edges[3]:SetWidth(1)

    edges[4]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    edges[4]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    edges[4]:SetWidth(1)

    bar.RapzoBagsEdges = edges
end

local function styleStatusBar(bar, color, lockColor)
    if not bar then return end
    safeCall(bar.SetStatusBarTexture, bar, WHITE_TEXTURE)
    if lockColor then
        bar.lockColor = true
        safeCall(bar.SetStatusBarColor, bar, color[1], color[2], color[3])
    end
    createBarBackground(bar)
    createBarEdges(bar, color)
end

local function findPlayerParts(frame)
    local content = frame and frame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthContainer = main and main.HealthBarsContainer
    local manaArea = main and main.ManaBarArea

    return {
        container = frame and frame.PlayerFrameContainer,
        main = main,
        healthContainer = healthContainer,
        health = healthContainer and healthContainer.HealthBar,
        power = manaArea and manaArea.ManaBar,
        name = _G.PlayerName or (main and main.PlayerName),
        level = _G.PlayerLevelText or (main and main.PlayerLevelText),
    }
end

local function findTargetParts(frame)
    local content = frame and frame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    local healthContainer = main and main.HealthBarsContainer

    return {
        container = frame and frame.TargetFrameContainer,
        main = main,
        healthContainer = healthContainer,
        health = healthContainer and healthContainer.HealthBar,
        power = main and main.ManaBar,
        name = main and main.Name,
        level = main and main.LevelText,
    }
end

local function hidePlayerArt(parts)
    local c = parts.container
    if not c then return end
    setRegionAlpha(c.PlayerPortrait, 0)
    setRegionAlpha(c.PlayerPortraitMask, 0)
    setRegionAlpha(c.FrameTexture, 0)
    setRegionAlpha(c.VehicleFrameTexture, 0)
    setRegionAlpha(c.AlternatePowerFrameTexture, 0)
    setRegionAlpha(c.FrameFlash, 0)
end

local function hideTargetArt(parts)
    local c = parts.container
    if c then
        setRegionAlpha(c.Portrait, 0)
        setRegionAlpha(c.PortraitMask, 0)
        setRegionAlpha(c.FrameTexture, 0)
        setRegionAlpha(c.Flash, 0)
        setRegionAlpha(c.BossPortraitFrameTexture, 0)
    end
    if parts.main then
        setRegionAlpha(parts.main.ReputationColor, 0)
    end
end

local function styleText(parts, color)
    if parts.name then
        safeCall(parts.name.ClearAllPoints, parts.name)
        safeCall(parts.name.SetPoint, parts.name, "BOTTOMLEFT", parts.healthContainer, "TOPLEFT", 3, 5)
        safeCall(parts.name.SetSize, parts.name, 170, 16)
        safeCall(parts.name.SetJustifyH, parts.name, "LEFT")
        safeCall(parts.name.SetTextColor, parts.name, 0.94, 0.96, 1.00)
    end

    if parts.level then
        safeCall(parts.level.ClearAllPoints, parts.level)
        safeCall(parts.level.SetPoint, parts.level, "BOTTOMRIGHT", parts.healthContainer, "TOPRIGHT", -3, 5)
        safeCall(parts.level.SetTextColor, parts.level, color[1], color[2], color[3])
    end
end

local function layoutBars(frame, parts, color)
    if not frame or not parts.healthContainer or not parts.health then return false end

    safeCall(parts.healthContainer.ClearAllPoints, parts.healthContainer)
    safeCall(parts.healthContainer.SetPoint, parts.healthContainer, "TOPLEFT", frame, "TOPLEFT", 6, -30)
    safeCall(parts.healthContainer.SetSize, parts.healthContainer, 220, 24)

    safeCall(parts.health.ClearAllPoints, parts.health)
    safeCall(parts.health.SetAllPoints, parts.healthContainer)
    styleStatusBar(parts.health, color, true)

    if parts.power then
        safeCall(parts.power.ClearAllPoints, parts.power)
        safeCall(parts.power.SetPoint, parts.power, "TOPLEFT", parts.healthContainer, "BOTTOMLEFT", 0, -3)
        safeCall(parts.power.SetSize, parts.power, 220, 11)
        safeCall(parts.power.SetStatusBarTexture, parts.power, WHITE_TEXTURE)
        createBarBackground(parts.power)
        createBarEdges(parts.power, { 0.34, 0.38, 0.46 })
    end

    styleText(parts, color)
    return true
end

function HUD:StyleUnitFrames()
    local cfg = getConfig()
    if not self:IsEnabled() or not cfg.unitFrames then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end

    if _G.PlayerFrame then
        local parts = findPlayerParts(_G.PlayerFrame)
        hidePlayerArt(parts)
        layoutBars(_G.PlayerFrame, parts, COLORS.player)
    end

    if _G.TargetFrame then
        local parts = findTargetParts(_G.TargetFrame)
        hideTargetArt(parts)
        layoutBars(_G.TargetFrame, parts, COLORS.target)
    end

    if _G.FocusFrame then
        local parts = findTargetParts(_G.FocusFrame)
        hideTargetArt(parts)
        layoutBars(_G.FocusFrame, parts, COLORS.focus)
    end
end

function HUD:CreateCursorRing()
    if self.cursorFrame then return self.cursorFrame end

    local frame = CreateFrame("Frame", "RapzoBagsCursorRing", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(10000)
    frame:EnableMouse(false)

    local outer = frame:CreateTexture(nil, "OVERLAY")
    outer:SetAllPoints(frame)
    outer:SetTexture(CURSOR_TEXTURE)
    outer:SetBlendMode("ADD")
    outer:SetVertexColor(0.10, 0.88, 1.00, 0.95)
    frame.outer = outer

    local inner = frame:CreateTexture(nil, "OVERLAY")
    inner:SetPoint("CENTER")
    inner:SetSize(38, 38)
    inner:SetTexture(CURSOR_TEXTURE)
    inner:SetBlendMode("ADD")
    inner:SetVertexColor(1.00, 0.68, 0.08, 0.72)
    frame.inner = inner

    frame:SetScript("OnUpdate", function(self)
        local cfg = getConfig()
        if not HUD:IsEnabled() or not cfg.cursor then
            self:Hide()
            return
        end

        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        if not x or not y or not scale or scale == 0 then return end

        local size = cfg.cursorSize
        self:SetSize(size, size)
        self.inner:SetSize(size * 0.66, size * 0.66)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        if not self:IsShown() then self:Show() end
    end)

    self.cursorFrame = frame
    return frame
end

local function createMinimapBorder()
    if not _G.Minimap or _G.Minimap.RapzoBagsSquareBorder then return end

    local edges = {}
    for i = 1, 4 do
        local tex = _G.Minimap:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.72)
        edges[i] = tex
    end

    edges[1]:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", -2, 2)
    edges[1]:SetPoint("TOPRIGHT", _G.Minimap, "TOPRIGHT", 2, 2)
    edges[1]:SetHeight(2)

    edges[2]:SetPoint("BOTTOMLEFT", _G.Minimap, "BOTTOMLEFT", -2, -2)
    edges[2]:SetPoint("BOTTOMRIGHT", _G.Minimap, "BOTTOMRIGHT", 2, -2)
    edges[2]:SetHeight(2)

    edges[3]:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", -2, 2)
    edges[3]:SetPoint("BOTTOMLEFT", _G.Minimap, "BOTTOMLEFT", -2, -2)
    edges[3]:SetWidth(2)

    edges[4]:SetPoint("TOPRIGHT", _G.Minimap, "TOPRIGHT", 2, 2)
    edges[4]:SetPoint("BOTTOMRIGHT", _G.Minimap, "BOTTOMRIGHT", 2, -2)
    edges[4]:SetWidth(2)

    _G.Minimap.RapzoBagsSquareBorder = edges
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
        return
    end

    if cfg.cursor then self:CreateCursorRing() end
    if cfg.squareMinimap then self:StyleMinimap() end
    if cfg.unitFrames then self:StyleUnitFrames() end
end

function HUD:SetEnabled(enabled)
    local cfg = getConfig()
    cfg.enabled = enabled and true or false
    RB:SetFeatureEnabled("hud", cfg.enabled, true)

    if not cfg.enabled then
        if self.cursorFrame then self.cursorFrame:Hide() end
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

    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            HUD:StyleUnitFrames()
            return
        end

        HUD:ScheduleApply(event == "PLAYER_ENTERING_WORLD" and 0.5 or 0.05)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            HUD:ScheduleApply(2.0)
        end
    end)

    self:ScheduleApply(0.5)
end

RB:RegisterCommand("hud", function(rest) HUD:HandleSlash(rest) end, "/rbags hud - cursor, minimapa y unit frames")
HUD:Initialize()
