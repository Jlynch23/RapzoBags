local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local STYLE_CURRENT = 1
local STYLE_ICON = 2
local STYLE2_WIDTH = 260
local STYLE2_HEIGHT = 61
local STYLE2_EDGE = 0
local STYLE2_CONTENT = 0
local STYLE2_AURA = 20
local STYLE2_AURA_WIDTH = STYLE2_WIDTH
local STYLE2_AURA_Y = 24

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return false end
    return pcall(func, ...)
end

local function getConfig()
    local db = RB:EnsureDB()
    db.settings.hud = type(db.settings.hud) == "table" and db.settings.hud or {}
    local cfg = db.settings.hud
    local style = tonumber(cfg.style)
    if style ~= STYLE_CURRENT and style ~= STYLE_ICON then
        style = STYLE_CURRENT
    end
    cfg.style = style
    HUD.config = cfg
    return cfg
end

function HUD:GetStyle()
    return getConfig().style
end

function HUD:GetStyleAuraOffset(unit)
    if self:GetStyle() ~= STYLE_ICON then return 0 end
    if unit == "target" or unit == "focus" then
        return 0
    end
    return STYLE2_CONTENT
end

function HUD:GetStyleAuraRightInset(unit)
    if self:GetStyle() ~= STYLE_ICON then return 0 end
    if unit == "target" or unit == "focus" then
        return STYLE2_CONTENT
    end
    return 6
end

local function createSimpleEdges(parent, color)
    if parent.RapzoQoLEdges then return parent.RapzoQoLEdges end
    color = color or {0.95, 0.70, 0.16}
    local edges = {}
    for i = 1, 4 do
        local tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(color[1], color[2], color[3], 0.78)
        edges[i] = tex
    end
    edges[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
    edges[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    edges[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
    edges[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -1, -1)
    edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 1, 1)
    edges[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    edges[4]:SetWidth(1)
    parent.RapzoQoLEdges = edges
    return edges
end

local function ensureCastBar(display)
    if display.RapzoQoLCastBar then return display.RapzoQoLCastBar end

    local bar = CreateFrame("StatusBar", nil, display)
    bar:SetStatusBarTexture(WHITE_TEXTURE)
    bar:SetStatusBarColor(0.92, 0.63, 0.12)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetHeight(14)
    bar:SetPoint("TOPLEFT", display, "BOTTOMLEFT", STYLE2_CONTENT, -4)
    bar:SetPoint("RIGHT", display, "RIGHT", -6, 0)
    bar:SetFrameLevel(display:GetFrameLevel() + 3)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0.01, 0.02, 0.03, 0.97)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    text:SetJustifyH("CENTER")
    text:SetText("")

    bar.RapzoQoLEdges = createSimpleEdges(bar, display.color)
    bar.RapzoQoLBackground = bg

    bar.RapzoQoLText = text
    display.RapzoQoLCastBar = bar
    bar:Hide()
    return bar
end

local function setCastText(fontString, value)
    if not fontString then return end
    if isSecret(value) then
        fontString:SetText(value)
    else
        fontString:SetText(value or "")
    end
end

local function updateCastBar(unit)
    local display = HUD.unitDisplays and HUD.unitDisplays[unit]
    if not display then return end

    local bar = ensureCastBar(display)
    if HUD:GetStyle() ~= STYLE_ICON then
        bar:Hide()
        return
    end

    local name
    local isChannel = false

    if type(UnitCastingInfo) == "function" then
        name = UnitCastingInfo(unit)
    end

    if name == nil and type(UnitChannelInfo) == "function" then
        name = UnitChannelInfo(unit)
        if name ~= nil then isChannel = true end
    end

    if name == nil then
        bar:Hide()
        return
    end

    setCastText(bar.RapzoQoLText, name)
    if display.color then
        bar:SetStatusBarColor(display.color[1] or 0.92, display.color[2] or 0.63, display.color[3] or 0.12)
        for _, edge in ipairs(bar.RapzoQoLEdges or {}) do
            edge:SetColorTexture(0.015, 0.018, 0.024, 0.98)
        end
    end

    local duration
    if isChannel and type(UnitChannelDuration) == "function" then
        duration = UnitChannelDuration(unit)
    elseif type(UnitCastingDuration) == "function" then
        duration = UnitCastingDuration(unit)
    end

    if duration and type(bar.SetTimerDuration) == "function" then
        if isChannel and Enum and Enum.StatusBarFillDirection and Enum.StatusBarFillDirection.Reverse then
            safeCall(bar.SetTimerDuration, bar, duration, Enum.StatusBarFillDirection.Reverse)
        else
            safeCall(bar.SetTimerDuration, bar, duration)
        end
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
    end

    if type(HUD.ApplyClassResourceCastAnchor) == "function" then
        HUD:ApplyClassResourceCastAnchor(unit, bar)
    end

    bar:Show()
end

local function initAuraButton(button)
    button:SetSize(STYLE2_AURA, STYLE2_AURA)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    safeCall(button.SetIcon, button, icon)

    if type(button.CreateMaskTexture) == "function" and type(icon.AddMaskTexture) == "function" then
        local mask = button:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:AddMaskTexture(mask)
        button.RapzoQoLAuraMask = mask
    end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    safeCall(cooldown.SetDrawEdge, cooldown, false)
    safeCall(cooldown.SetDrawBling, cooldown, false)
    if type(cooldown.SetHideCountdownNumbers) == "function" then
        safeCall(cooldown.SetHideCountdownNumbers, cooldown, false)
    end
    if type(button.SetDurationCooldown) == "function" then
        safeCall(button.SetDurationCooldown, button, cooldown)
    end

    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    ring:SetColorTexture(0.95, 0.70, 0.16, 0.26)
    if button.RapzoQoLAuraMask and type(ring.AddMaskTexture) == "function" then
        ring:AddMaskTexture(button.RapzoQoLAuraMask)
    end
    button.RapzoQoLAuraGlow = ring
end

local function ensurePlayerAuraContainer(display)
    if display.RapzoQoLPlayerAuras then return display.RapzoQoLPlayerAuras end
    if display.unit ~= "player" then return nil end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return nil
    end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, display, "CustomAuraContainerTemplate")
    if not ok or not container or type(container.AddAuraGroup) ~= "function" then
        return nil
    end

    container:SetSize(STYLE2_AURA_WIDTH, 22)
    container:SetPoint("BOTTOMLEFT", display, "TOPLEFT", STYLE2_CONTENT, STYLE2_AURA_Y)
    container:SetFrameLevel(display:GetFrameLevel() + 4)
    container:Show()

    local added = safeCall(container.AddAuraGroup, container, "rapzoPlayerHelpful", "HELPFUL", {
        maxFrameCount = 5,
        -- Let Blizzard's secret-safe AuraContainer engine discard long-lived
        -- utility buffs (flask, food, city buffs, etc.). The HUD strip is for
        -- short combat information only; the native BuffFrame remains complete.
        candidateFilters = {
            maxDuration = 120,
        },
        initializeFrame = initAuraButton,
        layout = {
            elementWidth = STYLE2_AURA,
            elementHeight = STYLE2_AURA,
            elementSpacing = 5,
            lineSpacing = 5,
        },
    })

    if not added then
        container:Hide()
        return nil
    end

    safeCall(container.SetUnit, container, "player")
    if type(container.SetEnabled) == "function" then
        safeCall(container.SetEnabled, container, true)
    end
    if type(container.UpdateAllAuras) == "function" then
        safeCall(container.UpdateAllAuras, container)
    end

    display.RapzoQoLPlayerAuras = container
    return container
end

local function ensureTargetAuraContainer(display)
    if not display or (display.unit ~= "target" and display.unit ~= "focus") then return nil end
    if display.RapzoQoLTargetAuras then return display.RapzoQoLTargetAuras end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return nil end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, display, "CustomAuraContainerTemplate")
    if not ok or not container or type(container.AddAuraGroup) ~= "function" then return nil end

    container:SetSize(STYLE2_AURA_WIDTH, 22)
    container:SetPoint("BOTTOMLEFT", display, "TOPLEFT", STYLE2_EDGE, STYLE2_AURA_Y)
    container:SetFrameLevel(display:GetFrameLevel() + 4)

    local added = safeCall(container.AddAuraGroup, container, "rapzoTargetHarmfulPlayer", "HARMFUL|PLAYER", {
        maxFrameCount = 5,
        candidateFilters = {},
        initializeFrame = initAuraButton,
        layout = {
            elementWidth = STYLE2_AURA,
            elementHeight = STYLE2_AURA,
            elementSpacing = 5,
            lineSpacing = 5,
        },
    })

    if not added then
        container:Hide()
        return nil
    end

    safeCall(container.SetUnit, container, display.unit)
    if type(container.SetEnabled) == "function" then
        safeCall(container.SetEnabled, container, true)
    end
    if type(container.UpdateAllAuras) == "function" then
        safeCall(container.UpdateAllAuras, container)
    end

    display.RapzoQoLTargetAuras = container
    return container
end

local function setTargetAurasEnabled(display, enabled)
    if not display or (display.unit ~= "target" and display.unit ~= "focus") then return end

    local container = display.RapzoQoLTargetAuras
    if enabled and not container then
        container = ensureTargetAuraContainer(display)
    end
    if not container then return end

    if type(container.SetEnabled) == "function" then
        safeCall(container.SetEnabled, container, enabled)
    end

    if enabled then
        container:Show()
        if type(container.SetUnit) == "function" then
            safeCall(container.SetUnit, container, display.unit)
        end
        if type(container.UpdateAllAuras) == "function" then
            safeCall(container.UpdateAllAuras, container)
        end
    else
        container:Hide()
    end
end

local function setPlayerAurasEnabled(display, enabled)
    if not display or display.unit ~= "player" then return end

    local container = display.RapzoQoLPlayerAuras
    if enabled and not container then
        container = ensurePlayerAuraContainer(display)
    end
    if not container then return end

    if type(container.SetEnabled) == "function" then
        safeCall(container.SetEnabled, container, enabled)
    end

    if enabled then
        container:Show()
        if type(container.UpdateAllAuras) == "function" then
            safeCall(container.UpdateAllAuras, container)
        end
    else
        container:Hide()
    end
end

local function setShellVisible(display, visible)
    if not display then return end

    if display.panel then
        display.panel:SetAlpha(visible and 1 or 0)
    end

    if display.accent then
        display.accent:SetAlpha(visible and 1 or 0)
    end

    for _, edge in ipairs(display.edges or {}) do
        edge:SetAlpha(visible and 1 or 0)
    end
end

local function setEdgesColor(edges, r, g, b, a)
    for _, edge in ipairs(edges or {}) do
        edge:SetColorTexture(r, g, b, a)
    end
end

local function ensureToxiDecor(display)
    if not display or not display.health then return end
    if display.RapzoQoLToxiDecor then return end

    local health = display.health

    local highlight = health:CreateTexture(nil, "OVERLAY")
    highlight:SetPoint("TOPLEFT", health, "TOPLEFT", 1, -1)
    highlight:SetPoint("TOPRIGHT", health, "TOPRIGHT", -1, -1)
    highlight:SetHeight(1)
    highlight:SetColorTexture(1, 1, 1, 0.10)

    local lowerShade = health:CreateTexture(nil, "OVERLAY")
    lowerShade:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 1, 1)
    lowerShade:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -1, 1)
    lowerShade:SetHeight(7)
    lowerShade:SetColorTexture(0, 0, 0, 0.10)

    display.RapzoQoLToxiDecor = {
        highlight = highlight,
        lowerShade = lowerShade,
    }
end

local function setToxiDecorVisible(display, visible)
    local decor = display and display.RapzoQoLToxiDecor
    if not decor then return end
    if decor.highlight then decor.highlight:SetShown(visible) end
    if decor.lowerShade then decor.lowerShade:SetShown(visible) end
end

local function applyToxiTypography(display)
    if not display then return end
    local fontPath = STANDARD_TEXT_FONT

    if display.nameText then
        display.nameText:SetTextColor(0.98, 0.98, 0.98)
        display.nameText:SetShadowColor(0, 0, 0, 1)
        display.nameText:SetShadowOffset(1, -1)
        if fontPath then
            pcall(display.nameText.SetFont, display.nameText, fontPath, 13, "OUTLINE")
        end
    end

    for _, text in ipairs({
        display.healthPercentText,
        display.healthValueText,
    }) do
        if text and fontPath then
            pcall(text.SetFont, text, fontPath, 11, "OUTLINE")
        end
    end

    if display.powerValueText and fontPath then
        pcall(display.powerValueText.SetFont, display.powerValueText, fontPath, 9, "OUTLINE")
    end
end

local function applyStyle1(display)
    if not display then return end

    setShellVisible(display, true)
    display:SetSize(240, 64)

    display.nameText:ClearAllPoints()
    display.nameText:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -8)
    display.nameText:SetPoint("RIGHT", display, "RIGHT", -6, 0)

    display.health:ClearAllPoints()
    display.health:SetHeight(24)
    display.health:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -25)
    display.health:SetPoint("RIGHT", display, "RIGHT", -6, 0)

    display.power:ClearAllPoints()
    display.power:SetHeight(10)
    display.power:SetPoint("TOPLEFT", display.health, "BOTTOMLEFT", 0, -4)
    display.power:SetPoint("RIGHT", display.health, "RIGHT", 0, 0)

    if display.unitTag then display.unitTag:Show() end
    if display.healthPercentText then display.healthPercentText:Hide() end
    if display.healthValueText then display.healthValueText:Hide() end
    if display.powerValueText then display.powerValueText:Hide() end
    if display.RapzoQoLUnitIcon then display.RapzoQoLUnitIcon:Hide() end
    if display.RapzoQoLCastBar then display.RapzoQoLCastBar:Hide() end
    setToxiDecorVisible(display, false)

    if display.color then
        setEdgesColor(display.health and display.health.RapzoQoLEdges, display.color[1], display.color[2], display.color[3], 0.60)
    end
    setEdgesColor(display.power and display.power.RapzoQoLEdges, 0.22, 0.28, 0.38, 0.60)

    setPlayerAurasEnabled(display, false)
    setTargetAurasEnabled(display, false)
end

local function applyStyle2(display)
    if not display then return end

    -- Rapzo QoL / ToxiUI-inspired:
    -- name floats above, health is the visual anchor and the power bar stays thin.
    -- No portrait, no exterior panel and no decorative shell.
    setShellVisible(display, false)
    display:SetSize(STYLE2_WIDTH, STYLE2_HEIGHT)

    display.health:ClearAllPoints()
    display.health:SetHeight(34)
    display.health:SetPoint("TOPLEFT", display, "TOPLEFT", STYLE2_EDGE, -17)
    display.health:SetPoint("RIGHT", display, "RIGHT", -STYLE2_EDGE, 0)

    display.power:ClearAllPoints()
    display.power:SetHeight(8)
    display.power:SetPoint("TOPLEFT", display.health, "BOTTOMLEFT", 0, -2)
    display.power:SetPoint("RIGHT", display.health, "RIGHT", 0, 0)

    display.nameText:ClearAllPoints()
    display.nameText:SetHeight(14)
    display.nameText:SetPoint("BOTTOMLEFT", display.health, "TOPLEFT", 2, 2)
    display.nameText:SetPoint("RIGHT", display.health, "RIGHT", -2, 0)
    display.nameText:SetJustifyH("LEFT")

    if display.unitTag then display.unitTag:Hide() end
    if display.healthPercentText then display.healthPercentText:Show() end
    if display.healthValueText then display.healthValueText:Show() end
    if display.powerValueText then display.powerValueText:Show() end

    if display.RapzoQoLUnitIcon then
        display.RapzoQoLUnitIcon:Hide()
    end

    ensureToxiDecor(display)
    setToxiDecorVisible(display, true)
    applyToxiTypography(display)

    -- ToxiUI-like black outline: let the class/reaction color be the fill,
    -- not the border. This keeps the frame readable over every zone.
    setEdgesColor(display.health.RapzoQoLEdges, 0.01, 0.01, 0.01, 1.00)
    setEdgesColor(display.power.RapzoQoLEdges, 0.01, 0.01, 0.01, 1.00)

    if display.health.RapzoQoLBackground then
        display.health.RapzoQoLBackground:SetColorTexture(0.025, 0.028, 0.035, 0.98)
    end
    if display.power.RapzoQoLBackground then
        display.power.RapzoQoLBackground:SetColorTexture(0.012, 0.015, 0.020, 0.99)
    end
    display.power:SetStatusBarColor(0.11, 0.14, 0.18, 1)

    local castBar = ensureCastBar(display)
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -5)
    castBar:SetPoint("RIGHT", display, "RIGHT", 0, 0)
    setEdgesColor(castBar.RapzoQoLEdges, 0.01, 0.01, 0.01, 1.00)
    if castBar.RapzoQoLBackground then
        castBar.RapzoQoLBackground:SetColorTexture(0.012, 0.015, 0.020, 0.99)
    end

    if type(HUD.ApplyClassResourceCastAnchor) == "function" then
        HUD:ApplyClassResourceCastAnchor(display.unit, castBar)
    end

    setPlayerAurasEnabled(display, display.unit == "player")
    setTargetAurasEnabled(display, display.unit == "target" or display.unit == "focus")
    updateCastBar(display.unit)
end

local function applyDisplayStyle(display)
    if HUD:GetStyle() == STYLE_ICON then
        applyStyle2(display)
    else
        applyStyle1(display)
    end
end

function HUD:ApplyFrameStyle(unit)
    if unit then
        applyDisplayStyle(self.unitDisplays and self.unitDisplays[unit])
        return
    end

    for _, key in ipairs({"player", "target", "focus"}) do
        applyDisplayStyle(self.unitDisplays and self.unitDisplays[key])
    end

    if type(self.ReanchorAuras) == "function" then
        self:ReanchorAuras()
    end
end

function HUD:SetStyle(style)
    style = tonumber(style)
    if style ~= STYLE_CURRENT and style ~= STYLE_ICON then
        RB:Print("Uso: /rapzo hud style 1|2")
        return false
    end

    local cfg = getConfig()
    cfg.style = style
    self:ApplyFrameStyle()

    if style == STYLE_CURRENT then
        RB:Print("HUD frames: ESTILO 1 (actual).")
    else
        RB:Print("HUD frames: ESTILO 2 TOXI (sin iconos, health principal + power fino).")
    end

    if type(self.RefreshPreview) == "function" then
        self:RefreshPreview()
    end
    return true
end

if type(hooksecurefunc) == "function" then
    if type(HUD.CreateUnitDisplays) == "function" then
        hooksecurefunc(HUD, "CreateUnitDisplays", function()
            HUD:ApplyFrameStyle()
        end)
    end

    if type(HUD.UpdateUnitFrames) == "function" then
        hooksecurefunc(HUD, "UpdateUnitFrames", function(_, unit)
            HUD:ApplyFrameStyle(unit)
        end)
    end
end

local castEvents = CreateFrame("Frame")
HUD.StyleEvents = castEvents

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
}) do
    pcall(castEvents.RegisterEvent, castEvents, event)
end

castEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        HUD:ApplyFrameStyle("target")
        updateCastBar("target")
        return
    elseif event == "PLAYER_FOCUS_CHANGED" then
        HUD:ApplyFrameStyle("focus")
        updateCastBar("focus")
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        HUD:ApplyFrameStyle()
        updateCastBar("player")
        updateCastBar("target")
        updateCastBar("focus")
        return
    end

    if unit == "player" or unit == "target" or unit == "focus" then
        updateCastBar(unit)
    end
end)

local baseHandleSlash = HUD.HandleSlash
function HUD:HandleSlash(rest)
    rest = tostring(rest or "")
    local part, value = rest:match("^(%S+)%s*(%S*)$")
    part = string.lower(part or "")
    value = string.lower(value or "")

    if part == "style" then
        if value == "" then
            RB:Print("HUD frame style actual: " .. tostring(self:GetStyle()) .. " | usa /rapzo hud style 1|2")
            return
        end
        self:SetStyle(value)
        return
    elseif part == "preview" then
        if type(self.TogglePreview) == "function" then
            self:TogglePreview(value)
        else
            RB:Print("Preview HUD todavia no esta disponible.")
        end
        return
    end

    return baseHandleSlash(self, rest)
end

if C_Timer and C_Timer.After then
    C_Timer.After(0.6, function() HUD:ApplyFrameStyle() end)
    C_Timer.After(2.0, function() HUD:ApplyFrameStyle() end)
else
    HUD:ApplyFrameStyle()
end
