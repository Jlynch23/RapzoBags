local addonName = ...
local RB = _G.RapzoQoL or _G.RapzoBags
if not RB or not RB.HUD then return end

local HUD = RB.HUD
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local STYLE_CURRENT = 1
local STYLE_ICON = 2
local STYLE2_WIDTH = 296
local STYLE2_HEIGHT = 72
local STYLE2_LEFT = 66

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

function HUD:GetStyleAuraOffset()
    return self:GetStyle() == STYLE_ICON and STYLE2_LEFT or 0
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

local function ensureUnitIcon(display)
    if display.RapzoQoLUnitIcon then return display.RapzoQoLUnitIcon end

    local holder = CreateFrame("Frame", nil, display)
    holder:SetSize(54, 54)
    holder:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -9)
    holder:SetFrameLevel(display:GetFrameLevel() + 2)

    local bg = holder:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", holder, "TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -3, 3)
    bg:SetColorTexture(0.01, 0.02, 0.03, 0.98)

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -4, 4)
    icon:SetTexture(FALLBACK_ICON)

    if type(holder.CreateMaskTexture) == "function" and type(icon.AddMaskTexture) == "function" then
        local mask = holder:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:AddMaskTexture(mask)
        bg:AddMaskTexture(mask)
        holder.RapzoQoLMask = mask
    end

    local ring = holder:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(holder)
    ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    ring:SetBlendMode("ADD")
    ring:SetVertexColor(0.95, 0.70, 0.16, 0.98)

    holder.icon = icon
    holder.RapzoQoLRing = ring
    display.RapzoQoLUnitIcon = holder
    return holder
end

local function setClassIcon(icon, unit)
    if type(UnitClass) ~= "function" or type(CLASS_ICON_TCOORDS) ~= "table" then return false end

    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok or isSecret(classFile) or type(classFile) ~= "string" then return false end

    local coords = CLASS_ICON_TCOORDS[classFile]
    if type(coords) ~= "table" then return false end

    icon:SetTexture(CLASS_TEXTURE)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

local function setReferencePortrait(icon, unit)
    icon:SetTexCoord(0, 1, 0, 1)
    if type(SetPortraitTexture) == "function" then
        local ok = pcall(SetPortraitTexture, icon, unit)
        if ok then return true end
    end
    icon:SetTexture(FALLBACK_ICON)
    return false
end

local function updateUnitIcon(display)
    if not display then return end
    local holder = ensureUnitIcon(display)

    if HUD:GetStyle() ~= STYLE_ICON then
        holder:Hide()
        return
    end

    holder:Show()

    local color = display.color or {0.95, 0.70, 0.16}
    if holder.RapzoQoLRing then
        holder.RapzoQoLRing:SetVertexColor(color[1], color[2], color[3], 0.98)
    end

    local unit = display.unit
    local isPlayer = false

    if type(UnitIsPlayer) == "function" then
        local ok, value = pcall(UnitIsPlayer, unit)
        if ok and not isSecret(value) and value == true then
            isPlayer = true
        end
    end

    if isPlayer and setClassIcon(holder.icon, unit) then
        return
    end

    setReferencePortrait(holder.icon, unit)
end

local function ensureCastBar(display)
    if display.RapzoQoLCastBar then return display.RapzoQoLCastBar end

    local bar = CreateFrame("StatusBar", nil, display)
    bar:SetStatusBarTexture(WHITE_TEXTURE)
    bar:SetStatusBarColor(0.92, 0.63, 0.12)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetHeight(14)
    bar:SetPoint("TOPLEFT", display, "BOTTOMLEFT", STYLE2_LEFT, -4)
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
            edge:SetColorTexture(display.color[1] or 0.92, display.color[2] or 0.63, display.color[3] or 0.12, 0.78)
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
    button:SetSize(26, 26)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    safeCall(button.SetIcon, button, icon)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    safeCall(cooldown.SetDrawEdge, cooldown, false)
    safeCall(cooldown.SetDrawBling, cooldown, false)
    if type(button.SetDurationCooldown) == "function" then
        safeCall(button.SetDurationCooldown, button, cooldown)
    end

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints(button)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(0.95, 0.70, 0.16, 0.82)
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

    container:SetSize(224, 28)
    container:SetPoint("BOTTOMLEFT", display, "TOPLEFT", STYLE2_LEFT, 7)
    container:SetFrameLevel(display:GetFrameLevel() + 4)
    container:Show()

    local added = safeCall(container.AddAuraGroup, container, "rapzoPlayerHelpful", "HELPFUL", {
        maxFrameCount = 6,
        candidateFilters = {},
        initializeFrame = initAuraButton,
        layout = {
            elementWidth = 26,
            elementHeight = 26,
            elementSpacing = 4,
            lineSpacing = 4,
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
    if display.RapzoQoLUnitIcon then display.RapzoQoLUnitIcon:Hide() end
    if display.RapzoQoLCastBar then display.RapzoQoLCastBar:Hide() end
    setPlayerAurasEnabled(display, false)
end

local function applyStyle2(display)
    if not display then return end

    -- Estilo 2 "naked": el frame contenedor solo sirve como ancla.
    -- No se dibuja panel, linea superior ni borde exterior.
    setShellVisible(display, false)
    display:SetSize(STYLE2_WIDTH, STYLE2_HEIGHT)

    display.nameText:ClearAllPoints()
    display.nameText:SetPoint("TOPLEFT", display, "TOPLEFT", STYLE2_LEFT, -8)
    display.nameText:SetPoint("RIGHT", display, "RIGHT", -6, 0)

    display.health:ClearAllPoints()
    display.health:SetHeight(24)
    display.health:SetPoint("TOPLEFT", display, "TOPLEFT", STYLE2_LEFT, -25)
    display.health:SetPoint("RIGHT", display, "RIGHT", -6, 0)

    display.power:ClearAllPoints()
    display.power:SetHeight(10)
    display.power:SetPoint("TOPLEFT", display.health, "BOTTOMLEFT", 0, -4)
    display.power:SetPoint("RIGHT", display.health, "RIGHT", 0, 0)

    if display.unitTag then display.unitTag:Hide() end

    local icon = ensureUnitIcon(display)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", display, "TOPLEFT", 6, -9)
    icon:Show()
    updateUnitIcon(display)

    local castBar = ensureCastBar(display)
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", display, "BOTTOMLEFT", STYLE2_LEFT, -4)
    castBar:SetPoint("RIGHT", display, "RIGHT", -6, 0)
    if type(HUD.ApplyClassResourceCastAnchor) == "function" then
        HUD:ApplyClassResourceCastAnchor(display.unit, castBar)
    end

    setPlayerAurasEnabled(display, display.unit == "player")
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
        RB:Print("HUD frames: ESTILO 2 (icono + auras TOP + castbar BOT).")
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
